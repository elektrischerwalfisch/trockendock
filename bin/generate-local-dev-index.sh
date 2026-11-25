#!/usr/bin/env bash
# Build trockendock.html (link hub) from project .env files (WordPress + static PHP stacks).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/load-config.sh
source "${SCRIPT_DIR}/../config/load-config.sh"
# shellcheck source=../stacks/lib/stack-image-pins.sh
source "${SCRIPT_DIR}/../stacks/lib/stack-image-pins.sh"

OUTPUT="${LOCAL_DEV_INDEX_FILE}"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M')"

mkdir -p "$(dirname "$OUTPUT")"

html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  printf '%s' "$text"
}

read_env_var() {
  local file="$1"
  local key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r' || true
}

# Sets PROJECT_STACK_LABEL, PROJECT_WEB_PORT, PROJECT_PMA_PORT, PROJECT_MAILHOG_PORT.
# Returns 0 when the project should appear in the index.
index_classify_project() {
  local env_file="$1"
  local stack slug wp_port web_port pma_port mailhog_port

  stack="$(read_env_var "$env_file" STACK)"
  slug="$(read_env_var "$env_file" PROJECT_SLUG)"
  wp_port="$(read_env_var "$env_file" WP_PORT)"
  web_port="$(read_env_var "$env_file" WEB_PORT)"
  pma_port="$(read_env_var "$env_file" PMA_PORT)"
  mailhog_port="$(read_env_var "$env_file" MAILHOG_UI_PORT)"

  case "$stack" in
    static-php)
      [[ -n "$slug" && -n "$web_port" ]] || return 1
      PROJECT_STACK_LABEL="static/php"
      PROJECT_WEB_PORT="$web_port"
      PROJECT_PMA_PORT=""
      PROJECT_MAILHOG_PORT=""
      ;;
    static-php-mailhog)
      [[ -n "$slug" && -n "$web_port" && -n "$mailhog_port" ]] || return 1
      PROJECT_STACK_LABEL="static/php/mailhog"
      PROJECT_WEB_PORT="$web_port"
      PROJECT_PMA_PORT=""
      PROJECT_MAILHOG_PORT="$mailhog_port"
      ;;
    *)
      [[ -n "$slug" && -n "$wp_port" && -n "$pma_port" && -n "$mailhog_port" ]] || return 1
      PROJECT_STACK_LABEL="wordpress"
      PROJECT_WEB_PORT="$wp_port"
      PROJECT_PMA_PORT="$pma_port"
      PROJECT_MAILHOG_PORT="$mailhog_port"
      ;;
  esac

  return 0
}

# Sets INDEX_LABEL_PHP / INDEX_LABEL_WP / INDEX_LABEL_MDB from .env (Option B).
index_version_chip_labels() {
  local env_file="$1" stack_label="$2"
  local wordpress_image mariadb_image php_image

  INDEX_LABEL_PHP=""
  INDEX_LABEL_WP=""
  INDEX_LABEL_MDB=""

  wordpress_image="$(read_env_var "$env_file" WORDPRESS_IMAGE)"
  mariadb_image="$(read_env_var "$env_file" MARIADB_IMAGE)"
  php_image="$(read_env_var "$env_file" PHP_IMAGE)"

  case "$stack_label" in
    wordpress)
      INDEX_LABEL_WP="$(trockendock_hub_label_wp "$wordpress_image" 2>/dev/null || true)"
      INDEX_LABEL_PHP="$(trockendock_hub_label_php_from_wordpress_image "$wordpress_image" 2>/dev/null || true)"
      INDEX_LABEL_MDB="$(trockendock_hub_label_mariadb "$mariadb_image" 2>/dev/null || true)"
      ;;
    static/php|static/php/mailhog)
      INDEX_LABEL_PHP="$(trockendock_hub_label_php "$php_image" 2>/dev/null || true)"
      ;;
  esac
}

# Hub "system" meta: only wordpress | static/php (mailhog is visible via its link).
index_system_label() {
  local stack_label="$1"
  case "$stack_label" in
    wordpress) printf 'wordpress' ;;
    static/php|static/php/mailhog) printf 'static/php' ;;
    *) printf '%s' "$stack_label" ;;
  esac
}

# Multisite marker for WordPress when WP_MULTISITE=1 (configured flag only).
index_multisite_label() {
  local env_file="$1" stack_label="$2"
  [[ "$stack_label" == "wordpress" ]] || return 0
  trockendock_hub_label_multisite "$(read_env_var "$env_file" WP_MULTISITE)" 2>/dev/null || true
}

# Generate-time Compose snapshot: web service up → running, else stopped.
# WordPress web service = wordpress; static stacks = web.
index_run_state() {
  local project_dir="$1" stack_label="$2"
  local service="wordpress"

  case "$stack_label" in
    static/php|static/php/mailhog) service="web" ;;
  esac

  if ! command -v docker >/dev/null 2>&1; then
    printf 'stopped'
    return 0
  fi
  if (
    cd "$project_dir" \
      && docker compose ps --status running --services 2>/dev/null \
      | grep -qx "$service"
  ); then
    printf 'running'
  else
    printf 'stopped'
  fi
}

projects=()

for project_dir in "${WEBSITES_ROOT}"/*/; do
  [ -d "$project_dir" ] || continue
  [ -f "${project_dir}docker-compose.yml" ] || continue

  env_file="${project_dir}.env"
  [ -f "$env_file" ] || continue

  index_classify_project "$env_file" || continue

  folder="$(basename "$project_dir")"
  slug="$(read_env_var "$env_file" PROJECT_SLUG)"
  live_url="$(read_env_var "$env_file" MIGRATION_SOURCE_URL)"
  index_version_chip_labels "$env_file" "$PROJECT_STACK_LABEL"
  multisite_label="$(index_multisite_label "$env_file" "$PROJECT_STACK_LABEL")"
  run_state="$(index_run_state "$project_dir" "$PROJECT_STACK_LABEL")"

  system_label="$(index_system_label "$PROJECT_STACK_LABEL")"

  # Fields: port|folder|slug|stack|web|pma|mailhog|live|system|multisite|php|wp|mdb|run
  projects+=("${PROJECT_WEB_PORT}|${folder}|${slug}|${PROJECT_STACK_LABEL}|${PROJECT_WEB_PORT}|${PROJECT_PMA_PORT}|${PROJECT_MAILHOG_PORT}|${live_url}|${system_label}|${multisite_label}|${INDEX_LABEL_PHP}|${INDEX_LABEL_WP}|${INDEX_LABEL_MDB}|${run_state}")
done

# Sort alphabetically by project folder (field 2).
IFS=$'\n' sorted=($(printf '%s\n' "${projects[@]:-}" | sort -t'|' -k2,2))
unset IFS

{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Trockendock</title>
  <style>
    :root {
      --canvas: #f5f5f4;
      --surface: #fff;
      --contrast: #292524;
      --muted: #78716c;
      --accent: #facc15;
      --shadow: 4px 4px 0 0 var(--contrast);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      padding: 2.5rem 1.25rem 3rem;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
      background: var(--canvas);
      color: var(--contrast);
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
    }
    main { max-width: 52rem; margin: 0 auto; }
    .page-head {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 1rem;
      margin: 0 0 1.5rem;
      padding-bottom: 0.75rem;
      border-bottom: 4px solid var(--contrast);
    }
    .page-head h1 {
      margin: 0;
      flex: 1 1 auto;
      min-width: 0;
      font-size: 1.75rem;
      font-weight: 900;
    }
    .meta {
      flex: 0 1 auto;
      max-width: 60%;
      margin: 0;
      text-align: right;
      font-size: 0.75rem;
      line-height: 1.25;
    }
    .meta-generated {
      margin: 0;
      color: var(--contrast);
      font-weight: 800;
    }
    .meta-source {
      margin: 0.25rem 0 0;
      color: var(--muted);
      font-weight: 600;
      word-break: break-all;
    }
    .grid {
      display: grid;
      gap: 1.25rem;
    }
    @media (min-width: 40rem) {
      .grid { grid-template-columns: repeat(2, 1fr); }
    }
    article,
    .empty {
      margin: 0;
      padding: 1rem 1.25rem;
      background: var(--surface);
      border: 2px solid var(--contrast);
      border-radius: 0;
      box-shadow: var(--shadow);
    }
    .card-head {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 0.75rem;
      margin: 0 0 0.5rem;
    }
    .card-head h2 {
      margin: 0;
      flex: 1 1 auto;
      min-width: 0;
      font-size: 1.25rem;
      font-weight: 900;
      word-break: break-word;
    }
    .badge {
      flex: 0 0 auto;
      padding: 0.25rem 0.5rem;
      border: 2px solid var(--contrast);
      border-radius: 0;
      font-size: 0.75rem;
      font-weight: 800;
      line-height: 1;
      text-transform: uppercase;
    }
    .badge-running {
      background: var(--accent);
      color: var(--contrast);
    }
    .badge-stopped {
      background: var(--canvas);
      color: var(--muted);
    }
    .card-meta {
      margin: 0 0 0.75rem;
      font-size: 0.75rem;
      font-weight: 700;
      text-transform: uppercase;
      color: var(--muted);
    }
    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
      list-style: none;
      margin: 0 0 1rem;
      padding: 0;
    }
    .chips li {
      margin: 0;
      padding: 0.25rem 0.5rem;
      background: var(--canvas);
      border: 2px solid var(--contrast);
      border-radius: 0;
      font-size: 0.75rem;
      font-weight: 800;
      line-height: 1.25;
    }
    .links { list-style: none; margin: 0; padding: 0; }
    .links li + li { margin-top: 0.5rem; }
    a {
      color: var(--contrast);
      font-weight: 700;
      text-decoration: underline;
      text-underline-offset: 0.25em;
    }
    a:hover { background: var(--accent); color: var(--contrast); text-decoration: none; }
    .empty { color: var(--muted); font-weight: 600; }
    footer {
      margin-top: 2rem;
      padding-top: 0.75rem;
      border-top: 2px solid var(--contrast);
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--muted);
    }
    footer a { font-weight: 800; }
    code { font-size: 0.75em; font-weight: 700; }
  </style>
</head>
<body>
  <main>
HTML_HEAD

  printf '    <div class="page-head">\n'
  printf '      <h1>Trockendock</h1>\n'
  printf '      <div class="meta">\n'
  printf '        <p class="meta-generated">Generated: %s</p>\n' \
    "$(html_escape "$GENERATED_AT")"
  printf '        <p class="meta-source">Source: <code>%s/*/.env</code></p>\n' \
    "$(html_escape "$WEBSITES_ROOT")"
  printf '      </div>\n'
  printf '    </div>\n'

  if [ "${#sorted[@]}" -eq 0 ] || [ -z "${sorted[0]:-}" ]; then
    cat <<'HTML_EMPTY'
    <p class="empty">No projects with <code>docker-compose.yml</code> and <code>.env</code> found. Create a project and run <code>$GENERATE_INDEX_SCRIPT</code> again.</p>
HTML_EMPTY
  else
    echo '    <div class="grid">'
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ folder _slug stack_label web_port pma_port mailhog_port live_url \
        system_label multisite_label label_php label_wp label_mdb run_state <<<"$entry"
      folder_esc="$(html_escape "$folder")"
      stack_meta="$(trockendock_hub_join_labels "$system_label" "$multisite_label")"
      stack_meta_esc="$(html_escape "$stack_meta")"
      run_state_esc="$(html_escape "$run_state")"
      badge_class="badge-stopped"
      [[ "$run_state" == "running" ]] && badge_class="badge-running"
      cat <<HTML_CARD
    <article>
      <div class="card-head">
        <h2>${folder_esc}</h2>
        <span class="badge ${badge_class}">${run_state_esc}</span>
      </div>
      <p class="card-meta">${stack_meta_esc}</p>
HTML_CARD
      if [[ -n "$label_php" || -n "$label_wp" || -n "$label_mdb" ]]; then
        echo '      <ul class="chips">'
        for chip in "$label_php" "$label_wp" "$label_mdb"; do
          [[ -n "$chip" ]] || continue
          printf '        <li>%s</li>\n' "$(html_escape "$chip")"
        done
        echo '      </ul>'
      fi
      cat <<HTML_LINKS
      <ul class="links">
        <li><a href="http://localhost:${web_port}/" target="_blank" rel="noopener">Web (:${web_port})</a></li>
HTML_LINKS
      if [[ -n "$pma_port" ]]; then
        printf '        <li><a href="http://localhost:%s/" target="_blank" rel="noopener">phpMyAdmin (:%s)</a></li>\n' \
          "$pma_port" "$pma_port"
      fi
      if [[ -n "$mailhog_port" ]]; then
        printf '        <li><a href="http://localhost:%s/" target="_blank" rel="noopener">Mailhog (:%s)</a></li>\n' \
          "$mailhog_port" "$mailhog_port"
      fi
      if [[ -n "$live_url" ]]; then
        live_url_esc="$(html_escape "$live_url")"
        live_host="${live_url#*://}"
        live_host="${live_host%%/*}"
        live_host_esc="$(html_escape "$live_host")"
        printf '        <li><a href="%s" target="_blank" rel="noopener">Live (%s)</a></li>\n' \
          "$live_url_esc" "$live_host_esc"
      fi
      cat <<'HTML_CARD_END'
      </ul>
    </article>
HTML_CARD_END
    done
    echo '    </div>'
  fi

  cat <<HTML_FOOT
    <footer>
      Trockendock <strong>v$(html_escape "${TROCKENDOCK_VERSION:-dev}")</strong>
      · by $(html_escape "elektrischerwalfisch")
      · <a href="https://github.com/elektrischerwalfisch/trockendock" target="_blank" rel="noopener">GitHub</a>
    </footer>
  </main>
</body>
</html>
HTML_FOOT

} >"$OUTPUT"

echo "Wrote ${OUTPUT} ($(wc -l <"$OUTPUT") lines, ${#sorted[@]} project(s))"
