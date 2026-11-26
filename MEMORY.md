# Development Progress

> Update this file after every development session. **Not updated = session not closed.**
> AI assistants must read this file at the start of each new session.

---

## Current Status

**Date**: 2026-11-26
**Phase**: Phase 2 · Hardening & polish

**Working on**: Phase 2 · D — [#4](https://github.com/elektrischerwalfisch/trockendock/issues/4) wp-content ownership switch (implemented; close worklog / commit when asked).

**Next steps**:
- [x] 1) Pin on create/migrate (`docs/issue-worklogs/done/pin-stack-image-versions-on-create-migrate.md`) — local worklog closed 2026-11-25
- [x] 2) Guided image bump CLI + menu (`docs/issue-worklogs/done/guided-image-version-bump.md`) — local worklog closed 2026-11-25; GitHub #2 close when asked
- [x] 3) Hub configured versions + run state (`docs/issue-worklogs/done/show-link-hub-configured-versions.md`) — local worklog closed 2026-11-25; GitHub #3 close when asked
- [x] Smoke tests for stack CLIs (Phase 2 · A — pin suite under `tests/smoke-*.sh`)
- [ ] Slim-fill `docs/ARCHITECTURE.md` gaps (Phase 2 · C)
- [x] #6 Menu pick existing project (`docs/issue-worklogs/done/menu-pick-existing-project.md`) — local + GitHub closed 2026-11-26
- [x] #4 Menu WP `wp-content` ownership switch (`docs/issue-worklogs/active/menu-wp-content-ownership-switch.md`) — wired; **close worklog** / commit when asked
- [ ] Backlog: validate image pins exist on Hub/registry ([`docs/issue-worklogs/unassigned/validate-docker-image-pins-exist.md`](docs/issue-worklogs/unassigned/validate-docker-image-pins-exist.md)) (#5)

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
- 2026-11-23 #1: `static-stack project create --php`; shared `stacks/lib/stack-image-pins.sh` (validate/format/`.env` write; moved from repo-root `lib/`)
- 2026-11-23 Documented `tests/` smoke suite (`tests/README.md` + README/docs links)
- 2026-11-23 #1: menu WordPress create prompts WP/PHP/MariaDB pins (placeholders + Hub; Enter = stack-defaults)
- 2026-11-23 #1 worklog marked active; menu Static PHP create prompts PHP pin (Hub + stack-defaults)
- 2026-11-23 #1: optional `--source-url` / menu live URL on WP+static create; install docs for `stack-defaults.env`
- 2026-11-24 #1: migrate dry-run proposes image pins; `--yes` writes them (backup WP + PHP/MDB from current/defaults/flags)
- 2026-11-24 #1: migrate “pin applied” vs “override used”; `--source-url` detect-first + menu prompt
- 2026-11-24 #1: menu migrate — dry-run proposal then Hub/placeholder pin overrides (Enter keeps detect)
- 2026-11-24 #1 docs: `stack-defaults.env` parallel to `paths.env` (install + config + getting-started); `migration.md` + WP create notes for pin/live-URL policy (`image-bump.md` left for #2)
- 2026-11-24 #1 docs: Static PHP create/`PHP_IMAGE` + defaults UX; menu pin UX section (WP + Static) in `docs/getting-started.md`
- 2026-11-24 #1 docs: cross-links — hub Live needs `MIGRATION_SOURCE_URL` (#3); guided bump (#2) may refresh `stack-defaults.env`
- 2026-11-24 #1 docs cleanup: SSOT roles (defaults / menu UX / migrate pins); drop #2/#3 worklog links from ops docs
- 2026-11-24 #1 hygiene: trim `stacks/wordpress/README.md` migrate narrative; fix MEMORY worklog path; align static template READMEs
- 2026-11-24 #1 smoke suite green (create/migrate pins + live URL detect-first; defaults isolated); Phase 2 · A marked Done; Next = #2
- 2026-11-25 #1 **close worklog** → `docs/issue-worklogs/done/`; closing comment ready; GitHub #1 still open until asked
- 2026-11-25 #2: `wp-stack image bump` designed + shipped (dry-run / `--yes` pin write via `stack-image-pins.sh`); smoke `tests/smoke-wp-stack-image-bump.sh`
- 2026-11-25 #2: `--yes` unsets shell image overrides then compose pull/recreate; `static-stack image bump`; smokes use `--skip-compose`
- 2026-11-25 #2: menu WordPress/Static **Image bump**; `docs/wordpress/image-bump.md` rewritten menu → CLI → manual
- 2026-11-25 #2: `--yes` image bump auto-refreshes link hub (soft-fail; `--no-index` opt-out)
- 2026-11-25 #2: smokes green; Multisite note in docs/CLI; MEMORY/ROADMAP package done; closing comment drafted
- 2026-11-25 #2 **close worklog** → `docs/issue-worklogs/done/`; #3 worklog moved to `active/`
- 2026-11-25 Hub: drop “Suggested next port” hint; meta Source shows resolved `$WEBSITES_ROOT/*/.env`
- 2026-11-25 Hub footer: version + author + GitHub link (drop regenerate/bookmark/convention paths)
- 2026-11-25 Hub CSS: minimal neo-brutal (hard border/shadow, stone palette; catalog-inspired)
- 2026-11-25 #3: hub image-tag labels (`trockendock_hub_label_*` in stack-image-pins; WP pin/`WP latest` + PHP/MariaDB); shown in card subtitle
- 2026-11-25 #3: hub subtitle Multisite (`WP_MULTISITE=1`) + Compose run state (`running`/`stopped` for wordpress/web)
- 2026-11-25 #3: hub card subtitle drops slug; order `stack · Multisite · PHP · WP · MariaDB · run state`
- 2026-11-25 #3: hub card layout — run-state badge (top right), stack/Multisite meta, version chips
- 2026-11-25 #3: hub system meta only `wordpress` / `static/php` (mailhog via link, not label)
- 2026-11-25 #3 docs: `port-convention.md` link-hub card contents + pin lifecycle cross-links; getting-started pointer
- 2026-11-25 #3: manual hub regen smoke (running+stopped); MEMORY/ROADMAP package done; closing comment drafted
- 2026-11-25 #3 **close worklog** → `docs/issue-worklogs/done/`; Next = Phase 2 · C
- 2026-11-25 Worklog (unassigned): menu WP `wp-content` ownership switch (www-data ↔ host)
- 2026-11-25 Worklog (unassigned): validate Docker image pins exist before writing `.env`
- 2026-11-26 Worklog (unassigned): menu project picker for existing-project dialogs
- 2026-11-26 #6: WP migrate/db/urls/bump + Static bump use `menu_pick_compose_project`; Create stays typed; docs + `bash -n`
- 2026-11-26 #6 **close worklog** → `docs/issue-worklogs/done/`; **close github issue** #6; Next = #4 ownership switch
- 2026-11-26 #4: `wp-stack wp-content owner` (status/toggle/set) + menu toggle UX; smoke + docs menu-first

---

## Notes / Known Landmines

> AI assistants: read this section at the start of every new session

- **Path Multisite**: template `.htaccess` must stay mounted; `/en/wp-content/...` otherwise 404s styles.
- **Fresh Multisite**: run `wp core multisite-convert` **before** setting `WP_MULTISITE=1` (see `docs/wordpress/multisite-convert.md`).
- **`wp-content` permissions**: after migrate/unpack, `700`/`600` as UID 1000 → blank page; www-data needs read (`33:33` + sane modes).
- **HTTPS on publish ports**: Firefox HTTPS-First against `localhost:<WP_PORT>` looks like an endless load — use `http://`.
- **`config/paths.env`**: machine-local; wrong `WEBSITES_ROOT` yields empty project lists in the menu/index. Wrong `TROCKENDOCK_ROOT` vs this checkout: stack CLIs still bind templates/`stacks/lib` from the script tree; hub/index scripts follow `paths.env`.
- **`config/stack-defaults.env`**: machine-local soft defaults (`DEFAULT_*` image pins); gitignored; load via `load-config.sh` — missing file ⇒ create must require explicit pins; never source `.example` as fallback. Prefixed keys avoid Compose shell overrides.
- **Compose shell env overrides `.env`**: stale `WORDPRESS_IMAGE` in the shell blocks image bumps — `unset` before pull/recreate.
