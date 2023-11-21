{lib, ...}: {
  imports = [
    ./cilium.nix
    ./flannel.nix
  ];

  options.networking = with lib; {
    cni = mkOption {
      type = types.nullOr (types.enum ["cilium" "flannel"]);
      default = null;
      description = ''
        Which CNI application to enable or none if `null`.
      '';
    };
  };
}
