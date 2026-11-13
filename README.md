# Media Manager NixOS Configuration

This is the configuration for my personal media server.

## Services

The following services are included:
- Emby, for media streaming
- Caddy, for reverse proxying and managing TLS certificates
- qBittorrent, for torrent downloading
- Sonarr, for managing TV shows
- Radarr, for managing movies
- Immich, for managing photos and videos
- Jellyserr, for managing movies and series requests

All of which run in Docker containers, as Docker Compose stacks managed by [Arcane](https://getarcane.app).

## Stacks

| Stack    | Compose file                | Variables from        | Contents                         |
| -------- | --------------------------- | --------------------- | -------------------------------- |
| `core`   | `stacks/core/compose.yaml`  | `configuration.nix`   | Caddy (`stacks/core/caddy/`), Arcane |
| `media`  | `stacks/media/compose.yaml` | `modules/media.nix`   | Emby, Sonarr, Radarr, Prowlarr, qBittorrent, Seerr |
| `immich` | `stacks/immich/compose.yaml`| `modules/immich.nix`  | Immich server, machine learning (OpenVINO), Valkey, Postgres |

- The compose files are plain YAML. Values that NixOS owns (uids, gids, paths, timezone) are `${VARIABLES}`, written
  to each stack's `.env` from the `cia.stacks.<name>.env` option (`modules/stacks.nix`). Secrets (Arcane's encryption
  key) come from sops and are copied next to the compose file at deploy time.
- `nixos-rebuild` validates every stack with `docker compose config`, copies it to `/opt/stacks/<name>` and runs
  `docker compose up -d` through the `stack-<name>` systemd unit. A change reloads the unit, so only the services
  whose configuration changed are recreated.
- `/opt/stacks` is Arcane's projects directory: Arcane shows the stacks and installs image updates. **Edit the stacks
  in this repo, not in Arcane's UI** — the copies are read-only and overwritten on every deploy.
- Caddy runs with `--watch`, so a Caddyfile change applies without a container restart.

## Updates

Containers are updated by Arcane (*Environments → Local Docker → Automations → Updates*). Images that must move
together with Immich (Valkey, Postgres) carry `com.getarcaneapp.arcane.updater=false`; Arcane still reports updates
for them but won't install them.

## Hardware

The server runs an Intel Core i5-14500 on NixOS 26.05, booting with systemd-boot (UEFI). Emby and Immich transcode on
the UHD 770 iGPU (Quick Sync) through `/dev/dri`; the host has the iHD VA-API driver and `intel_gpu_top` for checks.

`hardware-configuration.nix` is the file `nixos-generate-config` wrote on the server, kept verbatim (`make
hardware-config` fetches it). Host-specific settings (boot loader, GPU, data drives) live in `modules/hardware.nix`.

## Hard Drives

Paths are defined once in `modules/paths.nix` (`cia.paths`) and passed to the stacks and the backup script.

- `/` and `/boot` : main drive (see `hardware-configuration.nix`)
  - `/data/config/<app>` : app configuration and databases, including Immich's Postgres and model cache
  - `/data/torrents`, `/data/movies_intake` : downloads and the Sonarr/Radarr intake folder
- `/mnt/photos` -- 4 TB : Immich uploads, pictures and videos (formerly `/mnt/storage`)
- `/mnt/media` -- 12 TB : movies, series, animes and books
- `/mnt/bark_backup` -- 4 TB : backup storage for http://bark-barre.ca

The data drives haven't moved to the new machine yet: until `dataDrivesInstalled` is set in `modules/hardware.nix`,
their mount points are plain directories on the main drive. Anything written there is hidden once the drives are
mounted over it.
