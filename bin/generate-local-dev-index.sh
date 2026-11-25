#!/usr/bin/env bash
# Build trockendock.html (link hub) from project .env files (WordPress + static PHP stacks).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/load-config.sh
source "${SCRIPT_DIR}/../config/load-config.sh"

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

  projects+=("${PROJECT_WEB_PORT}|${folder}|${slug}|${PROJECT_STACK_LABEL}|${PROJECT_WEB_PORT}|${PROJECT_PMA_PORT}|${PROJECT_MAILHOG_PORT}|${live_url}")
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
    h1 {
      margin: 0 0 0.75rem;
      padding-bottom: 0.75rem;
      border-bottom: 4px solid var(--contrast);
      font-size: 1.75rem;
      font-weight: 900;
    }
    .meta {
      margin: 0 0 1.5rem;
      color: var(--muted);
      font-size: 0.75rem;
      font-weight: 600;
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
    article h2 {
      margin: 0 0 0.75rem;
      font-size: 1rem;
      font-weight: 900;
    }
    article h2 span {
      display: block;
      font-size: 0.75rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.2em;
      color: var(--muted);
    }
    ul { list-style: none; margin: 0; padding: 0; }
    li + li { margin-top: 0.5rem; }
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
    <h1>Trockendock</h1>
HTML_HEAD

  printf '    <p class="meta">Generated: %s<br>Source: <code>%s/*/.env</code></p>\n' \
    "$(html_escape "$GENERATED_AT")" \
    "$(html_escape "$WEBSITES_ROOT")"

  if [ "${#sorted[@]}" -eq 0 ] || [ -z "${sorted[0]:-}" ]; then
    cat <<'HTML_EMPTY'
    <p class="empty">No projects with <code>docker-compose.yml</code> and <code>.env</code> found. Create a project and run <code>$GENERATE_INDEX_SCRIPT</code> again.</p>
HTML_EMPTY
  else
    echo '    <div class="grid">'
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ folder slug stack_label web_port pma_port mailhog_port live_url <<<"$entry"
      folder_esc="$(html_escape "$folder")"
      slug_esc="$(html_escape "$slug")"
      stack_esc="$(html_escape "$stack_label")"
      cat <<HTML_CARD
    <article>
      <h2>${folder_esc}<span>${slug_esc} · ${stack_esc}</span></h2>
      <ul>
        <li><a href="http://localhost:${web_port}/" target="_blank" rel="noopener">Web (:${web_port})</a></li>
HTML_CARD
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
