#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: shared stacks/lib/stack-image-pins.sh validate / format / .env writer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/stacks/lib/stack-image-pins.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

[[ "$(trockendock_format_wordpress_image 6.4.3 8.3)" == "wordpress:6.4.3-php8.3-apache" ]]
[[ "$(trockendock_format_mariadb_image 10.11)" == "mariadb:10.11" ]]
[[ "$(trockendock_format_php_image 8.3)" == "php:8.3-apache" ]]
[[ "$(trockendock_resolve_php_image 8.2)" == "php:8.2-apache" ]]
[[ "$(trockendock_resolve_php_image php:8.1-apache)" == "php:8.1-apache" ]]

trockendock_validate_wordpress_image "wordpress:6.4.3-php8.3-apache"
trockendock_validate_mariadb_image "mariadb:10.11"
trockendock_validate_php_image "php:8.3-apache"

if trockendock_validate_wordpress_image "wordpress:php8.3-apache" 2>/dev/null; then
  echo "expected floating WP tag to fail" >&2
  exit 1
fi

cat >"${TMP_DIR}/.env" <<'EOF'
PHP_IMAGE=
# WORDPRESS_IMAGE=old
EOF

trockendock_set_env_var "${TMP_DIR}" PHP_IMAGE "php:8.3-apache"
trockendock_set_env_var "${TMP_DIR}" WORDPRESS_IMAGE "wordpress:6.4.3-php8.3-apache"
grep -qx 'PHP_IMAGE=php:8.3-apache' "${TMP_DIR}/.env"
grep -qx 'WORDPRESS_IMAGE=wordpress:6.4.3-php8.3-apache' "${TMP_DIR}/.env"

echo "smoke-stack-image-pins-lib: ok"
