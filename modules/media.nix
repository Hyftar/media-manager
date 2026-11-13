{ config, ... }:
let
  paths = config.cia.paths;
in
{
  users.groups = {
    emby = { gid = 2008; };
  };

  users.users = {
    emby = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Emby user";
      group = "emby";
      extraGroups = [ "media" "render" "video" ];
      uid = 900;
    };

    sonarr = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Sonarr user";
      group = "media";
      uid = 903;
    };

    radarr = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Radarr user";
      group = "media";
      uid = 904;
    };

    prowlarr = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Prowlarr user";
      group = "media";
      uid = 905;
    };

    deluge = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Deluge user";
      group = "media";
      uid = 906;
    };

    qbittorrent = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "qBittorrent user";
      group = "media";
      uid = 909;
    };

    jellyseerr = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "seerr user";
      group = "media";
      uid = 910;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${paths.media}/series 0770 hyftar media -"
    "d ${paths.media}/movies 0770 hyftar media -"
    "d ${paths.media}/animes 0770 hyftar media -"
    "d ${paths.media}/books 0770 hyftar media -"
    "Z ${paths.media}/ 0770 hyftar media -"

    "d ${paths.config}/emby 0770 emby media -"
    "d ${paths.config}/emby/backups 0770 emby media -"
    "Z ${paths.config}/emby/ 0770 emby media -"

    "d ${paths.config}/sonarr 0770 sonarr media -"
    "Z ${paths.config}/sonarr 0770 sonarr media -"

    "d ${paths.config}/radarr 0770 radarr media -"
    "Z ${paths.config}/radarr 0770 radarr media -"

    "d ${paths.config}/prowlarr 0770 prowlarr media -"
    "Z ${paths.config}/prowlarr 0770 prowlarr media -"

    "d ${paths.config}/qbittorrent 0770 qbittorrent media -"
    "Z ${paths.config}/qbittorrent 0770 qbittorrent media -"

    "d ${paths.torrents} 0770 qbittorrent media -"
    "Z ${paths.torrents} 0770 qbittorrent media -"

    "d ${paths.intake} 0666 qbittorrent media -"
    "Z ${paths.intake} 0666 qbittorrent media -"

    "d ${paths.config}/jellyseerr 0770 1000 media -"
    "Z ${paths.config}/jellyseerr 0770 1000 media -"
  ];

  cia.stacks.media = {
    source = ../stacks/media;
    dependsOn = [ "core" ];
    env = {
      CONFIG_DIR = paths.config;
      MEDIA_DIR = paths.media;
      TORRENTS_DIR = paths.torrents;
      INTAKE_DIR = paths.intake;
      TZ = config.time.timeZone;
      MEDIA_GID = config.users.groups.media.gid;
      RENDER_GID = config.users.groups.render.gid;
      EMBY_UID = config.users.users.emby.uid;
      SONARR_UID = config.users.users.sonarr.uid;
      RADARR_UID = config.users.users.radarr.uid;
      PROWLARR_UID = config.users.users.prowlarr.uid;
      QBITTORRENT_UID = config.users.users.qbittorrent.uid;
      SEERR_UID = config.users.users.jellyseerr.uid;
    };
  };
}
