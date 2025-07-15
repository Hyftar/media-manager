{ config, pkgs, ... }:
{
  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/disk/by-id/ata-WDC_WD1002FAEX-00Z3A0_WD-WCATR9408292" ];
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Enable FTP server (vsftpd) with SSL/TLS using Let's Encrypt certificates
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

    # SSL/TLS configuration
    forceLocalDataSSL = true;
    forceLocalLoginsSSL = true;
    rsaCertFile = "/mnt/storage/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ftp.grosluxe.ca/ftp.grosluxe.ca.crt";
    rsaKeyFile = "/mnt/storage/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ftp.grosluxe.ca/ftp.grosluxe.ca.key";
    # FTP configuration
    extraConfig = ''
      ssl_enable=YES
      force_local_data_ssl=YES
      force_local_logins_ssl=YES
      ssl_ciphers=HIGH

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

      # Additional SSL settings
      require_ssl_reuse=NO
      ssl_request_cert=NO
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
  users.users.hyftar = {
    isNormalUser = true;
    description = "Simon Landry";
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    home = "/mnt/storage/hyftar";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJVOVgvmbYJpZ+iU/ctEtdQdJPez9hZV0ucOxI0ZkjUJL98A/zLN6s/CvcszgHZfNyWU8ptd4jn2Ynw4PHNm4PQk+5iGdyX2iYCiV3kecFrfqQLVcz0qoBITqGEu2OGmOeIyvf0Xu/A159e+6lHKg1Bco6PBH1AiHr1VAepWUcyzAEk2lIdmhbyHjuBrtbXDEzbvbDwoXW7VCdWms235wzWSo/wcz8y0I5jPMYIbV8FDLT1TbjvocVZZMCnq3b9qlPk0h0WM6RbxOMF6R+je76tMGEFpiqBWkNXURewR6Y2UwEdXa3XUkQods6TKmIXgf9gd61BgjMA3C7oPLSlVKG2DMXTADFOK4z5u+KYB6/dUiaaFkwHaLsO0ck9vtWmay6G0Wyt7Iw9isY5T+yJ9fD1meqfNkQVvPE4opNg7/M5fCl6gAYxXfNOhRUBUsWjJnBwHkCKsjbomAWKh1XechCr84YjtV/HIcOVklmWUA5jtV5WxgT5ap5TlPr2kaGySQ2mzhLpig20dUPpujlEexfWIHrnrvaJ2gRzZPXIHtH32kx7/IJfd0trurWIoDzWKU3uFUuXCu1CLDBfEed+dtFZWk/Zx3wUgqzxG6KZXO1VlZEoqVBWU10DXnmQntLzDT7tGPnauPApAOe9EjZTnLDTjN3Jxg4XPpOcJZRr5pnPQ== simon.landry@rumandcode.io"
    ];
  };

  # Enable systemd for managing services
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';

  # Create necessary directories and set permissions
  systemd.tmpfiles.rules = [
    "d /mnt/storage/emby 0755 root root -"
    "d /mnt/storage/immich 0755 root root -"
    "d /mnt/storage/caddy 0755 root root -"
    "d /mnt/storage/caddy/data 0755 root root -"
    "d /mnt/storage/caddy/config 0755 root root -"
    "d /var/lib/docker-compose 0755 root root -"
  ];

  # Service to wait for Let's Encrypt certificates and restart vsftpd
  systemd.services.vsftpd-cert-watcher = {
    description = "Wait for Let's Encrypt certificates and restart vsftpd";
    after = [ "caddy.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "30";
    };

    script = ''
      CERT_PATH="/mnt/storage/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ftp.grosluxe.ca/ftp.grosluxe.ca.crt"
      KEY_PATH="/mnt/storage/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ftp.grosluxe.ca/ftp.grosluxe.ca.key"

      while true; do
        if [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ]; then
          echo "Let's Encrypt certificates found, restarting vsftpd..."
          systemctl restart vsftpd.service

          # Monitor for certificate renewals
          while true; do
            sleep 3600  # Check every hour
            if [ "$CERT_PATH" -nt /var/lib/vsftpd.last_restart ] || [ "$KEY_PATH" -nt /var/lib/vsftpd.last_restart ]; then
              echo "Certificate renewed, restarting vsftpd..."
              systemctl restart vsftpd.service
              touch /var/lib/vsftpd.last_restart
            fi
          done
        else
          echo "Waiting for Let's Encrypt certificates..."
          sleep 30
        fi
      done
    '';
  };

  # Create Caddy configuration file
  environment.etc."caddy/Caddyfile".text = ''
    # Global options
    {
      admin localhost:2019
      # Enable automatic HTTPS with Let's Encrypt
      email simonlandry762@gmail.com
      auto_https on
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
      reverse_proxy immich:3001
      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }

    # FTP over HTTPS subdomain
    ftp.grosluxe.ca {
      file_server browse {
        root /mnt/storage
      }

      header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
      }
    }
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
          - immich

      # Emby media server with NVIDIA GPU support
      emby:
        image: emby/embyserver:beta
        container_name: emby
        restart: unless-stopped
        environment:
          - UID=1000
          - GID=1000
          - GIDLIST=1000
          - NVIDIA_VISIBLE_DEVICES=all
          - NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
        volumes:
          - /mnt/storage/emby/config:/config
          - /mnt/storage/emby/media:/media
        ports:
          - "8096:8096"  # Emby web interface
        devices:
          - /dev/dri:/dev/dri  # For hardware acceleration
        runtime: nvidia  # Use NVIDIA runtime for GPU acceleration
        networks:
          - media-network

      # Immich photo management
      immich:
        image: ghcr.io/immich-app/immich-server:release
        container_name: immich
        restart: unless-stopped
        environment:
          - DB_HOSTNAME=immich-db
          - DB_USERNAME=immich
          - DB_PASSWORD=immich_password
          - DB_DATABASE_NAME=immich
          - REDIS_HOSTNAME=immich-redis
        volumes:
          - /mnt/storage/immich/upload:/usr/src/app/upload
        ports:
          - "3001:3001"
        depends_on:
          - immich-db
          - immich-redis
        networks:
          - media-network

      # Immich database
      immich-db:
        image: postgres:15
        container_name: immich-db
        restart: unless-stopped
        environment:
          - POSTGRES_USER=immich
          - POSTGRES_PASSWORD=immich_password
          - POSTGRES_DB=immich
        volumes:
          - /mnt/storage/immich/db:/var/lib/postgresql/data
        networks:
          - media-network

      # Immich Redis
      immich-redis:
        image: redis:7
        container_name: immich-redis
        restart: unless-stopped
        networks:
          - media-network
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
    enableOnBoot = true;
  };
}
