# Trockendock — AI Development Rules

> This file applies to all AI coding assistants (Cursor, Claude Code, GitHub Copilot, Codex CLI, and any other agents).
> Read this file in order before starting any development work.

---

## 1. Mandatory Reading Order

Before writing any code, read these files in order:

```
1. ROADMAP.md       ← Current phase and goals (WHAT)
2. MEMORY.md        ← Where we left off, known landmines (WHERE WE LEFT OFF)
3. docs/decisions/  ← Key decision records, newest-first (WHY)
```

**If anything is unclear, stop and ask. Do not read and modify code at the same time.**

---

## 2. Project Overview

Trockendock is a local development platform for website projects: reusable Docker templates, stack CLIs (`wp-stack`, `static-stack`), an interactive menu, and a generated link hub. Customer/site projects live under `$WEBSITES_ROOT/<project>/`, not inside this repository.

**Tech stack**: Bash + Docker Compose + WordPress/MariaDB/Mailhog templates + Static PHP templates

**Target users**: Operators running many local website stacks in parallel

---

## 2.1 Path resolution (mandatory)

**Always resolve paths from Trockendock config first.** Do not hardcode or guess machine-specific paths. Never paste literal values from `paths.env` into chat or tracked files.

1. Locate `config/load-config.sh` (glob: `**/trockendock/config/load-config.sh`).
2. Prefer `config/paths.env` if present; otherwise `config/paths.env.example`.
3. For shell commands: `source "${TROCKENDOCK_ROOT}/config/load-config.sh"`.

| Variable                | Role                                      |
|-------------------------|-------------------------------------------|
| `WEBSITES_ROOT`         | Parent folder of site projects            |
| `TROCKENDOCK_ROOT`      | This platform repository                  |
| `LOCAL_DEV_INDEX_FILE`  | Generated browser link hub                |
| `GENERATE_INDEX_SCRIPT` | Link hub generator script                 |

Docs index: `docs/README.md`. Ops that `./start-menu.sh` wraps: document the menu path first, then CLI.

---

## 3. Protected Zones (Do Not Touch)

The following paths / resources **must NOT be modified without explicit confirmation**:

- `config/paths.env`: Machine-local path overrides — never commit; do not rewrite casually.
- `$WEBSITES_ROOT/<project>/` (and project `.env` files): Live local site data — outside this repo; no bulk writes without confirmation.
- `templates/`: Breaking Compose/`.env.example`/`.htaccess` changes need explicit confirmation (affects every new project).

Any modification to the above requires explicit confirmation first.

---

## 4. Critical Rules (Non-Negotiable)

1. **All new features must have tests** — code without tests is not done (shell: at least a dry-run / smoke path where practical)
2. **Breaking changes require explicit authorization** — don't "casually refactor" stable CLIs or templates
3. **Minimize dependencies** — prefer Bash builtins and existing Docker images before adding tools
4. **Keep docs in sync** — if code changes, MEMORY.md must be updated in the same session
5. **No write operations on production paths** — don't touch live hosting, production DBs, or customer secrets
6. **Never read or display secrets** — project `.env`, passwords, tokens must not appear in chat
7. **No personal real names, real customer project names, or live customer URLs** in tracked files (use placeholders like `example-site`, `kundin-a`, `https://www.example.de`)

---

## 5. Agentic Execution Guardrails

> Extra constraints for autonomous agentic tasks (AI independently reading/writing files, running commands, calling APIs).

**Shell commands**:
- Safe to run autonomously: `git status / diff / log`, read-only `docker compose ps / logs`, `bash -n` syntax checks
- Must notify before running: `git commit / push`, `docker compose up/down`, `wp-stack migrate --yes`, bulk project generation
- Strictly forbidden: `rm -rf`, writing production APIs, modifying secrets / `config/paths.env` without confirmation

**File system**:
- Must not read or write `.env`, `*.secret`, `*.key`, `credentials.*` (in this repo or under `$WEBSITES_ROOT`)
- Must not modify any files inside protected zones (see Section 3)
- Before overwriting an existing file, confirm with the user first
- Prefer `docs/` for operational how-tos

---

## 6. Definition of Done (Doc Sync Discipline)

**After completing any piece of work, check off the following in the same session:**

| # | Document                | When Required                                                              |
|---|-------------------------|----------------------------------------------------------------------------|
| 1 | `MEMORY.md`             | **Always** — update current status + next steps                            |
| 2 | `ROADMAP.md`            | When Phase progress changes — check off the relevant sub-item              |
| 3 | Relevant ADR            | When a decision is revised — append revision history (don't edit original) |
| 4 | `docs/anti-patterns.md` | When a mistake is made — record the anti-pattern + correct approach        |

**Incomplete checklist = work is not done. Do not move to the next task / commit / tell the user "it's done".**

---

## 7. Code Standards

### General
- Use descriptive names — avoid tmp/data/obj/info and other meaningless words
- Each function does one thing — consider splitting if over 50 lines
- Errors must be handled — no empty catch blocks
- No dead code — delete commented-out old code, don't leave it
- **All new comments and variable names must be in English**

### Versioning
- Canonical SemVer lives in repo-root `VERSION` (single line). Do not duplicate it in scripts.
- Leave `VERSION` / `CHANGELOG.md` updates to the operator unless they explicitly ask.

### Bash
- Prefer `set -euo pipefail` in scripts
- Quote variables; avoid word-splitting pitfalls
- Source shared helpers via `config/load-config.sh` instead of hardcoding roots
- Parse `.env` carefully — never print secret values in logs or chat
- Prefer reading `VERSION` from repo root when showing a platform version (do not hardcode)

### Docker / Compose
- Project state lives in `$WEBSITES_ROOT/<project>/` — templates only scaffold
- Prefer idempotent CLI operations; destructive flags (`--yes`, `down -v`) need clear intent

---

## 8. Architecture Patterns

**Separate orchestration from side effects**:
- Path resolution and port logic as reusable functions/scripts
- Docker Compose and filesystem mutations in thin outer wrappers

**Error handling**:
- Fail fast with clear messages for operator-facing CLIs
- Dry-run modes (`--dry-run`) before destructive migrate/create steps

**Documentation**:
- `docs/` = active English operator + AI docs (guides, architecture, ADRs)

---

## 9. Common Task Checklists

### Adding a New Feature
1. Clarify requirements, record plan in MEMORY.md
2. (For complex features) Write a spike doc before writing code
3. Implement, following Critical Rules and Agentic Guardrails
4. Write tests / smoke checks
5. Run DoD checklist (Section 6)

### Fixing a Bug
1. Reproduce the issue, confirm root cause
2. Fix + add regression coverage where practical
3. Run DoD checklist (Section 6)

### Recording a Key Decision
1. Write ADR to `docs/decisions/YYYY-MM-DD-topic.md`
2. Add entry to the index in `docs/decisions/README.md`

---

## 10. Where to Look

| Question                          | Where to go                    |
|-----------------------------------|--------------------------------|
| What are we working on / progress | `MEMORY.md`                    |
| This Phase's goals / DoD          | `ROADMAP.md`                   |
| Why was this decision made        | `docs/decisions/` newest-first |
| What mistakes have been made      | `docs/anti-patterns.md`        |
| What is the system architecture   | `docs/ARCHITECTURE.md`         |
| Docs index / getting started      | `docs/README.md`               |
