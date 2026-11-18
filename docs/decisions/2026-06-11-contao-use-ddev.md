# ADR 2026-06-11 — Contao local via DDEV (not a Trockendock stack)

**Status**: Accepted

## Context

Contao Managed Edition is a Symfony/Composer app (document root `public/`, DNS mapping, no WordPress-style all-in-one image + single bind-mount). A first Contao project needed a local Docker approach while WordPress stayed on Trockendock.

## Decision

**Do not** add `templates/contao/` / `contao-stack` to Trockendock for now. Run **Contao on DDEV** (per project, `.ddev/` in that repo). Trockendock and DDEV may run in parallel on the same machine (Trockendock uses `80xx`; DDEV typically uses host 80/443).

## Alternatives

- **Build a Contao Compose template in Trockendock**: Rejected — high effort (PHP extensions, Composer, `files/` sync, Contao setup) vs official Contao + DDEV guidance.
- **Force Contao into the WordPress-shaped template**: Rejected — wrong project shape.

## Consequences

- Contao how-tos are out of scope for live Trockendock `docs/`.
- WordPress remains on Trockendock — see [`2026-06-11-wordpress-compose-vs-ddev.md`](2026-06-11-wordpress-compose-vs-ddev.md).
- Operators learn DDEV for Contao; no requirement to migrate WordPress to DDEV.
