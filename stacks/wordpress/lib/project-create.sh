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

Options:
  --slug <name>   PROJECT_SLUG in .env (default: folder name)
  --theme <slug>  Theme folder in wp-content/themes/ (default: folder name)
  --dry-run       Print actions without creating files
  --no-index      Skip generate-local-dev-index.sh
  -h, --help      Show this help

Example:
  wp-stack project create kundin-a --slug kundin-a --theme kundin-a-theme
EOF
}

wp_stack_project_create() {
  local folder="" slug="" theme_slug="" dry_run=0 skip_index=0

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
    echo "  folder:      ${target_dir}"
    echo "  slug:        ${slug}"
    echo "  port block:  ${block}x (WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog UI ${MAILHOG_UI_PORT}, SMTP ${MAILHOG_SMTP_PORT})"
    echo "  theme slug:  ${theme_slug}"
    return 0
  fi

  cp -a "${WORDPRESS_TEMPLATE}/." "${target_dir}/"
  # Template README is platform docs; do not keep it in the project folder.
  rm -f "${target_dir}/README.md"
  cp "${target_dir}/.env.example" "${target_dir}/.env"

  sed -i \
    -e "s/^PROJECT_SLUG=.*/PROJECT_SLUG=${slug}/" \
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
  echo "  PROJECT_SLUG: ${slug}"
  echo "  ports:        WP ${WP_PORT}, PMA ${PMA_PORT}, Mailhog ${MAILHOG_UI_PORT}/${MAILHOG_SMTP_PORT}"
  echo "  link hub:     ${LOCAL_DEV_INDEX_FILE}"
  echo ""
  echo "Next steps:"
  echo "  cd \"${target_dir}\""
  echo "  git clone <theme-repo> wp-content/themes/${theme_slug}"
  echo "  docker compose pull && docker compose up -d"
}
