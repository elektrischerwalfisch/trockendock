# WordPress local workflow (Trockendock)

Operational rules for AI and operators when creating, running, or migrating local WordPress stacks.

**Prefer the interactive menu** for actions it wraps (create, migrate, URL replace, hub, start/stop/down):

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

CLI equivalent: `stacks/wordpress/bin/wp-stack` and `docker compose` in the project folder.

Operator create/ops: [`getting-started.md`](getting-started.md). Platform entry: [`../getting-started.md`](../getting-started.md).

---

## Path resolution (mandatory)

**Always resolve paths from Trockendock config first.** Do not hardcode or guess machine-specific paths. Never paste literal values from `paths.env` into chat or tracked docs.

1. Locate `config/load-config.sh` (glob: `**/trockendock/config/load-config.sh`).
2. Prefer `config/paths.env` if present; otherwise `config/paths.env.example`.
3. For shell commands:

   ```bash
   source "${TROCKENDOCK_ROOT}/config/load-config.sh"
   ```

| Variable                | Set in                 | Role                               |
|-------------------------|------------------------|------------------------------------|
| `WEBSITES_ROOT`         | `config/paths.env`     | Parent folder of site projects     |
| `TROCKENDOCK_ROOT`      | `config/paths.env`     | Trockendock platform repository    |
| `LOCAL_DEV_INDEX_FILE`  | `config/load-config.sh` | Generated browser link hub         |
| `GENERATE_INDEX_SCRIPT` | `config/load-config.sh` | `bin/generate-local-dev-index.sh`  |

| Role               | Use                                              |
|--------------------|--------------------------------------------------|
| WordPress template | `${TROCKENDOCK_ROOT}/templates/wordpress/`       |
| WordPress guides   | `${TROCKENDOCK_ROOT}/docs/wordpress/`            |
| Port convention    | `${TROCKENDOCK_ROOT}/docs/port-convention.md`    |
| Live projects      | `${WEBSITES_ROOT}/<project-folder>/`             |

Config reference: `${TROCKENDOCK_ROOT}/config/README.md`

---

## Output / hygiene rules

- Use placeholders for **project names** only — not for `WEBSITES_ROOT` / `TROCKENDOCK_*`.
- One stack per project: `wordpress`, `db`, `phpmyadmin`, `mailhog`.
- Secrets in project `.env` only; keep `.env.example` tracked and generic.
- **Do not edit project `.env.example`** when configuring a site — change `.env` only.
- Prefer named Docker volumes for DB data.
- Use fixed `80xx` port blocks per project; regenerate the link hub after port assign/change/release:

  ```bash
  "$GENERATE_INDEX_SCRIPT"
  ```

---

## Create project

Preferred (explicit pins, or `DEFAULT_*` from `config/stack-defaults.env`):

```bash
source "${TROCKENDOCK_ROOT}/config/load-config.sh"
"${TROCKENDOCK_ROOT}/stacks/wordpress/bin/wp-stack" project create <folder> \
  --wordpress-image wordpress:<WP>-php<PHP>-apache \
  --mariadb-image mariadb:<x.y> \
  [--source-url https://www.example.de]
```

Manual (same outcome): copy `templates/wordpress/` → `${WEBSITES_ROOT}/<folder>/`, copy `.env.example` → `.env`, set unique `PROJECT_SLUG` / ports / **explicit** image tags in **`.env` only**.

Required `.env` keys (typical): `PROJECT_SLUG`, `WORDPRESS_IMAGE`, `MARIADB_IMAGE`, `WP_PORT`, `PMA_PORT`, `MAILHOG_UI_PORT`, `MAILHOG_SMTP_PORT`, `WP_DB_NAME`, `WP_DB_USER`, `WP_DB_PASSWORD`, `WP_DB_ROOT_PASSWORD`.

Stack behavior (template):
- Images from `.env` (`WORDPRESS_IMAGE`, `MARIADB_IMAGE`) — set by create/migrate, not silent floating tags
- Mount `./wp-content:/var/www/html/wp-content`
- Named DB volume (e.g. `${PROJECT_SLUG}_db_data`)
- `WORDPRESS_TABLE_PREFIX` from env (`WP_TABLE_PREFIX`)

Details: [`getting-started.md`](getting-started.md). Soft defaults: [`../../config/README.md`](../../config/README.md).

---

## Start / daily ops

```bash
cd "${WEBSITES_ROOT}/<folder>"
docker compose up -d
# verify http://localhost:<WP_PORT> (not https)
# phpMyAdmin / Mailhog on their ports from .env
docker compose stop    # pause
docker compose start   # resume
docker compose down    # remove containers, keep volumes
docker compose down -v # full reset (destructive)
```

Daily Compose / hub: [`../getting-started.md`](../getting-started.md#daily-commands). Image bump: [`image-bump.md`](image-bump.md).

---

## Migrate / Multisite

- Migrate CLI + import layout: [`migration.md`](migration.md)
- Fresh site → Multisite: [`multisite-convert.md`](multisite-convert.md)
- Landmines (permissions, HTTPS, convert order): [`../anti-patterns.md`](../anti-patterns.md), `MEMORY.md`

---

## Git hygiene (project repos)

- Track infra + theme code; ignore secrets and generated artifacts.
- Theme-only repos: ignore `wp-content` except `wp-content/themes/<theme-slug>/`.

## Archive / restore (optional)

- Before archive: `docker compose down`; optional SQL dump under `backups/`
- Copy project folder off-disk; regenerate link hub (port free when no `.env` uses the block)
- Restore: copy back → `docker compose up -d`
- Deferred manifest idea: dropped from live docs (see decoupling triage D4)
