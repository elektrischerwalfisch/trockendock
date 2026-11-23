# Development Progress

> Update this file after every development session. **Not updated = session not closed.**
> AI assistants must read this file at the start of each new session.

---

## Current Status

**Date**: 2026-11-23
**Phase**: Phase 2 · Hardening & polish

**Working on**: Stack image pin lifecycle — #1 (WP create pins done; static create + helpers next)

**Next steps**:
- [ ] 1) Pin on create/migrate (`docs/issue-worklogs/unassigned/pin-stack-image-versions-on-create-migrate.md`)
- [ ] 2) Guided image bump CLI + menu (`docs/issue-worklogs/unassigned/guided-image-version-bump.md`)
- [ ] 3) Hub configured versions + run state (`docs/issue-worklogs/unassigned/show-link-hub-configured-versions.md`)
- [ ] Smoke tests for stack CLIs (Phase 2 · A)
- [ ] Slim-fill `docs/ARCHITECTURE.md` gaps (Phase 2 · C)
- [ ] Optional TUI polish only for concrete friction (Phase 2 · D)

---

## Completed

- 2026-11-23 Local issue-worklogs tree; worklog switched to option B (configured `.env` versions; option C dropped)
- 2026-11-23 Worklog: pin WP/PHP/DB image versions on create + migrate
- 2026-11-23 Worklog: guided image version bump (CLI + menu); coordination note in `docs/issue-worklogs/README.md`
- 2026-11-23 Synced #1/#2 issue bodies + worklogs (hard #2→#1 depend; shared helpers; docs boundary)
- 2026-11-23 Hub worklog aligned locally (prefer after #1; display-only; no GitHub issue yet)
- 2026-11-23 Hub worklog: show Multisite when `WP_MULTISITE=1` in `.env`
- 2026-11-23 Synced Multisite hub display into GitHub #3
- 2026-11-23 #1/#3: live URL (`MIGRATION_SOURCE_URL`) on create/migrate; hub displays only
- 2026-11-23 #1 worklog: menu pin UX = generic placeholders + Docker Hub links (no stale “latest” defaults)
- 2026-11-23 #1 worklog: Static PHP create pin (`PHP_IMAGE`) + optional live URL in scope
- 2026-11-23 #1: operator `config/stack-defaults.env` (local soft defaults; no tracked version fallback)
- 2026-11-23 #1: shipped `stack-defaults.env.example`, gitignore, stack-defaults soft-load
- 2026-11-23 Consolidated `load-paths.sh` + `load-stack-defaults.sh` → `config/load-config.sh` (all call sites + docs)
- 2026-11-23 #1: template `.env.example` images empty; `wp-stack project create` requires flags or `stack-defaults`

---

## Notes / Known Landmines

> AI assistants: read this section at the start of every new session

- **Path Multisite**: template `.htaccess` must stay mounted; `/en/wp-content/...` otherwise 404s styles.
- **Fresh Multisite**: run `wp core multisite-convert` **before** setting `WP_MULTISITE=1` (see `docs/wordpress/multisite-convert.md`).
- **`wp-content` permissions**: after migrate/unpack, `700`/`600` as UID 1000 → blank page; www-data needs read (`33:33` + sane modes).
- **HTTPS on publish ports**: Firefox HTTPS-First against `localhost:<WP_PORT>` looks like an endless load — use `http://`.
- **`config/paths.env`**: machine-local; wrong `WEBSITES_ROOT` yields empty project lists in the menu/index.
- **`config/stack-defaults.env`**: machine-local soft defaults (`DEFAULT_*` image pins); gitignored; load via `load-config.sh` — missing file ⇒ create must require explicit pins; never source `.example` as fallback. Prefixed keys avoid Compose shell overrides.
- **Compose shell env overrides `.env`**: stale `WORDPRESS_IMAGE` in the shell blocks image bumps — `unset` before pull/recreate.
