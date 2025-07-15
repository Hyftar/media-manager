{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true; # NVIDIA drivers have an unfree license
  nixpkgs.config.nvidia.acceptLicense = true;

  # NVIDIA GTX 570 Graphics Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  # hardware.nvidia-container-toolkit.enable = true; # newer config, not supported with legacy cards

  # Configure NVIDIA driver for GTX 570 (legacy card)
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_390;

    nvidiaSettings = false;

    # Enable power management
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = false;

    modesetting.enable = true;
  };

  # NVIDIA Docker Configuration (deprecated but only option for legacy cards)
  virtualisation.docker.enableNvidia = true;

  # Root file system
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Media HDD
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/df617e43-0dd9-4c39-9143-830fbb1d0547";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
