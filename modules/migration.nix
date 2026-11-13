# One-time move of config and books off the old storage drive (see
# scripts/migrate-drives.sh). Remove this module once the migration is done.
{ config, pkgs, ... }:
let
  paths = config.cia.paths;

  migrate = pkgs.writeShellApplication {
    name = "cia-migrate-drives";
    runtimeInputs = with pkgs; [ coreutils rsync util-linux systemd ];
    runtimeEnv = {
      CONFIG_DIR = paths.config;
      PHOTOS_DIR = paths.photos;
      MEDIA_DIR = paths.media;
    };
    text = builtins.readFile ../scripts/migrate-drives.sh;
  };
in
{
  environment.systemPackages = [ migrate ];
}
