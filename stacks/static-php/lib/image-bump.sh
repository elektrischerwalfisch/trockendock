#!/usr/bin/env bash
# Guided Static PHP image bump (dry-run first; --yes writes .env + compose).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

static_stack_image_bump_usage() {
  cat <<'EOF'
Usage: static-stack image bump [options]

Change the pinned PHP_IMAGE for an existing static PHP project.
Dry-run by default. Pass --yes to write .env via shared pin helpers, unset
shell PHP_IMAGE, then pull/recreate the web service.

Options:
  --project <folder>     Project under $WEBSITES_ROOT (default: cwd)
  --php <x.y|php:x.y-apache>   Target PHP pin (required)
  --yes                  Write pin + compose apply (default: dry-run only)
  --skip-compose         With --yes: write .env only (no pull/recreate)
  --no-index             With --yes: skip link hub refresh
  -h, --help             Show this help

Hub tags:
  https://hub.docker.com/_/php/tags

Examples:
  static-stack image bump --project kundin-a --php 8.3
  static-stack image bump --project kundin-a --php php:8.2-apache --yes
EOF
}

static_stack_image_bump_read_env_var() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

static_stack_image_bump_refresh_hub() {
  if [[ ! -x "${GENERATE_INDEX_SCRIPT:-}" ]]; then
    static_stack_info "WARNING: GENERATE_INDEX_SCRIPT missing or not executable — skipped hub refresh"
    return 0
  fi
  if "$GENERATE_INDEX_SCRIPT"; then
    static_stack_info "refreshed link hub: ${LOCAL_DEV_INDEX_FILE}"
  else
    static_stack_info "WARNING: link hub refresh failed — run \$GENERATE_INDEX_SCRIPT manually"
  fi
}

static_stack_image_bump() {
  local project="" yes=0 skip_compose=0 skip_index=0 php_input=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        static_stack_image_bump_usage
        return 0
        ;;
      --project)
        [[ $# -ge 2 ]] || static_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --php)
        [[ $# -ge 2 ]] || static_stack_die "--php requires a value"
        php_input="$2"
        shift 2
        ;;
      --yes)
        yes=1
        shift
        ;;
      --skip-compose)
        skip_compose=1
        shift
        ;;
      --no-index)
        skip_index=1
        shift
        ;;
      --*)
        static_stack_die "unknown option: $1"
        ;;
      *)
        static_stack_die "unexpected argument: $1"
        ;;
    esac
  done

  [[ -n "$php_input" ]] || static_stack_die "missing --php <x.y|php:x.y-apache>"

  static_stack_resolve_project "$project"
  local dir="$STATIC_STACK_PROJECT_DIR"
  local env_file="${dir}/.env"
  local cur_php target_php

  static_stack_load_env "$dir"

  cur_php="$(static_stack_image_bump_read_env_var "$env_file" PHP_IMAGE)"
  target_php="$(trockendock_resolve_php_image "$php_input")"
  trockendock_validate_php_image "$target_php" || static_stack_die "invalid --php"

  echo ""
  static_stack_info "image bump plan for '${PROJECT_SLUG:-$(basename "$dir")}' (${dir})"
  echo "  PHP_IMAGE:  ${cur_php:-(unset)}  →  ${target_php}"

  if [[ "$yes" -eq 0 ]]; then
    echo ""
    static_stack_info "dry run — no changes made (pass --yes to write .env and apply compose)"
    return 0
  fi

  trockendock_set_env_var "$dir" PHP_IMAGE "$target_php"
  static_stack_info "wrote PHP_IMAGE=${target_php}"

  # Landmine: Compose prefers shell env over project .env.
  unset WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE
  static_stack_info "unset shell WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE (Compose must read .env)"

  if [[ "$skip_index" -eq 0 ]]; then
    static_stack_image_bump_refresh_hub
  else
    static_stack_info "skipped link hub refresh (--no-index)"
  fi

  if [[ "$skip_compose" -eq 1 ]]; then
    static_stack_info "skipped compose (--skip-compose); pull/recreate when ready"
    return 0
  fi

  static_stack_info "compose pull + recreate: web"
  (
    cd "$dir"
    docker compose config --images
    docker compose pull web
    docker compose up -d --force-recreate web
  )
  static_stack_info "image bump applied"
}
