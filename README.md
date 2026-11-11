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
| `immich` | `stacks/immich/compose.yaml`| `modules/immich.nix`  | Immich server, Valkey, Postgres  |

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

## Drivers

The nvidia driver version 570.153.02 is installed. This specific version was chosen because later versions were causing
issues with the system, particularly with the container toolkit.

## Hard Drives

There are four hard drives installed in total, each of which have a specific purpose:
- `/` -- 1 TB : NixOS install partition & boot / GRUB partition
- `/mnt/storage` -- 4 TB : Storage for containers configuration files and immich photos and videos
- `/mnt/media` -- 12 TB : Storage for media files
- `/mnt/bark_backup` -- 4 TB : backup storage for http://bark-barre.ca
