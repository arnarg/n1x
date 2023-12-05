{
  lib,
  config,
  ...
}: let
  cfg = config.services.argocd;

  chart = lib.kube.downloadHelmChart {
    repo = "https://argoproj.github.io/argo-helm/";
    chart = "argo-cd";
    version = "5.51.4";
    chartHash = "sha256-e2aREkDbLtD1bC/dAEHPeqnmHLG+Ch3RTMxQSWPP5PY=";
  };
in {
  options.services.argocd = with lib;
    mkServiceOptions "argocd" "argocd" {
      n1xPlugin = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to automatically add the n1x config management plugin to Argo CD.";
        };
        image = mkOption {
          type = types.str;
          default = "ghcr.io/arnarg/n1x/argocd-cmp-plugin:latest";
          description = "The image to use in the Argo CD config management plugin sidecar.";
        };
      };
      ingress = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Create an ingress for argocd-server.";
        };
        hosts = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Hostnames to put in the argocd-server ingress.";
        };
        ingressClass = mkOption {
          type = types.str;
          default = "";
          description = "Ingress class to set on the ingress for argocd-server.";
        };
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the argo-cd helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications."${cfg.name}" = lib.mkHelmApplication {
      inherit chart;
      inherit (cfg) name namespace extraYAMLs;
      description = "Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.";

      values =
        {
          server.ingress = {
            enabled = cfg.ingress.enable;
            hosts = cfg.ingress.hosts;
            ingressClassName = cfg.ingress.ingressClass;
          };
        }
        // (lib.optionalAttrs cfg.n1xPlugin.enable {
          repoServer.extraContainers = [
            {
              name = "n1x-plugin";
              command = [
                "/var/run/argocd/argocd-cmp-server"
                "--config-dir-path"
                "/lib/argocd/cmp-server/config"
              ];
              image = cfg.n1xPlugin.image;
              securityContext = {
                runAsNonRoot = true;
                runAsUser = 999;
              };
              volumeMounts = [
                {
                  mountPath = "/var/run/argocd";
                  name = "var-files";
                }
                {
                  mountPath = "/home/argocd/cmp-server/plugins";
                  name = "plugins";
                }
                {
                  mountPath = "/tmp";
                  name = "cmp-tmp";
                }
              ];
            }
          ];
          repoServer.volumes = [
            {
              name = "cmp-tmp";
              emptyDir = {};
            }
          ];
        })
        // cfg.values;
    };
  };
}
