# Static PHP: getting started

Flat PHP sites (no database) — two fixed variants. Pick at create time; no switching later.

Platform entry (menu, paths, hub): [`../getting-started.md`](../getting-started.md).  
CLI reference: [`../../stacks/static-php/README.md`](../../stacks/static-php/README.md).

**Prefer the interactive menu** for create and start/stop/hub:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ Static PHP → Create project · Platform → Start / Stop / Refresh link hub. CLI below is the equivalent.

## Variants

| Variant            | `--variant`          | Services               |
|--------------------|----------------------|------------------------|
| static/php         | `static-php`         | Apache + PHP           |
| static/php/mailhog | `static-php-mailhog` | Apache + PHP + Mailhog |

## Create + start

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/static-php/bin/static-stack project create <folder> --variant static-php
# or
./stacks/static-php/bin/static-stack project create <folder> --variant static-php-mailhog
```

Optional: `--slug <name>`, `--dry-run`, `--no-index`.

This copies the template, writes `.env` (next free `80Nx` port block), and regenerates the link hub.

Add your site files (project root = document root):

```bash
cd "${WEBSITES_ROOT}/<folder>"
git clone <repo-url> .
# or copy index.php, assets, …
docker compose pull && docker compose up -d
```

`.htaccess` (clean URLs, redirects) works out of the box — the template enables `mod_rewrite`.

Open `http://localhost:<WEB_PORT>/` (port from `.env` or the link hub).

Optional: set `MIGRATION_SOURCE_URL` in `.env` (e.g. `https://www.example.de`) for a **Live** link in the hub. After changing hub-relevant `.env` values, regenerate:

```bash
cd "$TROCKENDOCK_ROOT"
source config/load-paths.sh
"$GENERATE_INDEX_SCRIPT"
```

## Mailhog variant

UI / ports: [`../mailhog.md`](../mailhog.md). PHP wire-up: [`mailhog.md`](mailhog.md).

## Ports

One `80Nx` block per project (shared with WordPress): static/php uses `…1` only; static/php/mailhog uses `…1`, `…3`, `…4`. See [`../port-convention.md`](../port-convention.md).

## Related

| Topic       | Path                           |
|-------------|-------------------------------|
| Area index  | [`README.md`](README.md)       |
| Mailhog     | [`mailhog.md`](mailhog.md)     |
| Docs index  | [`../README.md`](../README.md) |
