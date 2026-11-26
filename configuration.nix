# 100% Reproducible Unified NixOS Configuration
# Everything in ONE single configuration file for any computer.

{ config, options, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
  ];

  # Bootloader EFI settings
  boot.loader.systemd-boot.enable = true;
  # Keep the EFI partition from filling up: every generation can bring its own
  # kernel and initrd (the latest kernel is updated often)
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest Linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "htl-storage-dispatcher" ''
        #!/bin/sh
        if [ "$2" = "down" ] || [ "$2" = "vpn-down" ]; then
          if ${pkgs.util-linux}/bin/mountpoint -q /mnt/school/MEDT; then
            ${pkgs.util-linux}/bin/umount -l /mnt/school/MEDT || true
          fi
        fi
      '';
      type = "basic";
    }
  ];

  # HTL SSD Storage (MEDT) via systemd automount + short timeout
  fileSystems."/mnt/school/MEDT" = {
    device = "//htl-ssd-storage01.htl-vil.local/MEDT";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "soft"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "uid=1000"
      "gid=100"
      "vers=3.0"
      "credentials=/etc/nixos/smb-secrets"
    ];
  };

  # Btrfs with transparent zstd compression. The installer creates /, /home and
  # /nix as Btrfs (sub)volumes; nixos-generate-config does not record mount
  # options, so they are set here and merged with hardware-configuration.nix.
  fileSystems."/".options = [ "compress=zstd" ];
  fileSystems."/home".options = [ "compress=zstd" ];
  fileSystems."/nix".options = [ "compress=zstd" "noatime" ];

  # ZRAM swap for memory efficiency and stability (used first, higher priority)
  zramSwap.enable = true;

  # Hibernation: scripts/install.sh creates a swap partition sized from the
  # machine's RAM, and nixos-generate-config lists it in hardware-configuration.nix.
  # Resume from that partition (zram is never part of swapDevices).
  boot.resumeDevice = lib.mkIf (config.swapDevices != [ ]) (lib.head config.swapDevices).device;

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
    khelpcenter
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

  # Native Wayland for Chromium-based browsers (Helium) and Electron apps
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # User account
  users.users."bigl" = {
    isNormalUser = true;
    description = "bigl";
    extraGroups = [ "networkmanager" "wheel" "unifi-endpoint" ];
    # Public keys allowed to log in via SSH (one "ssh-ed25519 AAAA... comment" per entry)
    openssh.authorizedKeys.keys = [ ];
  };

  # Dynamic linker for precompiled binaries (e.g. npm packages shipping native binaries)
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

  # Helium browser (flake input "helium"): Chromium-based, ships uBlock Origin built in
  programs.helium = {
    enable = true;

    # Upstream adds the flag below as a shell expression, but the generated
    # binary wrapper does not expand it: Helium received the literal text as an
    # extra command-line argument (headless mode fails with "Multiple targets").
    # Drop it and pass the intended flag directly instead. The assert makes the
    # evaluation fail once upstream changes this, so the workaround can go.
    package =
      let
        upstream = options.programs.helium.package.default;
        brokenFlag = ''--add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"'';
      in
      assert lib.assertMsg (lib.hasInfix brokenFlag upstream.preFixup)
        "Helium wrapper changed upstream: remove the preFixup workaround in configuration.nix";
      upstream.overrideAttrs (old: {
        preFixup = lib.replaceStrings [ brokenFlag ] [ "" ] old.preFixup;
      });
    flags = [ "--ozone-platform-hint=auto" ];

    # Chromium enterprise policies: https://chromeenterprise.google/policies/
    policies = {
      # Search: DuckDuckGo as the default search engine
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "DuckDuckGo";
      DefaultSearchProviderKeyword = "duckduckgo.com";
      DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
      DefaultSearchProviderIconURL = "https://duckduckgo.com/favicon.ico";

      # Startup: reopen the tabs of the last session
      RestoreOnStartup = 1;

      # Bookmarks: managed folder on an always visible bookmark bar
      BookmarkBarEnabled = true;
      ManagedBookmarks = [
        { toplevel_name = "Bookmarks"; }
        { name = "EVW"; url = "https://www.evw.at/"; }
      ];

      # Downloads: always ask where to save a file
      PromptForDownloadLocation = true;

      # The default browser is managed by this configuration (plasma.nix)
      DefaultBrowserSettingEnabled = false;

      # Do not store payment cards in the browser
      AutofillCreditCardEnabled = false;

      # Passwords live in a self-hosted Vaultwarden: install the Bitwarden
      # extension automatically (set the server URL once in the extension)
      # and turn off the built-in password manager.
      # Helium omits the browser version in update requests, so Google's update
      # server answers "noupdate"; Helium's own extension service (the URL Helium
      # rewrites store extensions to) serves the download instead.
      # uBlock Origin is already bundled with Helium.
      ExtensionInstallForcelist = [
        "nngceckbapebfimnlniiiahkandclblb;https://services.helium.imput.net/ext/"
      ];
      PasswordManagerEnabled = false;

      # Only HTTPS: plain HTTP pages show a warning page first
      HttpsOnlyMode = "force_enabled";
    };
  };

  # Blip file transfer (flake input "blip"); starts in the background at login
  programs.blip.enable = true;

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

  # Some prebuilt tools expect readlink and which in /usr/bin
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/readlink - - - - ${pkgs.coreutils}/bin/readlink"
    "L+ /usr/bin/which - - - - ${pkgs.which}/bin/which"
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
    rclone
    openssl
    kdePackages.kdialog
    cifs-utils
    # Browser (Helium comes from programs.helium) & communication
    ladybird
    teams-for-linux
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
    claude-code
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
    rebuild = "/run/wrappers/bin/sudo nixos-rebuild switch --flake /home/bigl/dotfiles#nixos";
    update-flake = "cd /home/bigl/dotfiles && nix flake update";
  };

  # SSH server: key-based logins only (keys in users.users.bigl.openssh.authorizedKeys)
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  system.stateVersion = "26.11";
}
