# WordPress stack

CLI and tooling for the WordPress Docker template. How-tos: [`../../docs/wordpress/`](../../docs/wordpress/).

> **Paths:** `source config/load-paths.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

## Template

Created via `wp-stack project create` (recommended). Manual copy: `cp -r "${TROCKENDOCK_ROOT}/templates/wordpress" "${WEBSITES_ROOT}/<project>"` — see [migration guide](../../docs/wordpress/migration.md).

## Documentation

| Topic                   | File                                                                                         |
|-------------------------|----------------------------------------------------------------------------------------------|
| Getting started         | [`../../docs/wordpress/getting-started.md`](../../docs/wordpress/getting-started.md)         |
| Local workflow          | [`../../docs/wordpress/local-workflow.md`](../../docs/wordpress/local-workflow.md)           |
| New project / migration | [`../../docs/wordpress/migration.md`](../../docs/wordpress/migration.md)                     |
| Fresh site → Multisite  | [`../../docs/wordpress/multisite-convert.md`](../../docs/wordpress/multisite-convert.md)     |
| Image bump (PHP/Core)   | [`../../docs/wordpress/image-bump.md`](../../docs/wordpress/image-bump.md)                   |
| Mailhog (shared)        | [`../../docs/mailhog.md`](../../docs/mailhog.md)                                             |
| Mailhog + WP Mail SMTP  | [`../../docs/wordpress/mailhog-smtp.md`](../../docs/wordpress/mailhog-smtp.md)               |
| Install Trockendock     | [`../../docs/install-trockendock.md`](../../docs/install-trockendock.md)                     |
| Area docs index         | [`../../docs/wordpress/README.md`](../../docs/wordpress/README.md)                           |
| Docs index              | [`../../docs/README.md`](../../docs/README.md)                                               |

## CLI

`bin/wp-stack` — add to `PATH` or call by full path:

```bash
source config/load-paths.sh
export PATH="${TROCKENDOCK_ROOT}/stacks/wordpress/bin:$PATH"
```

### Create project

```bash
wp-stack project create <folder> [--slug <slug>] [--theme <theme-slug>] [--dry-run]
```

Copies `templates/wordpress` to `$WEBSITES_ROOT/<folder>/`, writes `.env` (next free `80Nx` port block, random DB passwords), runs `$GENERATE_INDEX_SCRIPT`.

Onboarding: [`../../docs/wordpress/getting-started.md`](../../docs/wordpress/getting-started.md) · platform entry: [`../../docs/getting-started.md`](../../docs/getting-started.md).

### Migrate a backup (one command)

`migrate` restores one backup from `import/` in the project: it reads `wp-content`, the SQL dump, and optional `manifest.json` (table prefix + source URL), restores `wp-content`, wipes the project database, imports the DB, rewrites URLs, and recreates the container. A successful `--yes` then empties `import/` and keeps the folder.

Put the backup directly in `import/` — no extra folder around it. `--only all` needs `wp-content/` plus exactly one `.sql` or `.sql.gz`. `content` needs `wp-content/`. `db` needs the one dump. Anything else in `import/` (a dated wrapper, `wp-admin`, a second dump) aborts the run. `backups/` is not used and is not deleted.

```bash
# Dry run — only reports what was detected and the plan
wp-stack migrate --project <folder>

# Full restore (default)
wp-stack migrate --project <folder> --yes

# wp-content only (plugins, themes, uploads — no DB)
wp-stack migrate --project <folder> --only content --yes

# Database + URL rewrite only (keeps local wp-content)
wp-stack migrate --project <folder> --only db --yes
```

Detected `WP_TABLE_PREFIX` and `MIGRATION_SOURCE_URL` are written to `.env`. Prefix detection is Multisite-aware (base prefix from `*_blogs` / primary `*_options`, not `*_2_options`). When `*_blogs` is present, migrate also sets `WP_MULTISITE=1` (domain is `localhost:<WP_PORT>` via Compose) and rewrites `{prefix}blogs`/`site` domains during URL replace. Path Multisite needs the template `.htaccess` (mounted in Compose) so `/en/wp-content/...` resolves. Add `--chown-www` to set `wp-content` owner to `33:33` (www-data; uses sudo).

### Migrate step by step

The building blocks `migrate` uses, also callable on their own. Run inside the project directory or with `--project <folder>`; the stack must be running.

```bash
# Import a SQL dump
wp-stack db import import/live.sql.gz --project <folder>

# Preview URL rewrite, then apply + recreate
wp-stack urls replace --project <folder> --dry-run
wp-stack urls replace --project <folder> --recreate
```

`urls replace` derives the `wordpress:cli-phpX.Y` image from `WORDPRESS_IMAGE` and replaces `MIGRATION_SOURCE_URL` with `http://localhost:<WP_PORT>` (override via `--old-url` / `--new-url`).

Full migration background (table prefix, permissions): [`../../docs/wordpress/migration.md`](../../docs/wordpress/migration.md)

### Planned

```bash
wp-stack wp plugin list
```
