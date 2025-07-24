{ config, pkgs, ... }:
{
  system.stateVersion = "25.05";

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/disk/by-id/ata-WDC_WD1002FAEX-00Z3A0_WD-WCATR9408292" ];
  };

  time.timeZone = "America/Toronto";

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Add SSH and FTP ports to firewall
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 6881 ];
    allowedTCPPorts = [ 22 80 443 6881 58846 ];
    allowedTCPPortRanges = [
      { from = 50000; to = 50100; }  # FTP passive mode port range
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "bark" ];
      commands = [
        {
          command = "${pkgs.borgbackup}/bin/borg";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users = {
    groups = {
      bark = {
        gid = 420;
      };

      media = {
        gid = 2005;
      };

      photos = {
        gid = 2006;
      };

      immich = {
        gid = 2007;
      };

      emby = {
        gid = 2008;
      };

      caddy = {
        gid = 2009;
      };
    };

    users = {
      hyftar = {
        isNormalUser = true;
        description = "Simon Landry";
        extraGroups = [ "wheel" "docker" "networkmanager" ];
        home = "/mnt/storage/hyftar";
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJVOVgvmbYJpZ+iU/ctEtdQdJPez9hZV0ucOxI0ZkjUJL98A/zLN6s/CvcszgHZfNyWU8ptd4jn2Ynw4PHNm4PQk+5iGdyX2iYCiV3kecFrfqQLVcz0qoBITqGEu2OGmOeIyvf0Xu/A159e+6lHKg1Bco6PBH1AiHr1VAepWUcyzAEk2lIdmhbyHjuBrtbXDEzbvbDwoXW7VCdWms235wzWSo/wcz8y0I5jPMYIbV8FDLT1TbjvocVZZMCnq3b9qlPk0h0WM6RbxOMF6R+je76tMGEFpiqBWkNXURewR6Y2UwEdXa3XUkQods6TKmIXgf9gd61BgjMA3C7oPLSlVKG2DMXTADFOK4z5u+KYB6/dUiaaFkwHaLsO0ck9vtWmay6G0Wyt7Iw9isY5T+yJ9fD1meqfNkQVvPE4opNg7/M5fCl6gAYxXfNOhRUBUsWjJnBwHkCKsjbomAWKh1XechCr84YjtV/HIcOVklmWUA5jtV5WxgT5ap5TlPr2kaGySQ2mzhLpig20dUPpujlEexfWIHrnrvaJ2gRzZPXIHtH32kx7/IJfd0trurWIoDzWKU3uFUuXCu1CLDBfEed+dtFZWk/Zx3wUgqzxG6KZXO1VlZEoqVBWU10DXnmQntLzDT7tGPnauPApAOe9EjZTnLDTjN3Jxg4XPpOcJZRr5pnPQ== simon.landry@rumandcode.io"
        ];
      };

      bark = {
        isNormalUser = true;
        isSystemUser = false;
        createHome = false;
        description = "Bark Barré";
        home = "/mnt/bark_backup";
        group = "bark";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5HeefY97S3ZZS5qpZXHjSZgyuqFj+vgq8nMInzPds1"
        ];
      };

      emby = {
        isSystemUser = true;
        isNormalUser = false;
        createHome = false;
        description = "Emby user";
        group = "emby";
        extraGroups = [ "media" "render" "video" ];
        uid = 900;
      };

      immich = {
        description = "Immich user";
        isSystemUser = true;
        isNormalUser = false;
        createHome = false;
        group = "immich";
        extraGroups = [ "photos" ];
        uid = 901;
      };

      caddy = {
        description = "Caddy user";
        isSystemUser = true;
        isNormalUser = false;
        createHome = false;
        group = "caddy";
        extraGroups = [ ];
        uid = 902;
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
    };
  };

  # Enable systemd for managing services
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';

  # Create necessary directories and set permissions
  systemd.tmpfiles.rules = [
    "d /mnt/storage/emby 0750 emby emby -"
    "d /mnt/storage/deluge 0750 deluge media -"
    "d /mnt/storage/media/series 0770 hyftar media -"
    "d /mnt/storage/media/movies 0770 hyftar media -"
    "d /mnt/storage/media/animes 0770 hyftar media -"
    "d /mnt/storage/media/torrents 0770 hyftar media -"
    "Z /mnt/storage/media/ 0770 hyftar media -" # Recursively set permissions
    "d /mnt/storage/immich 0770 immich immich -"
    "d /mnt/storage/immich/upload 0770 immich immich -"
    "d /mnt/storage/immich/data 0770 immich immich -"
    "d /mnt/storage/caddy 0770 caddy caddy -"
    "Z /mnt/storage/caddy 0770 caddy caddy -"
    "d /mnt/storage/sonarr 0770 sonarr media -"
    "Z /mnt/storage/sonarr 0770 sonarr media -"
    "d /mnt/storage/radarr 0770 radarr media -"
    "Z /mnt/storage/radarr 0770 radarr media -"
    "Z /mnt/bark_backup 0770 bark bark -"
    "d /var/lib/docker-compose 0750 root root -"
  ];

  # Create Caddy configuration file
  environment.etc."caddy/Caddyfile".text = ''
    # Global options
    {
      admin localhost:2019
      # Enable automatic HTTPS with Let's Encrypt
      email simonlandry762@gmail.com
    }

    emby.grosluxe.ca {
      reverse_proxy emby:8096
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    photos.grosluxe.ca {
      reverse_proxy immich_server:2283
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    sonarr.grosluxe.ca {
      reverse_proxy sonarr:8989
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    radarr.grosluxe.ca {
      reverse_proxy radarr:7878
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    deluge.grosluxe.ca {
      reverse_proxy deluge:8112
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }
  '';

  # Docker-compose .env file
  environment.etc."docker-compose/.env".text = ''
    # == Begin Immich config ==
    UPLOAD_LOCATION=/mnt/storage/immich/upload
    DB_DATA_LOCATION=/mnt/storage/immich/data

    TZ=America/Toronto
    IMMICH_VERSION=release
    DB_PASSWORD=postgres

    # The values below this line do not need to be changed
    DB_USERNAME=postgres
    DB_DATABASE_NAME=immich
    # == End Immich config ==
  '';

  # Create docker-compose configuration
  environment.etc."docker-compose/docker-compose.yml".text = ''
    networks:
      media-network:
        driver: bridge

    services:
      # Caddy reverse proxy
      caddy:
        image: caddy:latest
        container_name: caddy
        restart: unless-stopped
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
          - /mnt/storage/caddy/data:/data
          - /mnt/storage/caddy/config:/config
          - /mnt/storage:/mnt/storage:ro  # Mount storage for file server
        networks:
          - media-network
        depends_on:
          - emby
          - immich-server

      # Emby media server with NVIDIA GPU support
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
          - /mnt/storage/emby/config:/config
          - /mnt/storage/media/movies:/media/movies
          - /mnt/storage/media/series:/media/series
          - /mnt/storage/media/animes:/media/animes
        ports:
          - 8096:8096
          - 8920:8920
        devices:
          - /dev/dri:/dev/dri
        runtime: nvidia
        networks:
          - media-network

      # Immich
      immich-server:
        container_name: immich_server
        group_add:
          - 2007
        image: ghcr.io/immich-app/immich-server:''${IMMICH_VERSION:-release}
        volumes:
          - ''${UPLOAD_LOCATION}:/usr/src/app/upload
          - /mnt/storage/pictures:/mnt/storage/pictures
          - /etc/localtime:/etc/localtime:ro
        env_file:
          - /etc/docker-compose/.env
        ports:
          - '2283:2283'
        depends_on:
          - redis
          - database
        restart: unless-stopped
        networks:
          - media-network
        healthcheck:
          disable: false

      immich-machine-learning:
        container_name: immich_machine_learning
        group_add:
          - 2007
        image: ghcr.io/immich-app/immich-machine-learning:''${IMMICH_VERSION:-release}
        volumes:
          - model-cache:/cache
        env_file:
          - /etc/docker-compose/.env
        restart: unless-stopped
        networks:
          - media-network
        healthcheck:
          disable: false

      redis:
        container_name: immich_redis
        group_add:
          - 2007
        image: docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177
        healthcheck:
          test: redis-cli ping || exit 1
        networks:
          - media-network
        restart: unless-stopped

      database:
        container_name: immich_postgres
        group_add:
          - 2007
        image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
        environment:
          POSTGRES_PASSWORD: ''${DB_PASSWORD}
          POSTGRES_USER: ''${DB_USERNAME}
          POSTGRES_DB: ''${DB_DATABASE_NAME}
          POSTGRES_INITDB_ARGS: '--data-checksums'
          DB_STORAGE_TYPE: 'HDD'
        volumes:
          - ''${DB_DATA_LOCATION}:/var/lib/postgresql/data
        networks:
          - media-network
        restart: unless-stopped

      sonarr:
        image: lscr.io/linuxserver/sonarr:latest
        container_name: sonarr
        environment:
          - PUID=903
          - PGID=2005
          - TZ=America/Toronto
        volumes:
          - /mnt/storage/sonarr:/config
          - /mnt/storage/media:/media
        ports:
          - 8989:8989
        networks:
          - media-network
        restart: unless-stopped

      radarr:
        image: lscr.io/linuxserver/radarr:latest
        container_name: radarr
        environment:
          - PUID=904
          - PGID=2005
          - TZ=America/Toronto
        volumes:
          - /mnt/storage/radarr:/config
          - /mnt/storage/media:/media
        ports:
          - 7878:7878
        networks:
          - media-network
        restart: unless-stopped

      deluge:
        image: lscr.io/linuxserver/deluge:latest
        container_name: deluge
        environment:
          - PUID=905
          - PGID=2005
          - TZ=America/Toronto
          - DELUGE_LOGLEVEL=error
        volumes:
          - /mnt/storage/deluge:/config
          - /mnt/storage/media/torrents:/media/torrents
        ports:
          - 8112:8112
          - 6881:6881
          - 6881:6881/udp
          - 58846:58846
        networks:
          - media-network
        restart: unless-stopped

      jackett:
        image: lscr.io/linuxserver/jackett:latest
        container_name: jackett
        environment:
          - PUID=1000
          - PGID=1000
          - TZ=America/Toronto
          - AUTO_UPDATE=true
        volumes:
          - /mnt/storage/jackett:/config
          - /mnt/storage/media/torrents:/downloads
        ports:
          - 9117:9117
        networks:
          - media-network
        restart: unless-stopped

    volumes:
      model-cache:
  '';

  # Systemd service to manage docker-compose (depends on certificates)
  systemd.services.media-server = {
    description = "Media Server Docker Compose";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose restart";
      TimeoutStartSec = 300;
    };

    environment = {
      COMPOSE_PROJECT_NAME = "media-server";
    };
  };

  # Install required packages
  environment.systemPackages = with pkgs; [
    borgbackup
    parted
    docker
    docker-compose
    openssl
    htop
    curl
    wget
    nvidia-docker
    neovim
    libva-utils
    git
  ];

  # Enable and start Docker service
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
    enableOnBoot = true;
  };

  nix.settings.download-buffer-size = 1024 * 1024 * 1024; # 1GB buffer size
}
