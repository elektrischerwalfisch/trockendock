#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: static-stack project create requires --php or DEFAULT_PHP_IMAGE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATIC_STACK="${ROOT}/stacks/static-php/bin/static-stack"
FOLDER="smoke-static-pin-$$"

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

unset DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE
STACK_DEFAULTS_LOADED=0
export STACK_DEFAULTS_LOADED DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE

fail_without_php() {
  if "${STATIC_STACK}" project create "${FOLDER}" --variant static-php --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err; then
    echo "expected create without --php to fail" >&2
    cat /tmp/static-create-smoke.err >&2
    exit 1
  fi
  grep -q "PHP image pin required" /tmp/static-create-smoke.err || {
    echo "expected PHP image pin required error" >&2
    cat /tmp/static-create-smoke.err >&2
    exit 1
  }
}

fail_invalid_php() {
  if "${STATIC_STACK}" project create "${FOLDER}" --variant static-php --php latest --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err; then
    echo "expected invalid --php to fail" >&2
    exit 1
  fi
  grep -q "invalid PHP_IMAGE" /tmp/static-create-smoke.err || {
    echo "expected invalid PHP_IMAGE error" >&2
    cat /tmp/static-create-smoke.err >&2
    exit 1
  }
}

ok_with_minor() {
  "${STATIC_STACK}" project create "${FOLDER}" --variant static-php --php 8.3 --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err
  grep -q "PHP_IMAGE:   php:8.3-apache" /tmp/static-create-smoke.out || {
    echo "dry-run missing formatted PHP_IMAGE" >&2
    cat /tmp/static-create-smoke.out >&2
    exit 1
  }
}

ok_with_full_tag() {
  "${STATIC_STACK}" project create "${FOLDER}" --variant static-php-mailhog --php php:8.2-apache --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err
  grep -q "PHP_IMAGE:   php:8.2-apache" /tmp/static-create-smoke.out || {
    echo "dry-run missing full-tag PHP_IMAGE" >&2
    cat /tmp/static-create-smoke.out >&2
    exit 1
  }
}

ok_from_defaults() {
  DEFAULT_PHP_IMAGE="php:8.1-apache"
  export DEFAULT_PHP_IMAGE
  "${STATIC_STACK}" project create "${FOLDER}" --variant static-php --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err
  grep -q "PHP_IMAGE:   php:8.1-apache" /tmp/static-create-smoke.out || {
    echo "defaults not applied for PHP_IMAGE" >&2
    cat /tmp/static-create-smoke.out >&2
    exit 1
  }
}

ok_with_source_url() {
  unset DEFAULT_PHP_IMAGE
  "${STATIC_STACK}" project create "${FOLDER}" --variant static-php --php 8.3 \
    --source-url "https://www.example.de" --dry-run \
    >/tmp/static-create-smoke.out 2>/tmp/static-create-smoke.err
  grep -q "MIGRATION_SOURCE_URL: https://www.example.de" /tmp/static-create-smoke.out || {
    echo "dry-run missing MIGRATION_SOURCE_URL" >&2
    cat /tmp/static-create-smoke.out >&2
    exit 1
  }
}

fail_without_php
fail_invalid_php
ok_with_minor
ok_with_full_tag
ok_from_defaults
ok_with_source_url

echo "smoke-static-stack-project-create-pins: ok"
