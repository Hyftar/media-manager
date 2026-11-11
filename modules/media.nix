{ config, ... }:
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
    "d /mnt/media/series 0770 hyftar media -"
    "d /mnt/media/movies 0770 hyftar media -"
    "d /mnt/media/animes 0770 hyftar media -"
    "Z /mnt/media/ 0770 hyftar media -"

    "d /mnt/storage/emby 0750 emby media -"
    "d /mnt/storage/emby/backups 0750 emby media -"
    "Z /mnt/storage/emby/ 0750 emby media -"

    "d /mnt/storage/sonarr 0770 sonarr media -"
    "Z /mnt/storage/sonarr 0770 sonarr media -"

    "d /mnt/storage/radarr 0770 radarr media -"
    "Z /mnt/storage/radarr 0770 radarr media -"

    "d /mnt/storage/prowlarr 0770 prowlarr media -"
    "Z /mnt/storage/prowlarr 0770 prowlarr media -"

    # Former Deluge config, kept until the switch to qBittorrent is confirmed.
    "d /mnt/storage/deluge 0770 deluge media -"
    "Z /mnt/storage/deluge 0770 deluge media -"

    "d /mnt/storage/qbittorrent 0770 qbittorrent media -"
    "Z /mnt/storage/qbittorrent 0770 qbittorrent media -"

    "d /mnt/storage/torrents 0770 qbittorrent media -"
    "Z /mnt/storage/torrents 0770 qbittorrent media -"

    "d /mnt/storage/movies_intake 0777 qbittorrent media -"
    "Z /mnt/storage/movies_intake 0777 qbittorrent media -"

    "d /mnt/storage/jellyseerr 0770 node media -"
    "Z /mnt/storage/jellyseerr 0770 node media -"
  ];

  cia.stacks.media = {
    source = ../stacks/media;
    dependsOn = [ "core" ];
    env = {
      TZ = config.time.timeZone;
      MEDIA_GID = config.users.groups.media.gid;
      EMBY_UID = config.users.users.emby.uid;
      SONARR_UID = config.users.users.sonarr.uid;
      RADARR_UID = config.users.users.radarr.uid;
      PROWLARR_UID = config.users.users.prowlarr.uid;
      QBITTORRENT_UID = config.users.users.qbittorrent.uid;
      SEERR_UID = config.users.users.jellyseerr.uid;
    };
  };
}
