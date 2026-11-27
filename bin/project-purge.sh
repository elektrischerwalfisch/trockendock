#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Purge a local site under $WEBSITES_ROOT: named DB volume (if any) + project folder.
# Does NOT run compose down — refuse when containers still exist (use Remove Stack first).
#
# Usage:
#   project-purge.sh --project <folder> --dry-run
#   project-purge.sh --project <folder> --yes
#   project-purge.sh --list-orphans

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config/load-config.sh
source "${ROOT}/config/load-config.sh"

purge_die() {
  echo "project-purge: $*" >&2
  exit 1
}

purge_read_env_var() {
  local file="$1"
  local key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

purge_usage() {
  cat <<'EOF'
Usage:
  project-purge.sh --project <folder> --dry-run
  project-purge.sh --project <folder> --yes
  project-purge.sh --list-orphans

Purge deletes the project directory under $WEBSITES_ROOT and the named
Docker volume ${PROJECT_SLUG}_db_data when present. Stack containers must
already be removed (compose down) — this command never runs compose down.
EOF
}

purge_resolve_project_dir() {
  local folder="$1"
  local project_dir websites_real project_real trockendock_real

  [[ -n "$folder" ]] || purge_die "empty project folder name"
  [[ "$folder" != "." && "$folder" != ".." ]] || purge_die "invalid project folder name"
  [[ "$folder" != */* ]] || purge_die "project must be a single folder name under \$WEBSITES_ROOT (got: ${folder})"

  project_dir="${WEBSITES_ROOT}/${folder}"
  [[ -d "$project_dir" ]] || purge_die "project folder not found: ${project_dir}"

  websites_real="$(cd "$WEBSITES_ROOT" && pwd)"
  project_real="$(cd "$project_dir" && pwd)"
  trockendock_real="$(cd "$TROCKENDOCK_ROOT" && pwd)"

  case "$project_real" in
    "${websites_real}"/*) ;;
    *) purge_die "refusing path outside \$WEBSITES_ROOT: ${project_real}" ;;
  esac
  [[ "$project_real" != "$websites_real" ]] || purge_die "refusing to purge \$WEBSITES_ROOT itself"

  case "$project_real" in
    "${trockendock_real}" | "${trockendock_real}"/*)
      purge_die "refusing path under \$TROCKENDOCK_ROOT: ${project_real}"
      ;;
  esac

  printf '%s' "$project_real"
}

purge_containers_present() {
  local dir="$1"
  local ids=""
  ids="$(docker compose -f "${dir}/docker-compose.yml" --project-directory "$dir" ps -aq 2>/dev/null || true)"
  [[ -n "$ids" ]]
}

purge_volume_name() {
  local dir="$1"
  local folder slug
  folder="$(basename "$dir")"
  slug=""
  if [[ -f "${dir}/.env" ]]; then
    slug="$(purge_read_env_var "${dir}/.env" PROJECT_SLUG)"
  fi
  slug="${slug:-$folder}"
  printf '%s_db_data' "$slug"
}

purge_volume_exists() {
  local volume_name="$1"
  docker volume inspect "$volume_name" >/dev/null 2>&1
}

purge_print_plan() {
  local dir="$1"
  local volume_name="$2"
  local volume_state="absent"
  if purge_volume_exists "$volume_name"; then
    volume_state="present — will delete"
  else
    volume_state="absent — skip"
  fi
  echo "Purge plan"
  echo "──────────"
  echo "  Folder:  ${dir}"
  echo "  Volume:  ${volume_name} (${volume_state})"
}

purge_list_orphans() {
  local websites_real vol slug folder found_any=0
  websites_real="$(cd "$WEBSITES_ROOT" && pwd)"

  echo "Orphan DB volumes (*_db_data with no matching project folder)"
  echo "────────────────────────────────────────────────────────────"
  while IFS= read -r vol; do
    [[ -n "$vol" ]] || continue
    [[ "$vol" == *_db_data ]] || continue
    slug="${vol%_db_data}"
    folder="${websites_real}/${slug}"
    if [[ -d "$folder" ]]; then
      continue
    fi
    # Also skip if any project .env uses this PROJECT_SLUG (folder name ≠ slug).
    if grep -Rsl --include='.env' -E "^PROJECT_SLUG=${slug}$" "${websites_real}" >/dev/null 2>&1; then
      continue
    fi
    echo "  ${vol}"
    found_any=1
  done < <(docker volume ls -q 2>/dev/null || true)

  if [[ "$found_any" -eq 0 ]]; then
    echo "  (none)"
  fi
}

purge_run() {
  local folder="$1"
  local mode="$2"
  local dir volume_name volume_ok=1 folder_ok=1

  dir="$(purge_resolve_project_dir "$folder")"
  [[ -f "${dir}/docker-compose.yml" ]] || purge_die "missing docker-compose.yml in ${dir}"

  if purge_containers_present "$dir"; then
    purge_die "stack containers still present for '${folder}'. Run Platform → Remove stack (compose down) first — purge never runs compose down."
  fi

  volume_name="$(purge_volume_name "$dir")"
  purge_print_plan "$dir" "$volume_name"

  if [[ "$mode" == "dry-run" ]]; then
    echo
    echo "Dry run — no changes made."
    return 0
  fi

  echo
  if purge_volume_exists "$volume_name"; then
    echo "→ docker volume rm ${volume_name}"
    if ! docker volume rm "$volume_name"; then
      echo "project-purge: failed to remove volume ${volume_name}" >&2
      volume_ok=0
    fi
  else
    echo "→ volume ${volume_name} absent — skip"
  fi

  echo "→ rm -rf ${dir}"
  if ! rm -rf -- "$dir"; then
    echo "project-purge: failed to delete project folder ${dir}" >&2
    folder_ok=0
  fi

  if [[ "$volume_ok" -eq 1 && "$folder_ok" -eq 1 ]]; then
    echo
    echo "Purge complete for '${folder}'."
    return 0
  fi

  echo
  echo "project-purge: partial failure — volume_ok=${volume_ok} folder_ok=${folder_ok}" >&2
  return 1
}

PROJECT_FOLDER=""
MODE=""
LIST_ORPHANS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || purge_die "--project requires a folder name"
      PROJECT_FOLDER="$2"
      shift 2
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --yes)
      MODE="yes"
      shift
      ;;
    --list-orphans)
      LIST_ORPHANS=1
      shift
      ;;
    -h | --help)
      purge_usage
      exit 0
      ;;
    *)
      purge_die "unknown argument: $1 (see --help)"
      ;;
  esac
done

if [[ "$LIST_ORPHANS" -eq 1 ]]; then
  [[ -z "$PROJECT_FOLDER" && -z "$MODE" ]] || purge_die "--list-orphans cannot be combined with --project / --dry-run / --yes"
  purge_list_orphans
  exit 0
fi

[[ -n "$PROJECT_FOLDER" ]] || {
  purge_usage
  purge_die "--project <folder> is required"
}
[[ -n "$MODE" ]] || purge_die "specify --dry-run or --yes"

purge_run "$PROJECT_FOLDER" "$MODE"
