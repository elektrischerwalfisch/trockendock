#!/usr/bin/env bash
# wp-stack migrate: restore one backup from the project's import/ folder.
# Expects wp-content and one SQL dump directly in import/ (optional manifest.json).
# Restores wp-content, imports the database, rewrites URLs, then empties import/.

_WP_STACK_MIGRATE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_WP_STACK_MIGRATE_LIB}/common.sh"
# shellcheck source=db.sh
source "${_WP_STACK_MIGRATE_LIB}/db.sh"
# shellcheck source=urls.sh
source "${_WP_STACK_MIGRATE_LIB}/urls.sh"

wp_stack_migrate_usage() {
  cat <<'EOF'
Usage: wp-stack migrate [options]

Restore one backup into a project. By default restores wp-content, database,
and URLs (--only all). The backup is read from import/ in the project:

  import/wp-content/
  import/<dump>.sql or import/<dump>.sql.gz
  import/manifest.json   (optional)

No extra folder around those entries. Exactly one SQL dump. manifest.json
supplies the table prefix and source URL when present. Run from the project
directory, or pass --project.

With --yes and --only db or all, the project database is wiped before import.
A successful --yes then removes what it consumed from import/ and leaves the
empty folder. backups/ is never touched. Create import/ only for that run.
By default this only reports the plan (dry run). Add --yes to execute.

Options:
  --project <folder>           Project under $WEBSITES_ROOT (default: current directory)
  --only <mode>                What to restore: all (default), content, or db
  --wordpress-image <tag>      Override proposed WORDPRESS_IMAGE pin
  --mariadb-image <tag>        Override proposed MARIADB_IMAGE pin
  --php <x.y>                  PHP minor when composing a pin from backup WP version
  --yes                        Actually perform the migration (otherwise dry run)
  --chown-www                  After wp-content restore, chown to 33:33 (www-data; sudo)
  -h, --help                   Show this help

Image pins: dry-run prints the proposal; --yes writes them to .env before compose.
WP core comes from backup detect (manifest) when possible; PHP/MariaDB from the
current project pin, stack-defaults, or --php / --*-image overrides.

Examples:
  wp-stack migrate --project example-site
  wp-stack migrate --project example-site --yes
  wp-stack migrate --project example-site --only content --yes
  wp-stack migrate --project example-site --only db --yes
  wp-stack migrate --project example-site --php 8.2 --yes
EOF
}

# Set or update KEY=VALUE in a project's .env (uncomments if needed).
wp_stack_set_env_var() {
  local dir="$1" key="$2" val="$3"
  trockendock_set_env_var "$dir" "$key" "$val" || wp_stack_die "failed to set ${key} in ${dir}/.env"
  wp_stack_info "set ${key}=${val} in .env"
}

# Names of direct children in import/ that are not part of one backup.
wp_stack_migrate_unexpected_names() {
  local base="$1" entry name
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    name="$(basename "$entry")"
    case "$name" in
      wp-content|manifest.json|.gitkeep|*.sql|*.sql.gz) ;;
      *) printf '%s\n' "$name" ;;
    esac
  done < <(find "$base" -mindepth 1 -maxdepth 1 | sort)
}

wp_stack_migrate_layout_hint() {
  cat <<'EOF' >&2
Expected layout, with no extra folder around the backup:
  import/wp-content/
  import/<dump>.sql or import/<dump>.sql.gz
  import/manifest.json   (optional)
EOF
}

# Remove the backup payload from import/ after a successful migrate.
# Refuses to delete anything that is not a direct child of <project>/import.
wp_stack_migrate_clear_import() {
  local project_dir="$1" only_mode="$2" sql="$3"
  local project_real import_root resolved entry name

  project_real="$(cd "$project_dir" && pwd -P)"
  import_root="${project_real}/import"
  [[ -d "$import_root" ]] || wp_stack_die "import folder missing: ${import_root}"
  [[ ! -L "$import_root" ]] || wp_stack_die "refusing to clear import/: it is a symlink"
  resolved="$(cd "$import_root" && pwd -P)"
  [[ "$resolved" == "${project_real}/import" ]] || wp_stack_die "refusing to clear unexpected path: ${resolved}"

  case "$only_mode" in
    all)
      while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        name="$(basename "$entry")"
        [[ "$name" == ".gitkeep" ]] && continue
        rm -rf "$entry"
      done < <(find "$resolved" -mindepth 1 -maxdepth 1)
      wp_stack_info "emptied import/"
      ;;
    content)
      rm -rf "${resolved}/wp-content"
      wp_stack_info "removed import/wp-content"
      ;;
    db)
      name="$(basename "$sql")"
      [[ -n "$name" && "$sql" == "${resolved}/${name}" ]] || wp_stack_die "refusing to delete SQL outside import/"
      rm -f "${resolved}/${name}"
      wp_stack_info "removed import/${name}"
      ;;
  esac
}

# Human-readable label for --only mode (plan output).
wp_stack_migrate_mode_label() {
  case "$1" in
    content) echo "content (wp-content only)" ;;
    db)      echo "db (database + URL rewrite)" ;;
    all)     echo "all (wp-content + database + URLs)" ;;
  esac
}

# True if the SQL dump contains a Multisite network table for this prefix
# (or any *_blogs table when prefix is still unknown).
wp_stack_sql_is_multisite() {
  local sql="$1" prefix="${2:-}"
  [[ -n "$sql" && -f "$sql" && "$sql" != *.gz ]] || return 1
  if [[ -n "$prefix" ]]; then
    grep -qaoE "CREATE TABLE \`${prefix}blogs\`" "$sql" 2>/dev/null
    return $?
  fi
  grep -qaoE 'CREATE TABLE `[a-zA-Z][a-zA-Z0-9_]*_blogs`' "$sql" 2>/dev/null
}

# Print 1 if dump looks like subdomain Multisite, else 0 (path-based default).
wp_stack_sql_subdomain_install() {
  local sql="$1" flag
  [[ -n "$sql" && -f "$sql" && "$sql" != *.gz ]] || { echo 0; return 0; }
  flag="$(
    grep -aoE "subdomain_install','[01]'" "$sql" 2>/dev/null \
      | head -1 \
      | sed -E "s/.*'([01])'/\1/" \
      || true
  )"
  [[ "$flag" == "1" ]] && echo 1 || echo 0
}

# Detect WordPress $table_prefix from a plain .sql dump.
# Single site: first *_options table (e.g. wp_options → wp_).
# Multisite: prefer network tables (*_blogs / *_sitemeta), else *_options
# that are not blog-ID tables (*_2_options). Never use dm_2_ as base prefix.
wp_stack_detect_table_prefix_from_sql() {
  local sql="$1"
  local prefix="" candidate

  [[ -n "$sql" && -f "$sql" ]] || return 0
  [[ "$sql" == *.gz ]] && return 0

  # Network tables always use the base prefix (blog 1 has no numeric segment).
  prefix="$(
    grep -aoE 'CREATE TABLE `[a-zA-Z][a-zA-Z0-9_]*_(blogs|sitemeta)`' "$sql" 2>/dev/null \
      | head -1 \
      | sed -E 's/.*`([a-zA-Z0-9_]+_)(blogs|sitemeta)`/\1/' \
      || true
  )"
  if [[ -n "$prefix" ]]; then
    printf '%s' "$prefix"
    return 0
  fi

  # Prefer primary *_options; skip Multisite subsite tables (*_<id>_options).
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if [[ "$candidate" =~ _[0-9]+_$ ]]; then
      continue
    fi
    printf '%s' "$candidate"
    return 0
  done < <(
    grep -aoE 'CREATE TABLE `[a-zA-Z0-9_]+_options`' "$sql" 2>/dev/null \
      | sed -E 's/.*`([a-zA-Z0-9_]+_)options`/\1/' \
      | awk '!seen[$0]++'
  )

  # Fallback: first *_options (unusual dumps with only numbered tables).
  prefix="$(
    grep -aoE 'CREATE TABLE `[a-zA-Z0-9_]+_options`' "$sql" 2>/dev/null \
      | head -1 \
      | sed -E 's/.*`([a-zA-Z0-9_]+_)options`/\1/' \
      || true
  )"
  printf '%s' "$prefix"
}

# Resolve PHP minor for migrate pins: --php, then current WORDPRESS_IMAGE, then
# DEFAULT_WORDPRESS_IMAGE. Prints the minor or returns 1.
wp_stack_migrate_resolve_php_minor() {
  local php_override="$1" current_wp_image="$2"
  local parts php_minor=""

  if [[ -n "$php_override" ]]; then
    printf '%s' "$php_override"
    return 0
  fi
  if [[ -n "$current_wp_image" ]] && parts="$(trockendock_parse_wordpress_image_parts "$current_wp_image")"; then
    read -r _ php_minor <<<"$parts"
    [[ -n "$php_minor" ]] && {
      printf '%s' "$php_minor"
      return 0
    }
  fi
  if [[ -n "${DEFAULT_WORDPRESS_IMAGE:-}" ]] && parts="$(trockendock_parse_wordpress_image_parts "$DEFAULT_WORDPRESS_IMAGE")"; then
    read -r _ php_minor <<<"$parts"
    [[ -n "$php_minor" ]] && {
      printf '%s' "$php_minor"
      return 0
    }
  fi
  return 1
}

# Resolve migrate image pins into MIGRATE_PROPOSED_WORDPRESS_IMAGE /
# MIGRATE_PROPOSED_MARIADB_IMAGE and human-readable source notes
# (MIGRATE_PIN_WP_SOURCE / MIGRATE_PIN_MDB_SOURCE).
wp_stack_migrate_resolve_image_pins() {
  local wp_ver="$1"
  local current_wp_image="$2"
  local current_mdb_image="$3"
  local wp_override="$4"
  local mdb_override="$5"
  local php_override="$6"
  local php_minor="" wp_core=""

  MIGRATE_PROPOSED_WORDPRESS_IMAGE=""
  MIGRATE_PROPOSED_MARIADB_IMAGE=""
  MIGRATE_PIN_WP_SOURCE=""
  MIGRATE_PIN_MDB_SOURCE=""

  if [[ -n "$wp_override" ]]; then
    MIGRATE_PROPOSED_WORDPRESS_IMAGE="$wp_override"
    MIGRATE_PIN_WP_SOURCE="override (--wordpress-image)"
  elif [[ -n "$wp_ver" ]]; then
    if ! php_minor="$(wp_stack_migrate_resolve_php_minor "$php_override" "$current_wp_image")"; then
      MIGRATE_PIN_WP_SOURCE="unresolved (backup WP ${wp_ver}; need --php, a pinned WORDPRESS_IMAGE, or DEFAULT_WORDPRESS_IMAGE)"
    else
      MIGRATE_PROPOSED_WORDPRESS_IMAGE="$(trockendock_format_wordpress_image "$wp_ver" "$php_minor")"
      if [[ -n "$php_override" ]]; then
        MIGRATE_PIN_WP_SOURCE="backup WP ${wp_ver} + --php ${php_minor}"
      else
        MIGRATE_PIN_WP_SOURCE="backup WP ${wp_ver} + PHP ${php_minor} (from current/default pin)"
      fi
    fi
  elif [[ -n "$current_wp_image" ]] && trockendock_validate_wordpress_image "$current_wp_image" 2>/dev/null; then
    MIGRATE_PROPOSED_WORDPRESS_IMAGE="$current_wp_image"
    MIGRATE_PIN_WP_SOURCE="keep current project pin (no backup WP version detected)"
  elif [[ -n "${DEFAULT_WORDPRESS_IMAGE:-}" ]]; then
    MIGRATE_PROPOSED_WORDPRESS_IMAGE="$DEFAULT_WORDPRESS_IMAGE"
    MIGRATE_PIN_WP_SOURCE="stack-defaults (no backup WP version detected)"
  else
    MIGRATE_PIN_WP_SOURCE="unresolved (no backup WP version, no pinned current image, no stack-defaults)"
  fi

  if [[ -n "$mdb_override" ]]; then
    MIGRATE_PROPOSED_MARIADB_IMAGE="$mdb_override"
    MIGRATE_PIN_MDB_SOURCE="override (--mariadb-image)"
  elif [[ -n "$current_mdb_image" ]] && trockendock_validate_mariadb_image "$current_mdb_image" 2>/dev/null; then
    MIGRATE_PROPOSED_MARIADB_IMAGE="$current_mdb_image"
    MIGRATE_PIN_MDB_SOURCE="keep current project pin"
  elif [[ -n "${DEFAULT_MARIADB_IMAGE:-}" ]]; then
    MIGRATE_PROPOSED_MARIADB_IMAGE="$DEFAULT_MARIADB_IMAGE"
    MIGRATE_PIN_MDB_SOURCE="stack-defaults"
  else
    MIGRATE_PIN_MDB_SOURCE="unresolved (no pinned current MariaDB image, no stack-defaults, no --mariadb-image)"
  fi
}

wp_stack_migrate_print_image_pin_plan() {
  local wp_ver="$1"
  echo "  image pins:"
  echo "    WORDPRESS_IMAGE: ${MIGRATE_PROPOSED_WORDPRESS_IMAGE:-'(none)'}  [${MIGRATE_PIN_WP_SOURCE}]"
  echo "    MARIADB_IMAGE:   ${MIGRATE_PROPOSED_MARIADB_IMAGE:-'(none)'}  [${MIGRATE_PIN_MDB_SOURCE}]"
  if [[ -n "$wp_ver" && -n "${MIGRATE_PROPOSED_WORDPRESS_IMAGE:-}" ]]; then
    local parts pinned=""
    if parts="$(trockendock_parse_wordpress_image_parts "$MIGRATE_PROPOSED_WORDPRESS_IMAGE")"; then
      read -r pinned _ <<<"$parts"
      if [[ -n "$pinned" && "${pinned%%.*}" != "${wp_ver%%.*}" ]]; then
        wp_stack_info "WARNING: WordPress major mismatch — backup ${wp_ver} vs proposed ${pinned}."
        echo "  Importing into a different major version can trigger DB upgrades."
      fi
    fi
  fi
}

wp_stack_migrate_apply_image_pins() {
  local dir="$1"

  if [[ -z "${MIGRATE_PROPOSED_WORDPRESS_IMAGE:-}" || -z "${MIGRATE_PROPOSED_MARIADB_IMAGE:-}" ]]; then
    wp_stack_die "cannot apply image pins: ${MIGRATE_PIN_WP_SOURCE}; ${MIGRATE_PIN_MDB_SOURCE}"
  fi
  trockendock_validate_wordpress_image "$MIGRATE_PROPOSED_WORDPRESS_IMAGE" \
    || wp_stack_die "refusing invalid proposed WORDPRESS_IMAGE"
  trockendock_validate_mariadb_image "$MIGRATE_PROPOSED_MARIADB_IMAGE" \
    || wp_stack_die "refusing invalid proposed MARIADB_IMAGE"

  wp_stack_set_env_var "$dir" WORDPRESS_IMAGE "$MIGRATE_PROPOSED_WORDPRESS_IMAGE"
  wp_stack_set_env_var "$dir" MARIADB_IMAGE "$MIGRATE_PROPOSED_MARIADB_IMAGE"
  wp_stack_load_env "$dir"
}

# Wait until the db is fully initialized: a plain ping answers "alive" already
# during MariaDB's first-boot init phase, before users/databases exist. So we
# wait until the project's WP user can actually log in and query its database.
wp_stack_wait_for_db() {
  local dir="$1" i
  for ((i = 1; i <= 60; i++)); do
    if ( cd "$dir" && docker compose exec -T db \
        mariadb -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" -e 'SELECT 1;' "${WP_DB_NAME}" ) >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

# Drop and recreate the project database so CREATE TABLE in the dump succeeds.
# Only used by migrate --yes (not by wp-stack db import).
wp_stack_migrate_wipe_db() {
  local dir="$1"

  : "${WP_DB_ROOT_PASSWORD:?WP_DB_ROOT_PASSWORD missing in .env}"
  : "${WP_DB_NAME:?WP_DB_NAME missing in .env}"
  : "${WP_DB_USER:?WP_DB_USER missing in .env}"

  wp_stack_info "wiping database '${WP_DB_NAME}' before import"
  ( cd "$dir" && docker compose exec -T db mariadb -u root -p"${WP_DB_ROOT_PASSWORD}" -e \
    "DROP DATABASE IF EXISTS \`${WP_DB_NAME}\`;
     CREATE DATABASE \`${WP_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
     GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'%';
     FLUSH PRIVILEGES;" )
}

# Replace the project's wp-content with the backup copy.
wp_stack_migrate_restore_wpcontent() {
  local dir="$1" src="$2"
  local dest="${dir}/wp-content"

  if [ -e "$dest" ]; then
    if ! rm -rf "$dest" 2>/dev/null; then
      wp_stack_info "existing wp-content not removable as ${USER} — fixing ownership with sudo"
      sudo chown -R "${USER}:${USER}" "$dest"
      rm -rf "$dest"
    fi
  fi

  mkdir -p "$dest"
  cp -a "${src}/." "${dest}/"
  rm -rf "${dest}/upgrade-temp-backup"
  wp_stack_info "wp-content restored (owner ${USER})"
}

wp_stack_migrate() {
  local project="" do_run=0 chown_www=0 only_mode="all"
  local wordpress_image_override="" mariadb_image_override="" php_override=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        wp_stack_migrate_usage
        exit 0
        ;;
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --only)
        [[ $# -ge 2 ]] || wp_stack_die "--only requires a value (all, content, or db)"
        only_mode="$2"
        shift 2
        ;;
      --wordpress-image)
        [[ $# -ge 2 ]] || wp_stack_die "--wordpress-image requires a value"
        wordpress_image_override="$2"
        shift 2
        ;;
      --mariadb-image)
        [[ $# -ge 2 ]] || wp_stack_die "--mariadb-image requires a value"
        mariadb_image_override="$2"
        shift 2
        ;;
      --php)
        [[ $# -ge 2 ]] || wp_stack_die "--php requires a value"
        php_override="$2"
        shift 2
        ;;
      --yes)
        do_run=1
        shift
        ;;
      --dry-run)
        do_run=0
        shift
        ;;
      --chown-www)
        chown_www=1
        shift
        ;;
      *)
        wp_stack_die "unexpected argument: $1 (the backup is taken from import/ automatically)"
        ;;
    esac
  done

  case "$only_mode" in
    all|content|db) ;;
    *) wp_stack_die "invalid --only value: ${only_mode} (use all, content, or db)" ;;
  esac

  local do_content=0 do_db=0
  [[ "$only_mode" == "all" || "$only_mode" == "content" ]] && do_content=1
  [[ "$only_mode" == "all" || "$only_mode" == "db" ]] && do_db=1

  wp_stack_resolve_project "$project"
  local dir="$WP_STACK_PROJECT_DIR"
  wp_stack_load_env "$dir"

  local import_root="${dir}/import"
  [ -d "$import_root" ] || wp_stack_die "import folder does not exist: ${import_root}"

  local unexpected=() line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    unexpected+=("$line")
  done < <(wp_stack_migrate_unexpected_names "$import_root")
  if [[ ${#unexpected[@]} -gt 0 ]]; then
    wp_stack_info "import/ contains entries that are not part of one backup:"
    for line in "${unexpected[@]}"; do echo "    ${line}" >&2; done
    wp_stack_migrate_layout_hint
    wp_stack_die "import/ must contain only wp-content, one SQL dump, and optional manifest.json"
  fi

  local wpc="" sql=""
  if [[ -e "${import_root}/wp-content" && ! -d "${import_root}/wp-content" ]]; then
    wp_stack_die "import/wp-content must be a directory"
  fi
  if [[ -d "${import_root}/wp-content" ]]; then
    wpc="${import_root}/wp-content"
  fi

  local sql_files=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    sql_files+=("$line")
  done < <(find "$import_root" -mindepth 1 -maxdepth 1 -type f \( -name '*.sql' -o -name '*.sql.gz' \) | sort)

  if [[ "$do_content" -eq 1 && -z "$wpc" ]]; then
    wp_stack_migrate_layout_hint
    wp_stack_die "no wp-content directory in ${import_root}"
  fi
  if [[ ${#sql_files[@]} -gt 1 || ( "$do_db" -eq 1 && ${#sql_files[@]} -ne 1 ) ]]; then
    wp_stack_info "import/ must contain exactly one .sql or .sql.gz (found ${#sql_files[@]})"
    if [[ ${#sql_files[@]} -gt 0 ]]; then
      for line in "${sql_files[@]}"; do echo "    $(basename "$line")" >&2; done
    fi
    wp_stack_migrate_layout_hint
    wp_stack_die "ambiguous or missing SQL dump"
  fi
  if [[ ${#sql_files[@]} -eq 1 ]]; then
    sql="${sql_files[0]}"
  fi

  local manifest="" prefix="" src_url="" wp_ver=""
  if [[ -f "${import_root}/manifest.json" ]]; then
    manifest="${import_root}/manifest.json"
  fi

  if [[ -n "$manifest" ]]; then
    prefix="$(grep -oE '"prefix":"[^"]*"' "$manifest" | head -1 | sed -E 's/.*:"([^"]*)"/\1/' || true)"
    src_url="$(grep -oE '"url":"[^"]*"' "$manifest" | head -1 | sed -E 's/.*:"([^"]*)"/\1/' | sed 's#\\/#/#g' || true)"
    wp_ver="$(grep -oE '"version":"[^"]*"' "$manifest" | head -1 | sed -E 's/.*:"([^"]*)"/\1/' || true)"
  fi

  if [[ -z "$prefix" && -n "$sql" ]]; then
    prefix="$(wp_stack_detect_table_prefix_from_sql "$sql")"
  fi
  if [[ -z "$src_url" && -n "$sql" && "$sql" != *.gz ]]; then
    src_url="$(grep -aoE "'(siteurl|home)','https?://[^']+'" "$sql" | head -1 | sed -E "s/.*,'(https?:\/\/[^']+)'/\1/" || true)"
  fi
  if [[ -z "$src_url" && -n "${MIGRATION_SOURCE_URL:-}" ]]; then
    src_url="$MIGRATION_SOURCE_URL"
  fi

  local is_multisite=0 multisite_subdomain=0
  if [[ "$do_db" -eq 1 && -n "$sql" ]] && wp_stack_sql_is_multisite "$sql" "$prefix"; then
    is_multisite=1
    multisite_subdomain="$(wp_stack_sql_subdomain_install "$sql")"
  fi

  echo ""
  wp_stack_info "migrate plan for '${PROJECT_SLUG}' (${dir})"
  echo "  mode:          $(wp_stack_migrate_mode_label "$only_mode")"
  echo "  import:        ${import_root}"
  if [[ "$do_content" -eq 1 ]]; then
    echo "  wp-content:    ${wpc:-NOT FOUND}"
  else
    echo "  wp-content:    skipped"
  fi
  if [[ "$do_db" -eq 1 ]]; then
    echo "  sql dump:      ${sql:-NOT FOUND}"
    echo "  table prefix:  ${prefix:-(unknown — keep current .env)}"
    echo "  source URL:    ${src_url:-(unknown)}"
    echo "  target URL:    http://localhost:${WP_PORT}"
    if [[ "$is_multisite" -eq 1 ]]; then
      echo "  multisite:     yes (WP_MULTISITE=1, SUBDOMAIN=${multisite_subdomain}, domain=localhost:${WP_PORT})"
    else
      echo "  multisite:     no (single site / not detected)"
    fi
    echo "  database:      will be wiped before import (with --yes)"
  else
    echo "  sql dump:      skipped"
  fi
  echo "  WordPress:     backup ${wp_ver:-(unknown)} / current image ${WORDPRESS_IMAGE:-(unset)}"
  case "$only_mode" in
    all)     echo "  after --yes:   import/ emptied, folder kept" ;;
    content) echo "  after --yes:   import/wp-content removed" ;;
    db)      echo "  after --yes:   SQL dump removed from import/" ;;
  esac
  echo ""

  wp_stack_migrate_resolve_image_pins \
    "$wp_ver" \
    "${WORDPRESS_IMAGE:-}" \
    "${MARIADB_IMAGE:-}" \
    "$wordpress_image_override" \
    "$mariadb_image_override" \
    "$php_override"
  wp_stack_migrate_print_image_pin_plan "$wp_ver"
  echo ""

  if [[ "$do_content" -eq 1 ]]; then
    [[ -n "$wpc" ]] || wp_stack_die "no wp-content found in backup"
  fi
  if [[ "$do_db" -eq 1 ]]; then
    [[ -n "$sql" ]] || wp_stack_die "no .sql dump found in backup"
    [[ -n "$src_url" ]] || wp_stack_die "source URL not detected — add MIGRATION_SOURCE_URL to .env or use a backup with manifest.json"
  fi

  if [[ "$do_run" -eq 0 ]]; then
    wp_stack_info "dry run — no changes made. Re-run with --yes to execute (writes image pins to .env)."
    return 0
  fi

  local perm_note=""

  # Apply image pins before compose so containers use the proposed tags.
  wp_stack_migrate_apply_image_pins "$dir"

  # Apply Multisite .env before first compose up so wp-config gets the defines.
  if [[ "$is_multisite" -eq 1 ]]; then
    wp_stack_set_env_var "$dir" WP_MULTISITE 1
    wp_stack_set_env_var "$dir" WP_MULTISITE_SUBDOMAIN "$multisite_subdomain"
  fi

  if [[ "$do_content" -eq 1 ]]; then
    if [[ -n "$src_url" ]]; then
      wp_stack_set_env_var "$dir" MIGRATION_SOURCE_URL "$src_url"
    fi

    wp_stack_info "stopping stack"
    ( cd "$dir" && docker compose stop ) || true

    wp_stack_migrate_restore_wpcontent "$dir" "$wpc"

    if [[ "$chown_www" -eq 1 ]]; then
      wp_stack_info "setting wp-content owner to 33:33 (sudo)"
      if ! sudo chown -R 33:33 "${dir}/wp-content"; then
        perm_note="could not set wp-content owner to 33:33 (sudo failed)"
      fi
    else
      local owner_uid
      owner_uid="$(stat -c '%u' "${dir}/wp-content" 2>/dev/null || echo "")"
      if [[ "$owner_uid" != "33" ]]; then
        perm_note="wp-content owner is ${USER} (uid ${owner_uid:-?}), not the container user www-data (uid 33) — setting it requires sudo"
      fi
    fi

    wp_stack_info "starting stack"
    ( cd "$dir" && docker compose up -d )
  fi

  if [[ "$do_db" -eq 1 ]]; then
    [[ -n "$prefix" ]] && wp_stack_set_env_var "$dir" WP_TABLE_PREFIX "$prefix"
    wp_stack_set_env_var "$dir" MIGRATION_SOURCE_URL "$src_url"

    if [[ "$do_content" -eq 0 ]]; then
      wp_stack_info "starting stack"
      ( cd "$dir" && docker compose up -d )
    fi

    wp_stack_info "waiting for database"
    wp_stack_wait_for_db "$dir" || wp_stack_die "database did not become ready"

    wp_stack_migrate_wipe_db "$dir"
    ( cd "$dir" && wp_stack_db_import "$sql" )
    ( cd "$dir" && wp_stack_urls_replace --recreate )
  fi

  wp_stack_load_env "$dir"

  if [[ -x "$GENERATE_INDEX_SCRIPT" ]]; then
    "$GENERATE_INDEX_SCRIPT"
  fi

  wp_stack_migrate_clear_import "$dir" "$only_mode" "$sql"

  echo ""
  wp_stack_info "migration complete"
  echo "  site:          http://localhost:${WP_PORT}"
  echo "  phpMyAdmin:    http://localhost:${PMA_PORT}"
  if [[ "$do_db" -eq 1 ]]; then
    echo "  table prefix:  ${WP_TABLE_PREFIX:-wp_}"
  fi
  echo "  link hub:      ${LOCAL_DEV_INDEX_FILE}"
  echo ""
  echo "Next:"
  if [[ "$do_db" -eq 1 ]]; then
    echo "  - Log in and flush permalinks (Settings → Permalinks → Save)"
  fi
  if [[ -n "$perm_note" ]]; then
    echo ""
    wp_stack_info "wp-content permissions: ${perm_note}"
    echo "  If uploads or plugin/theme updates fail in wp-admin, set ownership manually:"
    echo "      (cd \"${dir}\" && docker compose stop && sudo chown -R 33:33 wp-content && docker compose up -d)"
  fi
}
