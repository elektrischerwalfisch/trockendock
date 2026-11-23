#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: load-config.sh paths (required) + stack defaults (optional).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="${ROOT}/config/load-config.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_CONFIG="${TMP_DIR}/config"
mkdir -p "${FAKE_CONFIG}"
cp "${LOADER}" "${FAKE_CONFIG}/load-config.sh"

# Minimal paths so the required section succeeds
cat >"${FAKE_CONFIG}/paths.env" <<EOF
WEBSITES_ROOT="${TMP_DIR}/websites"
TROCKENDOCK_ROOT="${TMP_DIR}/trockendock"
EOF
mkdir -p "${TMP_DIR}/websites" "${TMP_DIR}/trockendock"

# 1) Paths load; missing stack-defaults.env → STACK_DEFAULTS_LOADED=0
# shellcheck disable=SC1091
source "${FAKE_CONFIG}/load-config.sh"
[[ "${WEBSITES_ROOT}" == "${TMP_DIR}/websites" ]] || {
  echo "unexpected WEBSITES_ROOT" >&2
  exit 1
}
[[ "${STACK_DEFAULTS_LOADED}" == "0" ]] || {
  echo "expected STACK_DEFAULTS_LOADED=0 without stack-defaults.env" >&2
  exit 1
}
[[ -z "${DEFAULT_WORDPRESS_IMAGE}" && -z "${DEFAULT_MARIADB_IMAGE}" && -z "${DEFAULT_PHP_IMAGE}" ]] || {
  echo "expected empty DEFAULT_* without stack-defaults.env" >&2
  exit 1
}

# 2) With stack-defaults.env → loaded
cat >"${FAKE_CONFIG}/stack-defaults.env" <<'EOF'
DEFAULT_WORDPRESS_IMAGE=wordpress:6.4.3-php8.2-apache
DEFAULT_MARIADB_IMAGE=mariadb:10.11
DEFAULT_PHP_IMAGE=php:8.2-apache
EOF

unset STACK_DEFAULTS_LOADED DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE
unset WEBSITES_ROOT TROCKENDOCK_ROOT
# shellcheck disable=SC1091
source "${FAKE_CONFIG}/load-config.sh"
[[ "${STACK_DEFAULTS_LOADED}" == "1" ]] || {
  echo "expected STACK_DEFAULTS_LOADED=1 with file" >&2
  exit 1
}
[[ "${DEFAULT_WORDPRESS_IMAGE}" == "wordpress:6.4.3-php8.2-apache" ]] || {
  echo "unexpected DEFAULT_WORDPRESS_IMAGE" >&2
  exit 1
}
[[ "${DEFAULT_MARIADB_IMAGE}" == "mariadb:10.11" ]] || {
  echo "unexpected DEFAULT_MARIADB_IMAGE" >&2
  exit 1
}
[[ "${DEFAULT_PHP_IMAGE}" == "php:8.2-apache" ]] || {
  echo "unexpected DEFAULT_PHP_IMAGE" >&2
  exit 1
}

# 3) Example must not count as loaded defaults
rm -f "${FAKE_CONFIG}/stack-defaults.env"
cp "${ROOT}/config/stack-defaults.env.example" "${FAKE_CONFIG}/stack-defaults.env.example"
unset STACK_DEFAULTS_LOADED DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE
unset WEBSITES_ROOT TROCKENDOCK_ROOT
# shellcheck disable=SC1091
source "${FAKE_CONFIG}/load-config.sh"
[[ "${STACK_DEFAULTS_LOADED}" == "0" ]] || {
  echo "example must not count as loaded defaults" >&2
  exit 1
}

echo "smoke-load-config: ok"
