# Static PHP + Mailhog template (static/php/mailhog)

Platform skeleton for `static-stack project create --variant static-php-mailhog` (and manual `cp -r`). This `README.md` stays in Trockendock only — **project create removes it** from the new project folder.

> **Paths:** `source config/load-config.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

## Quick start

```bash
source config/load-config.sh
cp -r "${TROCKENDOCK_ROOT}/templates/static-php-mailhog" "${WEBSITES_ROOT}/<project>"
cd "${WEBSITES_ROOT}/<project>"
cp .env.example .env
```

1. Configure `.env` (slug, ports, image) — do **not** edit `.env.example` for project-specific values
2. Optional: set `MIGRATION_SOURCE_URL` in `.env` for a live-site link in `$LOCAL_DEV_INDEX_FILE`
3. Set ports in `.env`, run `$GENERATE_INDEX_SCRIPT`, bookmark `$LOCAL_DEV_INDEX_FILE`
4. `docker compose pull && docker compose up -d`

## Stack

- Apache + PHP (project root → document root, flat layout like production)
- `mod_rewrite` enabled and `AllowOverride All` — `.htaccess` works like on typical shared hosting
- Mailhog (SMTP capture + web UI)

## Documentation

Full guides live in Trockendock, not in copied projects:

`${TROCKENDOCK_ROOT}/docs/mailhog.md` · `${TROCKENDOCK_ROOT}/docs/static-php/mailhog.md` · `${TROCKENDOCK_ROOT}/docs/static-php/getting-started.md`
