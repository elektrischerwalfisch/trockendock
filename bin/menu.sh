#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Trockendock — interactive operator menu
# Author: elektrischerwalfisch
#
# See LICENSE and VERSION at repository root.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config/load-config.sh
source "${ROOT}/config/load-config.sh"
# shellcheck source=../stacks/lib/stack-image-pins.sh
source "${ROOT}/stacks/lib/stack-image-pins.sh"

WP_STACK="${ROOT}/stacks/wordpress/bin/wp-stack"
STATIC_STACK="${ROOT}/stacks/static-php/bin/static-stack"
DOCKER_STATUS="${ROOT}/bin/docker-container-status.sh"

menu_pause() {
  echo
  read -r -p "Press Enter to continue..." _
}

menu_prompt() {
  local prompt="$1"
  local value=""
  read -r -p "${prompt}: " value
  printf '%s' "$value"
}

# Prompt with a format placeholder. If default is set, empty Enter uses it;
# otherwise empty input is rejected (re-prompt).
menu_prompt_pin() {
  local label="$1" placeholder="$2" default="${3:-}"
  local value=""
  while true; do
    if [[ -n "$default" ]]; then
      read -r -p "${label} [${placeholder}; Enter=${default}]: " value
      value="${value:-$default}"
    else
      read -r -p "${label} [${placeholder}]: " value
    fi
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    echo "Required — enter a value, or set config/stack-defaults.env for Enter defaults."
  done
}

menu_confirm_yes() {
  local prompt="$1"
  local answer=""
  read -r -p "${prompt} [y/N]: " answer
  [[ "${answer}" == "y" || "${answer}" == "Y" ]]
}

menu_run() {
  echo
  echo "→ $*"
  echo
  if "$@"; then
    menu_pause
    return 0
  fi
  echo
  echo "trockendock-menu: command failed (exit $?)."
  menu_pause
  return 0
}

# Open a local HTML file in the default *web browser*.
# Do not use plain xdg-open on the path: text/html may be bound to a non-browser
# (on this machine: Thunderbird), which opens a compose window instead of a tab.
menu_open_html_in_browser() {
  local file="$1"
  local url desktop
  url="file://${file}"

  echo
  echo "→ open in browser: ${file}"
  echo

  if [[ -n "${BROWSER:-}" ]]; then
    # shellcheck disable=SC2086
    ${BROWSER} "${url}" >/dev/null 2>&1 &
    menu_pause
    return 0
  fi

  desktop="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  if [[ -n "$desktop" ]]; then
    if command -v gtk-launch >/dev/null 2>&1; then
      gtk-launch "$desktop" "$url" >/dev/null 2>&1 &
      menu_pause
      return 0
    fi
    if command -v gio >/dev/null 2>&1; then
      for dir in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications /usr/share/applications; do
        if [[ -f "${dir}/${desktop}" ]]; then
          gio launch "${dir}/${desktop}" "$url" >/dev/null 2>&1 &
          menu_pause
          return 0
        fi
      done
    fi
  fi

  for browser in chromium-browser chromium google-chrome firefox brave-browser; do
    if command -v "$browser" >/dev/null 2>&1; then
      "$browser" "$url" >/dev/null 2>&1 &
      menu_pause
      return 0
    fi
  done

  echo "trockendock-menu: no web browser found. Open manually:"
  echo "  ${url}"
  menu_pause
}

menu_show_paths() {
  cat <<EOF

Trockendock paths
─────────────────
  VERSION               ${TROCKENDOCK_VERSION:-dev}
  TROCKENDOCK_ROOT      ${TROCKENDOCK_ROOT}
  WEBSITES_ROOT         ${WEBSITES_ROOT}
  LOCAL_DEV_INDEX_FILE  ${LOCAL_DEV_INDEX_FILE}
  GENERATE_INDEX_SCRIPT ${GENERATE_INDEX_SCRIPT}

EOF
  menu_pause
}

menu_wordpress_create() {
  local folder theme source_url=""
  local def_wp="" def_php="" def_mdb="" parts
  local wp_core php_minor mariadb_minor wordpress_image mariadb_image
  local create_args=()

  folder="$(menu_prompt "Project folder name under \$WEBSITES_ROOT")"
  [[ -n "$folder" ]] || return 0
  theme="$(menu_prompt "Theme slug (empty = folder name)")"

  if [[ -n "${DEFAULT_WORDPRESS_IMAGE:-}" ]]; then
    if parts="$(trockendock_parse_wordpress_image_parts "$DEFAULT_WORDPRESS_IMAGE")"; then
      read -r def_wp def_php <<<"$parts"
    fi
  fi
  if [[ -n "${DEFAULT_MARIADB_IMAGE:-}" ]]; then
    def_mdb="$(trockendock_parse_mariadb_image_minor "$DEFAULT_MARIADB_IMAGE" || true)"
  fi

  cat <<'EOF'

Image pins
──────────
  WordPress tags: https://hub.docker.com/_/wordpress/tags
  MariaDB tags:   https://hub.docker.com/_/mariadb/tags
  Format:         wordpress:<WP>-php<PHP>-apache

EOF
  if [[ -n "${DEFAULT_WORDPRESS_IMAGE:-}" || -n "${DEFAULT_MARIADB_IMAGE:-}" ]]; then
    echo "  stack-defaults: WORDPRESS_IMAGE=${DEFAULT_WORDPRESS_IMAGE:-'(unset)'} MARIADB_IMAGE=${DEFAULT_MARIADB_IMAGE:-'(unset)'}"
    echo
  fi

  wp_core="$(menu_prompt_pin "WordPress core" "x.y.z" "$def_wp")"
  php_minor="$(menu_prompt_pin "PHP minor" "x.y" "$def_php")"
  mariadb_minor="$(menu_prompt_pin "MariaDB" "x.y" "$def_mdb")"

  wordpress_image="$(trockendock_format_wordpress_image "$wp_core" "$php_minor")"
  mariadb_image="$(trockendock_format_mariadb_image "$mariadb_minor")"

  if ! trockendock_validate_wordpress_image "$wordpress_image"; then
    menu_pause
    return 0
  fi
  if ! trockendock_validate_mariadb_image "$mariadb_image"; then
    menu_pause
    return 0
  fi

  create_args=(project create "$folder" --wordpress-image "$wordpress_image" --mariadb-image "$mariadb_image")
  if [[ -n "$theme" ]]; then
    create_args+=(--theme "$theme")
  fi
  source_url="$(menu_prompt "Live site URL (optional, empty = no Live link)")"
  if [[ -n "$source_url" ]]; then
    create_args+=(--source-url "$source_url")
  fi
  if menu_confirm_yes "Dry run only"; then
    create_args+=(--dry-run)
  fi
  menu_run "$WP_STACK" "${create_args[@]}"
}

menu_wordpress_migrate() {
  local folder source_url="" args=(migrate)
  cat <<'EOF'

Migrate
───────
Create an import/ folder in the project and unpack exactly one backup directly into it:

  import/wp-content/
  import/<dump>.sql or import/<dump>.sql.gz
  import/manifest.json   (optional)

No extra folder around those entries. A successful run empties import/.

Image pins: dry-run shows "pin applied" (detect/defaults) vs "override used" (flags).
Source URL: auto-detect first (manifest / SQL / .env); prompt below only if needed.

EOF
  folder="$(menu_prompt "Project folder under \$WEBSITES_ROOT")"
  [[ -n "$folder" ]] || return 0
  args+=(--project "$folder")
  if ! menu_confirm_yes "Backup is laid out in import/ as shown above"; then
    return 0
  fi
  source_url="$(menu_prompt "Live site URL if not auto-detected (empty = detect only)")"
  if [[ -n "$source_url" ]]; then
    args+=(--source-url "$source_url")
  fi
  if menu_confirm_yes "Execute migration (--yes; otherwise dry run)"; then
    args+=(--yes)
  fi
  menu_run "$WP_STACK" "${args[@]}"
}

menu_wordpress_db_import() {
  local folder file
  folder="$(menu_prompt "Project folder under \$WEBSITES_ROOT")"
  [[ -n "$folder" ]] || return 0
  file="$(menu_prompt "SQL dump path (absolute or relative to project)")"
  [[ -n "$file" ]] || return 0
  menu_run "$WP_STACK" db import "$file" --project "$folder"
}

menu_wordpress_urls_replace() {
  local folder args=(urls replace)
  folder="$(menu_prompt "Project folder under \$WEBSITES_ROOT")"
  [[ -n "$folder" ]] || return 0
  args+=(--project "$folder")
  if menu_confirm_yes "Dry run only"; then
    args+=(--dry-run)
  elif menu_confirm_yes "Recreate wordpress container after replace (--recreate)"; then
    args+=(--recreate)
  fi
  menu_run "$WP_STACK" "${args[@]}"
}

menu_wordpress() {
  local choice
  while true; do
    cat <<'EOF'

WordPress
─────────
  1) Create project
  2) Migrate
  3) Import DB
  4) Replace URLs
  0) Back

EOF
    read -r -p "Choice: " choice
    case "$choice" in
      1) menu_wordpress_create ;;
      2) menu_wordpress_migrate ;;
      3) menu_wordpress_db_import ;;
      4) menu_wordpress_urls_replace ;;
      0|"") return 0 ;;
      *) echo "Unknown choice: ${choice}" ;;
    esac
  done
}

menu_static_create() {
  local folder variant source_url="" create_args=()
  local def_php="" php_minor php_image

  folder="$(menu_prompt "Project folder name under \$WEBSITES_ROOT")"
  [[ -n "$folder" ]] || return 0
  cat <<'EOF'

Variant:
  1) static-php
  2) static-php-mailhog

EOF
  read -r -p "Choice [1]: " variant
  case "${variant:-1}" in
    1) variant="static-php" ;;
    2) variant="static-php-mailhog" ;;
    *)
      echo "Unknown variant choice."
      menu_pause
      return 0
      ;;
  esac

  if [[ -n "${DEFAULT_PHP_IMAGE:-}" ]]; then
    def_php="$(trockendock_parse_php_image_minor "$DEFAULT_PHP_IMAGE" || true)"
  fi

  cat <<'EOF'

Image pin
─────────
  PHP tags: https://hub.docker.com/_/php/tags
  Format:   php:<PHP>-apache

EOF
  if [[ -n "${DEFAULT_PHP_IMAGE:-}" ]]; then
    echo "  stack-defaults: PHP_IMAGE=${DEFAULT_PHP_IMAGE}"
    echo
  fi

  php_minor="$(menu_prompt_pin "PHP minor" "x.y" "$def_php")"
  php_image="$(trockendock_format_php_image "$php_minor")"

  if ! trockendock_validate_php_image "$php_image"; then
    menu_pause
    return 0
  fi

  create_args=(project create "$folder" --variant "$variant" --php "$php_image")
  source_url="$(menu_prompt "Live site URL (optional, empty = no Live link)")"
  if [[ -n "$source_url" ]]; then
    create_args+=(--source-url "$source_url")
  fi
  if menu_confirm_yes "Dry run only"; then
    create_args+=(--dry-run)
  fi
  menu_run "$STATIC_STACK" "${create_args[@]}"
}

menu_static() {
  local choice
  while true; do
    cat <<'EOF'

Static PHP
──────────
  1) Create project
  0) Back

EOF
    read -r -p "Choice: " choice
    case "$choice" in
      1) menu_static_create ;;
      0|"") return 0 ;;
      *) echo "Unknown choice: ${choice}" ;;
    esac
  done
}

menu_platform_docker_status() {
  # Status view has its own "0) Back"; return straight to the Platform menu.
  bash "$DOCKER_STATUS" || true
}

# Populate MENU_PROJECT_DIRS with absolute project paths (compose projects under WEBSITES_ROOT).
# Optional filter: "running" | "stopped" | "all" (default).
menu_collect_compose_projects() {
  local filter="${1:-all}"
  local project_dir state
  MENU_PROJECT_DIRS=()
  [[ -d "$WEBSITES_ROOT" ]] || return 0
  for project_dir in "${WEBSITES_ROOT}"/*/; do
    [[ -d "$project_dir" ]] || continue
    [[ -f "${project_dir}docker-compose.yml" ]] || continue
    project_dir="${project_dir%/}"
    if [[ "$filter" != "all" ]]; then
      state="$(menu_compose_project_state "$project_dir")"
      [[ "$state" == "$filter" ]] || continue
    fi
    MENU_PROJECT_DIRS+=("$project_dir")
  done
}

menu_compose_project_state() {
  local dir="$1"
  local ids=""
  ids="$(docker compose -f "${dir}/docker-compose.yml" --project-directory "$dir" ps -q 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    printf 'running'
  else
    printf 'stopped'
  fi
}

# Sets MENU_SELECTED_PROJECT to the chosen absolute path, or empty if cancelled.
# Args: title, optional filter ("running" | "stopped" | "all").
menu_pick_compose_project() {
  local title="$1"
  local filter="${2:-all}"
  local i choice empty_msg
  MENU_SELECTED_PROJECT=""
  menu_collect_compose_projects "$filter"

  if [[ ${#MENU_PROJECT_DIRS[@]} -eq 0 ]]; then
    echo
    case "$filter" in
      running) empty_msg="No running projects under \$WEBSITES_ROOT." ;;
      stopped) empty_msg="No stopped projects under \$WEBSITES_ROOT." ;;
      *) empty_msg="No projects with docker-compose.yml under \$WEBSITES_ROOT." ;;
    esac
    echo "$empty_msg"
    menu_pause
    return 0
  fi

  echo
  echo "${title}"
  echo "────────"
  for i in "${!MENU_PROJECT_DIRS[@]}"; do
    printf "  %2d) %-40s [%s]\n" \
      "$((i + 1))" \
      "$(basename "${MENU_PROJECT_DIRS[$i]}")" \
      "$(menu_compose_project_state "${MENU_PROJECT_DIRS[$i]}")"
  done
  echo "   0) Back"
  echo
  read -r -p "Choice: " choice
  if [[ -z "$choice" || "$choice" == "0" ]]; then
    return 0
  fi
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#MENU_PROJECT_DIRS[@]} )); then
    echo "Unknown choice: ${choice}"
    menu_pause
    return 0
  fi
  MENU_SELECTED_PROJECT="${MENU_PROJECT_DIRS[$((choice - 1))]}"
}

menu_compose_start() {
  menu_pick_compose_project "Start Docker project (stopped only)" "stopped"
  [[ -n "${MENU_SELECTED_PROJECT:-}" ]] || return 0
  menu_run docker compose \
    -f "${MENU_SELECTED_PROJECT}/docker-compose.yml" \
    --project-directory "$MENU_SELECTED_PROJECT" \
    up -d
}

menu_compose_stop() {
  menu_pick_compose_project "Stop Docker project (running only)" "running"
  [[ -n "${MENU_SELECTED_PROJECT:-}" ]] || return 0
  if ! menu_confirm_yes "Stop containers for $(basename "$MENU_SELECTED_PROJECT")"; then
    return 0
  fi
  menu_run docker compose \
    -f "${MENU_SELECTED_PROJECT}/docker-compose.yml" \
    --project-directory "$MENU_SELECTED_PROJECT" \
    stop
}

menu_compose_down() {
  local name typed
  # Running only: stacks already fully removed have nothing useful to down.
  # Stopped-but-present stacks still appear as "stopped" if no running containers —
  # show all so a stopped stack can still be cleaned with down.
  menu_pick_compose_project "Remove Docker stack (compose down)" "all"
  [[ -n "${MENU_SELECTED_PROJECT:-}" ]] || return 0
  name="$(basename "$MENU_SELECTED_PROJECT")"

  echo
  echo "This runs: docker compose down"
  echo "  - Stops and removes containers and the Compose network for: ${name}"
  echo "  - Named volumes and the project folder on disk are NOT deleted"
  echo
  if ! menu_confirm_yes "Continue with compose down for ${name}"; then
    echo "Cancelled."
    menu_pause
    return 0
  fi
  echo
  read -r -p "Final confirmation — type the project name \"${name}\" to proceed: " typed
  if [[ "$typed" != "$name" ]]; then
    echo "Name did not match. Cancelled."
    menu_pause
    return 0
  fi
  menu_run docker compose \
    -f "${MENU_SELECTED_PROJECT}/docker-compose.yml" \
    --project-directory "$MENU_SELECTED_PROJECT" \
    down
}

menu_platform() {
  local choice
  while true; do
    cat <<'EOF'

Platform
────────
  1) Refresh link hub
  2) Open link hub in browser
  3) Docker status
  4) Start project (docker compose up -d)
  5) Stop project (docker compose stop)
  6) Remove stack (docker compose down)
  0) Back

EOF
    read -r -p "Choice: " choice
    case "$choice" in
      1)
        menu_run "$GENERATE_INDEX_SCRIPT"
        ;;
      2)
        if [[ -f "$LOCAL_DEV_INDEX_FILE" ]]; then
          menu_open_html_in_browser "$LOCAL_DEV_INDEX_FILE"
        else
          echo "Link hub not found: ${LOCAL_DEV_INDEX_FILE}"
          echo "Run \"Refresh link hub\" first."
          menu_pause
        fi
        ;;
      3)
        menu_platform_docker_status
        ;;
      4)
        menu_compose_start
        ;;
      5)
        menu_compose_stop
        ;;
      6)
        menu_compose_down
        ;;
      0|"") return 0 ;;
      *) echo "Unknown choice: ${choice}" ;;
    esac
  done
}

menu_main() {
  local choice
  while true; do
    cat <<EOF

Trockendock  v${TROCKENDOCK_VERSION:-dev}
───────────
  1) WordPress
  2) Static PHP
  3) Platform (link hub / Docker)
  4) Show paths
  0) Quit

EOF
    read -r -p "Choice: " choice
    case "$choice" in
      1) menu_wordpress ;;
      2) menu_static ;;
      3) menu_platform ;;
      4) menu_show_paths ;;
      0|"")
        echo "Bye."
        exit 0
        ;;
      *) echo "Unknown choice: ${choice}" ;;
    esac
  done
}

menu_main
