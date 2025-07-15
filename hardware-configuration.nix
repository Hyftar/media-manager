{ config, pkgs, ... }:
{
  # Enable Docker
  virtualisation.docker.enable = true;


  # NVIDIA GTX 570 Graphics Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

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


  # Media HDD
  # Commented out for now -- testing
  # fileSystems."/mnt/storage" = {
  #   device = "/dev/sdb1";
  #   fsType = "ext4";
  #   options = [ "defaults" "nofail" "user" "exec" ];
  # };
}
