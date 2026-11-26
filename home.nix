{ config, pkgs, lib, ... }:

{
  imports = [
    ./plasma.nix
  ];

  home.username = "bigl";
  home.homeDirectory = "/home/bigl";
  home.stateVersion = "24.11";

  # User applications overrides, wallpapers & gallery (real writable dirs with symlinked files)
  xdg.dataFile."applications" = {
    source = ./dotfiles/applications;
    recursive = true;
  };
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
    for path in "$HOME/.local/share/wallpapers" "$HOME/.local/share/applications" "$HOME/.local/share/kos/gallery"; do
      if [ -L "$path" ]; then
        rm -f "$path"
      fi
    done
  '';

  # KOS state & config must be real writable files inside $HOME, because
  # kos-platform's security check (resolveStatePath) rejects symlinks pointing into /nix/store.
  home.activation.syncKosConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "$HOME/.local/state/quickshell/kos" ]; then
      rm -f "$HOME/.local/state/quickshell/kos"
    fi
    if [ -L "$HOME/.config/kos" ]; then
      rm -f "$HOME/.config/kos"
    fi

    mkdir -p "$HOME/.local/state/quickshell/kos" "$HOME/.config/kos"
    cp -rf ${./dotfiles/quickshell-kos}/* "$HOME/.local/state/quickshell/kos/"
    chmod -R u+rwX "$HOME/.local/state/quickshell/kos"

    cp -rf ${./dotfiles/kos}/* "$HOME/.config/kos/"
    chmod -R u+rwX "$HOME/.config/kos"
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
