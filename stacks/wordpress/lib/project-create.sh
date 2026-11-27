#!/usr/bin/env bash
# Create a new WordPress project from the Trockendock template.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=ports.sh
source "${SCRIPT_DIR}/ports.sh"

wp_stack_project_create_usage() {
  cat <<'EOF'
Usage: wp-stack project create <folder> [options]

Create a new WordPress stack under $WEBSITES_ROOT from templates/wordpress.

Image pins (required unless set in config/stack-defaults.env):
  --wordpress-image <tag>   e.g. wordpress:6.4.3-php8.3-apache
  --mariadb-image <tag>     e.g. mariadb:10.11

Options:
  --slug <name>         PROJECT_SLUG in .env (default: folder name)
  --theme <slug>        Theme folder in wp-content/themes/ (default: folder name)
  --table-prefix <pfx>  WP_TABLE_PREFIX in .env (default: wp_)
  --source-url <url>    Optional live site URL → MIGRATION_SOURCE_URL (link hub)
  --dry-run             Print actions without creating files
  --no-index            Skip generate-local-dev-index.sh
  -h, --help            Show this help

Hub tags:
  https://hub.docker.com/_/wordpress/tags
  https://hub.docker.com/_/mariadb/tags

Example:
  wp-stack project create kundin-a \
    --wordpress-image wordpress:6.4.3-php8.3-apache \
    --mariadb-image mariadb:10.11 \
    --table-prefix wp_ \
    --source-url https://www.example.de \
    --slug kundin-a --theme kundin-a-theme
EOF
}

wp_stack_validate_table_prefix() {
  local prefix="$1"
  if [[ ! "$prefix" =~ ^[A-Za-z0-9_]+$ ]]; then
    wp_stack_die "invalid --table-prefix '${prefix}' (use letters, digits, underscore only, e.g. wp_ or oscr_)"
  fi
}

wp_stack_project_create() {
  local folder="" slug="" theme_slug="" dry_run=0 skip_index=0
  local wordpress_image="" mariadb_image="" source_url=""
  local table_prefix="wp_"

  if [[ $# -eq 0 ]]; then
    wp_stack_project_create_usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        wp_stack_project_create_usage
        exit 0
        ;;
      --slug)
        [[ $# -ge 2 ]] || wp_stack_die "--slug requires a value"
        slug="$2"
        shift 2
        ;;
      --theme)
        [[ $# -ge 2 ]] || wp_stack_die "--theme requires a value"
        theme_slug="$2"
        shift 2
        ;;
      --table-prefix)
        [[ $# -ge 2 ]] || wp_stack_die "--table-prefix requires a value"
        table_prefix="$2"
        shift 2
        ;;
      --wordpress-image)
        [[ $# -ge 2 ]] || wp_stack_die "--wordpress-image requires a value"
        wordpress_image="$2"
        shift 2
        ;;
      --mariadb-image)
        [[ $# -ge 2 ]] || wp_stack_die "--mariadb-image requires a value"
        mariadb_image="$2"
        shift 2
        ;;
      --source-url)
        [[ $# -ge 2 ]] || wp_stack_die "--source-url requires a value"
        source_url="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=1
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
        if [[ -n "$folder" ]]; then
          wp_stack_die "unexpected argument: $1"
        fi
        folder="$1"
        shift
        ;;
    esac
  done

  [[ -n "$folder" ]] || wp_stack_die "missing folder name"
  wp_stack_validate_folder_name "$folder"
  wp_stack_validate_table_prefix "$table_prefix"

  slug="${slug:-$folder}"
  theme_slug="${theme_slug:-$folder}"
  local target_dir="${WEBSITES_ROOT}/${folder}"

  wordpress_image="${wordpress_image:-${DEFAULT_WORDPRESS_IMAGE:-}}"
  mariadb_image="${mariadb_image:-${DEFAULT_MARIADB_IMAGE:-}}"

  if [[ -z "$wordpress_image" || -z "$mariadb_image" ]]; then
    wp_stack_die "image pins required: pass --wordpress-image and --mariadb-image, or set DEFAULT_WORDPRESS_IMAGE / DEFAULT_MARIADB_IMAGE in config/stack-defaults.env (see config/stack-defaults.env.example)"
  fi
  trockendock_validate_wordpress_image "$wordpress_image" || wp_stack_die "refusing to create with invalid WordPress image pin"
  trockendock_validate_mariadb_image "$mariadb_image" || wp_stack_die "refusing to create with invalid MariaDB image pin"

  [[ -d "$WORDPRESS_TEMPLATE" ]] || wp_stack_die "template not found: ${WORDPRESS_TEMPLATE}"
  [[ ! -e "$target_dir" ]] || wp_stack_die "target already exists: ${target_dir}"

  local block
  block="$(wp_stack_next_free_block)" || wp_stack_die "no free port block found (801–899)"
  wp_stack_ports_for_block "$block"

  local db_password db_root_password
  db_password="$(wp_stack_generate_password)"
  db_root_password="$(wp_stack_generate_password)"

  if [[ -n "$source_url" && ! "$source_url" =~ ^https?:// ]]; then
    wp_stack_die "invalid --source-url '${source_url}' (expected http:// or https:// URL)"
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    wp_stack_info "dry run — would create:"
    echo "  folder:           ${target_dir}"
    echo "  slug:             ${slug}"
    echo "  WORDPRESS_IMAGE:  ${wordpress_image}"
    echo "  MARIADB_IMAGE:    ${mariadb_image}"
    echo "  WP_TABLE_PREFIX:  ${table_prefix}"
    echo "  MIGRATION_SOURCE_URL: ${source_url:-'(unset)'}"
    echo "  port block:       ${block}x (WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog UI ${MAILHOG_UI_PORT}, SMTP ${MAILHOG_SMTP_PORT})"
    echo "  theme slug:       ${theme_slug}"
    return 0
  fi

  cp -a "${WORDPRESS_TEMPLATE}/." "${target_dir}/"
  # Template README is platform docs; do not keep it in the project folder.
  rm -f "${target_dir}/README.md"
  cp "${target_dir}/.env.example" "${target_dir}/.env"

  trockendock_set_env_var "${target_dir}" PROJECT_SLUG "${slug}"
  trockendock_set_env_var "${target_dir}" WORDPRESS_IMAGE "${wordpress_image}"
  trockendock_set_env_var "${target_dir}" MARIADB_IMAGE "${mariadb_image}"
  trockendock_set_env_var "${target_dir}" WP_TABLE_PREFIX "${table_prefix}"
  trockendock_set_env_var "${target_dir}" WP_PORT "${WP_PORT}"
  trockendock_set_env_var "${target_dir}" PMA_PORT "${PMA_PORT}"
  trockendock_set_env_var "${target_dir}" MAILHOG_UI_PORT "${MAILHOG_UI_PORT}"
  trockendock_set_env_var "${target_dir}" MAILHOG_SMTP_PORT "${MAILHOG_SMTP_PORT}"
  trockendock_set_env_var "${target_dir}" WP_DB_PASSWORD "${db_password}"
  trockendock_set_env_var "${target_dir}" WP_DB_ROOT_PASSWORD "${db_root_password}"
  if [[ -n "$source_url" ]]; then
    trockendock_set_env_var "${target_dir}" MIGRATION_SOURCE_URL "${source_url}"
  fi

  sed -i "s/your-theme/${theme_slug}/g" "${target_dir}/.gitignore"

  if [[ "$skip_index" -eq 0 ]]; then
    "$GENERATE_INDEX_SCRIPT"
  fi

  wp_stack_info "created ${target_dir}"
  echo "  PROJECT_SLUG:    ${slug}"
  echo "  WORDPRESS_IMAGE: ${wordpress_image}"
  echo "  MARIADB_IMAGE:   ${mariadb_image}"
  echo "  WP_TABLE_PREFIX: ${table_prefix}"
  if [[ -n "$source_url" ]]; then
    echo "  MIGRATION_SOURCE_URL: ${source_url}"
  fi
  echo "  ports:           WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog ${MAILHOG_UI_PORT}/${MAILHOG_SMTP_PORT}"
  echo "  link hub:        ${LOCAL_DEV_INDEX_FILE}"
  echo ""
  echo "Next steps:"
  echo "  cd \"${target_dir}\""
  echo "  git clone <theme-repo> wp-content/themes/${theme_slug}"
  echo "  docker compose pull && docker compose up -d"
}
