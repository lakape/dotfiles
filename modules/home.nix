{ config, pkgs, lib, ... }:

{
  home.username = "bigl";
  home.homeDirectory = "/home/bigl";
  home.stateVersion = "26.11";

  # Ensure XDG directories are managed
  xdg.enable = true;

  # Convenient shell aliases
  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos";
      rebuild-workstation = "sudo nixos-rebuild switch --flake ~/dotfiles#workstation";
      rebuild-secondary = "sudo nixos-rebuild switch --flake ~/dotfiles#secondary";
      update-flake = "cd ~/dotfiles && nix flake update";
    };
  };

  # KOS Window Configurations (managed declaratively)
  xdg.configFile."kos/window-appearance.json".source = ../dotfiles/kos/window-appearance.json;
  xdg.configFile."kos/window-buttons.json".source = ../dotfiles/kos/window-buttons.json;
  xdg.configFile."kos/window-integration.json".source = ../dotfiles/kos/window-integration.json;

  # Desktop & Shortcuts Seeding for 100% Identical Setup
  # Seeds kwinrc, kglobalshortcutsrc, and kdeglobals on fresh installs
  # while keeping them mutable so KDE Plasma GUI can write to them seamlessly
  home.activation.seedKdeDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config"
    if [ ! -f "$HOME/.config/kwinrc" ]; then
      cp ${../dotfiles/kde/kwinrc} "$HOME/.config/kwinrc"
      chmod 600 "$HOME/.config/kwinrc"
    fi
    if [ ! -f "$HOME/.config/kglobalshortcutsrc" ]; then
      cp ${../dotfiles/kde/kglobalshortcutsrc} "$HOME/.config/kglobalshortcutsrc"
      chmod 600 "$HOME/.config/kglobalshortcutsrc"
    fi
    if [ ! -f "$HOME/.config/kdeglobals" ]; then
      cp ${../dotfiles/kde/kdeglobals} "$HOME/.config/kdeglobals"
      chmod 600 "$HOME/.config/kdeglobals"
    fi
  '';
}
