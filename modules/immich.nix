{ config, ... }:
let
  paths = config.cia.paths;
in
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
    # Database and model cache on the main drive
    "d ${paths.config}/immich 0770 immich immich -"
    "d ${paths.config}/immich/postgres 0770 immich immich -"
    "d ${paths.config}/immich/model-cache 0770 immich immich -"

    # Photos on the photos drive
    "d ${paths.photos}/immich 0770 immich immich -"
    "d ${paths.photos}/immich/upload 0770 immich immich -"
    "d ${paths.photos}/videos 0770 immich immich -"
  ];

  cia.stacks.immich = {
    source = ../stacks/immich;
    dependsOn = [ "core" ];
    env = {
      UPLOAD_LOCATION = "${paths.photos}/immich/upload";
      PICTURES_LOCATION = "${paths.photos}/pictures";
      DB_DATA_LOCATION = "${paths.config}/immich/postgres";
      MODEL_CACHE_LOCATION = "${paths.config}/immich/model-cache";
      TZ = config.time.timeZone;
      IMMICH_GID = config.users.groups.immich.gid;

      DB_PASSWORD = "postgres";
      DB_USERNAME = "postgres";
      DB_DATABASE_NAME = "immich";
    };
  };

}
