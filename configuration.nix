{ config, pkgs, ... }:
{
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

  services.vsftpd = {
    enable = true;
    writeEnable = true;
    localUsers = true;
    userlist = [ "hyftar" ];
    userlistEnable = true;
    userlistDeny = false;
    anonymousUser = false;
    anonymousUserNoPassword = false;
    chrootlocalUser = false;

    extraConfig = ''
      ssl_enable=NO

      # Passive mode settings
      pasv_enable=YES
      pasv_min_port=50000
      pasv_max_port=50100

      # User settings
      local_umask=022
      dirmessage_enable=YES

      # Logging
      xferlog_enable=YES
      connect_from_port_20=YES

      # Performance
      use_localtime=YES
      allow_writeable_chroot=YES
    '';
  };

  # Add SSH and FTP ports to firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 21 22 80 443 ];
    allowedTCPPortRanges = [
      { from = 50000; to = 50100; }  # FTP passive mode port range
    ];
  };

  # Create hyftar user with SSH and FTP access
  users = {
    groups = {
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

      emby = {
        isSystemUser = true;
        isNormalUser = false;
        createHome = false;
        description = "Emby user";
        group = "emby";
        extraGroups = [ "media" ];
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
    };
  };

  # Enable systemd for managing services
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';

  # Create necessary directories and set permissions
  systemd.tmpfiles.rules = [
    "d /mnt/storage/emby 0755 emby emby -"
    "d /mnt/storage/series 0775 hyftar media -"
    "Z /mnt/storage/series 0775 hyftar media -" # Recursively set permissions
    "d /mnt/storage/movies 0775 hyftar media -"
    "Z /mnt/storage/movies 0775 hyftar media -"
    "d /mnt/storage/animes 0775 hyftar media -"
    "Z /mnt/storage/animes 0775 hyftar media -"
    "d /mnt/storage/immich 0775 immich immich -"
    "d /mnt/storage/immich/upload 0775 immich immich -"
    "d /mnt/storage/immich/data 0775 immich immich -"
    "d /mnt/storage/caddy 0775 caddy caddy -"
    "Z /mnt/storage/caddy 0775 caddy caddy -"
    "d /var/lib/docker-compose 0755 root root -"
  ];

  # Create Caddy configuration file
  environment.etc."caddy/Caddyfile".text = ''
    # Global options
    {
      admin localhost:2019
      # Enable automatic HTTPS with Let's Encrypt
      email simonlandry762@gmail.com
    }

    # Emby subdomain
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

    # Immich subdomain
    photos.grosluxe.ca {
      reverse_proxy immich-server:2283
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
          - /mnt/storage/movies:/media/movies
          - /mnt/storage/series:/media/series
          - /mnt/storage/animes:/media/animes
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
          - /etc/localtime:/etc/localtime:ro
        env_file:
          - /etc/docker-compose/.env
        ports:
          - '2283:2283'
        depends_on:
          - redis
          - database
        restart: unless-stopped
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
        healthcheck:
          disable: false

      redis:
        container_name: immich_redis
        group_add:
          - 2007
        image: docker.io/valkey/valkey:8-bookworm@sha256:fec42f399876eb6faf9e008570597741c87ff7662a54185593e74b09ce83d177
        healthcheck:
          test: redis-cli ping || exit 1
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
        restart: unless-stopped

    volumes:
      model-cache:
  '';

  # Systemd service to manage docker-compose (depends on certificates)
  systemd.services.media-server = {
    description = "Media Server Docker Compose";
    after = [ "docker.service" "network-online.target" "vsftpd-cert-watcher.service" ];
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
    docker
    docker-compose
    openssl
    htop
    curl
    wget
    nvidia-docker
    neovim
    git
  ];

  # Enable and start Docker service
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
    enableOnBoot = true;
  };
}
