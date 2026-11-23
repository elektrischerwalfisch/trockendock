#!/usr/bin/env bash
# Shared setup for static-stack scripts.

set -euo pipefail

STATIC_STACK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATIC_STACK_ROOT="$(cd "${STATIC_STACK_LIB}/.." && pwd)"
TROCKENDOCK_ROOT="$(cd "${STATIC_STACK_ROOT}/../.." && pwd)"

# shellcheck disable=SC1091
source "${TROCKENDOCK_ROOT}/config/load-config.sh"

static_stack_die() {
  echo "static-stack: $*" >&2
  exit 1
}

static_stack_info() {
  echo "static-stack: $*"
}

static_stack_validate_folder_name() {
  local folder="$1"

  if [[ ! "$folder" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    static_stack_die "invalid folder name '${folder}' (use lowercase letters, digits, hyphens)"
  fi

  if [[ "$folder" == "trockendock" || "$folder" == "00-trockendock" ]]; then
    static_stack_die "folder name '${folder}' is reserved"
  fi
}

static_stack_resolve_template() {
  local variant="$1"

  case "$variant" in
    static-php)
      STATIC_STACK_TEMPLATE="$STATIC_PHP_TEMPLATE"
      STATIC_STACK_VARIANT_LABEL="static/php"
      ;;
    static-php-mailhog)
      STATIC_STACK_TEMPLATE="$STATIC_PHP_MAILHOG_TEMPLATE"
      STATIC_STACK_VARIANT_LABEL="static/php/mailhog"
      ;;
    *)
      static_stack_die "unknown variant '${variant}' (use static-php or static-php-mailhog)"
      ;;
  esac
}
