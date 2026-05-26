{ pkgs, ... }:
{
  users.groups = {
    mealie = { gid = 2010; };
  };

  users.users = {
    mealie = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "mealie user";
      group = "mealie";
      uid = 907;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/storage/mealie 0770 mealie mealie -"
  ];

  environment.etc."docker-compose/docker-compose.mealie.yml".text = ''
    name: mealie-service
    services:
      mealie:
        image: ghcr.io/mealie-recipes/mealie:v3.11.0
        container_name: mealie
        restart: unless-stopped
        ports:
          - 9925:9000
        deploy:
          resources:
            limits:
              memory: 512M
        volumes:
          - /mnt/storage/mealie:/app/data/
        environment:
          ALLOW_SIGNUP: "false"
          PUID: 907
          PGID: 2010
          TZ: America/Toronto
          BASE_URL: https://recettes.grosluxe.ca
          DAILY_SCHEDULE_TIME: 23:30
          TOKEN_TIME: 4800
        networks:
          - cia-network

    networks:
      cia-network:
        external: true
        name: cia-server_cia-network
  '';

  systemd.services.mealie = {
    description = "Mealie Docker Compose";
    after = [ "docker.service" "network-online.target" "cia-server.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "cia-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.mealie.yml up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.mealie.yml down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.mealie.yml restart";
      TimeoutStartSec = 300;
    };
  };
}
