#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: wp-stack image bump dry-run + --yes .env write via shared pin helpers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WP_STACK="${ROOT}/stacks/wordpress/bin/wp-stack"
FOLDER="smoke-image-bump-$$"

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

PROJECT_DIR="${WEBSITES_ROOT}/${FOLDER}"
cleanup() {
  rm -rf "${PROJECT_DIR}"
}
trap cleanup EXIT

mkdir -p "${PROJECT_DIR}"
cp "${ROOT}/templates/wordpress/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cat >"${PROJECT_DIR}/.env" <<'EOF'
PROJECT_SLUG=smoke-image-bump
WORDPRESS_IMAGE=wordpress:6.4.3-php8.2-apache
MARIADB_IMAGE=mariadb:10.11
WP_PORT=8098
PMA_PORT=8198
MAILHOG_UI_PORT=8298
MAILHOG_SMTP_PORT=8398
WP_DB_NAME=wordpress
WP_DB_USER=wpuser
WP_DB_PASSWORD=test
WP_DB_ROOT_PASSWORD=testroot
WP_TABLE_PREFIX=wp_
EOF

out="/tmp/wp-image-bump-smoke.out"
err="/tmp/wp-image-bump-smoke.err"

"${WP_STACK}" image bump --project "${FOLDER}" --wordpress 6.5.0 --php 8.3 \
  >"$out" 2>"$err"

grep -q "WORDPRESS_IMAGE:  wordpress:6.4.3-php8.2-apache  →  wordpress:6.5.0-php8.3-apache" "$out" || {
  echo "expected dry-run current → target WORDPRESS_IMAGE" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "dry run — no changes made" "$out" || {
  echo "expected dry-run message" >&2
  cat "$out" >&2
  exit 1
}
grep -q '^WORDPRESS_IMAGE=wordpress:6.4.3-php8.2-apache$' "${PROJECT_DIR}/.env" || {
  echo "dry-run must not rewrite .env" >&2
  exit 1
}

# Stale shell override must be cleared before compose; --skip-compose avoids Docker in CI/smoke.
export WORDPRESS_IMAGE="wordpress:9.9.9-php9.9-apache"
export MARIADB_IMAGE="mariadb:9.9"
"${WP_STACK}" image bump --project "${FOLDER}" --wordpress 6.5.0 --php 8.3 --mariadb 10.6 --yes --skip-compose \
  >"$out" 2>"$err"

grep -q '^WORDPRESS_IMAGE=wordpress:6.5.0-php8.3-apache$' "${PROJECT_DIR}/.env" || {
  echo "--yes did not write WORDPRESS_IMAGE via pin helper" >&2
  cat "${PROJECT_DIR}/.env" "$out" "$err" >&2
  exit 1
}
grep -q '^MARIADB_IMAGE=mariadb:10.6$' "${PROJECT_DIR}/.env" || {
  echo "--yes did not write MARIADB_IMAGE via pin helper" >&2
  cat "${PROJECT_DIR}/.env" "$out" "$err" >&2
  exit 1
}
grep -q "unset shell WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE" "$out" || {
  echo "expected shell unset landmine step" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "skipped compose" "$out" || {
  echo "expected --skip-compose note" >&2
  cat "$out" >&2
  exit 1
}
grep -q "refreshed link hub:" "$out" || {
  echo "expected automatic link hub refresh after --yes" >&2
  cat "$out" "$err" >&2
  exit 1
}

"${WP_STACK}" image bump --project "${FOLDER}" --mariadb 10.11 --yes --skip-compose --no-index \
  >"$out" 2>"$err"
grep -q "skipped link hub refresh (--no-index)" "$out" || {
  echo "expected --no-index skip note" >&2
  cat "$out" "$err" >&2
  exit 1
}

echo "smoke-wp-stack-image-bump: ok"
