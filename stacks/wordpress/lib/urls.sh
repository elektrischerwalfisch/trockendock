#!/usr/bin/env bash
# wp-stack urls subcommands (rewrite site URLs via wp search-replace).

_WP_STACK_URLS_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_WP_STACK_URLS_LIB}/common.sh"

# Derive a wordpress:cli image tag from WORDPRESS_IMAGE.
# wordpress:6.9.4-php8.3-apache -> wordpress:cli-php8.3
# Falls back to wordpress:cli when no php tag is found.
wp_stack_wp_cli_image() {
  local php
  php="$(echo "${WORDPRESS_IMAGE:-}" | sed -n 's/.*-\(php[0-9.]*\)-apache/\1/p')"
  if [[ -n "$php" ]]; then
    echo "wordpress:cli-${php}"
  else
    echo "wordpress:cli"
  fi
}

# Host[:port] from a URL (no scheme, no path). https://www.ex.de/en → www.ex.de
wp_stack_url_host() {
  printf '%s' "$1" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#[/?#].*$##'
}

# Rewrite Multisite domain columns ({prefix}blogs / {prefix}site).
# search-replace only hits full URLs; these columns store the bare host (often with port locally).
wp_stack_urls_rewrite_multisite_domains() {
  local dir="$1" old_url="$2" new_url="$3" dry_run="${4:-0}"
  local prefix old_host new_host h
  prefix="${WP_TABLE_PREFIX:-wp_}"
  old_host="$(wp_stack_url_host "$old_url")"
  new_host="$(wp_stack_url_host "$new_url")"

  [[ -n "$old_host" && -n "$new_host" ]] || return 0
  [[ "$old_host" != "$new_host" ]] || return 0
  [[ "$old_host" =~ ^[A-Za-z0-9._:-]+$ && "$new_host" =~ ^[A-Za-z0-9._:-]+$ ]] || {
    wp_stack_info "skipping Multisite domain rewrite (unexpected host chars)"
    return 0
  }

  # Also try www / non-www twin of the source host.
  local -a hosts=("$old_host")
  if [[ "$old_host" == www.* ]]; then
    hosts+=("${old_host#www.}")
  else
    hosts+=("www.${old_host}")
  fi

  local has_blogs
  has_blogs="$(
    cd "$dir" && docker compose exec -T db \
      mariadb -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" -N -e \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='${prefix}blogs';" \
      "${WP_DB_NAME}" 2>/dev/null || echo 0
  )"
  [[ "${has_blogs//$'\r'/}" == "1" ]] || return 0

  wp_stack_info "Multisite domain columns: '${old_host}' -> '${new_host}' (${prefix}blogs / ${prefix}site)"

  if [[ "$dry_run" -eq 1 ]]; then
    echo "  [dry-run] would UPDATE ${prefix}blogs.domain and ${prefix}site.domain"
    for h in "${hosts[@]}"; do
      echo "  [dry-run] REPLACE domain host '${h}' -> '${new_host}'"
    done
    return 0
  fi

  for h in "${hosts[@]}"; do
    [[ "$h" =~ ^[A-Za-z0-9._:-]+$ ]] || continue
    ( cd "$dir" && docker compose exec -T db \
      mariadb -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" "${WP_DB_NAME}" -e \
      "UPDATE \`${prefix}blogs\` SET domain = '${new_host}' WHERE domain = '${h}';
       UPDATE \`${prefix}site\` SET domain = '${new_host}' WHERE domain = '${h}';" ) >/dev/null
  done
}

wp_stack_urls_replace_usage() {
  cat <<'EOF'
Usage: wp-stack urls replace [options]

Rewrite the source site URL to the local URL with wp search-replace.
Run from the project directory, or pass --project <folder>.
Requires the stack to be running (wordpress + db).

Options:
  --project <folder>  Project under $WEBSITES_ROOT (default: current directory)
  --old-url <url>     Source URL (default: MIGRATION_SOURCE_URL from .env)
  --new-url <url>     Target URL (default: http://localhost:<WP_PORT>)
  --dry-run           Show changes without applying them
  --recreate          After a live run, recreate the wordpress container
  -h, --help          Show this help

Example:
  wp-stack urls replace --project kundin-a --dry-run
  wp-stack urls replace --project kundin-a --recreate
EOF
}

wp_stack_urls_replace() {
  local project="" old_url="" new_url="" dry_run=0 recreate=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        wp_stack_urls_replace_usage
        exit 0
        ;;
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --old-url)
        [[ $# -ge 2 ]] || wp_stack_die "--old-url requires a value"
        old_url="$2"
        shift 2
        ;;
      --new-url)
        [[ $# -ge 2 ]] || wp_stack_die "--new-url requires a value"
        new_url="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --recreate)
        recreate=1
        shift
        ;;
      --*)
        wp_stack_die "unknown option: $1"
        ;;
      *)
        wp_stack_die "unexpected argument: $1"
        ;;
    esac
  done

  wp_stack_resolve_project "$project"
  local dir="$WP_STACK_PROJECT_DIR"
  wp_stack_load_env "$dir"

  old_url="${old_url:-${MIGRATION_SOURCE_URL:-}}"
  [[ -n "$old_url" ]] || wp_stack_die "no source URL (set MIGRATION_SOURCE_URL in .env or use --old-url)"

  : "${WP_PORT:?WP_PORT missing in .env}"
  : "${PROJECT_SLUG:?PROJECT_SLUG missing in .env}"
  : "${WP_DB_USER:?WP_DB_USER missing in .env}"
  : "${WP_DB_PASSWORD:?WP_DB_PASSWORD missing in .env}"
  : "${WP_DB_NAME:?WP_DB_NAME missing in .env}"

  new_url="${new_url:-http://localhost:${WP_PORT}}"

  local image dry_flag=""
  image="$(wp_stack_wp_cli_image)"
  [[ "$dry_run" -eq 1 ]] && dry_flag="--dry-run"

  wp_stack_info "search-replace '${old_url}' -> '${new_url}' (image ${image})${dry_flag:+ [dry-run]}"

  docker run --rm --user 33:33 \
    --volumes-from "${PROJECT_SLUG}-wp" \
    --network "container:${PROJECT_SLUG}-wp" \
    -e WORDPRESS_DB_HOST=db:3306 \
    -e WORDPRESS_DB_USER="${WP_DB_USER}" \
    -e WORDPRESS_DB_PASSWORD="${WP_DB_PASSWORD}" \
    -e WORDPRESS_DB_NAME="${WP_DB_NAME}" \
    -e WORDPRESS_TABLE_PREFIX="${WP_TABLE_PREFIX:-wp_}" \
    "${image}" wp --path=/var/www/html \
    search-replace "${old_url}" "${new_url}" --all-tables ${dry_flag} --allow-root

  # Bare host in Multisite tables is not covered by URL search-replace.
  wp_stack_urls_rewrite_multisite_domains "$dir" "$old_url" "$new_url" "$dry_run"

  if [[ "$dry_run" -eq 1 ]]; then
    return 0
  fi

  if [[ "$recreate" -eq 1 ]]; then
    wp_stack_info "recreating wordpress container"
    ( cd "$dir" && docker compose up -d --force-recreate wordpress )
  else
    echo "Next: (cd \"${dir}\" && docker compose up -d --force-recreate wordpress) — often forgotten"
  fi
}
