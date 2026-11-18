# Trockendock

> **Trockendock** · Author: elektrischerwalfisch · License: MIT · Version: see `VERSION`

Local development platform for website projects: reusable **templates**, stack-specific **tooling**, and shared **infrastructure** (ports, link hub).

Projects (ships) live under `$WEBSITES_ROOT/<project>/`.

**Changelog:** [`CHANGELOG.md`](CHANGELOG.md) · **License:** [MIT](LICENSE)

**New here?** Start with [`docs/getting-started.md`](docs/getting-started.md) — prerequisites, stack choice, then WordPress / static PHP area guides.

**AI assistants:** read [`AGENTS.md`](AGENTS.md) → [`ROADMAP.md`](ROADMAP.md) → [`MEMORY.md`](MEMORY.md).

## Repository layout

```
trockendock/
├── AGENTS.md / MEMORY.md / ROADMAP.md
├── README.md / LICENSE / VERSION / CHANGELOG.md
├── start-menu.sh             # Interactive terminal menu
├── trockendock.html          # Generated link hub (gitignored) — bookmark this
├── bin/                      # Platform executables (menu, index hub, status helper)
├── config/                   # Central paths (paths.env.example, load-paths.sh)
├── docs/                     # Active English docs (guides, architecture, ADRs)
├── templates/
│   ├── wordpress/
│   ├── static-php/
│   └── static-php-mailhog/
└── stacks/
    ├── wordpress/
    └── static-php/
```

**Quick start (interactive):** from `$TROCKENDOCK_ROOT`, run `./start-menu.sh`.

## Documentation

| Topic                      | File                                                   |
|----------------------------|--------------------------------------------------------|
| Docs index                 | [`docs/README.md`](docs/README.md)                     |
| Install Trockendock        | [`docs/install-trockendock.md`](docs/install-trockendock.md) |
| Getting started            | [`docs/getting-started.md`](docs/getting-started.md)   |
| Port convention + link hub | [`docs/port-convention.md`](docs/port-convention.md)   |
| Architecture               | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)         |
| ADRs                       | [`docs/decisions/README.md`](docs/decisions/README.md) |
| Path configuration         | [`config/README.md`](config/README.md)                 |
