# Static PHP → Mailhog

Shared Mailhog ports and Docker SMTP targets: [`../mailhog.md`](../mailhog.md).

For projects from `templates/static-php-mailhog/` only (`STACK=static-php-mailhog`). Plain `static-php` has no Mailhog service.

**Prefer the interactive menu** to create the Mailhog variant and start/stop:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ Static PHP → Create project (choose `static-php-mailhog`) · Platform → Start / Stop.

Create/start: [`getting-started.md`](getting-started.md).

## Wire SMTP from PHP in Docker

Point your mailer (PHPMailer or similar) at:

| Setting    | Value     |
|------------|-----------|
| Host       | `mailhog` |
| Port       | `1025`    |
| Encryption | none      |
| Auth       | none      |

PHP `mail()` does **not** use Mailhog by default. Prefer an explicit SMTP library, or a sendmail shim if you add one to the image later.

Host-side tools: `localhost` + `MAILHOG_SMTP_PORT` — see [`../mailhog.md`](../mailhog.md).

## Related

| Topic            | Path                                       |
|------------------|--------------------------------------------|
| Shared Mailhog   | [`../mailhog.md`](../mailhog.md)           |
| Getting started  | [`getting-started.md`](getting-started.md) |
| WordPress wire-up| [`../wordpress/mailhog-smtp.md`](../wordpress/mailhog-smtp.md) |
