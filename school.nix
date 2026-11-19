# HTL Villach - MEDT School NAS Automount Module
{ config, pkgs, ... }:

{
  # CIFS mounting utilities
  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  # Fester Automount unter /mnt/school/MEDT
  fileSystems."/mnt/school/MEDT" = {
    device = "//htl-ssd-storage01.htl-vil.local/MEDT";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "credentials=/etc/nixos/smb-secrets"
      "uid=1000"
      "gid=100"
      "dir_mode=0700"
      "file_mode=0700"
      "domain=HTL"
      "_netdev"
    ];
  };
}
