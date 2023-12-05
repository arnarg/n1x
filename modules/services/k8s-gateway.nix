{
  lib,
  config,
  ...
}: let
  cfg = config.services.k8s-gateway;

  chart = lib.kube.downloadHelmChart {
    repo = "https://ori-edge.github.io/k8s_gateway/";
    chart = "k8s-gateway";
    version = "2.0.4";
    chartHash = "sha256-/UXkfpgwLNM2HdabvErxzj1gRTQNdWo8HQ7s+Pb6Gpk=";
  };
in {
  options.services.k8s-gateway = with lib;
    mkServiceOptions "k8s-gateway" "k8s-gateway" {
      domain = mkOption {
        type = types.str;
        description = "Delegated domain for k8s_gateway to use.";
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the k8s-gateway helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications."${cfg.name}" = lib.mkHelmApplication {
      inherit chart;
      inherit (cfg) name namespace extraYAMLs;
      description = "A CoreDNS plugin to resolve all types of external Kubernetes resources.";

      values =
        {
          domain = cfg.domain;
        }
        // cfg.values;
    };
  };
}
