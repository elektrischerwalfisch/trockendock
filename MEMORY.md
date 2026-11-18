# Development Progress

> Update this file after every development session. **Not updated = session not closed.**
> AI assistants must read this file at the start of each new session.

---

## Current Status

**Date**: 2026-11-18
**Phase**: Phase 2 · Hardening & polish

**Working on**: Phase 2 items A / C / D (see `ROADMAP.md`)

**Next steps**:
- [ ] Smoke tests for stack CLIs (Phase 2 · A)
- [ ] Slim-fill `docs/ARCHITECTURE.md` gaps (Phase 2 · C)
- [ ] Optional TUI polish only for concrete friction (Phase 2 · D)

---

## Notes / Known Landmines

> AI assistants: read this section at the start of every new session

- **Path Multisite**: template `.htaccess` must stay mounted; `/en/wp-content/...` otherwise 404s styles.
- **Fresh Multisite**: run `wp core multisite-convert` **before** setting `WP_MULTISITE=1` (see `docs/wordpress/multisite-convert.md`).
- **`wp-content` permissions**: after migrate/unpack, `700`/`600` as UID 1000 → blank page; www-data needs read (`33:33` + sane modes).
- **HTTPS on publish ports**: Firefox HTTPS-First against `localhost:<WP_PORT>` looks like an endless load — use `http://`.
- **`config/paths.env`**: machine-local; wrong `WEBSITES_ROOT` yields empty project lists in the menu/index.
- **Compose shell env overrides `.env`**: stale `WORDPRESS_IMAGE` in the shell blocks image bumps — `unset` before pull/recreate.
