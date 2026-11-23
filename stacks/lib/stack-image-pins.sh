#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Trockendock — shared stack image pin helpers (validate / format / .env write)
# Author: elektrischerwalfisch
#
# See LICENSE and VERSION at repository root.
#
# Usage: source "${TROCKENDOCK_ROOT}/stacks/lib/stack-image-pins.sh"

# Idempotent KEY=VALUE in project .env (updates, uncomments, or appends).
trockendock_set_env_var() {
  local dir="$1" key="$2" val="$3"
  local file="${dir}/.env" esc
  [[ -f "$file" ]] || {
    echo "trockendock_set_env_var: missing ${file}" >&2
    return 1
  }
  esc="$(printf '%s' "$val" | sed -e 's/[&|]/\\&/g')"
  if grep -qE "^#?[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${esc}|" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >>"$file"
  fi
}

trockendock_format_wordpress_image() {
  local wp_core="$1" php_minor="$2"
  printf 'wordpress:%s-php%s-apache' "$wp_core" "$php_minor"
}

trockendock_format_mariadb_image() {
  local mariadb_minor="$1"
  printf 'mariadb:%s' "$mariadb_minor"
}

trockendock_format_php_image() {
  local php_minor="$1"
  printf 'php:%s-apache' "$php_minor"
}

# Accept full tag (php:8.3-apache) or bare minor (8.3).
trockendock_resolve_php_image() {
  local input="$1"
  if [[ "$input" == php:* ]]; then
    printf '%s' "$input"
  else
    trockendock_format_php_image "$input"
  fi
}

trockendock_validate_wordpress_image() {
  local image="$1"
  if [[ ! "$image" =~ ^wordpress:[0-9]+\.[0-9]+(\.[0-9]+)?-php[0-9]+\.[0-9]+-apache$ ]]; then
    echo "invalid WORDPRESS_IMAGE '${image}' (expected wordpress:<WP>-php<PHP>-apache, e.g. wordpress:6.4.3-php8.3-apache)" >&2
    return 1
  fi
}

trockendock_validate_mariadb_image() {
  local image="$1"
  if [[ ! "$image" =~ ^mariadb:[0-9]+\.[0-9]+$ ]]; then
    echo "invalid MARIADB_IMAGE '${image}' (expected mariadb:<x.y>, e.g. mariadb:10.11)" >&2
    return 1
  fi
}

trockendock_validate_php_image() {
  local image="$1"
  if [[ ! "$image" =~ ^php:[0-9]+\.[0-9]+-apache$ ]]; then
    echo "invalid PHP_IMAGE '${image}' (expected php:<x.y>-apache, e.g. php:8.3-apache)" >&2
    return 1
  fi
}

# Print "WP_CORE PHP_MINOR" from a full WORDPRESS_IMAGE tag (or return 1).
trockendock_parse_wordpress_image_parts() {
  local image="$1" wp_core php_minor
  wp_core="$(printf '%s' "$image" | sed -n 's/^wordpress:\([0-9][0-9.]*\)-php[0-9].*-apache$/\1/p')"
  php_minor="$(printf '%s' "$image" | sed -n 's/^wordpress:[0-9][0-9.]*-php\([0-9][0-9.]*\)-apache$/\1/p')"
  if [[ -z "$wp_core" || -z "$php_minor" ]]; then
    return 1
  fi
  printf '%s %s' "$wp_core" "$php_minor"
}

# Print MariaDB minor (x.y) from MARIADB_IMAGE (or return 1).
trockendock_parse_mariadb_image_minor() {
  local image="$1" minor
  minor="$(printf '%s' "$image" | sed -n 's/^mariadb:\([0-9][0-9.]*\)$/\1/p')"
  if [[ -z "$minor" ]]; then
    return 1
  fi
  printf '%s' "$minor"
}

# Print PHP minor (x.y) from PHP_IMAGE (or return 1).
trockendock_parse_php_image_minor() {
  local image="$1" minor
  minor="$(printf '%s' "$image" | sed -n 's/^php:\([0-9][0-9.]*\)-apache$/\1/p')"
  if [[ -z "$minor" ]]; then
    return 1
  fi
  printf '%s' "$minor"
}
