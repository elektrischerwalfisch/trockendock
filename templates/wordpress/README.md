# WordPress template

Platform skeleton for `wp-stack project create` (and manual `cp -r`). This `README.md` stays in Trockendock only — **project create removes it** from the new project folder.

> **Paths:** `source config/load-config.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

## Quick start

```bash
source config/load-config.sh
cp -r "${TROCKENDOCK_ROOT}/templates/wordpress" "${WEBSITES_ROOT}/<project>"
cd "${WEBSITES_ROOT}/<project>"
cp .env.example .env
```

1. Configure `.env` (slug, ports, **explicit** `WORDPRESS_IMAGE` / `MARIADB_IMAGE`) — template leaves images empty on purpose; prefer `wp-stack project create` with flags or `config/stack-defaults.env`
2. Set ports in `.env`, run `$GENERATE_INDEX_SCRIPT`, bookmark `$LOCAL_DEV_INDEX_FILE`
3. Replace `your-theme` in `.gitignore` with your theme slug
4. `docker compose pull && docker compose up -d`

## Stack

- WordPress
- MariaDB
- phpMyAdmin
- Mailhog

## Documentation

Full guides live in Trockendock, not in copied projects:

`${TROCKENDOCK_ROOT}/docs/wordpress/migration.md` · `${TROCKENDOCK_ROOT}/docs/wordpress/getting-started.md`
