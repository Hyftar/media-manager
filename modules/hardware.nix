{ config, lib, pkgs, ... }:
let
  # The data drives haven't moved to the new machine yet. Until they do, their
  # mount points are plain directories on the main drive; anything written there
  # is hidden once the drives are mounted over it. Flip to true after moving
  # them (and check the labels/UUIDs still match).

  paths = config.cia.paths;
  dataDrivesInstalled = false;
in
{
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  fileSystems = lib.mkIf dataDrivesInstalled {
    # Photos HDD (Immich uploads, pictures, videos); formerly /mnt/storage
    ${paths.photos} = {
      device = "/dev/disk/by-uuid/df617e43-0dd9-4c39-9143-830fbb1d0547";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };

    # Bark Backup HDD (BorgBackup repository)
    "/mnt/bark_backup" = {
      device = "/dev/disk/by-partlabel/bark_backup";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };

    # Media HDD (movies, series, animes, books)
    ${paths.media} = {
      device = "/dev/disk/by-partlabel/media";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };
  };
}
