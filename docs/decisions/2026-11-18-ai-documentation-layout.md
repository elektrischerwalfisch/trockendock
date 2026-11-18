# ADR 2026-11-18 — AI documentation layout (live `docs/` vs frozen legacy tree)

**Status**: Accepted

## Context

Trockendock already had operational how-tos and ADR-like records under a single `docs/` tree. Introducing the AI collaboration baseline (`AGENTS.md`, `MEMORY.md`, `ROADMAP.md`, formal ADRs) needed a clear split so assistants do not edit legacy how-tos in place.

The **runtime stack** (Bash + Docker Compose + WordPress/Static PHP templates) was already decided earlier — see [`2026-06-11-wordpress-compose-vs-ddev.md`](2026-06-11-wordpress-compose-vs-ddev.md) and related June 2026 ADRs. This ADR does **not** re-decide that stack; it only records the documentation layout change.

## Decision

- Active AI-facing docs live under `docs/` (`ARCHITECTURE.md`, `docs/decisions/`, `anti-patterns.md`, migrated guides).
- Legacy how-tos, plans, and historical decision write-ups are frozen as a **read-only sibling tree** beside `docs/` and migrated gradually into live docs.
- New decisions use dated filenames `YYYY-MM-DD-topic.md` in `docs/decisions/`.

## Alternatives

- **Keep one editable `docs/` tree** for how-tos and AI meta-docs: Rejected — unclear ownership and high risk of rewriting archive material.
- **Rewrite all how-tos into AI docs in one pass**: Deferred — Phase 1 migrates by priority.
- **Move archive ADRs into dated `docs/decisions/` files immediately**: Deferred — index them with proposed dates first; copy/normalize when a topic is actively revisited.

## Consequences

- AI must not edit the frozen legacy tree; port knowledge outward when a topic is worked on.
- Operators use live `docs/` for day-to-day how-tos; the frozen tree is filesystem freeze only (do not link from live docs).
- Stack changes (e.g. WordPress → DDEV) still require a **new** ADR; the June 2026 Slim ADRs remain the live rationale until superseded.

## Revision history

| Date       | Change |
|------------|--------|
| 2026-11-18 | Clarified operators use live `docs/` day-to-day (decoupling Steps 2–5). |
| 2026-11-18 | Step 8: renamed file; removed on-disk legacy-tree basename from live wording. |
