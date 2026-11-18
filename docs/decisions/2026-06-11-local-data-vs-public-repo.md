# ADR 2026-06-11 — Keep private ops data out of the public repo

**Status**: Accepted (revised July 2026 — see Consequences)

## Context

Trockendock may be a **public** Git repository. Generated link hubs, real project names, and similar ops artifacts must not be committed. Port **schema** docs are not sensitive and may stay public.

## Decision

Treat the public repo as **platform only** (templates, scripts, generic examples, schema docs). Keep real project names, per-project `.env`, and generated hub HTML **out of git** (gitignored / machine-local).

Convention: document `80xx` blocks in [`../port-convention.md`](../port-convention.md); regenerate `$LOCAL_DEV_INDEX_FILE` (`trockendock.html`) locally.

## Alternatives

- **Commit a filled hub / real project tables**: Rejected — leaks client/project layout.
- **Long-lived private ops tree (`TROCKENDOCK_LOCAL`) + archive manifests as the primary model**: Superseded in practice (July 2026) — see Consequences.

## Consequences

- `.env` and `trockendock.html` stay gitignored; `.env.example` stays generic.
- **July 2026:** Active archive-manifest workflow and `TROCKENDOCK_LOCAL` as a required ops path were **dropped** (triage D4). Do not revive without a new ADR.
- One-time move from the previous local Docker toolkit folder → Trockendock is historical checklist only (triage D5 — no live ADR).
