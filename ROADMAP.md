# Trockendock Roadmap

> **WHAT layer**: Goals, deliverables, and Definition of Done for each Phase.
> For WHY, see `docs/decisions/`.
> For progress, see `MEMORY.md`.
>
> **Rule: Each Phase has a hard DoD. You may not advance to the next Phase until it is met.**

---

## Development Discipline (Run After Every Task)

After completing any piece of work, complete the relevant items below in the same session:

| # | Document                | When Required               | Update                                          |
|---|-------------------------|-----------------------------|-------------------------------------------------|
| 1 | `MEMORY.md`             | **Always**                  | Current status + next steps                     |
| 2 | `ROADMAP.md`            | When Phase progress changes | Check off sub-items in the current Phase        |
| 3 | Relevant ADR            | When a decision is revised  | Append revision history (don't edit original)   |
| 4 | `docs/anti-patterns.md` | When a mistake is made      | Anti-pattern + correct approach                 |

**Incomplete checklist = work is not done. Do not move on / commit / say "it's done".**

---

## Current Status

| Item          | Value                                   |
|---------------|-----------------------------------------|
| Current Phase | **Phase 2 · Hardening & polish**        |
| Next Phase    | Phase 3 · TBD                           |
| Live Version  | `1.0.0` (see `VERSION`)                 |
| Last Updated  | 2026-11-25                              |

---

## Phase Overview

| Phase | Name                     | Status      | Notes                          |
|-------|--------------------------|-------------|--------------------------------|
| **0** | Documentation foundation | Done        | `AGENTS.md` / docs skeleton    |
| **1** | Curated English `docs/`  | Done        | Operator guides + ADRs live    |
| **2** | Hardening & polish       | In progress | Smoke tests, architecture, TUI |
| **3** | (TBD)                    | Not started | After Phase 2 closed           |

---

## Phase 2 · Hardening & polish

**Goal**: Make the platform safer to change and cleaner to operate, without new stacks.

| # | Item | Status |
|---|------|--------|
| A | Smoke tests for `wp-stack` / `static-stack` (`--dry-run`, `bash -n`, small fixture if practical) | Done (pin create/migrate + image bump under `tests/smoke-*.sh`) |
| — | Pin lifecycle #1 (explicit image pins on create/migrate + docs) | Done locally |
| — | Pin lifecycle #2 (guided image bump CLI + menu + docs + hub refresh) | Done locally (`docs/issue-worklogs/done/guided-image-version-bump.md`); GitHub #2 close when asked |
| — | Pin lifecycle #3 (link hub configured versions + run state) | Done locally (`docs/issue-worklogs/active/show-link-hub-configured-versions.md`); await **close worklog**; GitHub #3 close when asked |
| C | Slim-fill `docs/ARCHITECTURE.md` gaps from operator knowledge | Open — **Next** after #3 close |
| D | TUI polish only for concrete menu bugs/friction | Optional |

**Definition of Done**:
- [ ] Agreed items checked off or explicitly deferred to Phase 3
- [ ] `MEMORY.md` reflects Phase 2 closed

---

## Decision Log

| Date       | Decision                                         | See |
|------------|--------------------------------------------------|-----|
| 2026-11-18 | Live `docs/` layout for AI collaboration         | `docs/decisions/2026-11-18-ai-documentation-layout.md` |
| 2026-06-11 | WordPress own Compose setup vs DDEV              | `docs/decisions/2026-06-11-wordpress-compose-vs-ddev.md` |
| 2026-06-11 | Contao → DDEV (not a Trockendock stack)          | `docs/decisions/2026-06-11-contao-use-ddev.md` |
| 2026-06-11 | Private ops data out of public repo              | `docs/decisions/2026-06-11-local-data-vs-public-repo.md` |
