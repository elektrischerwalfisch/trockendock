# Static PHP stack

CLI and tooling for static PHP Docker templates (`static/php` and `static/php/mailhog`). How-tos: [`../../docs/static-php/`](../../docs/static-php/).

> **Paths:** `source config/load-config.sh` from `$TROCKENDOCK_ROOT` — see [`../../config/README.md`](../../config/README.md).

## Templates

| Variant              | Template                        | Services               |
| -------------------- | ------------------------------- | ---------------------- |
| `static-php`         | `templates/static-php/`         | Apache + PHP           |
| `static-php-mailhog` | `templates/static-php-mailhog/` | Apache + PHP + Mailhog |

Flat project layout: site files (`index.php`, assets, …) live in the project root — same as typical server/FTP setups.

Apache starts with `mod_rewrite` and `AllowOverride All` so project `.htaccess` files work locally.

## CLI

`bin/static-stack` — add to `PATH` or call by full path:

```bash
source config/load-config.sh
export PATH="${TROCKENDOCK_ROOT}/stacks/static-php/bin:$PATH"
```

### Create project

```bash
static-stack project create <folder> --variant static-php --php 8.3
static-stack project create <folder> --variant static-php-mailhog --php php:8.2-apache [--slug <slug>] [--dry-run]
```

`--php` (or `DEFAULT_PHP_IMAGE` in `config/stack-defaults.env`) is required. Accepts bare `x.y` or full `php:x.y-apache`. Copies the chosen template to `$WEBSITES_ROOT/<folder>/`, writes `.env` (pin + next free `80Nx` port block), runs `$GENERATE_INDEX_SCRIPT`.

Onboarding: [`../../docs/static-php/getting-started.md`](../../docs/static-php/getting-started.md) · platform entry: [`../../docs/getting-started.md`](../../docs/getting-started.md).

### After create

```bash
cd "${WEBSITES_ROOT}/<folder>"
# add or clone site files
docker compose pull && docker compose up -d
```

## Documentation

| Topic              | File                                                                           |
|--------------------|--------------------------------------------------------------------------------|
| Getting started    | [`../../docs/static-php/getting-started.md`](../../docs/static-php/getting-started.md) |
| Mailhog (shared)   | [`../../docs/mailhog.md`](../../docs/mailhog.md)                               |
| Mailhog + PHP SMTP | [`../../docs/static-php/mailhog.md`](../../docs/static-php/mailhog.md)         |
| Docs index         | [`../../docs/README.md`](../../docs/README.md)                                 |
