#!/usr/bin/env bash
# wp-stack db subcommands (import a SQL dump into the project db container).

_WP_STACK_DB_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_WP_STACK_DB_LIB}/common.sh"

wp_stack_db_import_usage() {
  cat <<'EOF'
Usage: wp-stack db import <file> [options]

Import a SQL dump into the project's db container.
Run from the project directory, or pass --project <folder>.
Requires the stack to be running (docker compose up -d).

Arguments:
  <file>              SQL dump (.sql or .sql.gz), relative to project or absolute

Options:
  --project <folder>  Project under $WEBSITES_ROOT (default: current directory)
  -h, --help          Show this help

Example:
  wp-stack db import import/live.sql.gz --project kundin-a
EOF
}

wp_stack_db_import() {
  local project="" file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        wp_stack_db_import_usage
        exit 0
        ;;
      --project)
        [[ $# -ge 2 ]] || wp_stack_die "--project requires a value"
        project="$2"
        shift 2
        ;;
      --*)
        wp_stack_die "unknown option: $1"
        ;;
      *)
        [[ -z "$file" ]] || wp_stack_die "unexpected argument: $1"
        file="$1"
        shift
        ;;
    esac
  done

  [[ -n "$file" ]] || wp_stack_die "missing file path (usage: wp-stack db import <file> ...)"

  wp_stack_resolve_project "$project"
  local dir="$WP_STACK_PROJECT_DIR"
  wp_stack_load_env "$dir"

  local dump_path="${dir}/${file}"
  [[ "$file" = /* ]] && dump_path="$file"
  [[ -f "$dump_path" ]] || wp_stack_die "dump not found: ${dump_path}"

  : "${WP_DB_USER:?WP_DB_USER missing in .env}"
  : "${WP_DB_PASSWORD:?WP_DB_PASSWORD missing in .env}"
  : "${WP_DB_NAME:?WP_DB_NAME missing in .env}"

  wp_stack_info "importing ${dump_path} → database '${WP_DB_NAME}'"

  if [[ "$dump_path" == *.gz ]]; then
    gunzip -c "$dump_path" | \
      ( cd "$dir" && docker compose exec -T db \
        mariadb -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" "${WP_DB_NAME}" )
  else
    ( cd "$dir" && docker compose exec -T db \
      mariadb -u"${WP_DB_USER}" -p"${WP_DB_PASSWORD}" "${WP_DB_NAME}" ) < "$dump_path"
  fi

  wp_stack_info "import done"
  echo "Next: wp-stack urls replace${project:+ --project ${project}} --dry-run"
}
