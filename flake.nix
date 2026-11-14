{
  description = "Modular NixOS configuration for Workstation & Secondary PC with NextKDE (KOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nextkde = {
      url = "path:./nextkde";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nextkde, ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        # Workstation host (Intel i9 + NVIDIA RTX 4060 Mobile PRIME)
        "workstation" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/common.nix
            ./hosts/workstation/default.nix
            nextkde.nixosModules.kos
            home-manager.nixosModules.home-manager
            {
              services.kos.enable = true;
              services.kos.weather.enable = false;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.bigl = import ./modules/home.nix;
            }
          ];
        };

        # Default alias for seamless backward compatibility
        "nixos" = self.nixosConfigurations.workstation;

        # Weaker secondary PC (Open-Source Mesa KMS, optimized resource footprint)
        "secondary" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/common.nix
            ./hosts/secondary/default.nix
            nextkde.nixosModules.kos
            home-manager.nixosModules.home-manager
            {
              services.kos.enable = true;
              services.kos.weather.enable = false;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.bigl = import ./modules/home.nix;
            }
          ];
        };
      };
    };
}
