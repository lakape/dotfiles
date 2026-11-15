{
  description = "100% Reproducible Unified NixOS & KOS Configuration for ANY Computer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nextkde = {
      url = "path:./nextkde";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nextkde, ... }@inputs: {
    nixosConfigurations = {
      "nixos" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          nextkde.nixosModules.kos
        ];
      };
      # Alias 'default' for convenient installations
      "default" = self.nixosConfigurations.nixos;
    };
  };
}
