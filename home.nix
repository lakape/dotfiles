{ config, pkgs, lib, ... }:

{
  imports = [
    ./plasma.nix
  ];

  home.username = "bigl";
  home.homeDirectory = "/home/bigl";
  home.stateVersion = "24.11";

  # Wallpapers & gallery (real writable dirs with symlinked files)
  xdg.dataFile."wallpapers" = {
    source = ./dotfiles/wallpapers;
    recursive = true;
  };
  xdg.dataFile."kos/gallery" = {
    source = ./dotfiles/kos-share/gallery;
    recursive = true;
  };

  # Clean legacy directory symlinks so recursive xdg.dataFile targets can be created as real directories
  home.activation.cleanLegacySymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for path in "$HOME/.local/share/wallpapers" "$HOME/.local/share/kos/gallery"; do
      if [ -L "$path" ]; then
        rm -f "$path"
      fi
    done
  '';

  # KOS state & config must be real writable files inside $HOME: kos-platform only
  # reads and writes state whose canonical path stays below ~/.local/state/quickshell
  # (resolveStatePath), so links into /nix/store or into this repository are rejected.
  # The repository files are first-install defaults: missing files are added,
  # but settings changed in the GUI (dock, tray order, appearance) are kept.
  # scripts/sync-desktop-to-repo.sh copies live changes back into the repository.
  home.activation.seedKosConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "$HOME/.local/state/quickshell/kos" ]; then
      rm -f "$HOME/.local/state/quickshell/kos"
    fi
    if [ -L "$HOME/.config/kos" ]; then
      rm -f "$HOME/.config/kos"
    fi

    mkdir -p "$HOME/.local/state/quickshell/kos" "$HOME/.config/kos"
    cp -r --update=none ${./dotfiles/quickshell-kos}/* "$HOME/.local/state/quickshell/kos/"
    chmod -R u+rwX "$HOME/.local/state/quickshell/kos"

    cp -r --update=none ${./dotfiles/kos}/* "$HOME/.config/kos/"
    chmod -R u+rwX "$HOME/.config/kos"
  '';

  # Plasma only creates its default layout (including the bottom panel with the
  # application launcher) when this file does not exist. Seeding a layout without
  # panels before the first login means that panel is never created. Existing
  # layouts are left alone.
  home.activation.seedPlasmaLayout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    layout="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    if [ ! -e "$layout" ]; then
      install -Dm600 ${./dotfiles/kde/plasma-org.kde.plasma.desktop-appletsrc} "$layout"
    fi
  '';

  # Bash shell integration & aliases
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      # Ensure NixOS setuid wrappers (like sudo) always take precedence over /run/current-system/sw/bin
      if [[ ":$PATH:" != *":/run/wrappers/bin:"* ]]; then
        export PATH="/run/wrappers/bin:$PATH"
      fi
    '';
    shellAliases = {
      rebuild = "/run/wrappers/bin/sudo nixos-rebuild switch --flake /home/bigl/dotfiles#nixos";
      update-flake = "cd /home/bigl/dotfiles && nix flake update";
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
