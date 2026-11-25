#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: wp-stack project create requires explicit / default image pins.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WP_STACK="${ROOT}/stacks/wordpress/bin/wp-stack"
FOLDER="smoke-pin-create-$$"

# Hide operator stack-defaults: stack CLIs re-source load-config.sh and would
# otherwise pick up local DEFAULT_* (unset in this shell is not enough).
_SMOKE_DEFAULTS="${ROOT}/config/stack-defaults.env"
_SMOKE_DEFAULTS_BAK=""
if [[ -f "${_SMOKE_DEFAULTS}" ]]; then
  _SMOKE_DEFAULTS_BAK="${_SMOKE_DEFAULTS}.bak-smoke-$$"
  mv "${_SMOKE_DEFAULTS}" "${_SMOKE_DEFAULTS_BAK}"
fi
restore_smoke_defaults() {
  if [[ -n "${_SMOKE_DEFAULTS_BAK}" && -f "${_SMOKE_DEFAULTS_BAK}" ]]; then
    mv "${_SMOKE_DEFAULTS_BAK}" "${_SMOKE_DEFAULTS}"
  fi
}
trap restore_smoke_defaults EXIT

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

unset DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE
STACK_DEFAULTS_LOADED=0
export STACK_DEFAULTS_LOADED DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE

fail_create_without_pins() {
  if "${WP_STACK}" project create "${FOLDER}" --dry-run >/tmp/wp-create-smoke.out 2>/tmp/wp-create-smoke.err; then
    echo "expected create without pins to fail" >&2
    cat /tmp/wp-create-smoke.err >&2
    exit 1
  fi
  grep -q "image pins required" /tmp/wp-create-smoke.err || {
    echo "expected 'image pins required' error" >&2
    cat /tmp/wp-create-smoke.err >&2
    exit 1
  }
}

fail_floating_wordpress_tag() {
  if "${WP_STACK}" project create "${FOLDER}" \
    --wordpress-image "wordpress:php8.3-apache" \
    --mariadb-image "mariadb:10.11" \
    --dry-run >/tmp/wp-create-smoke.out 2>/tmp/wp-create-smoke.err; then
    echo "expected floating WORDPRESS_IMAGE to fail" >&2
    exit 1
  fi
  grep -q "invalid WORDPRESS_IMAGE" /tmp/wp-create-smoke.err || {
    echo "expected invalid WORDPRESS_IMAGE error" >&2
    cat /tmp/wp-create-smoke.err >&2
    exit 1
  }
}

ok_create_with_flags() {
  "${WP_STACK}" project create "${FOLDER}" \
    --wordpress-image "wordpress:6.4.3-php8.3-apache" \
    --mariadb-image "mariadb:10.11" \
    --dry-run >/tmp/wp-create-smoke.out 2>/tmp/wp-create-smoke.err
  grep -q "WORDPRESS_IMAGE:  wordpress:6.4.3-php8.3-apache" /tmp/wp-create-smoke.out || {
    echo "dry-run missing WORDPRESS_IMAGE line" >&2
    cat /tmp/wp-create-smoke.out >&2
    exit 1
  }
  grep -q "MARIADB_IMAGE:    mariadb:10.11" /tmp/wp-create-smoke.out || {
    echo "dry-run missing MARIADB_IMAGE line" >&2
    cat /tmp/wp-create-smoke.out >&2
    exit 1
  }
}

ok_create_from_defaults() {
  DEFAULT_WORDPRESS_IMAGE="wordpress:6.5.0-php8.2-apache"
  DEFAULT_MARIADB_IMAGE="mariadb:10.6"
  export DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE
  "${WP_STACK}" project create "${FOLDER}" --dry-run >/tmp/wp-create-smoke.out 2>/tmp/wp-create-smoke.err
  grep -q "WORDPRESS_IMAGE:  wordpress:6.5.0-php8.2-apache" /tmp/wp-create-smoke.out || {
    echo "defaults not applied for WORDPRESS_IMAGE" >&2
    cat /tmp/wp-create-smoke.out >&2
    exit 1
  }
  grep -q "MARIADB_IMAGE:    mariadb:10.6" /tmp/wp-create-smoke.out || {
    echo "defaults not applied for MARIADB_IMAGE" >&2
    cat /tmp/wp-create-smoke.out >&2
    exit 1
  }
}

ok_create_with_source_url() {
  unset DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE
  "${WP_STACK}" project create "${FOLDER}" \
    --wordpress-image "wordpress:6.4.3-php8.3-apache" \
    --mariadb-image "mariadb:10.11" \
    --source-url "https://www.example.de" \
    --dry-run >/tmp/wp-create-smoke.out 2>/tmp/wp-create-smoke.err
  grep -q "MIGRATION_SOURCE_URL: https://www.example.de" /tmp/wp-create-smoke.out || {
    echo "dry-run missing MIGRATION_SOURCE_URL" >&2
    cat /tmp/wp-create-smoke.out >&2
    exit 1
  }
}

fail_create_without_pins
fail_floating_wordpress_tag
ok_create_with_flags
ok_create_from_defaults
ok_create_with_source_url

echo "smoke-wp-stack-project-create-pins: ok"
