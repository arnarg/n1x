{
  lib,
  config,
  ...
}: let
  cfg = config.services.traefik;

  chart = lib.kube.downloadHelmChart {
    repo = "https://traefik.github.io/charts/";
    chart = "traefik";
    version = "25.0.0";
    chartHash = "sha256-zJHbv36y4ipXf/ATFcTUxPvD56P0HR/hOzEjIduEzn8=";
  };
in {
  options.services.traefik = with lib;
    mkServiceOptions "traefik" "traefik" {
      ingressClass = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable creating an ingress class resource for traefik.";
        };
        isDefaultClass = mkOption {
          type = types.bool;
          default = true;
          description = "Set traefik ingress class as the default one.";
        };
        name = mkOption {
          type = types.str;
          default = "traefik";
          description = "The name of the ingress class for traefik.";
        };
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the traefik helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications.traefik = {
      description = "A Traefik based Kubernetes ingress controller.";
      namespace = cfg.namespace;
      resources = lib.kube.renderHelmChart {
        inherit chart;
        name = "traefik";
        namespace = cfg.namespace;
        values = cfg.values;
      };
    };
  };
}
