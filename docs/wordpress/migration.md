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

1. Note live WP / PHP / MariaDB versions; pin matching tags in project `.env` (`WORDPRESS_IMAGE`, `MARIADB_IMAGE`).
2. Create the project (`wp-stack project create <folder>`) if it does not exist yet.
3. In **`.env` only** (not `.env.example`), set at least:

| Variable                 | Role                                                                 |
|--------------------------|----------------------------------------------------------------------|
| `MIGRATION_SOURCE_URL`   | Live URL as stored in the DB (schema + domain); also hub Live link   |
| `WP_TABLE_PREFIX`        | Table prefix (migrate can detect and write this)                     |
| `WP_MULTISITE`           | Set by migrate when `*_blogs` is in the dump; do not guess early     |
| `WP_MULTISITE_SUBDOMAIN` | `0` path (`/en/`), `1` subdomain — local default is path             |

`DOMAIN_CURRENT_SITE` is always `localhost:<WP_PORT>` via Compose (no separate env var).

Path Multisite serves assets under `/en/wp-content/...`. The template `.htaccess` (Compose-mounted) maps those to `/wp-content/...`. Without it, secondary sites look unstyled.

## Import layout

Unpack **one** backup flat into `${WEBSITES_ROOT}/<folder>/import/`:

- `wp-content/` (themes, plugins, uploads — not a full live webroot with `wp-admin` / `wp-includes`)
- exactly one `.sql` or `.sql.gz`
- optional `manifest.json` (prefix + source URL)

No dated wrapper folder. Extra dumps or `wp-admin` abort `migrate`. A successful `--yes` empties `import/` and keeps the folder. Use `backups/` for dumps you want to keep.

## One-command migrate (recommended)

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/wordpress/bin/wp-stack migrate --project <folder>        # dry run
./stacks/wordpress/bin/wp-stack migrate --project <folder> --yes    # full restore
```

| Mode | Flag | Needs in `import/` |
|------|------|--------------------|
| Full | `--only all` (default) | `wp-content/` + one dump |
| Files only | `--only content` | `wp-content/` |
| DB + URL rewrite | `--only db` | one dump |

What `--yes` does: restore `wp-content`, wipe project DB, import SQL, rewrite URLs, recreate WordPress, write detected `WP_TABLE_PREFIX` / `MIGRATION_SOURCE_URL` into `.env`. Multisite dumps also set `WP_MULTISITE=1` and rewrite `{prefix}blogs` / `{prefix}site` hosts. Add `--chown-www` for `wp-content` → `33:33` (uses sudo).

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

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Installer / language screen | Wrong table prefix in container | Set `WP_TABLE_PREFIX`, `--force-recreate wordpress` |
| WP-CLI “not installed” | Missing SQL or wrong prefix | Re-import; fix prefix + recreate |
| `/en/wp-content/...` 404, no styles | Missing Multisite `.htaccess` rules | Keep template `.htaccess` mounted |
| Blank page after unpack | `700`/`600` as UID 1000 | `chown 33:33` + readable modes |
| Backend Core update ≠ image | `.env` tag stale | See [`image-bump.md`](image-bump.md) |

## Related

| Topic | Path |
|-------|------|
| Create / ownership         | [`getting-started.md`](getting-started.md) |
| Image bump                 | [`image-bump.md`](image-bump.md)           |
| Fresh → Multisite          | [`multisite-convert.md`](multisite-convert.md) |
| Daily Compose / hub        | [`../getting-started.md`](../getting-started.md#daily-commands) |
| Ports                      | [`../port-convention.md`](../port-convention.md) |
