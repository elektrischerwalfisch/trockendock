# Getting started with Trockendock

Cross-cutting onboarding. Stack-specific create and ops live under [`wordpress/getting-started.md`](wordpress/getting-started.md) and [`static-php/getting-started.md`](static-php/getting-started.md).

## Prerequisites

- **Docker Engine + Compose plugin** — required for every stack
- **Path config** — once per machine: `cp config/paths.env.example config/paths.env` (adjust if needed)
- **Stack image soft defaults** (optional) — same pattern: `cp config/stack-defaults.env.example config/stack-defaults.env`, then set `DEFAULT_*` pins. Without this file, create (menu/CLI) requires explicit image flags. Details: [`../config/README.md`](../config/README.md)
- **Load config** before path-dependent commands:

  ```bash
  source config/load-config.sh   # from $TROCKENDOCK_ROOT
  ```

First-time setup: [`install-trockendock.md`](install-trockendock.md) (tested on Ubuntu; other OS may work — not verified).

## Interactive menu (recommended)

From `$TROCKENDOCK_ROOT`:

```bash
./start-menu.sh
```

Numbered menus for WordPress, Static PHP, link hub refresh/open, Docker status, and start/stop/remove project stacks. Dialogs that target an **existing** stack (migrate, DB import, URL replace, image bump, Platform start/stop/down) use a numbered project list under `$WEBSITES_ROOT`; **Create project** still asks for a new folder name.

### Menu image-pin UX

Create (and migrate pin overrides) never invent Hub-“latest” versions. Prompts use **format placeholders** plus Docker Hub tag links; **Enter** applies local soft defaults only when `config/stack-defaults.env` is set — otherwise you must type pins.

| Flow                         | Prompts                                    | Hub links                                                                                                        | Enter means                                                  |
| ---------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| WordPress create             | WP core, PHP minor, MariaDB minor          | [wordpress/tags](https://hub.docker.com/_/wordpress/tags), [mariadb/tags](https://hub.docker.com/_/mariadb/tags) | `DEFAULT_WORDPRESS_IMAGE` / `DEFAULT_MARIADB_IMAGE` when set |
| Static PHP create            | PHP minor (→ `PHP_IMAGE=php:<x.y>-apache`) | [php/tags](https://hub.docker.com/_/php/tags)                                                                    | `DEFAULT_PHP_IMAGE` when set                                 |
| WordPress migrate (optional) | Same placeholders after dry-run proposal   | Same as WP create                                                                                                | Keep auto proposal (detect / current / defaults)             |

Optional live URL on create (WP + Static) and migrate gap-fill → `MIGRATION_SOURCE_URL` (hub **Live** link only when set). Soft defaults: [`../config/README.md`](../config/README.md). Later image bumps: [`wordpress/image-bump.md`](wordpress/image-bump.md). Migrate pin resolution: [`wordpress/migration.md`](wordpress/migration.md).

Optional — add stack CLIs to `PATH`:

```bash
source config/load-config.sh
export PATH="${TROCKENDOCK_ROOT}/stacks/wordpress/bin:${TROCKENDOCK_ROOT}/stacks/static-php/bin:$PATH"
```

## Choose a stack

| Goal                         | Create with (pins required)                                                     | Operator guide                                                   |
| ---------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| WordPress (new or migration) | `wp-stack project create <folder> --wordpress-image … --mariadb-image …`        | [`wordpress/getting-started.md`](wordpress/getting-started.md)   |
| Static PHP (no Mailhog)      | `static-stack project create <folder> --variant static-php --php <x.y>`         | [`static-php/getting-started.md`](static-php/getting-started.md) |
| Static PHP + Mailhog         | `static-stack project create <folder> --variant static-php-mailhog --php <x.y>` | [`static-php/getting-started.md`](static-php/getting-started.md) |

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

Hub cards show **configured** image pins + Multisite from `.env`, and a **running/stopped** Compose snapshot at generate time — details: [`port-convention.md`](port-convention.md#link-hub-card-contents). Pins are written by create/migrate/bump; the hub only displays them.

Use **`http://localhost:<port>`**, not `https://` — publish ports are HTTP-only (HTTPS-First in the browser can look like an endless load).

Port blocks: [`port-convention.md`](port-convention.md).

## Where next

| Topic           | Path                                           |
| --------------- | ---------------------------------------------- |
| Docs index      | [`README.md`](README.md)                       |
| Link hub cards  | [`port-convention.md`](port-convention.md#link-hub-card-contents) |
| Image bump      | [`wordpress/image-bump.md`](wordpress/image-bump.md) |
| WordPress area  | [`wordpress/README.md`](wordpress/README.md)   |
| Static PHP area | [`static-php/README.md`](static-php/README.md) |
| AI rules        | [`../AGENTS.md`](../AGENTS.md)                 |
