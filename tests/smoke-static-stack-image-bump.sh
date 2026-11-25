#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: static-stack image bump dry-run + --yes .env write + unset landmine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATIC_STACK="${ROOT}/stacks/static-php/bin/static-stack"
FOLDER="smoke-static-image-bump-$$"

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

PROJECT_DIR="${WEBSITES_ROOT}/${FOLDER}"
cleanup() {
  rm -rf "${PROJECT_DIR}"
}
trap cleanup EXIT

mkdir -p "${PROJECT_DIR}"
cp "${ROOT}/templates/static-php/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cat >"${PROJECT_DIR}/.env" <<'EOF'
PROJECT_SLUG=smoke-static-image-bump
STACK=static-php
PHP_IMAGE=php:8.2-apache
WEB_PORT=8097
EOF

out="/tmp/static-image-bump-smoke.out"
err="/tmp/static-image-bump-smoke.err"

"${STATIC_STACK}" image bump --project "${FOLDER}" --php 8.3 \
  >"$out" 2>"$err"

grep -q "PHP_IMAGE:  php:8.2-apache  →  php:8.3-apache" "$out" || {
  echo "expected dry-run current → target PHP_IMAGE" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "dry run — no changes made" "$out" || {
  echo "expected dry-run message" >&2
  cat "$out" >&2
  exit 1
}

export PHP_IMAGE="php:9.9-apache"
"${STATIC_STACK}" image bump --project "${FOLDER}" --php 8.3 --yes --skip-compose \
  >"$out" 2>"$err"

grep -q '^PHP_IMAGE=php:8.3-apache$' "${PROJECT_DIR}/.env" || {
  echo "--yes did not write PHP_IMAGE" >&2
  cat "${PROJECT_DIR}/.env" "$out" "$err" >&2
  exit 1
}
grep -q "unset shell WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE" "$out" || {
  echo "expected shell unset landmine step" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "refreshed link hub:" "$out" || {
  echo "expected automatic link hub refresh after --yes" >&2
  cat "$out" "$err" >&2
  exit 1
}

"${STATIC_STACK}" image bump --project "${FOLDER}" --php 8.2 --yes --skip-compose --no-index \
  >"$out" 2>"$err"
grep -q "skipped link hub refresh (--no-index)" "$out" || {
  echo "expected --no-index skip note" >&2
  cat "$out" "$err" >&2
  exit 1
}

echo "smoke-static-stack-image-bump: ok"
