# 100% Reproducible Unified NixOS Configuration
# Everything in ONE single configuration file for any computer.

{ config, pkgs, lib, ... }:

let
  # Antigravity IDE (Official Google Deepmind build, 100% reproducible)
  antigravity = pkgs.stdenv.mkDerivation rec {
    pname = "antigravity";
    version = "2.32.0";
    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.0-6141816156848128/linux-x64/Antigravity.tar.gz";
      hash = "sha256-2YoTcfK9TKfdLn7ujzLqBwVDoeDkXGl2H3ANZ0VPQnU=";
    };
    sourceRoot = ".";
    dontBuild = true;
    dontConfigure = true;
    dontStrip = true;
    dontPatchELF = true;
    nativeBuildInputs = [ pkgs.python3 ];

    installPhase = ''
      mkdir -p $out/opt/antigravity $out/bin $out/share/applications $out/share/icons/hicolor/512x512/apps
      cp -r Antigravity-x64/* $out/opt/antigravity/

      # Patch Antigravity app.asar to enable setTitleBarOverlay on Linux (removes hardcoded Windows-only check)
      python3 -c "
p = '$out/opt/antigravity/resources/app.asar'
data = open(p, 'rb').read()
old = b\"win && process.platform === 'win32'\"
new = b\"win && process.platform != 'darwin'\"
assert old in data, 'target pattern not found in app.asar'
open(p, 'wb').write(data.replace(old, new, 1))
"

      cat << 'WRAPPER' > $out/bin/antigravity
#!/bin/sh
if [ -z "$DISPLAY" ] && [ -n "$WAYLAND_DISPLAY" ]; then
  exec "$out/opt/antigravity/antigravity" --ozone-platform=wayland "$@"
else
  exec "$out/opt/antigravity/antigravity" --ozone-platform-hint=auto "$@"
fi
WRAPPER
      substituteInPlace $out/bin/antigravity --replace-fail '$out' "$out"
      chmod +x $out/bin/antigravity

      cp ${./dotfiles/icons/antigravity.png} $out/share/icons/hicolor/512x512/apps/antigravity.png
      cp ${./dotfiles/icons/antigravity.png} $out/opt/antigravity/antigravity.png
      cp ${./dotfiles/applications/antigravity.desktop} $out/share/applications/antigravity.desktop
    '';
  };

  # uBlock Origin extension for Chromium (100% declarative & installed from start)
  ublock-version = "1.76.2";
  ublock-crx = pkgs.fetchurl {
    url = "https://github.com/gorhill/uBlock/releases/download/${ublock-version}/uBlock0_${ublock-version}.chromium.crx";
    hash = "sha256-pcE3pXCSDHO5pdD01HeJQK/UWl1JUxDIiQNeaV0WWtk=";
  };
  ublock-manifest = pkgs.writeText "fkgkibajhfbepljeaefdnfnegdcjomkh.json" (builtins.toJSON {
    external_crx = "${ublock-crx}";
    external_version = ublock-version;
  });
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader EFI settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest Linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # ZRAM swap for memory efficiency and stability
  zramSwap.enable = true;

  # Time & Locales
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  # Display Server & Desktop Environment (Plasma 6)
  services.xserver.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Exclude default bloated KDE applications
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    gwenview
    kate
    print-manager
  ];

  # Deinstall KDE PIM
  programs.kde-pim.enable = false;

  # Austrian Keyboard Layout
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  # NextKDE / KOS Desktop Shell
  services.kos.enable = true;
  services.kos.weather.enable = false;

  # Ensure CPU/RAM status cell is available even on systems/VMs without ACPI thermal sensors
  systemd.user.services.kos-shell-init = {
    postStart = ''
      if [ -f "$HOME/.config/quickshell/kos/desktop/modules/bar/CpuTemperature.qml" ]; then
        ${pkgs.gnused}/bin/sed -z -i 's/MetricsService.currentMilliC >= 0\s*&& MetricsService.maximum5MinuteMilliC >= 0/(MetricsService.currentMilliC >= 0 \&\& MetricsService.maximum5MinuteMilliC >= 0) || MetricsService.ready/g' "$HOME/.config/quickshell/kos/desktop/modules/bar/CpuTemperature.qml"
      fi
    '';
  };

  # Sound with PipeWire
  services.printing.enable = false;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth (off on boot, toggleable via Control Center)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  # Universal Graphics & Hardware Acceleration (Mesa for Intel, AMD, VirtIO, QEMU)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Tolerant Video Drivers: Loads NVIDIA when hardware present, falls back to modesetting
  services.xserver.videoDrivers = [ "nvidia" "modesetting" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Wayland Native support for Chromium and Electron apps
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # User account
  users.users."bigl" = {
    isNormalUser = true;
    description = "bigl";
    initialPassword = "password";
    extraGroups = [ "networkmanager" "wheel" "unifi-endpoint" ];
  };

  # Dynamic Linker for precompiled binaries (Antigravity IDE, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    glib
    gtk3
    nss
    nspr
    dbus
    atk
    at-spi2-atk
    cups
    expat
    libdrm
    libxkbcommon
    mesa
    libgbm
    alsa-lib
    pango
    cairo
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxtst
    libxcb
  ];

  # Deinstall unnecessary browsers & Steam
  programs.firefox.enable = false;
  programs.google-chrome.enable = false;
  programs.steam.enable = false;

  # UniFi Identity Endpoint (version 1.1.7)
  programs.unifi-endpoint = {
    enable = true;
    package = pkgs.unifi-endpoint.overrideAttrs (old: rec {
      version = "1.1.7-28";
      src = pkgs.fetchurl {
        url = "https://fw-download.ubnt.com/data/unifi-endpoint-desktop-app-deb/55c2-linux-1.1.7-28-54b0e439-ddb5-41be-9e6f-56739775cdd9.deb";
        hash = "sha256-mWzVcMMNw+yVID7vC8he92g7mZrePlXK3D3b7XWuWa0=";
      };
    });
  };

  # Browser symlinks & declarative system-wide extension seeding
  systemd.tmpfiles.rules = [
    "L+ /opt/google/chrome/chrome - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/google-chrome - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/google-chrome-stable - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/chromium - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/chromium-browser - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/ungoogled-chromium - - - - ${pkgs.ungoogled-chromium}/bin/chromium"
    "L+ /usr/bin/readlink - - - - ${pkgs.coreutils}/bin/readlink"
    "L+ /usr/bin/which - - - - ${pkgs.which}/bin/which"
    # System-wide Chromium extension fallback
    "d /usr/share/chromium 0755 root root -"
    "d /usr/share/chromium/extensions 0755 root root -"
    "C /usr/share/chromium/extensions/fkgkibajhfbepljeaefdnfnegdcjomkh.json 0644 root root - ${ublock-manifest}"
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Ensure Chromium runs natively on Wayland with crisp scaling
  nixpkgs.config.chromium = {
    commandLineArgs = "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations";
  };

  # Overlays (KWalletManager removal, wireguard-tools PATH fix)
  nixpkgs.overlays = [
    (final: prev: {
      kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
        kwalletmanager = prev.emptyDirectory;
      });
      wireguard-tools = prev.wireguard-tools.overrideAttrs (old: {
        postFixup = ''
          substituteInPlace $out/lib/systemd/system/wg-quick@.service \
            --replace-warn /usr/bin $out/bin
          for f in $out/bin/*; do
            wrapProgram $f \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.coreutils prev.procps prev.iproute2 ]} \
              --suffix PATH : ${prev.lib.makeBinPath [ prev.iptables prev.openresolv ]}
          done
        '';
      });
    })
  ];

  # Nix settings, automatic GC and store deduplication
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Podman virtualization
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
  };

  # System Packages (all tools consolidated declaratively)
  environment.localBinInPath = true;
  environment.systemPackages = with pkgs; [
    antigravity
    ungoogled-chromium
    bluez
    bluez-tools
    git
    gh
    # Desktop & Clipboard utilities
    wl-clipboard
    cliphist
    resvg
    # Development tools
    python3
    nodejs
    pnpm
    postgresql
    podman-compose
  ];

  # Fonts (Apple SF-Pro font collection)
  fonts.packages = [
    (pkgs.runCommand "sf-pro-fonts" {} ''
      mkdir -p $out/share/fonts/opentype
      cp -r ${./fonts/SF-Pro}/* $out/share/fonts/opentype/
    '')
  ];

  # Shell aliases
  programs.bash.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake /home/bigl/dotfiles#nixos";
    update-flake = "cd /home/bigl/dotfiles && nix flake update";
  };

  # OpenSSH daemon
  services.openssh.enable = true;

  # Automatically update and install uBlock Origin for ungoogled-chromium
  systemd.user.services.update-ublock = {
    description = "Automatically update uBlock Origin for ungoogled-chromium";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "update-ublock" ''
        ${pkgs.python3}/bin/python3 - << 'PYEOF'
import json, os, sys, tempfile, urllib.request, xml.etree.ElementTree as ET

UPDATE_XML_URL = "https://raw.githubusercontent.com/gorhill/uBlock/master/dist/chromium/update.xml"
EXT_DIR = os.path.expanduser("~/.local/share/ungoogled-chromium/extensions")
EXT_JSON_DIR = os.path.expanduser("~/.config/chromium/External Extensions")
CRX_FILE = os.path.join(EXT_DIR, "ublock.crx")
JSON_FILE = os.path.join(EXT_JSON_DIR, "fkgkibajhfbepljeaefdnfnegdcjomkh.json")

def get_latest_version_info():
    req = urllib.request.Request(UPDATE_XML_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        xml_data = resp.read()
    tree = ET.fromstring(xml_data)
    for app in tree.iter("{http://www.google.com/update2/response}app"):
        if app.attrib.get("appid") == "fkgkibajhfbepljeaefdnfnegdcjomkh":
            for uc in app.iter("{http://www.google.com/update2/response}updatecheck"):
                return uc.attrib.get("version"), uc.attrib.get("codebase")
    raise RuntimeError("uBlock appid not found in update.xml")

def main():
    os.makedirs(EXT_DIR, exist_ok=True)
    os.makedirs(EXT_JSON_DIR, exist_ok=True)
    try:
        latest_ver, download_url = get_latest_version_info()
    except Exception as e:
        print(f"Error checking update: {e}", file=sys.stderr)
        return 0

    current_ver = None
    if os.path.exists(JSON_FILE) and os.path.exists(CRX_FILE):
        try:
            with open(JSON_FILE, "r") as f:
                current_ver = json.load(f).get("external_version")
        except Exception:
            pass

    if current_ver == latest_ver and os.path.exists(CRX_FILE):
        return 0

    print(f"Updating uBlock Origin to {latest_ver}...")
    try:
        req = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=30) as resp, tempfile.NamedTemporaryFile(dir=EXT_DIR, delete=False) as tmp:
            tmp.write(resp.read())
            tmp_path = tmp.name
        os.replace(tmp_path, CRX_FILE)
        with open(JSON_FILE, "w") as f:
            json.dump({"external_crx": CRX_FILE, "external_version": latest_ver}, f, indent=2)
        print("Updated successfully.")
    except Exception as e:
        print(f"Failed to update uBlock: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
PYEOF
      ''}";
    };
  };

  systemd.user.timers.update-ublock = {
    description = "Check for uBlock Origin updates daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "30s";
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  system.stateVersion = "26.11";
}
