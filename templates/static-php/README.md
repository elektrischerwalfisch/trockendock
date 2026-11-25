# Static PHP template (static/php)

Platform skeleton for `static-stack project create --variant static-php` (and manual `cp -r`). This `README.md` stays in Trockendock only — **project create removes it** from the new project folder.

> **Paths:** `source config/load-config.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

## Quick start

```bash
source config/load-config.sh
cp -r "${TROCKENDOCK_ROOT}/templates/static-php" "${WEBSITES_ROOT}/<project>"
cd "${WEBSITES_ROOT}/<project>"
cp .env.example .env
```

1. Configure `.env` (slug, ports, **explicit** `PHP_IMAGE`) — template leaves the image empty on purpose; prefer `static-stack project create` with `--php` or `config/stack-defaults.env`
2. Optional: `MIGRATION_SOURCE_URL` (create `--source-url` or set in `.env`) for a Live link in `$LOCAL_DEV_INDEX_FILE`
3. Set ports in `.env`, run `$GENERATE_INDEX_SCRIPT`, bookmark `$LOCAL_DEV_INDEX_FILE`
4. `docker compose pull && docker compose up -d`

## Stack

- Apache + PHP (project root → document root, flat layout like production)
- `mod_rewrite` enabled and `AllowOverride All` — `.htaccess` works like on typical shared hosting
- No database, no Mailhog (use `static-php-mailhog` template if you need local mail capture)

## Documentation

Full guides live in Trockendock, not in copied projects:

`${TROCKENDOCK_ROOT}/docs/static-php/getting-started.md`
