# WordPress docs

Operator and AI guides for the WordPress stack. English only.

Prefer `./start-menu.sh` for create, migrate, image bump, URL replace, hub refresh, and start/stop/down when the menu covers the action.

## Guides

| Guide                 | Path                                                           | Notes |
|-----------------------|----------------------------------------------------------------|-------|
| Getting started       | [`getting-started.md`](getting-started.md)                     | Create, ownership, Multisite pointer |
| Local workflow        | [`local-workflow.md`](local-workflow.md)                       | Paths, hygiene, AI/operator spine |
| Migration             | [`migration.md`](migration.md)                                 | `wp-stack migrate`, import layout |
| Multisite convert     | [`multisite-convert.md`](multisite-convert.md)                 | Fresh convert + network DB upgrade |
| Image bump            | [`image-bump.md`](image-bump.md)                               | Menu / CLI / manual; WP+MariaDB (+ Static PHP) |

| Mailhog SMTP (WP)     | [`mailhog-smtp.md`](mailhog-smtp.md)                           | WP Mail SMTP; shared basics → [`../mailhog.md`](../mailhog.md) |
| Install Trockendock   | [`../install-trockendock.md`](../install-trockendock.md)       | Host setup (Ubuntu tested) |
| Daily Compose + hub   | [`../getting-started.md`](../getting-started.md#daily-commands) · [`../port-convention.md`](../port-convention.md) | Shared with all stacks |
| Public tunnel         | —                                                              | Dropped (triage H11) |

CLI: [`../../stacks/wordpress/README.md`](../../stacks/wordpress/README.md) · Docs index: [`../README.md`](../README.md)
