# Port block convention (Trockendock stacks)

Public reference for local Docker port assignment. **Operational overview:** `$LOCAL_DEV_INDEX_FILE` (generated HTML from project `.env` files).

Do **not** put real client or project names in the public repository.

**Prefer the interactive menu** to regenerate or open the hub:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ Platform → Refresh link hub / Open link hub. CLI below is the equivalent.

## Link hub tooling

| Item | Location / variable |
|------|---------------------|
| Generator script | `$GENERATE_INDEX_SCRIPT` → `bin/generate-local-dev-index.sh` |
| Generated HTML | `$LOCAL_DEV_INDEX_FILE` (Trockendock root: `trockendock.html`, gitignored) |

```bash
source config/load-config.sh
"$GENERATE_INDEX_SCRIPT"
xdg-open "$LOCAL_DEV_INDEX_FILE"
```

Per-project ports live in each project's `.env` only. Do not put project-specific values in `.env.example`.

## Port block convention

One `80Nx` block per project (tens digit = project index). Blocks are **shared across all stack types** — pick one free block per new project.

### WordPress (`templates/wordpress/`)

| Block | Web (`WP_PORT`) | phpMyAdmin | Mailhog UI | Mailhog SMTP |
|-------|-----------------|------------|------------|--------------|
| 801x  | 8011            | 8012       | 8013       | 8014         |
| 802x  | 8021            | 8022       | 8023       | 8024         |
| 803x  | 8031            | 8032       | 8033       | 8034         |
| 804x  | 8041            | 8042       | 8043       | 8044         |

URLs: `http://localhost:<WP_PORT>` · `http://localhost:<PMA_PORT>` · `http://localhost:<MAILHOG_UI_PORT>`

### Static PHP (`templates/static-php/`)

| Block | Web (`WEB_PORT`) | phpMyAdmin | Mailhog |
|-------|------------------|------------|---------|
| 805x  | 8051             | —          | —       |

One port per project (`…1` only). Slot `…2` stays unused.

### Static PHP + Mailhog (`templates/static-php-mailhog/`)

| Block | Web (`WEB_PORT`) | phpMyAdmin | Mailhog UI | Mailhog SMTP |
|-------|------------------|------------|------------|--------------|
| 805x  | 8051             | —          | 8053       | 8054         |

Slots `…2` unused; Mailhog uses `…3` and `…4` (same positions as WordPress Mailhog).

URLs: `http://localhost:<WEB_PORT>` · `http://localhost:<MAILHOG_UI_PORT>`

## Next free block

Pick the smallest `80Nx` block not used by any project `.env` (`WP_PORT` or `WEB_PORT` in that tens range).

`wp-stack` and `static-stack project create` assign the next free block automatically.

## When adding a project

1. Pick the next free block (create CLI/menu, or table above).
2. Set ports in the project **`.env` only** (not `.env.example`).
3. Run `$GENERATE_INDEX_SCRIPT` and bookmark `$LOCAL_DEV_INDEX_FILE`.
4. Run `docker compose up -d` only after ports are unique across all running stacks.

## Link hub card contents

The generator builds cards from each project `.env` (+ a Compose snapshot). It **reads** pins; it does not write them.

| Card part        | Source                                                                                         | Notes                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Title            | Project folder name                                                                            | —                                                                                              |
| Run-state badge  | `docker compose ps` at generate time                                                           | `running` / `stopped` for the web service (`wordpress` or `web`); snapshot, not live polling   |
| System meta      | `STACK` / WP ports                                                                             | Display label is only `wordpress` or `static/php` (Mailhog variant still shows a Mailhog link) |
| Multisite        | `WP_MULTISITE=1`                                                                               | Configured flag only; omitted when unset / `0`                                                 |
| Version chips    | `WORDPRESS_IMAGE` / `PHP_IMAGE` / `MARIADB_IMAGE`                                              | Configured tags only — no `docker exec` / runtime Ist                                          |
| `WP latest` chip | WordPress image tag **without** a core pin (e.g. `wordpress:php8.3-apache`)                    | Never invent a core version                                                                    |
| Links            | Ports + optional `MIGRATION_SOURCE_URL`                                                        | Live link only when that URL is set                                                            |

**Who writes pins (hub only displays):**

| Moment              | Guide                                                                              |
| ------------------- | ---------------------------------------------------------------------------------- |
| Create (WP/Static)  | [`wordpress/getting-started.md`](wordpress/getting-started.md) · [`static-php/getting-started.md`](static-php/getting-started.md) |
| Migrate (WP)        | [`wordpress/migration.md`](wordpress/migration.md)                                 |
| Guided image bump   | [`wordpress/image-bump.md`](wordpress/image-bump.md)                               |
| Soft defaults       | [`../config/README.md`](../config/README.md)                                       |

After create, migrate `--yes`, or image bump `--yes`, regenerate the hub (menu Platform → Refresh link hub, or `$GENERATE_INDEX_SCRIPT`). Bump already refreshes the hub by default.

## Stack detection in the link hub

The generator reads `STACK` from each `.env`:

| `STACK` value                    | System meta  | Links shown                                              |
| -------------------------------- | ------------ | -------------------------------------------------------- |
| *(absent, with `WP_PORT`)*       | `wordpress`  | Web, phpMyAdmin, Mailhog (+ Live if URL set)             |
| `static-php`                     | `static/php` | Web only (+ Live if URL set)                             |
| `static-php-mailhog`             | `static/php` | Web, Mailhog (+ Live if URL set)                         |

All stacks: optional `MIGRATION_SOURCE_URL` in `.env` adds a **Live** link in the index (create via menu/`--source-url`; WordPress migrate writes it detect-first).
