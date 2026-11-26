# WordPress: getting started

Create, start, migrate basics, ownership, Multisite pointer, and image-bump link for the WordPress stack.

Platform entry (menu, paths, hub): [`../getting-started.md`](../getting-started.md).  
CLI reference: [`../../stacks/wordpress/README.md`](../../stacks/wordpress/README.md).

**Prefer the interactive menu** when it covers the step:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ WordPress → Create project / Migrate · Platform → Start / Stop project. CLI below is the equivalent.

## Create + start

Image pins are **required** (CLI flags or local soft defaults). Optional `--source-url` → `MIGRATION_SOURCE_URL`. Soft defaults: [`../../config/README.md`](../../config/README.md). Menu pin UX: [`../getting-started.md`](../getting-started.md#menu-image-pin-ux).

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/wordpress/bin/wp-stack project create <folder> \
  --wordpress-image wordpress:<WP>-php<PHP>-apache \
  --mariadb-image mariadb:<x.y> \
  [--theme <theme-slug>] \
  [--source-url https://www.example.de]
```

This copies the template, writes `.env` (pins, next free `80Nx` port block, DB passwords), and regenerates the link hub. Then:

```bash
cd "${WEBSITES_ROOT}/<folder>"
docker compose pull && docker compose up -d
```

Open `http://localhost:<WP_PORT>/` (port from `.env` or the link hub).

More create/ops rules: [`local-workflow.md`](local-workflow.md).

## Migrate (short)

1. Create the project (above).
2. Unpack **one** backup directly into `${WEBSITES_ROOT}/<folder>/import/` (`wp-content/`, one `.sql` or `.sql.gz`, optional `manifest.json`). A successful `--yes` empties that folder and leaves it in place. `backups/` stays for dumps you keep.
3. Preview, then restore — dry-run shows proposed image pins; `--yes` writes pins, prefix, and source URL:

```bash
cd "$TROCKENDOCK_ROOT"
./stacks/wordpress/bin/wp-stack migrate --project <folder>        # dry run
./stacks/wordpress/bin/wp-stack migrate --project <folder> --yes    # full restore
```

Modes (`--only content`, `--only db`), pin resolution, and flags: [`migration.md`](migration.md).

## Ownership (`wp-content`)

`wp-content` is a bind mount. Switch owner when you change how you work: **33:33** (`www-data`) for plugin/theme updates in wp-admin, **`$USER:$USER`** for editing on the host.

### Menu (recommended)

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ **WordPress** → **Switch wp-content ownership** — choose project → see current owner → confirm toggle to the other target (`[y/N]`). Runs stop → `sudo chown` → up. `sudo` may prompt for a password.

### CLI

```bash
wp-stack wp-content owner status --project <folder>
wp-stack wp-content owner toggle --project <folder>        # dry-run plan
wp-stack wp-content owner toggle --project <folder> --yes  # apply
wp-stack wp-content owner set www-data|host --project <folder> --yes
```

`toggle` only when current is www-data or host. For other UIDs, use `set`. `--skip-compose` skips stop/up (chown only).

### Manual fallback

```bash
cd "${WEBSITES_ROOT}/<folder>"
docker compose stop
sudo chown -R 33:33 wp-content          # wp-admin updates
# or: sudo chown -R "$USER:$USER" wp-content   # host/Git editing
docker compose up -d
```

After migrate/unpack, `700`/`600` as UID 1000 often yields a blank page — www-data needs read access. Ownership switch does not fix modes.

The template sets `FS_METHOD` via Compose so wp-admin does not ask for FTP credentials. Keep `wp-content` at `33:33` while installing/updating from wp-admin.

## Multisite (pointer)

| Variable                 | Role                                                                          |
|--------------------------|-------------------------------------------------------------------------------|
| `WP_MULTISITE`           | `0` off / `1` on — injects Multisite defines through `WORDPRESS_CONFIG_EXTRA` |
| `WP_MULTISITE_SUBDOMAIN` | `0` path-based (`/en/`), `1` subdomain                                        |

`DOMAIN_CURRENT_SITE` is derived as `localhost:<WP_PORT>` inside the container.

Turning a **fresh** single-site into Multisite: convert the DB first, **then** set `WP_MULTISITE=1`. Full steps: [`multisite-convert.md`](multisite-convert.md).

Network DB upgrade after a Core bump (browser „Upgrade Network“ often fails on `localhost:<WP_PORT>`): [`multisite-convert.md`](multisite-convert.md#network-database-upgrade-after-core-bumps). Prefer the mu-plugin `trockendock-docker-loopback.php` shipped with the template.

## PHP / Core image bump

Menu → WordPress → Image bump, or CLI. Full guide (menu → CLI → manual): [`image-bump.md`](image-bump.md).

## Related

| Topic                  | Path                                       |
|------------------------|--------------------------------------------|
| Area index             | [`README.md`](README.md)                   |
| Image bump             | [`image-bump.md`](image-bump.md)           |
| Ports                  | [`../port-convention.md`](../port-convention.md) |
| Mailhog (shared)       | [`../mailhog.md`](../mailhog.md)           |
| Mailhog SMTP (WP)      | [`mailhog-smtp.md`](mailhog-smtp.md)       |
| Install Trockendock    | [`../install-trockendock.md`](../install-trockendock.md)     |

