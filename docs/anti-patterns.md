# Anti-Pattern Records

Documents mistakes made in this project — wrong approaches and lessons learned.

**Add entries here whenever a mistake is made, to prevent repeating it.**

---

## Format

```markdown
### [Date] [Short Title]

**Situation**: What was happening when this occurred
**Wrong approach**: What was done
**Consequence**: What went wrong
**Correct approach**: What should be done instead
```

---

## Records

### 2026-11-18 Enable Multisite env before network tables exist

**Situation**: Fresh WordPress project should become Multisite.
**Wrong approach**: Set `WP_MULTISITE=1` immediately (Compose injects full `MULTISITE` defines).
**Consequence**: Site breaks — network tables (`blogs`, `site`, …) missing.
**Correct approach**: `wp core multisite-convert` first, then `WP_MULTISITE=1` + recreate. See `docs/wordpress/multisite-convert.md`.

### 2026-11-18 Leave migrated wp-content as 700/600 owned by host UID

**Situation**: After unpack/migrate, frontend was a blank HTTP 200.
**Wrong approach**: Assume ownership docs (`$USER` vs `33:33`) alone explain empty HTML.
**Consequence**: `www-data` cannot read the active theme → empty body.
**Correct approach**: Ensure readable modes for the web user (`chown`/`chmod` as needed). See `docs/wordpress/getting-started.md` (ownership).

### 2026-11-18 Open local stack via https://localhost:PORT

**Situation**: After permissions fix, browser “never finished loading”.
**Wrong approach**: Rely on Firefox HTTPS-First against an HTTP-only publish port.
**Consequence**: TLS ClientHello → Apache 400; tab appears hung.
**Correct approach**: Use `http://localhost:<WP_PORT>/` (and language paths like `/de/`).
