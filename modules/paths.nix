# Where data lives on the host. The stacks get these through their .env and the
# backup script through its environment, so a move only needs a change here.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.cia.paths;

  path = default: description: mkOption { type = types.str; inherit default description; };
in
{
  options.cia.paths = {
    # Main drive
    config = path "/data/config" "App configuration and databases, one folder per app.";
    torrents = path "/data/torrents" "qBittorrent downloads.";
    intake = path "/data/movies_intake" "Drop folder imported by Sonarr and Radarr.";

    # Data drives (see modules/hardware.nix)
    photos = path "/mnt/photos" "Photos drive: Immich uploads, pictures, videos.";
    media = path "/mnt/media" "Media drive: movies, series, animes, books.";
  };

  config.systemd.tmpfiles.rules = [
    "d /data 0755 root root -"
    "d ${cfg.config} 0755 root root -"
  ];
}
