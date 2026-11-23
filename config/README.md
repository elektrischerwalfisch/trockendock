# Trockendock configuration

Central path and optional stack-default definitions for scripts and documentation reference.

| File | In git | Purpose |
|------|--------|---------|
| `load-config.sh` | Yes | Sourced by scripts; loads paths (required) + stack defaults (optional) |
| `paths.env.example` | Yes | Default paths (generic, safe for public repo) |
| `paths.env` | No (gitignored) | Your machine's paths — `cp paths.env.example paths.env` |
| `stack-defaults.env.example` | Yes | Keys / format / Hub links for image soft defaults (no create-fallback versions) |
| `stack-defaults.env` | No (gitignored) | Your preferred image pins — `cp stack-defaults.env.example stack-defaults.env` |

## Variables (paths)

| Variable | Meaning |
|----------|---------|
| `WEBSITES_ROOT` | Parent folder of site projects |
| `TROCKENDOCK_ROOT` | This repository |

## Derived (in `load-config.sh`)

| Variable | Points to |
|----------|-----------|
| `LOCAL_DEV_INDEX_FILE` | `${TROCKENDOCK_ROOT}/trockendock.html` |
| `GENERATE_INDEX_SCRIPT` | `${TROCKENDOCK_ROOT}/bin/generate-local-dev-index.sh` |
| `STATIC_PHP_TEMPLATE` | `${TROCKENDOCK_ROOT}/templates/static-php` |
| `STATIC_PHP_MAILHOG_TEMPLATE` | `${TROCKENDOCK_ROOT}/templates/static-php-mailhog` |

## Stack image soft defaults (optional)

Missing `stack-defaults.env` is fine — create then requires explicit pins. The tracked `.example` is **never** sourced as a version fallback. Soft defaults are loaded automatically when you source `load-config.sh`.

| Variable | Meaning |
|----------|---------|
| `STACK_DEFAULTS_LOADED` | `1` if local `stack-defaults.env` was sourced, else `0` |
| `DEFAULT_WORDPRESS_IMAGE` | Soft default for WP create (`wordpress:<WP>-php<PHP>-apache`) |
| `DEFAULT_MARIADB_IMAGE` | Soft default MariaDB tag |
| `DEFAULT_PHP_IMAGE` | Soft default for Static PHP create (`php:<x.y>-apache`) |

Prefixed `DEFAULT_*` keys avoid exporting `WORDPRESS_IMAGE` / `PHP_IMAGE` into the shell (Compose would override project `.env`).

## Usage in scripts

```bash
source "${TROCKENDOCK_ROOT}/config/load-config.sh"
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
source config/load-config.sh
```

**New projects** — prefer stack CLIs (assign ports, write `.env`, regenerate link hub):

```bash
source config/load-config.sh
./stacks/wordpress/bin/wp-stack project create <folder>
./stacks/static-php/bin/static-stack project create <folder> --variant static-php
```

See [`../docs/getting-started.md`](../docs/getting-started.md). Manual `cp -r templates/...` remains possible; see stack READMEs.

Former private path `TROCKENDOCK_LOCAL` / archive manifests: dropped from the active workflow (triage D4). Do not revive without a new ADR.
