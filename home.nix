{ config, pkgs, ... }:

{
  imports = [
    ./plasma.nix
  ];

  home.username = "bigl";
  home.homeDirectory = "/home/bigl";
  home.stateVersion = "24.11";

  # KOS JSON configurations (~/.config/kos)
  xdg.configFile."kos".source = ./dotfiles/kos;

  # Gemini CLI / Agent configuration (~/.gemini/config/config.json)
  home.file.".gemini/config/config.json".source = ./dotfiles/gemini/config.json;

  # User applications overrides (~/.local/share/applications)
  xdg.dataFile."applications".source = ./dotfiles/applications;

  # KOS Wallpapers & Gallery (~/.local/share/wallpapers and ~/.local/share/kos/gallery)
  xdg.dataFile."wallpapers".source = ./dotfiles/wallpapers;
  xdg.dataFile."kos/gallery".source = ./dotfiles/kos-share/gallery;

  # Quickshell state (~/.local/state/quickshell/kos)
  xdg.stateFile."quickshell/kos".source = ./dotfiles/quickshell-kos;

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
