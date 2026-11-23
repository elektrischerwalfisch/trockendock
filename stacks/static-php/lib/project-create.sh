#!/usr/bin/env bash
# Create a new static PHP project from a Trockendock template.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=ports.sh
source "${SCRIPT_DIR}/ports.sh"

static_stack_project_create_usage() {
  cat <<'EOF'
Usage: static-stack project create <folder> --variant <name> [options]

Create a new static PHP stack under $WEBSITES_ROOT.

Variants (required):
  static-php           Apache + PHP only (static/php)
  static-php-mailhog   Apache + PHP + Mailhog (static/php/mailhog)

Image pin (required unless set in config/stack-defaults.env):
  --php <x.y|php:x.y-apache>   e.g. 8.3 or php:8.3-apache → PHP_IMAGE

Options:
  --slug <name>   PROJECT_SLUG in .env (default: folder name)
  --dry-run       Print actions without creating files
  --no-index      Skip generate-local-dev-index.sh
  -h, --help      Show this help

Hub tags:
  https://hub.docker.com/_/php/tags

Examples:
  static-stack project create kundin-a --variant static-php --php 8.3
  static-stack project create kundin-b --variant static-php-mailhog --php php:8.2-apache --slug kundin-b
EOF
}

static_stack_project_create() {
  local folder="" slug="" variant="" dry_run=0 skip_index=0
  local php_input="" php_image=""

  if [[ $# -eq 0 ]]; then
    static_stack_project_create_usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        static_stack_project_create_usage
        exit 0
        ;;
      --variant)
        [[ $# -ge 2 ]] || static_stack_die "--variant requires a value"
        variant="$2"
        shift 2
        ;;
      --slug)
        [[ $# -ge 2 ]] || static_stack_die "--slug requires a value"
        slug="$2"
        shift 2
        ;;
      --php)
        [[ $# -ge 2 ]] || static_stack_die "--php requires a value"
        php_input="$2"
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
        static_stack_die "unknown option: $1"
        ;;
      *)
        if [[ -n "$folder" ]]; then
          static_stack_die "unexpected argument: $1"
        fi
        folder="$1"
        shift
        ;;
    esac
  done

  [[ -n "$folder" ]] || static_stack_die "missing folder name"
  [[ -n "$variant" ]] || static_stack_die "missing --variant (static-php or static-php-mailhog)"

  static_stack_validate_folder_name "$folder"
  static_stack_resolve_template "$variant"

  slug="${slug:-$folder}"
  local target_dir="${WEBSITES_ROOT}/${folder}"

  if [[ -n "$php_input" ]]; then
    php_image="$(trockendock_resolve_php_image "$php_input")"
  else
    php_image="${DEFAULT_PHP_IMAGE:-}"
  fi

  if [[ -z "$php_image" ]]; then
    static_stack_die "PHP image pin required: pass --php <x.y|php:x.y-apache>, or set DEFAULT_PHP_IMAGE in config/stack-defaults.env (see config/stack-defaults.env.example)"
  fi
  trockendock_validate_php_image "$php_image" || static_stack_die "refusing to create with invalid PHP image pin"

  [[ -d "$STATIC_STACK_TEMPLATE" ]] || static_stack_die "template not found: ${STATIC_STACK_TEMPLATE}"
  [[ ! -e "$target_dir" ]] || static_stack_die "target already exists: ${target_dir}"

  local block
  block="$(static_stack_next_free_block)" || static_stack_die "no free port block found (801–899)"
  static_stack_ports_for_block "$variant" "$block"

  if [[ "$dry_run" -eq 1 ]]; then
    static_stack_info "dry run — would create:"
    echo "  folder:      ${target_dir}"
    echo "  variant:     ${STATIC_STACK_VARIANT_LABEL} (${variant})"
    echo "  slug:        ${slug}"
    echo "  PHP_IMAGE:   ${php_image}"
    if [[ "$variant" == "static-php-mailhog" ]]; then
      echo "  port block:  ${block}x (Web ${WEB_PORT}, Mailhog UI ${MAILHOG_UI_PORT}, SMTP ${MAILHOG_SMTP_PORT})"
    else
      echo "  port block:  ${block}x (Web ${WEB_PORT})"
    fi
    return 0
  fi

  cp -a "${STATIC_STACK_TEMPLATE}/." "${target_dir}/"
  # Template README is platform docs; do not keep it in the project folder.
  rm -f "${target_dir}/README.md"
  cp "${target_dir}/.env.example" "${target_dir}/.env"

  trockendock_set_env_var "${target_dir}" PROJECT_SLUG "${slug}"
  trockendock_set_env_var "${target_dir}" PHP_IMAGE "${php_image}"
  trockendock_set_env_var "${target_dir}" WEB_PORT "${WEB_PORT}"

  if [[ "$variant" == "static-php-mailhog" ]]; then
    trockendock_set_env_var "${target_dir}" MAILHOG_UI_PORT "${MAILHOG_UI_PORT}"
    trockendock_set_env_var "${target_dir}" MAILHOG_SMTP_PORT "${MAILHOG_SMTP_PORT}"
  fi

  if [[ "$skip_index" -eq 0 ]]; then
    "$GENERATE_INDEX_SCRIPT"
  fi

  static_stack_info "created ${target_dir}"
  echo "  variant:      ${STATIC_STACK_VARIANT_LABEL}"
  echo "  PROJECT_SLUG: ${slug}"
  echo "  PHP_IMAGE:    ${php_image}"
  if [[ "$variant" == "static-php-mailhog" ]]; then
    echo "  ports:        Web ${WEB_PORT}, Mailhog ${MAILHOG_UI_PORT}/${MAILHOG_SMTP_PORT}"
  else
    echo "  ports:        Web ${WEB_PORT}"
  fi
  echo "  link hub:     ${LOCAL_DEV_INDEX_FILE}"
  echo ""
  echo "Next steps:"
  echo "  cd \"${target_dir}\""
  echo "  # add or clone site files (index.php, assets, …)"
  echo "  docker compose pull && docker compose up -d"
}
