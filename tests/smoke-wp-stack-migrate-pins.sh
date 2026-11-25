#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Smoke: migrate dry-run proposes WORDPRESS_IMAGE from backup + PHP pin source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WP_STACK="${ROOT}/stacks/wordpress/bin/wp-stack"
FOLDER="smoke-migrate-pins-$$"

# Hide operator stack-defaults while the CLI reloads load-config.sh.
_SMOKE_DEFAULTS="${ROOT}/config/stack-defaults.env"
_SMOKE_DEFAULTS_BAK=""
if [[ -f "${_SMOKE_DEFAULTS}" ]]; then
  _SMOKE_DEFAULTS_BAK="${_SMOKE_DEFAULTS}.bak-smoke-$$"
  mv "${_SMOKE_DEFAULTS}" "${_SMOKE_DEFAULTS_BAK}"
fi

# shellcheck disable=SC1091
source "${ROOT}/config/load-config.sh"

PROJECT_DIR="${WEBSITES_ROOT}/${FOLDER}"
cleanup() {
  rm -rf "${PROJECT_DIR}"
  if [[ -n "${_SMOKE_DEFAULTS_BAK}" && -f "${_SMOKE_DEFAULTS_BAK}" ]]; then
    mv "${_SMOKE_DEFAULTS_BAK}" "${_SMOKE_DEFAULTS}"
  fi
}
trap cleanup EXIT

mkdir -p "${PROJECT_DIR}/import/wp-content"
cp "${ROOT}/templates/wordpress/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cat >"${PROJECT_DIR}/.env" <<'EOF'
PROJECT_SLUG=smoke-migrate-pins
WORDPRESS_IMAGE=wordpress:6.5.0-php8.2-apache
MARIADB_IMAGE=mariadb:10.11
WP_PORT=8099
PMA_PORT=8199
MAILHOG_UI_PORT=8299
MAILHOG_SMTP_PORT=8399
WP_DB_NAME=wordpress
WP_DB_USER=wpuser
WP_DB_PASSWORD=test
WP_DB_ROOT_PASSWORD=testroot
WP_TABLE_PREFIX=wp_
EOF

cat >"${PROJECT_DIR}/import/manifest.json" <<'EOF'
{"version":"6.4.3","prefix":"wp_","url":"https://www.example.de"}
EOF

unset DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE
export DEFAULT_WORDPRESS_IMAGE DEFAULT_MARIADB_IMAGE DEFAULT_PHP_IMAGE

out="/tmp/wp-migrate-pins-smoke.out"
err="/tmp/wp-migrate-pins-smoke.err"

"${WP_STACK}" migrate --project "${FOLDER}" --only content \
  >"$out" 2>"$err"

grep -q "WORDPRESS_IMAGE: wordpress:6.4.3-php8.2-apache" "$out" || {
  echo "expected proposed pin from backup WP + current PHP" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "pin applied — backup WP 6.4.3" "$out" || {
  echo "expected pin applied messaging for backup WP" >&2
  cat "$out" >&2
  exit 1
}
grep -q "MARIADB_IMAGE:   mariadb:10.11" "$out" || {
  echo "expected keep current MariaDB pin" >&2
  cat "$out" >&2
  exit 1
}
grep -q "pin applied — keep current project pin" "$out" || {
  echo "expected pin applied messaging for MariaDB keep" >&2
  cat "$out" >&2
  exit 1
}
grep -q "dry run — no changes made" "$out" || {
  echo "expected dry-run message" >&2
  cat "$out" >&2
  exit 1
}

# Override path
"${WP_STACK}" migrate --project "${FOLDER}" --only content \
  --wordpress-image "wordpress:6.4.3-php8.1-apache" \
  --mariadb-image "mariadb:10.6" \
  >"$out" 2>"$err"

grep -q "WORDPRESS_IMAGE: wordpress:6.4.3-php8.1-apache" "$out" || {
  echo "expected --wordpress-image override in plan" >&2
  cat "$out" >&2
  exit 1
}
grep -q "override used — override (--wordpress-image)" "$out" || {
  echo "expected override used messaging" >&2
  cat "$out" >&2
  exit 1
}
grep -q "MARIADB_IMAGE:   mariadb:10.6" "$out" || {
  echo "expected --mariadb-image override in plan" >&2
  cat "$out" >&2
  exit 1
}

# --only db prints source URL; SQL required
cat >"${PROJECT_DIR}/import/smoke.sql" <<'EOF'
INSERT INTO `wp_options` VALUES (1,'siteurl','https://from-sql.example.de','yes');
EOF

# Detect-first: manifest wins over --source-url
"${WP_STACK}" migrate --project "${FOLDER}" --only db \
  --source-url "https://ignored.example.de" \
  >"$out" 2>"$err"
grep -q "source URL:    https://www.example.de  \\[detected (manifest.json)\\]" "$out" || {
  echo "expected manifest detect-first for source URL" >&2
  cat "$out" "$err" >&2
  exit 1
}
grep -q "ignoring --source-url" "$out" || {
  echo "expected note that --source-url was ignored (detect-first)" >&2
  cat "$out" "$err" >&2
  exit 1
}

# Source URL flag fills gap when detection empty
rm -f "${PROJECT_DIR}/import/manifest.json"
# Remove siteurl from SQL so flag is the only source
cat >"${PROJECT_DIR}/import/smoke.sql" <<'EOF'
INSERT INTO `wp_options` VALUES (1,'blogname','Smoke','yes');
EOF
"${WP_STACK}" migrate --project "${FOLDER}" --only db \
  --source-url "https://flag-only.example.de" \
  >"$out" 2>"$err"
grep -q "source URL:    https://flag-only.example.de  \\[flag (--source-url)\\]" "$out" || {
  echo "expected --source-url when detection empty" >&2
  cat "$out" "$err" >&2
  exit 1
}

echo "smoke-wp-stack-migrate-pins: ok"
