# ADR 2026-06-11 — Keep own WordPress Compose setup (vs DDEV)

**Status**: Accepted

## Context

Trockendock already ran multiple local WordPress stacks (Compose template, `80xx` ports, `wp-content` bind-mount, SQL + WP-CLI migration). The question was whether to replace that with DDEV (or similar) for WordPress.

## Decision

**Stay on the own WordPress Compose setup** (`templates/wordpress/`, `wp-stack`). Close migration gaps with CLI (`project create`, `migrate` / `db import` / `urls replace`) rather than adopting DDEV for WordPress.

Revisit DDEV for WordPress only if team size, migration frequency, or maintenance cost clearly outweigh the slim multi-project model.

## Alternatives

- **Switch WordPress to DDEV**: Rejected for now — would replace a working multi-project port-block model and theme-only git layout with a heavier platform.
- **Plugin-only migration (Duplicator, etc.) without CLI**: Incomplete for repeatable Docker restores; kept as optional operator path, not the primary design.

## Consequences

- WordPress local ops stay in Trockendock docs (`docs/wordpress/`).
- Contao is a separate decision (use DDEV) — see [`2026-06-11-contao-use-ddev.md`](2026-06-11-contao-use-ddev.md).
- Historical long-form German essay remains frozen in the filesystem archive; this ADR is the live summary.
