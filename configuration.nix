{ config, pkgs, ... }:
{
  imports = [
    ./media.nix
    ./immich.nix
    ./mealie.nix
  ];

  system.stateVersion = "25.05";

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/disk/by-id/ata-WDC_WD1002FAEX-00Z3A0_WD-WCATR9408292" ];
  };

  time.timeZone = "America/Toronto";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      StrictModes = false;
    };
  };

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "192.168.0.0/16"
    ];
    bantime = "24h"; # Ban IPs for one day on the first ban
    bantime-increment = {
      enable = true;
      multipliers = "1 2 5 7 14 31 60";
      maxtime = "168h";
      overalljails = true; # Calculate the bantime based on all the violations
    };
  };

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 6881 ];
    allowedTCPPorts = [ 22 80 443 6881 58846 ]; # SSH, HTTP, HTTPS, Deluge
  };

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

      caddy = {
        gid = 2009;
      };
    };

    users = {
      hyftar = {
        isNormalUser = true;
        description = "Simon Landry";
        extraGroups = [ "wheel" "docker" "networkmanager" "media" "mealie" "immich" ];
        home = "/mnt/storage/hyftar";
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJVOVgvmbYJpZ+iU/ctEtdQdJPez9hZV0ucOxI0ZkjUJL98A/zLN6s/CvcszgHZfNyWU8ptd4jn2Ynw4PHNm4PQk+5iGdyX2iYCiV3kecFrfqQLVcz0qoBITqGEu2OGmOeIyvf0Xu/A159e+6lHKg1Bco6PBH1AiHr1VAepWUcyzAEk2lIdmhbyHjuBrtbXDEzbvbDwoXW7VCdWms235wzWSo/wcz8y0I5jPMYIbV8FDLT1TbjvocVZZMCnq3b9qlPk0h0WM6RbxOMF6R+je76tMGEFpiqBWkNXURewR6Y2UwEdXa3XUkQods6TKmIXgf9gd61BgjMA3C7oPLSlVKG2DMXTADFOK4z5u+KYB6/dUiaaFkwHaLsO0ck9vtWmay6G0Wyt7Iw9isY5T+yJ9fD1meqfNkQVvPE4opNg7/M5fCl6gAYxXfNOhRUBUsWjJnBwHkCKsjbomAWKh1XechCr84YjtV/HIcOVklmWUA5jtV5WxgT5ap5TlPr2kaGySQ2mzhLpig20dUPpujlEexfWIHrnrvaJ2gRzZPXIHtH32kx7/IJfd0trurWIoDzWKU3uFUuXCu1CLDBfEed+dtFZWk/Zx3wUgqzxG6KZXO1VlZEoqVBWU10DXnmQntLzDT7tGPnauPApAOe9EjZTnLDTjN3Jxg4XPpOcJZRr5pnPQ== simon.landry@rumandcode.io"
        ];
      };

      bark = {
        isNormalUser = true;
        createHome = true;
        description = "Bark Barré";
        home = "/mnt/bark_backup/bark";
        group = "bark";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5HeefY97S3ZZS5qpZXHjSZgyuqFj+vgq8nMInzPds1"
        ];
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

  systemd.tmpfiles.rules = [
    "d /mnt/storage/tugtainer 0770 hyftar media -"
    "Z /mnt/storage/tugtainer 0770 hyftar media -"

    "d /mnt/storage/caddy 0770 caddy caddy -"
    "Z /mnt/storage/caddy 0770 caddy caddy -"

    "Z /mnt/bark_backup 0770 bark bark -"

    "d /var/lib/docker-compose 0750 root root -"
  ];

  environment.etc."caddy/Caddyfile".text = ''
    {
      email simonlandry762@gmail.com
      servers {
        trusted_proxies static private_ranges
      }
    }

    (secure_headers) {
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
      }
    }

    docker.grosluxe.ca {
      import secure_headers
      reverse_proxy tugtainer:80
    }

    emby.grosluxe.ca {
      import secure_headers
      reverse_proxy emby:8096
    }

    photos.grosluxe.ca {
      import secure_headers
      reverse_proxy immich_server:2283
    }

    requests.grosluxe.ca {
      import secure_headers
      reverse_proxy seerr:5055
    }

    sonarr.grosluxe.ca {
      import secure_headers
      reverse_proxy sonarr:8989
    }

    radarr.grosluxe.ca {
      import secure_headers
      reverse_proxy radarr:7878
    }

    recettes.grosluxe.ca {
      import secure_headers
      reverse_proxy mealie:9000
    }
  '';

  environment.etc."docker-compose/docker-compose.yml".text = ''
    name: cia-server

    networks:
      cia-network:
        driver: bridge

    services:
      caddy:
        image: caddy:latest
        container_name: caddy
        restart: unless-stopped
        ports:
          - 80:80
          - 443:443
        volumes:
          - /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
          - /mnt/storage/caddy/data:/data
          - /mnt/storage/caddy/config:/config
        networks:
          - cia-network

      tugtainer:
        image: quenary/tugtainer:latest
        container_name: tugtainer
        restart: unless-stopped
        ports:
          - 5678:80
        group_add:
          - ${toString config.users.groups.docker.gid}
        volumes:
          - /mnt/storage/tugtainer:/tugtainer
          - /var/run/docker.sock:/var/run/docker.sock:ro
        networks:
          - cia-network
  '';

  # Systemd service to manage caddy and the media-network docker network
  systemd.services.cia-server = {
    description = "CIA Server Docker Compose";
    after = [ "docker.service" "docker.socket" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "docker.socket" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.yml up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.yml down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.yml restart";
      TimeoutStartSec = 300;
      Restart = "on-abnormal";
      RestartSec = 25;
    };
  };

  systemd.services."config-backup" = {
    description = "Backup app configs and databases";
    path = [ pkgs.bash pkgs.borgbackup ];
    serviceConfig = {
      User = "hyftar";
      ExecStart = "${pkgs.bash}/bin/bash -c '/mnt/storage/hyftar/Scripts/backup.sh apps'";
    };
  };

  systemd.timers."config-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
      AccuracySec = "1h";
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

  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
    enableOnBoot = true;
  };

  nixpkgs.config.packageOverrides = pkgs: {
      nvidia-container-toolkit = pkgs.nvidia-container-toolkit.overrideAttrs (oldAttrs: {
        version = "1.17.6";
        src = pkgs.fetchFromGitHub {
          owner = "NVIDIA";
          repo = "nvidia-container-toolkit";
          rev = "v1.17.6";
          sha256 = "sha256-MQQTQ6AaoA4VIAT7YPo3z6UbZuKHjOvu9sW2975TveM=";
        };
      });
    };

  nix.settings.download-buffer-size = 1024 * 1024 * 1024; # 1GB buffer size
}
