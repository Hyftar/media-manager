{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true; # NVIDIA drivers have an unfree license

  # Enable Docker
  virtualisation.docker.enable = true;


  # NVIDIA GTX 570 Graphics Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable32Bit = true;
  hardware.opengl.enable = true;

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

  # Add NVIDIA runtime for Docker containers (for hardware acceleration)
  virtualisation.docker.enableNvidia = true;

  # Root file system
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  # Media HDD
  fileSystems."/mnt/storage" = {
    device = "/dev/sdb1";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
