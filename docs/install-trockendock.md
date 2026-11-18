# Install Trockendock

First-time setup so this repository can run local stacks (`./start-menu.sh`, `wp-stack`, `static-stack`).

**Tested on:** Ubuntu (current LTS recommended).  
**Other environments:** May work wherever Docker Engine + Compose are available; that is **not verified** here. Use your OS’s [official Docker install docs](https://docs.docker.com/engine/install/) and continue with the Trockendock steps below.

Full generic Docker install steps stay in Docker’s documentation — do not treat this page as a mirror of those guides.

After install, continue with [`getting-started.md`](getting-started.md).

## Goal

- Docker Engine + Compose plugin available for your user
- Trockendock paths configured once
- Ready to create and start a project

## Prerequisites

- A machine with `sudo` (or equivalent) to install Docker if needed
- Network access to pull images and install packages
- This repository cloned as `$TROCKENDOCK_ROOT`

## Install Docker (official)

On **Ubuntu** (tested path):

1. Follow [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) (uninstall old packages → set up the Docker apt repo → install `docker-ce` + Compose plugin).
2. Verify:

   ```bash
   sudo docker run --rm hello-world
   docker compose version
   ```

3. Optional but recommended — run Docker without `sudo` ([Linux post-install](https://docs.docker.com/engine/install/linux-postinstall/)):

   ```bash
   sudo groupadd docker 2>/dev/null || true
   sudo usermod -aG docker "$USER"
   newgrp docker
   docker run --rm hello-world
   ```

On **other OS**: use the matching guide under [Docker Engine install](https://docs.docker.com/engine/install/), then the same verify steps (`docker` / `docker compose`).

## Trockendock paths (once)

```bash
cd "$TROCKENDOCK_ROOT"   # this repository
cp config/paths.env.example config/paths.env   # adjust WEBSITES_ROOT if needed
source config/load-paths.sh
```

Details: [`../config/README.md`](../config/README.md).

## First project

Prefer the menu, then CLI:

```bash
./start-menu.sh
```

Then: [`getting-started.md`](getting-started.md) · WordPress [`wordpress/getting-started.md`](wordpress/getting-started.md) · Static PHP [`static-php/getting-started.md`](static-php/getting-started.md).

## Out of scope here

- Full multi-project template walkthrough (see getting-started / stack guides)
- Public tunnels (dropped from live docs — triage H11)
- Copy-paste of every package-manager line from Docker’s docs (links above stay authoritative)
