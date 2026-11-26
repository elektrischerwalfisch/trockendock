#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Switch wp-content ownership between www-data (33:33) and the host user.
# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Official WordPress image runs as www-data uid/gid 33.
WP_STACK_WWW_DATA_UID=33
WP_STACK_WWW_DATA_GID=33

wp_stack_wp_content_owner_usage() {
  cat <<'EOF'
Usage:
  wp-stack wp-content owner status [--project <folder>]
  wp-stack wp-content owner toggle [--project <folder>] [--yes] [--skip-compose]
  wp-stack wp-content owner set www-data|host [--project <folder>] [--yes] [--skip-compose]

Toggle / set stop Compose, sudo chown -R on wp-content, then start again (unless
--skip-compose). Without --yes, print the plan only.

Targets:
  www-data  → 33:33 (wp-admin plugin/theme updates)
  host      → $USER:$USER (host/Git editing)

Current owner is detected from the wp-content directory only (not a recursive scan).
EOF
}

# Print "uid:gid" for a path (directory or file).
wp_stack_wp_content_stat_owner() {
  local path="$1"
  stat -c '%u:%g' "$path"
}

# Classify uid:gid → www-data | host | unknown
# Sets WP_STACK_OWNER_KIND and WP_STACK_OWNER_LABEL.
wp_stack_wp_content_classify_owner() {
  local ug="$1"
  local host_ug
  host_ug="$(id -u):$(id -g)"

  WP_STACK_OWNER_KIND=""
  WP_STACK_OWNER_LABEL=""

  if [[ "$ug" == "${WP_STACK_WWW_DATA_UID}:${WP_STACK_WWW_DATA_GID}" ]]; then
    WP_STACK_OWNER_KIND="www-data"
    WP_STACK_OWNER_LABEL="www-data (33:33)"
  elif [[ "$ug" == "$host_ug" ]]; then
    WP_STACK_OWNER_KIND="host"
    WP_STACK_OWNER_LABEL="host user (${USER} ${host_ug})"
  else
    WP_STACK_OWNER_KIND="unknown"
    WP_STACK_OWNER_LABEL="unknown (${ug})"
  fi
}

wp_stack_wp_content_target_spec() {
  local target="$1"
  case "$target" in
    www-data)
      printf '%s:%s' "$WP_STACK_WWW_DATA_UID" "$WP_STACK_WWW_DATA_GID"
      ;;
    host)
      printf '%s:%s' "$(id -u)" "$(id -g)"
      ;;
    *)
      return 1
      ;;
  esac
}

wp_stack_wp_content_target_label() {
  local target="$1"
  case "$target" in
    www-data) printf 'www-data (33:33) — wp-admin updates / plugins' ;;
    host) printf 'host user (%s %s:%s) — host/Git editing' "$USER" "$(id -u)" "$(id -g)" ;;
    *) return 1 ;;
  esac
}

wp_stack_wp_content_other_target() {
  local kind="$1"
  case "$kind" in
    www-data) printf 'host' ;;
    host) printf 'www-data' ;;
    *) return 1 ;;
  esac
}

wp_stack_wp_content_owner_status() {
  local project="" dir wpc ug
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      -h|--help|help)
        wp_stack_wp_content_owner_usage
        return 0
        ;;
      *)
        wp_stack_die "unknown argument: $1 (see wp-stack wp-content owner --help)"
        ;;
    esac
  done

  wp_stack_resolve_project "$project"
  dir="$WP_STACK_PROJECT_DIR"
  wpc="${dir}/wp-content"
  [[ -d "$wpc" ]] || wp_stack_die "missing wp-content directory: ${wpc}"

  ug="$(wp_stack_wp_content_stat_owner "$wpc")"
  wp_stack_wp_content_classify_owner "$ug"
  echo "wp-content ownership — $(basename "$dir")"
  echo "  path:    ${wpc}"
  echo "  current: ${WP_STACK_OWNER_LABEL}"
  if [[ "$WP_STACK_OWNER_KIND" == "unknown" ]]; then
    echo "  note:    neither www-data (33:33) nor host (${USER} $(id -u):$(id -g)); use 'set www-data|host'"
  fi
}

# Apply ownership change. Args: target (www-data|host), project, do_run (0/1), skip_compose (0/1)
wp_stack_wp_content_owner_apply() {
  local target="$1"
  local project="$2"
  local do_run="$3"
  local skip_compose="$4"
  local dir wpc ug target_ug target_label chown_spec

  case "$target" in
    www-data|host) ;;
    *) wp_stack_die "target must be www-data or host" ;;
  esac

  wp_stack_resolve_project "$project"
  dir="$WP_STACK_PROJECT_DIR"
  wpc="${dir}/wp-content"
  [[ -d "$wpc" ]] || wp_stack_die "missing wp-content directory: ${wpc}"

  ug="$(wp_stack_wp_content_stat_owner "$wpc")"
  wp_stack_wp_content_classify_owner "$ug"
  target_ug="$(wp_stack_wp_content_target_spec "$target")"
  target_label="$(wp_stack_wp_content_target_label "$target")"

  if [[ "$WP_STACK_OWNER_KIND" == "$target" ]]; then
    wp_stack_info "already ${WP_STACK_OWNER_LABEL} — nothing to do"
    return 0
  fi

  if [[ "$target" == "host" ]]; then
    chown_spec="${USER}:${USER}"
  else
    chown_spec="${WP_STACK_WWW_DATA_UID}:${WP_STACK_WWW_DATA_GID}"
  fi

  echo "wp-content ownership — $(basename "$dir")"
  echo "  current: ${WP_STACK_OWNER_LABEL}"
  echo "  target:  ${target_label}"
  echo "  plan:"
  if [[ "$skip_compose" -eq 0 ]]; then
    echo "    1. docker compose stop"
    echo "    2. sudo chown -R ${chown_spec} wp-content"
    echo "    3. docker compose up -d"
  else
    echo "    1. sudo chown -R ${chown_spec} wp-content  (--skip-compose)"
  fi
  echo "  note: sudo may ask for your password"

  if [[ "$do_run" -ne 1 ]]; then
    wp_stack_info "dry run — no changes made. Re-run with --yes to execute."
    return 0
  fi

  if [[ "$skip_compose" -eq 0 ]]; then
    wp_stack_info "docker compose stop"
    if ! docker compose -f "${dir}/docker-compose.yml" --project-directory "$dir" stop; then
      wp_stack_die "docker compose stop failed — ownership not changed"
    fi
  fi

  wp_stack_info "sudo chown -R ${chown_spec} wp-content"
  if ! sudo chown -R "$chown_spec" "$wpc"; then
    if [[ "$skip_compose" -eq 0 ]]; then
      wp_stack_info "chown failed — attempting docker compose up -d to restore containers"
      docker compose -f "${dir}/docker-compose.yml" --project-directory "$dir" up -d || true
    fi
    wp_stack_die "sudo chown failed — ownership not changed"
  fi

  if [[ "$skip_compose" -eq 0 ]]; then
    wp_stack_info "docker compose up -d"
    if ! docker compose -f "${dir}/docker-compose.yml" --project-directory "$dir" up -d; then
      wp_stack_die "docker compose up -d failed after chown (wp-content may already be ${chown_spec})"
    fi
  fi

  ug="$(wp_stack_wp_content_stat_owner "$wpc")"
  if [[ "$ug" != "$target_ug" ]]; then
    wp_stack_die "after chown, wp-content owner is ${ug}, expected ${target_ug}"
  fi
  wp_stack_wp_content_classify_owner "$ug"
  wp_stack_info "done: wp-content owned by ${WP_STACK_OWNER_LABEL}"
}

wp_stack_wp_content_owner_toggle() {
  local project="" do_run=0 skip_compose=0
  local dir wpc ug other

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --yes)
        do_run=1
        shift
        ;;
      --skip-compose)
        skip_compose=1
        shift
        ;;
      -h|--help|help)
        wp_stack_wp_content_owner_usage
        return 0
        ;;
      *)
        wp_stack_die "unknown argument: $1 (see wp-stack wp-content owner --help)"
        ;;
    esac
  done

  wp_stack_resolve_project "$project"
  dir="$WP_STACK_PROJECT_DIR"
  wpc="${dir}/wp-content"
  [[ -d "$wpc" ]] || wp_stack_die "missing wp-content directory: ${wpc}"

  ug="$(wp_stack_wp_content_stat_owner "$wpc")"
  wp_stack_wp_content_classify_owner "$ug"
  if [[ "$WP_STACK_OWNER_KIND" == "unknown" ]]; then
    wp_stack_die "current owner is ${WP_STACK_OWNER_LABEL} — toggle needs www-data or host; use: wp-stack wp-content owner set www-data|host --project $(basename "$dir") --yes"
  fi
  other="$(wp_stack_wp_content_other_target "$WP_STACK_OWNER_KIND")"
  wp_stack_wp_content_owner_apply "$other" "$project" "$do_run" "$skip_compose"
}

wp_stack_wp_content_owner_set() {
  local target="${1:-}"
  local project="" do_run=0 skip_compose=0
  shift || true

  case "$target" in
    www-data|host) ;;
    ""|-h|--help|help)
      wp_stack_wp_content_owner_usage
      return 0
      ;;
    *)
      wp_stack_die "set requires www-data or host (got: ${target})"
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --yes)
        do_run=1
        shift
        ;;
      --skip-compose)
        skip_compose=1
        shift
        ;;
      -h|--help|help)
        wp_stack_wp_content_owner_usage
        return 0
        ;;
      *)
        wp_stack_die "unknown argument: $1 (see wp-stack wp-content owner --help)"
        ;;
    esac
  done

  wp_stack_wp_content_owner_apply "$target" "$project" "$do_run" "$skip_compose"
}

wp_stack_wp_content_owner() {
  local action="${1:-}"
  case "$action" in
    ""|-h|--help|help)
      wp_stack_wp_content_owner_usage
      ;;
    status)
      shift
      wp_stack_wp_content_owner_status "$@"
      ;;
    toggle)
      shift
      wp_stack_wp_content_owner_toggle "$@"
      ;;
    set)
      shift
      wp_stack_wp_content_owner_set "$@"
      ;;
    *)
      wp_stack_die "unknown wp-content owner action: ${action} (status|toggle|set)"
      ;;
  esac
}
