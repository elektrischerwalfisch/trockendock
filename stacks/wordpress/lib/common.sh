#!/usr/bin/env bash
# Shared setup for wp-stack scripts.

set -euo pipefail

WP_STACK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WP_STACK_ROOT="$(cd "${WP_STACK_LIB}/.." && pwd)"
TROCKENDOCK_ROOT="$(cd "${WP_STACK_ROOT}/../.." && pwd)"
WORDPRESS_TEMPLATE="${TROCKENDOCK_ROOT}/templates/wordpress"

# shellcheck disable=SC1091
source "${TROCKENDOCK_ROOT}/config/load-paths.sh"

wp_stack_die() {
  echo "wp-stack: $*" >&2
  exit 1
}

wp_stack_info() {
  echo "wp-stack: $*"
}

wp_stack_generate_password() {
  openssl rand -base64 18 | tr -d '/+=' | head -c 20
}

wp_stack_validate_folder_name() {
  local folder="$1"

  if [[ ! "$folder" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    wp_stack_die "invalid folder name '${folder}' (use lowercase letters, digits, hyphens)"
  fi

  if [[ "$folder" == "trockendock" || "$folder" == "00-trockendock" ]]; then
    wp_stack_die "folder name '${folder}' is reserved"
  fi
}

# Resolve the project directory from a folder name under $WEBSITES_ROOT,
# or fall back to the current directory. Sets WP_STACK_PROJECT_DIR.
wp_stack_resolve_project() {
  local project="${1:-}"
  local dir

  if [[ -n "$project" ]]; then
    dir="${WEBSITES_ROOT}/${project}"
  else
    dir="$PWD"
  fi

  [[ -f "${dir}/docker-compose.yml" ]] || wp_stack_die "not a project directory: ${dir} (no docker-compose.yml — pass --project <folder> or cd into the project)"
  [[ -f "${dir}/.env" ]] || wp_stack_die "missing .env in ${dir}"

  WP_STACK_PROJECT_DIR="$dir"
}

# Source a project's .env into the environment (exported).
wp_stack_load_env() {
  local dir="$1"
  set -a
  # shellcheck disable=SC1090,SC1091
  source "${dir}/.env"
  set +a
}
