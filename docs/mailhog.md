# Mailhog (Trockendock stacks)

Shared local SMTP catcher used by WordPress and Static PHP + Mailhog templates. Mail stays in the browser inbox — nothing is sent to the internet.

**Prefer the interactive menu** to start/stop stacks or refresh the hub:

```bash
cd "$TROCKENDOCK_ROOT"
./start-menu.sh
```

→ Platform → Start / Stop / Refresh link hub. App/plugin SMTP wiring is stack-specific (links below).

## Ports (per `80Nx` block)

| Service      | Env variable        | Typical slot     |
|--------------|---------------------|------------------|
| Mailhog UI   | `MAILHOG_UI_PORT`   | `…3` (e.g. 8023) |
| Mailhog SMTP | `MAILHOG_SMTP_PORT` | `…4` (e.g. 8024) |

- Inbox: `http://localhost:<MAILHOG_UI_PORT>/`
- Hub: `$LOCAL_DEV_INDEX_FILE` after `source config/load-config.sh`
- Full block schema: [`port-convention.md`](port-convention.md)

## SMTP targets

| From | Host | Port |
|------|------|------|
| App container on the Compose network | `mailhog` | `1025` |
| Your machine (host tools, Thunderbird, …) | `localhost` | `<MAILHOG_SMTP_PORT>` from `.env` |

Encryption: none · Auth: none.

The stack starts Mailhog but does **not** auto-wire your app. Empty inbox usually means the app still sends elsewhere (or uses PHP `mail()` / sendmail without SMTP).

## Notes

- Inbox storage is **ephemeral** (container restart can clear it).
- Do not put production SMTP credentials in `.env` or this repo.

## Stack wire-up

| Stack | Guide |
|-------|-------|
| WordPress (WP Mail SMTP) | [`wordpress/mailhog-smtp.md`](wordpress/mailhog-smtp.md) |
| Static PHP (PHPMailer / library) | [`static-php/mailhog.md`](static-php/mailhog.md) |
