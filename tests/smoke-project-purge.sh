#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: project-purge dry-run + --yes on a fixture folder (no real Docker volume required).
# Also bash -n for menu wiring.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PURGE="${ROOT}/bin/project-purge.sh"
FOLDER="smoke-project-purge-$$"

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

PROJECT_DIR="${WEBSITES_ROOT}/${FOLDER}"
cleanup() {
  rm -rf "${PROJECT_DIR}"
}
trap cleanup EXIT

bash -n "${ROOT}/bin/menu.sh"
bash -n "$PURGE"

mkdir -p "${PROJECT_DIR}"
cp "${ROOT}/templates/wordpress/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cat >"${PROJECT_DIR}/.env" <<EOF
PROJECT_SLUG=${FOLDER}
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

out="/tmp/project-purge-smoke.out"
err="/tmp/project-purge-smoke.err"

"$PURGE" --project "$FOLDER" --dry-run >"$out" 2>"$err"
grep -q "Dry run — no changes made" "$out" || {
  echo "expected dry-run message" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "${FOLDER}_db_data" "$out" || {
  echo "expected volume name in plan" >&2
  cat "$out" >&2
  exit 1
}
[[ -d "$PROJECT_DIR" ]] || {
  echo "dry-run must keep project folder" >&2
  exit 1
}

# Refuse paths with slashes
if "$PURGE" --project "../etc" --dry-run >"$out" 2>"$err"; then
  echo "expected slash project name to fail" >&2
  cat "$out" "$err" >&2
  exit 1
fi

"$PURGE" --project "$FOLDER" --yes >"$out" 2>"$err"
grep -q "Purge complete" "$out" || {
  echo "expected purge complete" >&2
  cat "$out" "$err" >&2
  exit 1
}
[[ ! -d "$PROJECT_DIR" ]] || {
  echo "expected project folder deleted" >&2
  exit 1
}

# Idempotent absence
if "$PURGE" --project "$FOLDER" --dry-run >"$out" 2>"$err"; then
  echo "expected missing folder to fail" >&2
  cat "$out" "$err" >&2
  exit 1
fi

"$PURGE" --list-orphans >"$out" 2>"$err" || {
  echo "list-orphans should succeed" >&2
  cat "$out" "$err" >&2
  exit 1
}

echo "smoke-project-purge: ok"
