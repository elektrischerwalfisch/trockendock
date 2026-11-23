# System Architecture

> Describes Trockendock's overall architecture, module breakdown, data flow, and key design decisions.
> For decision rationale, see `docs/decisions/`.

---

## High-Level Architecture

```
Operator
  │
  ├─ start-menu.sh / bin/menu.sh          (TUI)
  ├─ stacks/wordpress/bin/wp-stack        (CLI)
  └─ stacks/static-php/bin/static-stack   (CLI)
        │
        ├─ templates/<stack>/  ──copy──►  $WEBSITES_ROOT/<project>/
        │                                      ├─ docker-compose.yml
        │                                      ├─ .env
        │                                      └─ wp-content / site files
        │
        └─ bin/generate-local-dev-index.sh ──► trockendock.html
                                                   (ports / links hub)
```

Docker Compose runs per project: WordPress (+ MariaDB, phpMyAdmin, Mailhog) or Static PHP (+ optional Mailhog).

---

## Module Breakdown

| Module              | Path                         | Responsibility                                      |
|---------------------|------------------------------|-----------------------------------------------------|
| Config loader       | `config/`                    | `load-config.sh` (paths + optional stack-defaults)   |
| Platform bin        | `bin/`                       | Menu, link hub, Docker status helper                |
| WordPress stack     | `stacks/wordpress/`          | `wp-stack` create / migrate / db / urls             |
| Static PHP stack    | `stacks/static-php/`         | `static-stack` create                               |
| Templates           | `templates/`                 | Compose + `.env.example` + seed files               |
| AI docs (active)    | `docs/`                      | Guides, architecture, ADRs, anti-patterns           |

---

## Data Flow

### Create WordPress project

```
wp-stack project create <folder>
  ↓
Copy templates/wordpress → $WEBSITES_ROOT/<folder>
  ↓
Write .env (ports, DB passwords)
  ↓
Regenerate trockendock.html
  ↓
Operator: docker compose up -d (+ optional browser install)
```

### Migrate WordPress backup

```
Place wp-content + SQL in import/
  ↓
wp-stack migrate --project <folder> [--yes]
  ↓
Restore content / import DB / URL rewrite / optional Multisite env
  ↓
Empty import/ on success
```

---

## Key Design Decisions

| Decision                         | Choice                                      | See |
|----------------------------------|---------------------------------------------|-----|
| Tech stack / WordPress vs DDEV   | Bash + Compose + WP/Static templates        | `docs/decisions/2026-06-11-wordpress-compose-vs-ddev.md` |
| AI docs / layout                 | Curated English `docs/` + ADRs              | `docs/decisions/2026-11-18-ai-documentation-layout.md` |
| Contao                           | Out of scope — use DDEV                     | `docs/decisions/2026-06-11-contao-use-ddev.md` |
| Local data vs public repo        | Hub/secrets gitignored; manifests dropped   | `docs/decisions/2026-06-11-local-data-vs-public-repo.md` |

---

## External Dependencies

| Dependency        | Purpose                         | Notes                          |
|-------------------|---------------------------------|--------------------------------|
| Docker Engine     | Run project stacks              | Required                       |
| Docker Compose    | Multi-service projects          | Plugin / v2                    |
| WordPress image   | WP + Apache + PHP               | Tag in project `.env`          |
| MariaDB image     | WP database                     | Tag in project `.env`          |
| Mailhog           | Local SMTP catcher              | Optional per template          |

---

## Performance / Security Boundaries

- Secrets stay in project `.env` / `config/paths.env` — never commit or paste into chat
- Link hub may list local URLs/ports; keep customer PII out of the public Trockendock tree
- Destructive CLI flags (`migrate --yes`, `compose down -v`) require explicit operator intent
