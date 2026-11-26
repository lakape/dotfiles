# File systems and swap, addressed by the labels that scripts/install.sh gives
# the partitions (boot, nixos, swap). Labels stay the same on every machine and
# every reinstall, so this file is the same everywhere; hardware-configuration.nix
# is generated with --no-filesystems and contains no UUIDs.
#
# Btrfs layout: the top-level volume is mounted at /, the subvolumes `home` and
# `nix` at /home and /nix, all with transparent zstd compression.

{ ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Swap partition sized from the RAM by the installer; used for hibernation.
  # zram (configuration.nix) stays the primary swap for normal operation.
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];
  boot.resumeDevice = "/dev/disk/by-label/swap";
}
