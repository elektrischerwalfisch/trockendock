#!/usr/bin/env bash
# Shared setup for static-stack scripts.

set -euo pipefail

STATIC_STACK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATIC_STACK_ROOT="$(cd "${STATIC_STACK_LIB}/.." && pwd)"
# Platform root from this checkout (paths.env may later override TROCKENDOCK_ROOT).
_STATIC_STACK_PLATFORM_ROOT="$(cd "${STATIC_STACK_ROOT}/../.." && pwd)"
TROCKENDOCK_ROOT="${_STATIC_STACK_PLATFORM_ROOT}"

# shellcheck disable=SC1091
source "${_STATIC_STACK_PLATFORM_ROOT}/config/load-config.sh"
# shellcheck disable=SC1091
source "${_STATIC_STACK_PLATFORM_ROOT}/stacks/lib/stack-image-pins.sh"

# Prefer templates from this checkout (paths.env may point TROCKENDOCK_ROOT elsewhere).
STATIC_PHP_TEMPLATE="${_STATIC_STACK_PLATFORM_ROOT}/templates/static-php"
STATIC_PHP_MAILHOG_TEMPLATE="${_STATIC_STACK_PLATFORM_ROOT}/templates/static-php-mailhog"
export STATIC_PHP_TEMPLATE STATIC_PHP_MAILHOG_TEMPLATE
unset _STATIC_STACK_PLATFORM_ROOT

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
