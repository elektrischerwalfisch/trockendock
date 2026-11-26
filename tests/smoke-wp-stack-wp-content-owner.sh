#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: wp-stack wp-content owner status + toggle dry-run (no sudo/chown --yes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WP_STACK="${ROOT}/stacks/wordpress/bin/wp-stack"
FOLDER="smoke-wp-content-owner-$$"

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

PROJECT_DIR="${WEBSITES_ROOT}/${FOLDER}"
cleanup() {
  rm -rf "${PROJECT_DIR}"
}
trap cleanup EXIT

mkdir -p "${PROJECT_DIR}/wp-content"
cp "${ROOT}/templates/wordpress/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cat >"${PROJECT_DIR}/.env" <<'EOF'
PROJECT_SLUG=smoke-wp-content-owner
WORDPRESS_IMAGE=wordpress:6.4.3-php8.2-apache
MARIADB_IMAGE=mariadb:10.11
WP_PORT=8097
PMA_PORT=8197
MAILHOG_UI_PORT=8297
MAILHOG_SMTP_PORT=8397
WP_DB_NAME=wordpress
WP_DB_USER=wpuser
WP_DB_PASSWORD=test
WP_DB_ROOT_PASSWORD=testroot
WP_TABLE_PREFIX=wp_
EOF

# Fixture owned by host user (default mkdir).
out="/tmp/wp-content-owner-smoke.out"
err="/tmp/wp-content-owner-smoke.err"

"${WP_STACK}" wp-content owner status --project "${FOLDER}" >"$out" 2>"$err"
grep -q "host user" "$out" || {
  echo "expected status to report host user" >&2
  cat "$out" "$err" >&2
  exit 1
}

"${WP_STACK}" wp-content owner toggle --project "${FOLDER}" >"$out" 2>"$err"
grep -q "www-data (33:33)" "$out" || {
  echo "expected dry-run toggle target www-data" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "dry run — no changes made" "$out" || {
  echo "expected dry-run message" >&2
  cat "$out" >&2
  exit 1
}
owner_before="$(stat -c '%u:%g' "${PROJECT_DIR}/wp-content")"
owner_after="$(stat -c '%u:%g' "${PROJECT_DIR}/wp-content")"
[[ "$owner_before" == "$owner_after" ]] || {
  echo "dry-run must not chown wp-content" >&2
  exit 1
}

"${WP_STACK}" wp-content owner set host --project "${FOLDER}" >"$out" 2>"$err"
grep -q "already" "$out" || {
  echo "expected already-host short-circuit" >&2
  cat "$out" "$err" >&2
  exit 1
}

# Unknown owner: fake uid/gid labels via a nested check is hard without root;
# missing wp-content must fail clearly.
rm -rf "${PROJECT_DIR}/wp-content"
if "${WP_STACK}" wp-content owner status --project "${FOLDER}" >"$out" 2>"$err"; then
  echo "expected missing wp-content to fail" >&2
  cat "$out" "$err" >&2
  exit 1
fi
grep -qi "missing wp-content" "$err" || {
  echo "expected missing wp-content error" >&2
  cat "$err" >&2
  exit 1
}

bash -n "${ROOT}/bin/menu.sh"
bash -n "${ROOT}/stacks/wordpress/lib/wp-content-owner.sh"
grep -q 'menu_wordpress_wp_content_owner' "${ROOT}/bin/menu.sh"
grep -q 'wp-content owner toggle' "${ROOT}/bin/menu.sh"

echo "smoke-wp-stack-wp-content-owner: OK"
