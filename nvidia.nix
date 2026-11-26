# Proprietary NVIDIA driver, enabled per machine.
#
# Disabled by default. scripts/install.sh detects NVIDIA GPUs during installation
# and appends the matching `dotfiles.nvidia` settings (including PRIME bus IDs on
# hybrid laptops) to the machine's hardware-configuration.nix.
{ config, lib, ... }:

let
  cfg = config.dotfiles.nvidia;

  busIdOption = description: lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "PCI:1:0:0";
    inherit description;
  };

  # PRIME offload needs the NVIDIA GPU plus an integrated Intel or AMD GPU.
  usePrime = cfg.prime.nvidiaBusId != null
    && (cfg.prime.intelBusId != null || cfg.prime.amdgpuBusId != null);
in
{
  options.dotfiles.nvidia = {
    enable = lib.mkEnableOption "the proprietary NVIDIA driver";

    prime = {
      nvidiaBusId = busIdOption "PCI bus ID of the NVIDIA GPU (decimal notation).";
      intelBusId = busIdOption "PCI bus ID of the integrated Intel GPU (decimal notation).";
      amdgpuBusId = busIdOption "PCI bus ID of the integrated AMD GPU (decimal notation).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      # Open kernel modules require a Turing (GTX 16xx / RTX 20xx) or newer GPU
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = true;
      powerManagement.finegrained = usePrime;

      prime = lib.mkIf usePrime {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = cfg.prime.nvidiaBusId;
        intelBusId = lib.mkIf (cfg.prime.intelBusId != null) cfg.prime.intelBusId;
        amdgpuBusId = lib.mkIf (cfg.prime.amdgpuBusId != null) cfg.prime.amdgpuBusId;
      };
    };
  };
}
