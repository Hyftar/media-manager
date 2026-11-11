{ config, ... }:
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

  cia.stacks.immich = {
    source = ../stacks/immich;
    dependsOn = [ "core" ];
    env = {
      UPLOAD_LOCATION = "/mnt/storage/immich/upload";
      DB_DATA_LOCATION = "/mnt/storage/immich/data";
      TZ = config.time.timeZone;
      IMMICH_GID = config.users.groups.immich.gid;

      DB_PASSWORD = "postgres";
      DB_USERNAME = "postgres";
      DB_DATABASE_NAME = "immich";
    };
  };

}
