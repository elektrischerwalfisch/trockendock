# Smoke tests

Lightweight shell checks for Trockendock platform behavior. No external test framework — each script is a self-contained smoke that exits `0` on success and prints a short `…: ok` line.

Part of the public repo so pin/create regressions stay reproducible (see `AGENTS.md`: new features need at least a dry-run / smoke path).

## Run

From `$TROCKENDOCK_ROOT`:

```bash
./tests/smoke-load-config.sh
./tests/smoke-stack-image-pins-lib.sh
./tests/smoke-wp-stack-project-create-pins.sh
./tests/smoke-static-stack-project-create-pins.sh
```

Or all at once:

```bash
for t in ./tests/smoke-*.sh; do "$t" || exit 1; done
```

Requires a working `config/paths.env` (or `.example` fallback via `load-config.sh`) for scripts that exercise stack CLIs. Create smokes use `--dry-run` only — they do not write under `$WEBSITES_ROOT`.

## Scripts

| Script | What it checks |
| ------ | -------------- |
| `smoke-load-config.sh` | Paths load; optional `stack-defaults.env`; `.example` is never a version fallback |
| `smoke-stack-image-pins-lib.sh` | `stacks/lib/stack-image-pins.sh` format / validate / parse / `.env` writer |
| `smoke-wp-stack-project-create-pins.sh` | `wp-stack project create` requires pins or defaults; rejects floating WP tags |
| `smoke-static-stack-project-create-pins.sh` | `static-stack project create` requires `--php` or `DEFAULT_PHP_IMAGE` |
| `smoke-wp-stack-migrate-pins.sh` | `wp-stack migrate` dry-run proposes pins from backup + overrides |

## Conventions

- Name: `smoke-<area>.sh`, executable, `set -euo pipefail`
- Prefer dry-run / temp dirs; do not mutate real customer projects
- Keep output quiet except failures and the final `ok` line
- English comments and messages
