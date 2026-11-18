#!/usr/bin/env bash
# Port block helpers for static-stack (801x convention, shared with wp-stack).

# Read the primary web port from a project .env (WP_PORT or WEB_PORT).
static_stack_read_web_port_from_env() {
  local env_file="$1"
  local wp_port web_port

  wp_port="$(grep -E '^WP_PORT=' "$env_file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r')"
  if [[ "$wp_port" =~ ^[0-9]+$ ]]; then
    echo "$wp_port"
    return 0
  fi

  web_port="$(grep -E '^WEB_PORT=' "$env_file" 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\r')"
  if [[ "$web_port" =~ ^[0-9]+$ ]]; then
    echo "$web_port"
    return 0
  fi

  return 1
}

# Populates global array STATIC_STACK_USED_BLOCKS from project .env files.
static_stack_collect_used_blocks() {
  STATIC_STACK_USED_BLOCKS=()

  local project_dir env_file web_port
  for project_dir in "${WEBSITES_ROOT}"/*/; do
    [ -d "$project_dir" ] || continue
    [ -f "${project_dir}docker-compose.yml" ] || continue

    env_file="${project_dir}.env"
    [ -f "$env_file" ] || continue

    if web_port="$(static_stack_read_web_port_from_env "$env_file")"; then
      STATIC_STACK_USED_BLOCKS+=($((web_port / 10)))
    fi
  done
}

# Prints the next free block number (e.g. 803). Empty if none in 801–899.
static_stack_next_free_block() {
  static_stack_collect_used_blocks

  local block used in_use
  for block in $(seq 801 899); do
    in_use=0
    for used in "${STATIC_STACK_USED_BLOCKS[@]:-}"; do
      if [[ "$used" -eq "$block" ]]; then
        in_use=1
        break
      fi
    done
    if [[ "$in_use" -eq 0 ]]; then
      echo "$block"
      return 0
    fi
  done

  return 1
}

# Sets WEB_PORT for static-php; adds Mailhog ports for static-php-mailhog.
static_stack_ports_for_block() {
  local variant="$1"
  local block="$2"

  WEB_PORT="${block}1"

  case "$variant" in
    static-php)
      ;;
    static-php-mailhog)
      MAILHOG_UI_PORT="${block}3"
      MAILHOG_SMTP_PORT="${block}4"
      ;;
    *)
      static_stack_die "unknown variant for ports: ${variant}"
      ;;
  esac
}
