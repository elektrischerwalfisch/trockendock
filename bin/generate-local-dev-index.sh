#!/usr/bin/env bash
# Build trockendock.html (link hub) from project .env files (WordPress + static PHP stacks).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/load-config.sh
source "${SCRIPT_DIR}/../config/load-config.sh"

OUTPUT="${LOCAL_DEV_INDEX_FILE}"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M')"
PORT_CONVENTION_DOC="${TROCKENDOCK_ROOT}/docs/port-convention.md"

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
used_blocks=()

for project_dir in "${WEBSITES_ROOT}"/*/; do
  [ -d "$project_dir" ] || continue
  [ -f "${project_dir}docker-compose.yml" ] || continue

  env_file="${project_dir}.env"
  [ -f "$env_file" ] || continue

  index_classify_project "$env_file" || continue

  folder="$(basename "$project_dir")"
  slug="$(read_env_var "$env_file" PROJECT_SLUG)"
  live_url="$(read_env_var "$env_file" MIGRATION_SOURCE_URL)"

  if [[ "$PROJECT_WEB_PORT" =~ ^[0-9]+$ ]]; then
    used_blocks+=($((PROJECT_WEB_PORT / 10)))
  fi

  projects+=("${PROJECT_WEB_PORT}|${folder}|${slug}|${PROJECT_STACK_LABEL}|${PROJECT_WEB_PORT}|${PROJECT_PMA_PORT}|${PROJECT_MAILHOG_PORT}|${live_url}")
done

# Sort alphabetically by project folder (field 2).
IFS=$'\n' sorted=($(printf '%s\n' "${projects[@]:-}" | sort -t'|' -k2,2))
unset IFS

next_block_label=""
for block in $(seq 801 899); do
  in_use=0
  for used in "${used_blocks[@]:-}"; do
    if [[ "$used" -eq "$block" ]]; then
      in_use=1
      break
    fi
  done
  if [[ "$in_use" -eq 0 ]]; then
    next_block_label="${block}x (WP: ${block}1–${block}4 · static/php: ${block}1 · static/php/mailhog: ${block}1, ${block}3–${block}4)"
    break
  fi
done

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
      --bg: #f4f6f8;
      --card: #fff;
      --text: #1a1a1a;
      --muted: #5c6570;
      --accent: #0060df;
      --border: #d7dde5;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 2rem 1.5rem 3rem;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
    }
    main { max-width: 52rem; margin: 0 auto; }
    h1 { margin: 0 0 0.25rem; font-size: 1.75rem; }
    .meta { color: var(--muted); font-size: 0.9rem; margin-bottom: 1rem; }
    .hint {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 0.75rem 1rem;
      margin-bottom: 1.5rem;
      font-size: 0.9rem;
    }
    .grid {
      display: grid;
      gap: 1rem;
    }
    @media (min-width: 40rem) {
      .grid { grid-template-columns: repeat(2, 1fr); }
    }
    article {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1rem 1.25rem;
    }
    article h2 {
      margin: 0 0 0.75rem;
      font-size: 1.1rem;
    }
    article h2 span {
      display: block;
      font-size: 0.85rem;
      font-weight: normal;
      color: var(--muted);
    }
    ul {
      list-style: none;
      margin: 0;
      padding: 0;
    }
    li + li { margin-top: 0.35rem; }
    a {
      color: var(--accent);
      text-decoration: none;
    }
    a:hover { text-decoration: underline; }
    .empty {
      background: var(--card);
      border: 1px dashed var(--border);
      border-radius: 8px;
      padding: 1.25rem;
      color: var(--muted);
    }
    footer {
      margin-top: 2rem;
      font-size: 0.85rem;
      color: var(--muted);
    }
    code { font-size: 0.85em; }
  </style>
</head>
<body>
  <main>
    <h1>Trockendock</h1>
HTML_HEAD

  printf '    <p class="meta">Generated: %s · Source: <code>$WEBSITES_ROOT/*/.env</code></p>\n' \
    "$(html_escape "$GENERATED_AT")"

  if [[ -n "$next_block_label" ]]; then
    printf '    <p class="hint">Suggested next port block: <strong>%s</strong></p>\n' \
      "$(html_escape "$next_block_label")"
  fi

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

  cat <<'HTML_FOOT'
    <footer>
      Regenerate: <code>$GENERATE_INDEX_SCRIPT</code>
      · Bookmark: <code>$LOCAL_DEV_INDEX_FILE</code>
      · Convention: <code>$TROCKENDOCK_ROOT/docs/port-convention.md</code>
    </footer>
  </main>
</body>
</html>
HTML_FOOT

} >"$OUTPUT"

echo "Wrote ${OUTPUT} ($(wc -l <"$OUTPUT") lines, ${#sorted[@]} project(s), next block: ${next_block_label:-n/a})"
