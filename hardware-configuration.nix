{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true; # NVIDIA drivers have an unfree license
  nixpkgs.config.nvidia.acceptLicense = true;

  # NVIDIA GTX 750 Graphics Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.nvidia-container-toolkit.enable = true;

  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
  ];

  # Configure NVIDIA driver for GTX 750 Ti
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production;

    nvidiaSettings = false;

    # Enable power management
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = false;

    modesetting.enable = true;
  };

  # Root file system
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    # Media HDD
    "/mnt/storage" = {
      device = "/dev/disk/by-uuid/df617e43-0dd9-4c39-9143-830fbb1d0547";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };

    "/mnt/bark_backup" = {
      device = "/dev/disk/by-label/bark_backup";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    };
  };
}
