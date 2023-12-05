{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.tailscale-operator;

  # Tailscale doesn't have a helm repository so we just need to clone
  # the tailscale git repository and pass the folder.
  src = pkgs.fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "v1.54.0";
    hash = "sha256-/l3csuj1AZQo7C0BzkhqvkMNEQxc6Ers0KtZvxWS96Q=";
  };
  chart = "${src}/cmd/k8s-operator/deploy/chart";
in {
  options.services.tailscale-operator = with lib;
    mkServiceOptions "tailscale-operator" "tailscale-operator" {
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the tailscale-operator helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications."${cfg.name}" = lib.mkHelmApplication {
      inherit chart;
      inherit (cfg) name namespace extraYAMLs;
      description = "Operator to expose ingresses and services on Tailscale.";

      values = cfg.values;
    };
  };
}
