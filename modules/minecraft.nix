{ config, ... }:
let
  paths = config.cia.paths;
in
{
  users.groups = {
    minecraft = { gid = 2012; };
  };

  users.users = {
    minecraft = {
      isSystemUser = true;
      isNormalUser = false;
      createHome = false;
      description = "Minecraft Bedrock server user";
      group = "minecraft";
      uid = 911;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${paths.config}/minecraft 0770 minecraft minecraft -"
  ];

  networking.firewall = {
    allowedTCPPorts = [ 19132 ];
    allowedUDPPortRanges = [
      { from = 19140; to = 19155; }
    ];
  };

  cia.stacks.minecraft = {
    source = ../stacks/minecraft;
    env = {
      CONFIG_DIR = paths.config;
      TZ = config.time.timeZone;
      MINECRAFT_UID = config.users.users.minecraft.uid;
      MINECRAFT_GID = config.users.groups.minecraft.gid;
    };
  };
}
