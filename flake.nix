{
  description = "100% Reproducible Unified NixOS & KOS Configuration for ANY Computer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nextkde = {
      url = "path:./nextkde";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blip = {
      url = "github:blip-net/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, plasma-manager, nextkde, ... }@inputs:
  let
    # Login name of the primary user. scripts/install.sh has the same value in
    # PRIMARY_USER; change both together.
    username = "user";
  in
  {
    nixosConfigurations = {
      "nixos" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs username; };
        modules = [
          ./configuration.nix
          nextkde.nixosModules.kos
          inputs.helium.nixosModules.default
          inputs.blip.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ];
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = { inherit inputs username; };
          }
        ];
      };
      # Alias 'default' for convenient installations
      "default" = self.nixosConfigurations.nixos;
    };
  };
}
