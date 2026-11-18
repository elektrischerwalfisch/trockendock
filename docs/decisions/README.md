# Architecture Decision Records (ADR)

Records every important technical / architectural / product decision in this project.

**AI assistants: read from the newest file first (files are sorted by date, descending).**

---

## File Naming

```
YYYY-MM-DD-decision-topic.md
```

## ADR Structure

```markdown
# ADR YYYY-MM-DD — [Decision Title]

**Status**: Accepted | Superseded by [new ADR]

## Context
Why this decision needed to be made

## Decision
What was decided

## Alternatives
- Option A: why it wasn't chosen
- Option B: why it wasn't chosen

## Consequences
- Benefits
- Costs / constraints
```

---

## Decision Index (active)

| Date       | File | Summary |
|------------|------|---------|
| 2026-11-18 | [2026-11-18-ai-documentation-layout.md](2026-11-18-ai-documentation-layout.md) | Curated English `docs/` layout for AI collaboration |
| 2026-06-11 | [2026-06-11-wordpress-compose-vs-ddev.md](2026-06-11-wordpress-compose-vs-ddev.md) | Keep own WordPress Compose setup vs DDEV |
| 2026-06-11 | [2026-06-11-contao-use-ddev.md](2026-06-11-contao-use-ddev.md) | Contao → DDEV; not a Trockendock stack |
| 2026-06-11 | [2026-06-11-local-data-vs-public-repo.md](2026-06-11-local-data-vs-public-repo.md) | Private ops / hub gitignored; manifests dropped |

## Dropped from live ADRs (no formal English ADR)

| Triage | Topic | Handling |
|--------|-------|----------|
| D4 | Deferred archive manifests | One-liner in local-data ADR Consequences |
| D5 | Migration from previous local Docker toolkit | Historical; no live how-to/ADR |
