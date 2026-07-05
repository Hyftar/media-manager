{ pkgs, ... }:
{
  users.groups = {
    immich = { gid = 2007; };
  };

  users.users = {
    immich = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Immich user";
      group = "immich";
      extraGroups = [ "photos" "render" "video" ];
      uid = 901;
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/storage/immich 0770 immich immich -"
    "d /mnt/storage/immich/upload 0770 immich immich -"
    "d /mnt/storage/immich/data 0770 immich immich -"
    "d /mnt/storage/videos 0770 immich immich -"
  ];

  environment.etc."docker-compose/.env".text = ''
    # == Begin Immich config ==
    UPLOAD_LOCATION=/mnt/storage/immich/upload
    DB_DATA_LOCATION=/mnt/storage/immich/data

    TZ=America/Toronto
    IMMICH_VERSION=v3
    DB_PASSWORD=postgres

    # The values below this line do not need to be changed
    DB_USERNAME=postgres
    DB_DATABASE_NAME=immich
    # == End Immich config ==
  '';

  environment.etc."docker-compose/docker-compose.immich.yml".text = ''
    name: immich-service
    services:
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
          - 2283:2283
        depends_on:
          - redis
          - database
        restart: unless-stopped
        devices:
          - /dev/dri:/dev/dri
          - nvidia.com/gpu=all
        networks:
          - cia-network
        healthcheck:
          disable: false

      redis:
        container_name: immich_redis
        group_add:
          - 2007
        image: docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9
        healthcheck:
          test: redis-cli ping || exit 1
        networks:
          - cia-network
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
          - cia-network
        shm_size: 128mb
        restart: unless-stopped

    networks:
      cia-network:
        external: true
        name: cia-server_cia-network
  '';

  systemd.services.immich = {
    description = "Immich Docker Compose";
    after = [ "docker.service" "network-online.target" "cia-server.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "cia-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.immich.yml up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.immich.yml down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f docker-compose.immich.yml restart";
      TimeoutStartSec = 600;
    };
  };

}
