#!/usr/bin/env bash
# Guided WordPress / PHP / MariaDB image bump (dry-run first; --yes writes .env + compose).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

wp_stack_image_bump_usage() {
  cat <<'EOF'
Usage: wp-stack image bump [options]

Change pinned Compose image tags for an existing WordPress project.
Dry-run by default (prints current → target). Pass --yes to write .env via
shared pin helpers, unset shell image overrides, then pull/recreate services.

Options:
  --project <folder>           Project under $WEBSITES_ROOT (default: cwd)
  --wordpress-image <tag>      Full tag, e.g. wordpress:6.8.0-php8.3-apache
  --wordpress <core>           WP core x.y or x.y.z (with --php or current PHP)
  --php <x.y>                  PHP minor for WORDPRESS_IMAGE (keeps/sets WP core)
  --mariadb-image <tag>        Full tag, e.g. mariadb:10.11
  --mariadb <x.y>              MariaDB minor → mariadb:<x.y>
  --yes                        Write pins + compose apply (default: dry-run only)
  --skip-compose               With --yes: write .env only (no pull/recreate)
  --no-index                   With --yes: skip link hub refresh
  -h, --help                   Show this help

Hub tags:
  https://hub.docker.com/_/wordpress/tags
  https://hub.docker.com/_/mariadb/tags

Examples:
  wp-stack image bump --project kundin-a --wordpress 6.8.0 --php 8.3
  wp-stack image bump --project kundin-a --mariadb 10.11 --yes
  wp-stack image bump --wordpress-image wordpress:6.7.2-php8.2-apache --yes
EOF
}

wp_stack_image_bump_read_env_var() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

wp_stack_image_bump_major() {
  local ver="$1"
  printf '%s' "${ver%%.*}"
}

wp_stack_image_bump_refresh_hub() {
  if [[ ! -x "${GENERATE_INDEX_SCRIPT:-}" ]]; then
    wp_stack_info "WARNING: GENERATE_INDEX_SCRIPT missing or not executable — skipped hub refresh"
    return 0
  fi
  if "$GENERATE_INDEX_SCRIPT"; then
    wp_stack_info "refreshed link hub: ${LOCAL_DEV_INDEX_FILE}"
  else
    wp_stack_info "WARNING: link hub refresh failed — run \$GENERATE_INDEX_SCRIPT manually"
  fi
}

wp_stack_image_bump() {
  local project="" yes=0 skip_compose=0 skip_index=0
  local wordpress_image="" wordpress_core="" php_minor=""
  local mariadb_image="" mariadb_minor=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        wp_stack_image_bump_usage
        return 0
        ;;
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --wordpress-image)
        [[ $# -ge 2 ]] || wp_stack_die "--wordpress-image requires a value"
        wordpress_image="$2"
        shift 2
        ;;
      --wordpress)
        [[ $# -ge 2 ]] || wp_stack_die "--wordpress requires a value"
        wordpress_core="$2"
        shift 2
        ;;
      --php)
        [[ $# -ge 2 ]] || wp_stack_die "--php requires a value"
        php_minor="$2"
        shift 2
        ;;
      --mariadb-image)
        [[ $# -ge 2 ]] || wp_stack_die "--mariadb-image requires a value"
        mariadb_image="$2"
        shift 2
        ;;
      --mariadb)
        [[ $# -ge 2 ]] || wp_stack_die "--mariadb requires a value"
        mariadb_minor="$2"
        shift 2
        ;;
      --yes)
        yes=1
        shift
        ;;
      --skip-compose)
        skip_compose=1
        shift
        ;;
      --no-index)
        skip_index=1
        shift
        ;;
      --*)
        wp_stack_die "unknown option: $1"
        ;;
      *)
        wp_stack_die "unexpected argument: $1"
        ;;
    esac
  done

  if [[ -z "$wordpress_image" && -z "$wordpress_core" && -z "$php_minor" && -z "$mariadb_image" && -z "$mariadb_minor" ]]; then
    wp_stack_die "nothing to bump — pass --wordpress-image / --wordpress / --php / --mariadb-image / --mariadb"
  fi
  if [[ -n "$wordpress_image" && ( -n "$wordpress_core" || -n "$php_minor" ) ]]; then
    wp_stack_die "use either --wordpress-image or --wordpress/--php, not both"
  fi
  if [[ -n "$mariadb_image" && -n "$mariadb_minor" ]]; then
    wp_stack_die "use either --mariadb-image or --mariadb, not both"
  fi

  wp_stack_resolve_project "$project"
  local dir="$WP_STACK_PROJECT_DIR"
  local env_file="${dir}/.env"
  local cur_wp cur_mdb target_wp="" target_mdb=""
  local cur_wp_core="" cur_php="" parts

  wp_stack_load_env "$dir"

  cur_wp="$(wp_stack_image_bump_read_env_var "$env_file" WORDPRESS_IMAGE)"
  cur_mdb="$(wp_stack_image_bump_read_env_var "$env_file" MARIADB_IMAGE)"

  if [[ -n "$cur_wp" ]] && parts="$(trockendock_parse_wordpress_image_parts "$cur_wp")"; then
    read -r cur_wp_core cur_php <<<"$parts"
  fi

  if [[ -n "$wordpress_image" ]]; then
    trockendock_validate_wordpress_image "$wordpress_image" || wp_stack_die "invalid --wordpress-image"
    target_wp="$wordpress_image"
  elif [[ -n "$wordpress_core" || -n "$php_minor" ]]; then
    local use_core use_php
    use_core="${wordpress_core:-$cur_wp_core}"
    use_php="${php_minor:-$cur_php}"
    [[ -n "$use_core" ]] || wp_stack_die "cannot build WORDPRESS_IMAGE — pass --wordpress or set a pinned WORDPRESS_IMAGE in .env"
    [[ -n "$use_php" ]] || wp_stack_die "cannot build WORDPRESS_IMAGE — pass --php or set a pinned WORDPRESS_IMAGE in .env"
    target_wp="$(trockendock_format_wordpress_image "$use_core" "$use_php")"
    trockendock_validate_wordpress_image "$target_wp" || wp_stack_die "composed WORDPRESS_IMAGE invalid"
  fi

  if [[ -n "$mariadb_image" ]]; then
    trockendock_validate_mariadb_image "$mariadb_image" || wp_stack_die "invalid --mariadb-image"
    target_mdb="$mariadb_image"
  elif [[ -n "$mariadb_minor" ]]; then
    target_mdb="$(trockendock_format_mariadb_image "$mariadb_minor")"
    trockendock_validate_mariadb_image "$target_mdb" || wp_stack_die "invalid --mariadb"
  fi

  echo ""
  wp_stack_info "image bump plan for '${PROJECT_SLUG:-$(basename "$dir")}' (${dir})"
  if [[ -n "$target_wp" ]]; then
    echo "  WORDPRESS_IMAGE:  ${cur_wp:-(unset)}  →  ${target_wp}"
    if [[ -n "$cur_wp_core" ]]; then
      local new_parts new_core
      if new_parts="$(trockendock_parse_wordpress_image_parts "$target_wp")"; then
        read -r new_core _ <<<"$new_parts"
        if [[ "$(wp_stack_image_bump_major "$cur_wp_core")" != "$(wp_stack_image_bump_major "$new_core")" ]]; then
          wp_stack_info "WARNING: WordPress major bump ${cur_wp_core} → ${new_core} — review plugins/themes; Multisite may need network DB upgrade"
        fi
      fi
    fi
  else
    echo "  WORDPRESS_IMAGE:  ${cur_wp:-(unset)}  (unchanged)"
  fi
  if [[ -n "$target_mdb" ]]; then
    echo "  MARIADB_IMAGE:    ${cur_mdb:-(unset)}  →  ${target_mdb}"
  else
    echo "  MARIADB_IMAGE:    ${cur_mdb:-(unset)}  (unchanged)"
  fi

  if [[ "$yes" -eq 0 ]]; then
    echo ""
    wp_stack_info "dry run — no changes made (pass --yes to write .env and apply compose)"
    return 0
  fi

  if [[ -n "$target_wp" ]]; then
    trockendock_set_env_var "$dir" WORDPRESS_IMAGE "$target_wp"
    wp_stack_info "wrote WORDPRESS_IMAGE=${target_wp}"
  fi
  if [[ -n "$target_mdb" ]]; then
    trockendock_set_env_var "$dir" MARIADB_IMAGE "$target_mdb"
    wp_stack_info "wrote MARIADB_IMAGE=${target_mdb}"
  fi

  # Landmine: Compose prefers shell env over project .env — stale exports block bumps.
  unset WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE
  wp_stack_info "unset shell WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE (Compose must read .env)"

  if [[ "$skip_index" -eq 0 ]]; then
    wp_stack_image_bump_refresh_hub
  else
    wp_stack_info "skipped link hub refresh (--no-index)"
  fi

  if [[ "$skip_compose" -eq 1 ]]; then
    wp_stack_info "skipped compose (--skip-compose); pull/recreate when ready"
    return 0
  fi

  local services=()
  [[ -n "$target_wp" ]] && services+=(wordpress)
  [[ -n "$target_mdb" ]] && services+=(db)
  [[ ${#services[@]} -gt 0 ]] || wp_stack_die "internal: no services to recreate"

  wp_stack_info "compose pull + recreate: ${services[*]}"
  (
    cd "$dir"
    docker compose config --images
    docker compose pull "${services[@]}"
    docker compose up -d --force-recreate "${services[@]}"
  )
  wp_stack_info "image bump applied"
}
