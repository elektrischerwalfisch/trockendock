#!/usr/bin/env bash
# Live overview of Compose projects and running containers.
# Press 0 or q to return (refresh every 8s while waiting).

while true; do
  clear
  date
  echo

  echo "=== Docker Compose projects ==="
  if docker compose ls 2>/dev/null | tail -n +2 | grep -q .; then
    docker compose ls
  else
    echo "(no compose projects)"
  fi

  echo
  echo "=== Running containers ==="
  if docker ps -q 2>/dev/null | grep -q .; then
    docker ps --format '{{.Names}} | {{.Status}} | {{.Ports}}'
  else
    echo "(no running containers)"
  fi

  echo
  echo "=== Stopped compose containers (last 10) ==="
  docker ps -a \
    --filter 'label=com.docker.compose.project' \
    --filter 'status=exited' \
    --format '{{.Names}} | {{.Status}}' 2>/dev/null | head -n 10

  echo
  echo "0) Back   |   q = quit view   |   auto-refresh every 8s"
  echo -n "Choice: "

  key=""
  if read -r -t 8 -n 1 key; then
    echo
    case "$key" in
      0|q|Q)
        exit 0
        ;;
    esac
  fi
done
