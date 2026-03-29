{ pkgs, ... }:
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

    deluge = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Deluge user";
      group = "media";
      uid = 905;
    };

    jellyseerr = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "seerr user";
      group = "media";
      uid = 906;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/media/series 0770 hyftar media -"
    "d /mnt/media/movies 0770 hyftar media -"
    "d /mnt/media/animes 0770 hyftar media -"
    "Z /mnt/media/ 0770 hyftar media -"

    "d /mnt/storage/emby 0750 emby emby -"
    "d /mnt/storage/emby/backups 0750 emby emby -"
    "Z /mnt/storage/emby/ 0750 emby media -"

    "d /mnt/storage/sonarr 0770 sonarr media -"
    "Z /mnt/storage/sonarr 0770 sonarr media -"

    "d /mnt/storage/radarr 0770 radarr media -"
    "Z /mnt/storage/radarr 0770 radarr media -"

    "d /mnt/storage/prowlarr 0770 radarr media -"
    "Z /mnt/storage/prowlarr 0770 radarr media -"

    "d /mnt/storage/deluge 0770 deluge media -"
    "Z /mnt/storage/deluge 0770 deluge media -"

    "d /mnt/storage/torrents 0770 deluge media -"
    "Z /mnt/storage/torrents 0770 deluge media -"

    "d /mnt/storage/jellyseerr 0770 node media -"
    "Z /mnt/storage/jellyseerr 0770 node media -"
  ];

  environment.etc."docker-compose/docker-compose.media-service.yml".text = ''
    name: media-service
    services:
      emby:
        image: emby/embyserver:beta
        container_name: emby
        restart: unless-stopped
        environment:
          - UID=900
          - GID=2005
          - GIDLIST=2005
          - NVIDIA_VISIBLE_DEVICES=all
          - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
        volumes:
          - /mnt/storage/emby/backups:/backups
          - /mnt/storage/emby/config:/config
          - /mnt/storage/books:/media/books
          - /mnt/media/movies:/media/movies
          - /mnt/media/series:/media/series
          - /mnt/media/animes:/media/animes
          - /etc/localtime:/etc/localtime:ro
        ports:
          - 8096:8096
          - 8920:8920
        devices:
          - /dev/dri:/dev/dri
        runtime: nvidia
        networks:
          - cia-network

      sonarr:
        image: lscr.io/linuxserver/sonarr:latest
        container_name: sonarr
        restart: unless-stopped
        environment:
          - PUID=903
          - PGID=2005
          - TZ=America/Toronto
        volumes:
          - /mnt/storage/sonarr:/config
          - /mnt/media:/media
          - /mnt/storage/torrents:/media/torrents
        ports:
          - 8989:8989
        networks:
          - cia-network

      radarr:
        image: lscr.io/linuxserver/radarr:latest
        container_name: radarr
        restart: unless-stopped
        environment:
          - PUID=904
          - PGID=2005
          - TZ=America/Toronto
        volumes:
          - /mnt/storage/radarr:/config
          - /mnt/media:/media
          - /mnt/storage/torrents:/media/torrents
        ports:
          - 7878:7878
        networks:
          - cia-network

      seerr:
        image: ghcr.io/seerr-team/seerr:latest
        init: true
        container_name: seerr
        restart: unless-stopped
        environment:
          - LOG_LEVEL=error
          - PUID=906
          - PGID=2005
          - TZ=America/Toronto
          - PORT=5055
        ports:
          - 5055:5055
        volumes:
          - /mnt/storage/jellyseerr:/app/config
        healthcheck:
          test: wget --no-verbose --tries=1 --spider http://localhost:5055/api/v1/status || exit 1
          start_period: 20s
          timeout: 3s
          interval: 15s
          retries: 3
        networks:
          - cia-network

      deluge:
        image: lscr.io/linuxserver/deluge:2.1.1
        container_name: deluge
        restart: unless-stopped
        environment:
          - PUID=905
          - PGID=2005
          - UMASK=007
          - TZ=America/Toronto
          - DELUGE_LOGLEVEL=error
        volumes:
          - /mnt/storage/deluge:/config
          - /mnt/storage/torrents:/media/torrents
        ports:
          - 8112:8112
          - 6881:6881
          - 6881:6881/udp
          - 58846:58846
        networks:
          - cia-network

      prowlarr:
        image: lscr.io/linuxserver/prowlarr:latest
        container_name: prowlarr
        restart: unless-stopped
        environment:
          - PUID=904
          - PGID=2005
          - TZ=America/Toronto
        volumes:
          - /mnt/storage/prowlarr:/config
        ports:
          - 9696:9696
        networks:
          - cia-network

    networks:
      cia-network:
        external: true
        name: cia-server_cia-network
  '';

  systemd.services.media = {
    description = "Media Service Docker Compose";
    after = [ "docker.service" "network-online.target" "cia-server.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "cia-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.media-service.yml up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.media-service.yml down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.media-service.yml restart";
      TimeoutStartSec = 300;
    };
  };
}
