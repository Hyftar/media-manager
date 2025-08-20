# Media Manager NixOS Configuration

This is the configuration for my personal media server.

## Services

The following services are included:
- Emby, for media streaming
- Caddy, for reverse proxying and managing TLS certificates
- Deluge, for torrent downloading
- Sonarr, for managing TV shows
- Radarr, for managing movies
- Immich, for managing photos and videos

All of which, are running in Docker containers managed by a Docker Compose file.

## Timers / tasks

### Media Server

This service manages the media server docker containers, this way, they can be started easily using
`systemctl start media-server`.
It is also configured to start at boot and each container is configured to restart if it crashes.

### Media Pull

This service is responsible for pulling the latest media-server images from Docker Hub and restarting the containers
daily at 02:00 AM.

## Drivers

The nvidia driver version 570.153.02 is installed. This specific version was chosen because later versions were causing
issues with the system, particularly with the container toolkit.

## Hard Drives

There are four hard drives installed in total, each of which have a specific purpose:
- `/` -- 1 TB : NixOS install partition & boot / GRUB partition
- `/mnt/storage` -- 4 TB : Storage for containers configuration files and immich photos and videos
- `/mnt/media` -- 12 TB : Storage for media files
- `/mnt/bark_backup` -- 4 TB : backup storage for http://bark-barre.ca
