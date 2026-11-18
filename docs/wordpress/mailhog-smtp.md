# WordPress → Mailhog (WP Mail SMTP)

Shared Mailhog ports and Docker SMTP targets: [`../mailhog.md`](../mailhog.md).

Applies to stacks from `templates/wordpress/` (Mailhog is always in the Compose file).

## Why the inbox can stay empty

- The stack starts Mailhog but does **not** wire WordPress to it automatically.
- After a live migration, **WP Mail SMTP** often still has production SMTP settings from the database.
- The default WordPress mailer (`sendmail` in the container) is **not** routed to Mailhog.

**Short:** Mailhog is running — WordPress must send there explicitly via SMTP.

## WP Mail SMTP (recommended)

In wp-admin: **WP Mail SMTP → Settings**.

| Setting           | Value          |
|-------------------|----------------|
| Mailer            | **Other SMTP** |
| SMTP Host         | `mailhog`      |
| SMTP Port         | `1025`         |
| Encryption        | **None**       |
| Authentication    | **Off**        |
| Username/Password | empty          |

Use host `mailhog` / `1025` from the WordPress container — not `localhost` / `MAILHOG_SMTP_PORT` (those are for host-side tools). See [`../mailhog.md`](../mailhog.md).

## Default PHP mailer

**Not** enough here: “Default” / PHP `mail` uses `sendmail` in the image and is not preconfigured for Mailhog. Use **Other SMTP** as above.

## Test

1. Save settings.
2. Send a **test email** in WP Mail SMTP → should appear in the Mailhog inbox.
3. Resubmit a contact form if needed.
4. On failure: WP Mail SMTP → email log / debug events.

## Notes

- Settings live in the **database** (plugin options). Before deploy to live, switch back to the real SMTP service.
- Prefer `./start-menu.sh` → Platform for start/stop/hub; plugin settings are wp-admin only.

## Related

| Topic              | Path                                         |
|--------------------|----------------------------------------------|
| Shared Mailhog     | [`../mailhog.md`](../mailhog.md)             |
| Migration verify   | [`migration.md`](migration.md)               |
| WP getting started | [`getting-started.md`](getting-started.md)   |
