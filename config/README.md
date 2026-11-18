# Trockendock configuration

Central path definitions for scripts and documentation reference.

| File | In git | Purpose |
|------|--------|---------|
| `paths.env.example` | Yes | Default paths (generic, safe for public repo) |
| `paths.env` | No (gitignored) | Your machine's paths — `cp paths.env.example paths.env` |
| `load-paths.sh` | Yes | Sourced by scripts; sets derived path variables |

## Variables

| Variable | Meaning |
|----------|---------|
| `WEBSITES_ROOT` | Parent folder of site projects |
| `TROCKENDOCK_ROOT` | This repository |

## Derived (in `load-paths.sh` only)

| Variable | Points to |
|----------|-----------|
| `LOCAL_DEV_INDEX_FILE` | `${TROCKENDOCK_ROOT}/trockendock.html` |
| `GENERATE_INDEX_SCRIPT` | `${TROCKENDOCK_ROOT}/bin/generate-local-dev-index.sh` |
| `STATIC_PHP_TEMPLATE` | `${TROCKENDOCK_ROOT}/templates/static-php` |
| `STATIC_PHP_MAILHOG_TEMPLATE` | `${TROCKENDOCK_ROOT}/templates/static-php-mailhog` |

## Usage in scripts

```bash
source "${TROCKENDOCK_ROOT}/config/load-paths.sh"
```

Override before running: `WEBSITES_ROOT=/other/path ./bin/generate-local-dev-index.sh`

## Documentation convention

In Trockendock docs and copied templates, use **variable names** — not literal paths from `paths.env`.

| Instead of | Use |
|------------|-----|
| `~/Dokumente/00-Websites/...` | `$WEBSITES_ROOT` |
| `.../trockendock/...` | `$TROCKENDOCK_ROOT` |

**Standard command prefix** (from `$TROCKENDOCK_ROOT` or after `cd` there):

```bash
source config/load-paths.sh
```

**New projects** — prefer stack CLIs (assign ports, write `.env`, regenerate link hub):

```bash
source config/load-paths.sh
./stacks/wordpress/bin/wp-stack project create <folder>
./stacks/static-php/bin/static-stack project create <folder> --variant static-php
```

See [`../docs/getting-started.md`](../docs/getting-started.md). Manual `cp -r templates/...` remains possible; see stack READMEs.

Former private path `TROCKENDOCK_LOCAL` / archive manifests: dropped from the active workflow (triage D4). Do not revive without a new ADR.
