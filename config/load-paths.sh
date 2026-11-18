#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Trockendock — central path loader
# Author: elektrischerwalfisch
#
# See LICENSE and VERSION at repository root.
#
# Usage: source "/path/to/trockendock/config/load-paths.sh"

_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${_CONFIG_DIR}/paths.env" ]]; then
  # shellcheck disable=SC1091
  source "${_CONFIG_DIR}/paths.env"
elif [[ -f "${_CONFIG_DIR}/paths.env.example" ]]; then
  # shellcheck disable=SC1091
  source "${_CONFIG_DIR}/paths.env.example"
else
  echo "load-paths.sh: missing config/paths.env and paths.env.example" >&2
  return 1 2>/dev/null || exit 1
fi

# Derived paths — filenames only defined here
LOCAL_DEV_INDEX_FILE="${TROCKENDOCK_ROOT}/trockendock.html"
GENERATE_INDEX_SCRIPT="${TROCKENDOCK_ROOT}/bin/generate-local-dev-index.sh"
STATIC_PHP_TEMPLATE="${TROCKENDOCK_ROOT}/templates/static-php"
STATIC_PHP_MAILHOG_TEMPLATE="${TROCKENDOCK_ROOT}/templates/static-php-mailhog"

if [[ -f "${TROCKENDOCK_ROOT}/VERSION" ]]; then
  TROCKENDOCK_VERSION="$(tr -d '[:space:]' < "${TROCKENDOCK_ROOT}/VERSION")"
else
  TROCKENDOCK_VERSION="dev"
fi

# Drop retired vars if present from an older shell profile / previous load
unset TROCKENDOCK_LOCAL ARCHIVE_MANIFESTS_DIR 2>/dev/null || true

export WEBSITES_ROOT TROCKENDOCK_ROOT TROCKENDOCK_VERSION
export LOCAL_DEV_INDEX_FILE GENERATE_INDEX_SCRIPT
export STATIC_PHP_TEMPLATE STATIC_PHP_MAILHOG_TEMPLATE
