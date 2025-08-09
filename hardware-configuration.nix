{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production.overrideAttrs (oldAttrs: {
      version = "570.153.02";
    });

    nvidiaSettings = false;

    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = false;

    modesetting.enable = true;
  };

  fileSystems = {
    # Root file system
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    # Storage HDD (photos, videos, documents)
    "/mnt/storage" = {
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

    # Media HDD (movies, series)
    "/mnt/media" = {
      device = "/dev/disk/by-partlabel/media";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };
  };
}
