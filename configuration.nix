{ config, pkgs, ... }:
{
  imports = [
    ./modules/hardware.nix
    ./modules/paths.nix
    ./modules/stacks.nix
    ./modules/media.nix
    ./modules/immich.nix
    ./modules/backup.nix
    ./modules/migration.nix
  ];

  system.stateVersion = "26.05";

  networking.hostName = "cia";

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
    bantime = "1h"; # Ban IPs for one hour on the first ban
    bantime-increment = {
      enable = true;
      multipliers = "1 2 5 7 14 31 60";
      maxtime = "168h";
      overalljails = true; # Calculate the bantime based on all the violations
    };
  };

  networking.firewall = {
    enable = true;

    allowedUDPPorts = [
      6881 # qBittorrent
    ];

    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      2377  # Swarm
      6881  # qBittorrent peers
    ];
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

      arcane = {
        gid = 2011;
      };
    };

    users = {
      hyftar = {
        isNormalUser = true;
        description = "Simon Landry";
        extraGroups = [ "wheel" "docker" "networkmanager" "media" "mealie" "immich" ];
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
        extraGroups = [ "media" ];
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

      arcane = {
        description = "Arcane user";
        isSystemUser = true;
        isNormalUser = false;
        createHome = false;
        group = "arcane";
        uid = 908;
      };

    };
  };

  systemd.tmpfiles.rules = [
    "d ${config.cia.paths.config}/arcane 0770 arcane arcane -"

    "d ${config.cia.paths.config}/caddy 0770 caddy caddy -"
    "Z ${config.cia.paths.config}/caddy 0770 caddy caddy -"

    "Z /mnt/bark_backup 0770 bark bark -"

    "d /var/lib/docker-compose 0750 root root -"
  ];

  sops.secrets."arcane/encryption_key".sopsFile = ./secrets/arcane.yaml;

  sops.templates."arcane.env".content = ''
    ENCRYPTION_KEY=${config.sops.placeholder."arcane/encryption_key"}
  '';

  cia.stacks.core = {
    source = ./stacks/core;
    after = [ "docker-swarm-init.service" ];
    env = {
      TZ = config.time.timeZone;
      ARCANE_UID = config.users.users.arcane.uid;
      ARCANE_GID = config.users.groups.arcane.gid;
      STACKS_DIR = config.cia.stacksDirectory;
      CONFIG_DIR = config.cia.paths.config;
    };
    secrets."secrets.env" = config.sops.templates."arcane.env".path;
    secretsOwner = "arcane";
  };

  systemd.services.docker-swarm-init = {
      description = "Initialize single-node Docker Swarm";
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        if ! ${pkgs.docker}/bin/docker info --format '{{.Swarm.LocalNodeState}}' | grep -q active; then
          # Advertise the LAN address (source of the default route), whatever DHCP gave us.
          addr=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 \
            | ${pkgs.gnused}/bin/sed -n 's/.* src \([0-9.]*\).*/\1/p')
          ${pkgs.docker}/bin/docker swarm init --advertise-addr "$addr"
        fi

        ${pkgs.docker}/bin/docker network inspect cia-overlay >/dev/null 2>&1 \
          || ${pkgs.docker}/bin/docker network create \
               --driver overlay --attachable cia-overlay
      '';
    };

  environment.systemPackages = with pkgs; [
    borgbackup
    parted
    docker
    docker-compose
    openssl
    htop
    curl
    wget
    neovim
    libva-utils
    intel-gpu-tools
    git
  ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  nix.settings.download-buffer-size = 1024 * 1024 * 1024; # 1GB buffer size
}
