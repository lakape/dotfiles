{
  description = "Universal 100% Reproducible NixOS & KOS Configuration for ANY Computer";

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

      # Universal modules for ANY computer (VMs, Intel, AMD, Laptops, Desktops)
      universalModules = [
        ./hardware-configuration.nix
        ./modules/common.nix
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
    in {
      nixosConfigurations = {
        # 1. Universal Default Configuration (Works on ANY computer, VM, Intel, AMD)
        "nixos" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = universalModules;
        };

        "default" = self.nixosConfigurations.nixos;

        # 2. Configuration for PCs with dedicated NVIDIA GPU (PRIME Offload)
        "workstation" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = universalModules ++ [
            ./modules/nvidia.nix
          ];
        };

        "nvidia" = self.nixosConfigurations.workstation;
      };
    };
}
