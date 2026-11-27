# WordPress stack

CLI and tooling for the WordPress Docker template. How-tos: [`../../docs/wordpress/`](../../docs/wordpress/).

> **Paths:** `source config/load-config.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

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
source config/load-config.sh
export PATH="${TROCKENDOCK_ROOT}/stacks/wordpress/bin:$PATH"
```

### Create project

```bash
wp-stack project create <folder> \
  --wordpress-image wordpress:<WP>-php<PHP>-apache \
  --mariadb-image mariadb:<x.y> \
  [--table-prefix wp_] \
  [--source-url https://www.example.de] \
  [--slug <slug>] [--theme <theme-slug>] [--dry-run]
```

Pins required (flags or `config/stack-defaults.env`). Optional `--source-url` → `MIGRATION_SOURCE_URL`. Details: [`../../docs/wordpress/getting-started.md`](../../docs/wordpress/getting-started.md) · soft defaults: [`../../config/README.md`](../../config/README.md).

### Migrate a backup (one command)

Backup layout, pin resolution, prefix/source URL, Multisite: [`../../docs/wordpress/migration.md`](../../docs/wordpress/migration.md).

```bash
# Dry run — detection + plan (including proposed image pins)
wp-stack migrate --project <folder>

# Full restore (default)
wp-stack migrate --project <folder> --yes

# wp-content only (plugins, themes, uploads — no DB)
wp-stack migrate --project <folder> --only content --yes

# Database + URL rewrite only (keeps local wp-content)
wp-stack migrate --project <folder> --only db --yes

# Optional pin / URL overrides (see migration.md)
  wp-stack migrate --project <folder> --yes \
  [--wordpress-image <tag>] [--mariadb-image <tag>] [--php <x.y>] \
  [--source-url https://www.example.de] [--chown-www]
```

### Image bump (guided)

Dry-run first; `--yes` writes pins, unsets shell `WORDPRESS_IMAGE`/`MARIADB_IMAGE`/`PHP_IMAGE`, refreshes the link hub, then pull/recreate changed services. `--skip-compose` writes `.env` only (hub still refreshes); `--no-index` skips the hub.

```bash
wp-stack image bump --project <folder> --wordpress <core> --php <x.y>
wp-stack image bump --project <folder> --mariadb 10.11 --yes
```

Details: [`../../docs/wordpress/image-bump.md`](../../docs/wordpress/image-bump.md).

### wp-content ownership

Toggle between www-data (`33:33`) and the host user. Prefer the menu (**WordPress** → **Switch wp-content ownership**). CLI:

```bash
wp-stack wp-content owner status --project <folder>
wp-stack wp-content owner toggle --project <folder> --yes
wp-stack wp-content owner set www-data|host --project <folder> --yes
```

Details: [`../../docs/wordpress/getting-started.md`](../../docs/wordpress/getting-started.md#ownership-wp-content).

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
