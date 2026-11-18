# WordPress: convert a fresh single-site to Multisite

For **new** Trockendock projects that start as a normal WordPress install and should become Multisite locally.

**Not** for importing an existing Multisite dump — `wp-stack migrate` sets `WP_MULTISITE` when `*_blogs` is present. See [`migration.md`](migration.md).

`./start-menu.sh` does **not** wrap Multisite convert — use the WP-CLI steps below. Project create / start / stop remain available via the menu ([`../getting-started.md`](../getting-started.md)).

## Order of operations (mandatory)

Compose injects full Multisite defines when `WP_MULTISITE=1` (`MULTISITE`, `DOMAIN_CURRENT_SITE`, …). Those require network tables (`{prefix}blogs`, `{prefix}site`, …) **already** in the database.

1. Create network tables (`wp core multisite-convert`)
2. Set `WP_MULTISITE=1` in `.env`
3. Recreate the WordPress container

`WP_MULTISITE=1` **before** convert → broken/empty site (missing network tables).

## Path vs subdomain

| Mode                              | `.env`                     | Local recommendation |
|-----------------------------------|----------------------------|----------------------|
| Path (`/en/`, `/de/`, …)          | `WP_MULTISITE_SUBDOMAIN=0` | Yes                  |
| Subdomain (`en.localhost`, …)     | `WP_MULTISITE_SUBDOMAIN=1` | No                   |

With `localhost:<WP_PORT>`, subdomains are impractical (no wildcard DNS / port mapping). Default local: **path Multisite**.

`DOMAIN_CURRENT_SITE` comes from Compose as `localhost:<WP_PORT>` — no separate env var.

The template `.htaccess` is mounted and maps path-Multisite assets (`/en/wp-content/…` → `/wp-content/…`).

## Prerequisites

- Project created (`wp-stack project create` or template copy)
- Stack running: `docker compose up -d` in the project folder
- WordPress installer completed once (`http://localhost:<WP_PORT>/`)
- Paths loaded if needed: `source config/load-paths.sh` from `$TROCKENDOCK_ROOT`

## Steps

All commands in the **project folder** (`${WEBSITES_ROOT}/<folder>`).

### 1. Create network tables with WP-CLI

Load `.env` (passwords stay local in the shell — do not commit):

```bash
cd "${WEBSITES_ROOT}/<folder>"
set -a && source .env && set +a

WP_CLI_IMAGE="wordpress:cli-$(echo "${WORDPRESS_IMAGE}" | sed -n 's/.*-\(php[0-9.]*\)-apache/\1/p')"
CONFIG_EXTRA="$(docker compose exec -T wordpress printenv WORDPRESS_CONFIG_EXTRA)"

docker run --rm --user 33:33 \
  --volumes-from "${PROJECT_SLUG}-wp" \
  --network "container:${PROJECT_SLUG}-wp" \
  -e WORDPRESS_DB_HOST=db:3306 \
  -e WORDPRESS_DB_USER="${WP_DB_USER}" \
  -e WORDPRESS_DB_PASSWORD="${WP_DB_PASSWORD}" \
  -e WORDPRESS_DB_NAME="${WP_DB_NAME}" \
  -e WORDPRESS_TABLE_PREFIX="${WP_TABLE_PREFIX:-wp_}" \
  -e WORDPRESS_CONFIG_EXTRA="${CONFIG_EXTRA}" \
  "${WP_CLI_IMAGE}" wp --path=/var/www/html core multisite-convert \
    --title="Site Title" \
    --base=/ \
    --allow-root
```

- `--title=…` — network title
- `--base=/` — subdirectory install

Afterwards `{prefix}blogs` and `{prefix}site` exist.

### 2. Enable Multisite in `.env`

```env
WP_MULTISITE=1
WP_MULTISITE_SUBDOMAIN=0
```

(Comments live in `.env.example`.)

### 3. Recreate WordPress

```bash
docker compose up -d --force-recreate wordpress
```

### 4. Verify

| Check         | URL / action                                      |
|---------------|---------------------------------------------------|
| Frontend      | `http://localhost:<WP_PORT>/`                     |
| Network Admin | `http://localhost:<WP_PORT>/wp-admin/network/`    |
| New sites     | Network Admin → Sites → Add New (e.g. `/en/`)     |

Use **http**, not https (no TLS on the publish port).

## Network database upgrade (after Core bumps)

Network Admin → „Upgrade Network“ may fail with:

`cURL error 7: Failed to connect to localhost port <WP_PORT>`

**Cause:** WordPress HTTP-pings each site URL (e.g. `http://localhost:8101/en`). Inside the container Apache listens on port **80**; `<WP_PORT>` is only the host publish port. Unrelated to `wp-content` ownership.

The browser may still show the error when DBs are already current — it always HTTP-pings each site.

**Preferred (browser + loopbacks):** keep the mu-plugin  
`wp-content/mu-plugins/trockendock-docker-loopback.php`  
(ships with the template). It rewrites `http://localhost:<WP_PORT>/…` → `http://127.0.0.1/…` with `Host: localhost:<WP_PORT>`. Then „Upgrade Network“ works in wp-admin.

**Alternative / verification:** WP-CLI network DB upgrade (no HTTP loopback). Pass the same Multisite env as the WordPress service — otherwise WP-CLI reports `This is not a multisite installation`.

```bash
cd "${WEBSITES_ROOT}/<folder>"
set -a && source .env && set +a
WP_CLI_IMAGE="wordpress:cli-$(echo "${WORDPRESS_IMAGE}" | sed -n 's/.*-\(php[0-9.]*\)-apache/\1/p')"
CONFIG_EXTRA="$(docker compose exec -T wordpress printenv WORDPRESS_CONFIG_EXTRA)"

docker run --rm --user 33:33 \
  --volumes-from "${PROJECT_SLUG}-wp" \
  --network "container:${PROJECT_SLUG}-wp" \
  -e WORDPRESS_DB_HOST=db:3306 \
  -e WORDPRESS_DB_USER="${WP_DB_USER}" \
  -e WORDPRESS_DB_PASSWORD="${WP_DB_PASSWORD}" \
  -e WORDPRESS_DB_NAME="${WP_DB_NAME}" \
  -e WORDPRESS_TABLE_PREFIX="${WP_TABLE_PREFIX:-wp_}" \
  -e WP_MULTISITE=1 \
  -e WP_MULTISITE_SUBDOMAIN="${WP_MULTISITE_SUBDOMAIN:-0}" \
  -e WP_PORT="${WP_PORT}" \
  -e WORDPRESS_CONFIG_EXTRA="${CONFIG_EXTRA}" \
  "${WP_CLI_IMAGE}" wp --path=/var/www/html core update-db --network --allow-root
```

If Core was updated in wp-admin, also bump `WORDPRESS_IMAGE` in `.env` to the same WP/PHP tag — otherwise the next recreate can roll back Core from the image. Image bump steps: [`image-bump.md`](image-bump.md).

## Scope

| Situation                        | Approach                                              |
|----------------------------------|-------------------------------------------------------|
| Fresh site → Multisite           | This guide                                            |
| Live Multisite dump              | [`migration.md`](migration.md) (`wp-stack migrate`)   |
| Defines without convert          | Do not — site breaks without network tables           |

## Related

| Topic | Path |
|-------|------|
| Create / Multisite env pointer | [`getting-started.md`](getting-started.md) |
| Migration | [`migration.md`](migration.md) |
| Anti-patterns | [`../anti-patterns.md`](../anti-patterns.md) |
