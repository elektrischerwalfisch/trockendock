# WordPress: change PHP or Core version

PHP and WordPress Core come from the Docker image tag in `.env` (`WORDPRESS_IMAGE`), not from wp-admin settings.

This flow is **not** wrapped by `./start-menu.sh` — edit `.env` and use Compose in the project folder. A guided CLI/menu bump (and optional refresh of local `config/stack-defaults.env`) is planned as worklog [#2](../issue-worklogs/unassigned/guided-image-version-bump.md); keep this page as the manual fallback until then.

## Steps

1. Edit `.env` — use a tag that exists on Docker Hub **and** is PHP-compatible with that WP version:

   ```env
   WORDPRESS_IMAGE=wordpress:6.3-php8.2-apache
   # optional:
   # MARIADB_IMAGE=mariadb:10.11
   ```

   Format: `wordpress:<WP-Version>-php<PHP-Version>-apache`

2. Clear shell overrides, then pull and recreate WordPress:

   ```bash
   cd "${WEBSITES_ROOT}/<folder>"
   # Compose prefers shell env over .env — stale WORDPRESS_IMAGE in the shell blocks bumps
   unset WORDPRESS_IMAGE MARIADB_IMAGE
   docker compose config --images | grep wordpress   # must match .env
   docker compose pull
   docker compose up -d --force-recreate wordpress
   docker compose exec wordpress php -v
   ```

`wp-content` and the database volume stay. Plain `up -d` may keep the old container — use `--force-recreate wordpress`.

If pull still shows the old tag, unset shell vars and check again. Ownership of `wp-content` (`33:33` / `$USER`) is unrelated.

Tags: [Docker Hub — wordpress](https://hub.docker.com/_/wordpress/tags) · [mariadb](https://hub.docker.com/_/mariadb)

## Backend update vs `.env`

- Update in wp-admin changes Core **in the running** container.
- `WORDPRESS_IMAGE` applies on the **next** recreate.
- After a backend Core update, bump `.env` to the same tag — otherwise a later recreate can roll back.

## Multisite

After a Core bump on Multisite, run the network DB upgrade: [`multisite-convert.md`](multisite-convert.md#network-database-upgrade-after-core-bumps).

## Related

| Topic                 | Path                                                                                                                                                                             |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ownership             | [`getting-started.md`](getting-started.md#ownership-wp-content)                                                                                                                  |
| Daily Compose         | [`../getting-started.md`](../getting-started.md#daily-commands)                                                                                                                  |
| Create / migrate pins | [`getting-started.md`](getting-started.md) · [`migration.md`](migration.md)                                                                                                      |
| Soft defaults         | [`../../config/README.md`](../../config/README.md)                                                                                                                               |
| Guided bump (planned) | [`../issue-worklogs/unassigned/guided-image-version-bump.md`](../issue-worklogs/unassigned/guided-image-version-bump.md) (#2)                                                    |
| Hub Live / versions   | [`../issue-worklogs/unassigned/show-link-hub-configured-versions.md`](../issue-worklogs/unassigned/show-link-hub-configured-versions.md) (#3; Live needs `MIGRATION_SOURCE_URL`) |
