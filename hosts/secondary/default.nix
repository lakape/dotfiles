{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "secondary";

  # Standard Linux kernel (or latest)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Open-source Graphics & Hardware Acceleration (Intel / AMD Mesa)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Power efficiency / TLP for weaker hardware / laptop
  # services.power-profiles-daemon.enable = true;
}
