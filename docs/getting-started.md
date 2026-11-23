# Getting started with Trockendock

Cross-cutting onboarding. Stack-specific create and ops live under [`wordpress/getting-started.md`](wordpress/getting-started.md) and [`static-php/getting-started.md`](static-php/getting-started.md).

## Prerequisites

- **Docker Engine + Compose plugin** — required for every stack
- **Path config** — once per machine: `cp config/paths.env.example config/paths.env` (adjust if needed); details: [`../config/README.md`](../config/README.md)
- **Load paths** before path-dependent commands:

  ```bash
  source config/load-config.sh   # from $TROCKENDOCK_ROOT
  ```

First-time setup: [`install-trockendock.md`](install-trockendock.md) (tested on Ubuntu; other OS may work — not verified).

## Interactive menu (recommended)

From `$TROCKENDOCK_ROOT`:

```bash
./start-menu.sh
```

Numbered menus for WordPress, Static PHP, link hub refresh/open, Docker status, and start/stop/remove project stacks.

Optional — add stack CLIs to `PATH`:

```bash
source config/load-config.sh
export PATH="${TROCKENDOCK_ROOT}/stacks/wordpress/bin:${TROCKENDOCK_ROOT}/stacks/static-php/bin:$PATH"
```

## Choose a stack

| Goal                         | Create with                                                          | Operator guide                                                       |
|------------------------------|----------------------------------------------------------------------|----------------------------------------------------------------------|
| WordPress (new or migration) | `wp-stack project create <folder>`                                   | [`wordpress/getting-started.md`](wordpress/getting-started.md)       |
| Static PHP (no Mailhog)      | `static-stack project create <folder> --variant static-php`          | [`static-php/getting-started.md`](static-php/getting-started.md)     |
| Static PHP + Mailhog         | `static-stack project create <folder> --variant static-php-mailhog`  | [`static-php/getting-started.md`](static-php/getting-started.md)     |

## Daily commands

**Prefer the interactive menu** for hub refresh/open and start/stop/down:

```bash
./start-menu.sh
```

→ Platform → Refresh / Open link hub · Start / Stop project · Remove stack.

CLI equivalent — from any **project folder**:

```bash
docker compose up -d
docker compose stop
docker compose logs -f
```

Regenerate and open the link hub:

```bash
source config/load-config.sh
"$GENERATE_INDEX_SCRIPT"
xdg-open "$LOCAL_DEV_INDEX_FILE"   # trockendock.html at repo root (gitignored)
```

Use **`http://localhost:<port>`**, not `https://` — publish ports are HTTP-only (HTTPS-First in the browser can look like an endless load).

Port blocks: [`port-convention.md`](port-convention.md).

## Where next

| Topic           | Path                                               |
|-----------------|----------------------------------------------------|
| Docs index      | [`README.md`](README.md)                           |
| WordPress area  | [`wordpress/README.md`](wordpress/README.md)       |
| Static PHP area | [`static-php/README.md`](static-php/README.md)     |
| AI rules        | [`../AGENTS.md`](../AGENTS.md)                     |
