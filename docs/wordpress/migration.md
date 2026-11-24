# WordPress: migrate an existing site

Restore a live or staging WordPress site into a local Trockendock project. The stack mounts only **`wp-content`**; Core and PHP come from `WORDPRESS_IMAGE`.

**Prefer the interactive menu** for migrate, DB import, and URL replace:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ WordPress → Migrate / Import DB / Replace URLs. CLI below is the equivalent.

Create/start basics: [`getting-started.md`](getting-started.md). CLI flags: [`../../stacks/wordpress/README.md`](../../stacks/wordpress/README.md).

## Before you start

1. Create the project if it does not exist yet (`wp-stack project create` — see [`getting-started.md`](getting-started.md#create--start)). Explicit image pins are required on create (flags or `config/stack-defaults.env`).
2. Note live WP / PHP / MariaDB versions for the migrate pin proposal (backup detect + overrides below). You do **not** need to hand-edit `.env` pins before `--yes` when migrate can resolve them.
3. Optional before migrate: set `MIGRATION_SOURCE_URL` in **`.env` only** if you already know the live URL. Migrate is detect-first (manifest / SQL / existing `.env`); menu prompts or `--source-url` only fill a gap.

| Variable                 | Role                                                               |
| ------------------------ | ------------------------------------------------------------------ |
| `MIGRATION_SOURCE_URL`   | Live URL as stored in the DB (schema + domain); also hub Live link |
| `WP_TABLE_PREFIX`        | Table prefix (migrate detects and writes this on `--yes`)          |
| `WORDPRESS_IMAGE`        | Compose WP/PHP pin (migrate proposes / writes on `--yes`)          |
| `MARIADB_IMAGE`          | Compose MariaDB pin (migrate proposes / writes on `--yes`)         |
| `WP_MULTISITE`           | Set by migrate when `*_blogs` is in the dump; do not guess early   |
| `WP_MULTISITE_SUBDOMAIN` | `0` path (`/en/`), `1` subdomain — local default is path           |

`DOMAIN_CURRENT_SITE` is always `localhost:<WP_PORT>` via Compose (no separate env var).

Path Multisite serves assets under `/en/wp-content/...`. The template `.htaccess` (Compose-mounted) maps those to `/wp-content/...`. Without it, secondary sites look unstyled.

## Import layout

Unpack **one** backup flat into `${WEBSITES_ROOT}/<folder>/import/`:

- `wp-content/` (themes, plugins, uploads — not a full live webroot with `wp-admin` / `wp-includes`)
- exactly one `.sql` or `.sql.gz`
- optional `manifest.json` (prefix + source URL + WP version when present)

No dated wrapper folder. Extra dumps or `wp-admin` abort `migrate`. A successful `--yes` empties `import/` and keeps the folder. Use `backups/` for dumps you want to keep.

## One-command migrate (recommended)

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/wordpress/bin/wp-stack migrate --project <folder>        # dry run
./stacks/wordpress/bin/wp-stack migrate --project <folder> --yes    # full restore
```

| Mode             | Flag                   | Needs in `import/`       |
| ---------------- | ---------------------- | ------------------------ |
| Full             | `--only all` (default) | `wp-content/` + one dump |
| Files only       | `--only content`       | `wp-content/`            |
| DB + URL rewrite | `--only db`            | one dump                 |

### Image pins (create vs migrate)

| Step    | Who sets pins                                                                |
| ------- | ---------------------------------------------------------------------------- |
| Create  | Operator flags or local `DEFAULT_*` in `config/stack-defaults.env`           |
| Migrate | Dry-run **proposes**; `--yes` **writes** `WORDPRESS_IMAGE` / `MARIADB_IMAGE` |

Pin resolution on migrate (messages say **pin applied** vs **override used**):

- **WordPress core** — from backup `manifest.json` when present; PHP minor from current project pin, `stack-defaults`, or `--php` / `--wordpress-image`
- **MariaDB** — current project pin, then `DEFAULT_MARIADB_IMAGE`, then `--mariadb-image`
- **Overrides** — `--wordpress-image`, `--mariadb-image`, `--php` win over detect/defaults when you must diverge

Menu migrate: dry-run proposal first, then optional Hub/placeholder overrides (Enter keeps the proposal).

### What `--yes` writes / does

Restore `wp-content`, wipe project DB, import SQL, rewrite URLs, recreate WordPress, and write into `.env`:

- detected `WP_TABLE_PREFIX`
- resolved `MIGRATION_SOURCE_URL` (detect-first; `--source-url` only if still empty)
- resolved `WORDPRESS_IMAGE` / `MARIADB_IMAGE`

Multisite dumps also set `WP_MULTISITE=1` and rewrite `{prefix}blogs` / `{prefix}site` hosts. Add `--chown-www` for `wp-content` → `33:33` (uses sudo).

Later image bumps: [`image-bump.md`](image-bump.md).

## Building blocks (optional)

Stack must be running. Same as migrate internals:

```bash
wp-stack db import import/live.sql.gz --project <folder>
wp-stack urls replace --project <folder> --dry-run
wp-stack urls replace --project <folder> --recreate
```

`urls replace` derives `wordpress:cli-phpX.Y` from `WORDPRESS_IMAGE` and replaces `MIGRATION_SOURCE_URL` → `http://localhost:<WP_PORT>` (override with `--old-url` / `--new-url`).

After changing `WP_TABLE_PREFIX` manually, always:

```bash
docker compose up -d --force-recreate wordpress
```

Without recreate, `wp-config` often stays on `wp_` → installer screen despite imported tables. Check: `docker compose exec wordpress grep table_prefix /var/www/html/wp-config.php`.

## Ownership (`wp-content`)

Prefer: place `wp-content` **before** first `up`, or use migrate / `--chown-www`.

If the stack already ran and the host cannot replace files (`nobody:nogroup`):

```bash
docker compose stop
sudo chown -R "$USER:$USER" wp-content
# replace contents, then:
docker compose up -d
```

For wp-admin installs/uploads, switch to www-data:

```bash
docker compose stop
sudo chown -R 33:33 wp-content
docker compose up -d
```

More: [`getting-started.md`](getting-started.md#ownership-wp-content).

## Verify

1. `docker compose up -d --force-recreate wordpress` after prefix / URL changes
2. Open **`http://`** `localhost:<WP_PORT>` (not https)
3. Frontend, `/wp-admin`, theme, plugins, media
4. Permalinks → Save once in wp-admin
5. Optional Mailhog test: [`mailhog-smtp.md`](mailhog-smtp.md)

## Troubleshooting (short)

| Symptom                             | Likely cause                            | Fix                                                                                |
| ----------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------- |
| Installer / language screen         | Wrong table prefix in container         | Set `WP_TABLE_PREFIX`, `--force-recreate wordpress`                                |
| WP-CLI “not installed”              | Missing SQL or wrong prefix             | Re-import; fix prefix + recreate                                                   |
| `/en/wp-content/...` 404, no styles | Missing Multisite `.htaccess` rules     | Keep template `.htaccess` mounted                                                  |
| Blank page after unpack             | `700`/`600` as UID 1000                 | `chown 33:33` + readable modes                                                     |
| Backend Core update ≠ image         | `.env` tag stale                        | See [`image-bump.md`](image-bump.md)                                               |
| Migrate refuses unresolved pins     | No backup WP version / defaults / flags | Pass `--php` / `--wordpress-image` / `--mariadb-image` or set `stack-defaults.env` |

## Related

| Topic              | Path                                                               |
| ------------------ | ------------------------------------------------------------------ |
| Create / ownership | [`getting-started.md`](getting-started.md)                         |
| Image bump         | [`image-bump.md`](image-bump.md)                                   |
| Fresh → Multisite  | [`multisite-convert.md`](multisite-convert.md)                     |
| Soft defaults      | [`../../config/README.md`](../../config/README.md)                 |
| Menu pin UX        | [`../getting-started.md`](../getting-started.md#menu-image-pin-ux) |
| Ports              | [`../port-convention.md`](../port-convention.md)                   |
