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
  --slug <name>   PROJECT_SLUG in .env (default: folder name)
  --theme <slug>  Theme folder in wp-content/themes/ (default: folder name)
  --dry-run       Print actions without creating files
  --no-index      Skip generate-local-dev-index.sh
  -h, --help      Show this help

Hub tags:
  https://hub.docker.com/_/wordpress/tags
  https://hub.docker.com/_/mariadb/tags

Example:
  wp-stack project create kundin-a \
    --wordpress-image wordpress:6.4.3-php8.3-apache \
    --mariadb-image mariadb:10.11 \
    --slug kundin-a --theme kundin-a-theme
EOF
}

# Reject floating / unpinned WordPress tags (e.g. wordpress:php8.3-apache).
wp_stack_validate_wordpress_image() {
  local image="$1"
  if [[ ! "$image" =~ ^wordpress:[0-9]+\.[0-9]+(\.[0-9]+)?-php[0-9]+\.[0-9]+-apache$ ]]; then
    wp_stack_die "invalid WORDPRESS_IMAGE '${image}' (expected wordpress:<WP>-php<PHP>-apache with explicit core+PHP, e.g. wordpress:6.4.3-php8.3-apache)"
  fi
}

wp_stack_validate_mariadb_image() {
  local image="$1"
  if [[ ! "$image" =~ ^mariadb:[0-9]+\.[0-9]+$ ]]; then
    wp_stack_die "invalid MARIADB_IMAGE '${image}' (expected mariadb:<x.y>, e.g. mariadb:10.11)"
  fi
}

wp_stack_project_create() {
  local folder="" slug="" theme_slug="" dry_run=0 skip_index=0
  local wordpress_image="" mariadb_image=""

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

  slug="${slug:-$folder}"
  theme_slug="${theme_slug:-$folder}"
  local target_dir="${WEBSITES_ROOT}/${folder}"

  wordpress_image="${wordpress_image:-${DEFAULT_WORDPRESS_IMAGE:-}}"
  mariadb_image="${mariadb_image:-${DEFAULT_MARIADB_IMAGE:-}}"

  if [[ -z "$wordpress_image" || -z "$mariadb_image" ]]; then
    wp_stack_die "image pins required: pass --wordpress-image and --mariadb-image, or set DEFAULT_WORDPRESS_IMAGE / DEFAULT_MARIADB_IMAGE in config/stack-defaults.env (see config/stack-defaults.env.example)"
  fi
  wp_stack_validate_wordpress_image "$wordpress_image"
  wp_stack_validate_mariadb_image "$mariadb_image"

  [[ -d "$WORDPRESS_TEMPLATE" ]] || wp_stack_die "template not found: ${WORDPRESS_TEMPLATE}"
  [[ ! -e "$target_dir" ]] || wp_stack_die "target already exists: ${target_dir}"

  local block
  block="$(wp_stack_next_free_block)" || wp_stack_die "no free port block found (801–899)"
  wp_stack_ports_for_block "$block"

  local db_password db_root_password
  db_password="$(wp_stack_generate_password)"
  db_root_password="$(wp_stack_generate_password)"

  if [[ "$dry_run" -eq 1 ]]; then
    wp_stack_info "dry run — would create:"
    echo "  folder:           ${target_dir}"
    echo "  slug:             ${slug}"
    echo "  WORDPRESS_IMAGE:  ${wordpress_image}"
    echo "  MARIADB_IMAGE:    ${mariadb_image}"
    echo "  port block:       ${block}x (WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog UI ${MAILHOG_UI_PORT}, SMTP ${MAILHOG_SMTP_PORT})"
    echo "  theme slug:       ${theme_slug}"
    return 0
  fi

  cp -a "${WORDPRESS_TEMPLATE}/." "${target_dir}/"
  # Template README is platform docs; do not keep it in the project folder.
  rm -f "${target_dir}/README.md"
  cp "${target_dir}/.env.example" "${target_dir}/.env"

  sed -i \
    -e "s/^PROJECT_SLUG=.*/PROJECT_SLUG=${slug}/" \
    -e "s|^WORDPRESS_IMAGE=.*|WORDPRESS_IMAGE=${wordpress_image}|" \
    -e "s|^MARIADB_IMAGE=.*|MARIADB_IMAGE=${mariadb_image}|" \
    -e "s/^WP_PORT=.*/WP_PORT=${WP_PORT}/" \
    -e "s/^PMA_PORT=.*/PMA_PORT=${PMA_PORT}/" \
    -e "s/^MAILHOG_UI_PORT=.*/MAILHOG_UI_PORT=${MAILHOG_UI_PORT}/" \
    -e "s/^MAILHOG_SMTP_PORT=.*/MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT}/" \
    -e "s/^WP_DB_PASSWORD=.*/WP_DB_PASSWORD=${db_password}/" \
    -e "s/^WP_DB_ROOT_PASSWORD=.*/WP_DB_ROOT_PASSWORD=${db_root_password}/" \
    "${target_dir}/.env"

  sed -i "s/your-theme/${theme_slug}/g" "${target_dir}/.gitignore"

  if [[ "$skip_index" -eq 0 ]]; then
    "$GENERATE_INDEX_SCRIPT"
  fi

  wp_stack_info "created ${target_dir}"
  echo "  PROJECT_SLUG:    ${slug}"
  echo "  WORDPRESS_IMAGE: ${wordpress_image}"
  echo "  MARIADB_IMAGE:   ${mariadb_image}"
  echo "  ports:           WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog ${MAILHOG_UI_PORT}/${MAILHOG_SMTP_PORT}"
  echo "  link hub:        ${LOCAL_DEV_INDEX_FILE}"
  echo ""
  echo "Next steps:"
  echo "  cd \"${target_dir}\""
  echo "  git clone <theme-repo> wp-content/themes/${theme_slug}"
  echo "  docker compose pull && docker compose up -d"
}
