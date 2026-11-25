# Change stack image versions (guided bump)

PHP, WordPress Core, and MariaDB come from Compose image tags in the project `.env` (`WORDPRESS_IMAGE`, `MARIADB_IMAGE`), not from wp-admin settings. Static PHP uses `PHP_IMAGE`.

Prefer the **interactive menu** or the stack CLI. Manual Compose steps remain a fallback.

## Menu (recommended)

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

- **WordPress** → **Image bump** — optional WP core / PHP / MariaDB (empty Enter = keep current); dry-run first, then confirm apply (`--yes`)
- **Static PHP** → **Image bump** — PHP minor; dry-run first, then confirm apply

Hub tag links and format placeholders match create/migrate pin UX ([`../getting-started.md`](../getting-started.md#menu-image-pin-ux)).

## CLI

Dry-run by default. `--yes` writes pins via shared helpers, unsets shell `WORDPRESS_IMAGE` / `MARIADB_IMAGE` / `PHP_IMAGE` (Compose would otherwise override `.env`), refreshes the link hub (`$GENERATE_INDEX_SCRIPT`; fails soft with a warning), then `docker compose pull` + `up -d --force-recreate` for changed services. Use `--skip-compose` to write `.env` only (hub still refreshes). Use `--no-index` to skip the hub refresh.

### WordPress

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/wordpress/bin/wp-stack image bump --project <folder> --wordpress <core> --php <x.y>
./stacks/wordpress/bin/wp-stack image bump --project <folder> --mariadb 10.11 --yes
./stacks/wordpress/bin/wp-stack image bump --project <folder> \
  --wordpress-image wordpress:6.8.0-php8.3-apache --yes
```

Flags: `--wordpress` / `--php` (compose a tag from current pin + overrides) or `--wordpress-image`; `--mariadb` or `--mariadb-image`. At least one change is required.

### Static PHP

```bash
./stacks/static-php/bin/static-stack image bump --project <folder> --php 8.3
./stacks/static-php/bin/static-stack image bump --project <folder> --php php:8.2-apache --yes
```

CLI reference: [`../../stacks/wordpress/README.md`](../../stacks/wordpress/README.md) · [`../../stacks/static-php/README.md`](../../stacks/static-php/README.md).

## Manual fallback

1. Edit `.env` — use tags that exist on Docker Hub **and** are PHP-compatible with that WP version:

   ```env
   WORDPRESS_IMAGE=wordpress:6.3-php8.2-apache
   # optional:
   # MARIADB_IMAGE=mariadb:10.11
   ```

   Format: `wordpress:<WP-Version>-php<PHP-Version>-apache`

2. Clear shell overrides, then pull and recreate:

   ```bash
   cd "${WEBSITES_ROOT}/<folder>"
   # Compose prefers shell env over .env — stale WORDPRESS_IMAGE in the shell blocks bumps
   unset WORDPRESS_IMAGE MARIADB_IMAGE PHP_IMAGE
   docker compose config --images | grep wordpress   # must match .env
   docker compose pull
   docker compose up -d --force-recreate wordpress
   docker compose exec wordpress php -v
   ```

`wp-content` and the database volume stay. Plain `up -d` may keep the old container — use `--force-recreate`.

If pull still shows the old tag, unset shell vars and check again. Ownership of `wp-content` (`33:33` / `$USER`) is unrelated.

Tags: [Docker Hub — wordpress](https://hub.docker.com/_/wordpress/tags) · [mariadb](https://hub.docker.com/_/mariadb) · [php](https://hub.docker.com/_/php/tags)

## Backend update vs `.env`

- Update in wp-admin changes Core **in the running** container.
- `WORDPRESS_IMAGE` applies on the **next** recreate.
- After a backend Core update, bump `.env` (menu/CLI or manual) to the same tag — otherwise a later recreate can roll back.

## Multisite

After a Core bump on Multisite, run the network DB upgrade: [`multisite-convert.md`](multisite-convert.md#network-database-upgrade-after-core-bumps). Guided bump warns on WordPress **major** changes.

## Related

| Topic         | Path                                                            |
| ------------- | --------------------------------------------------------------- |
| Ownership     | [`getting-started.md`](getting-started.md#ownership-wp-content) |
| Daily Compose | [`../getting-started.md`](../getting-started.md#daily-commands) |
| Create        | [`getting-started.md`](getting-started.md)                      |
| Migrate pins  | [`migration.md`](migration.md)                                  |
| Soft defaults | [`../../config/README.md`](../../config/README.md)              |
| Static PHP    | [`../static-php/getting-started.md`](../static-php/getting-started.md) |
