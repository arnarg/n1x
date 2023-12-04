{
  lib,
  config,
  ...
}: let
  appOpts = with lib;
    {name, ...}: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the application is enabled.";
        };
        name = mkOption {
          type = types.str;
          default = name;
          description = "Name of the application.";
        };
        namespace = mkOption {
          type = types.str;
          default = name;
          description = "Namespace to deploy application into (defaults to name).";
        };
        description = mkOption {
          type = types.str;
          default = "";
          description = "Description for the application.";
        };
        inBootstrap = mkOption {
          type = types.bool;
          default = false;
          description = "Whether application should be a part of the bootstrap application.";
        };
        inAppOfApps = mkOption {
          type = types.bool;
          default = true;
          description = "Whether application should be a part of the app-of-apps application.";
        };
        project = mkOption {
          type = types.str;
          default = "default";
          description = "ArgoCD project to make application a part of.";
        };
        syncPolicy = {
          automated = {
            prune = mkOption {
              type = types.bool;
              default = config.n1x.defaultSyncPolicy.automated.prune;
              description = "Specifies if resources should be pruned during auto-syncing.";
            };
            selfHeal = mkOption {
              type = types.bool;
              default = config.n1x.defaultSyncPolicy.automated.selfHeal;
              description = "Specifies if partial app sync should be executed when resources are changed only in target Kubernetes cluster and no git change detected.";
            };
          };
        };
        resources = mkOption {
          type = types.attrsOf (types.attrsOf (types.attrsOf types.anything));
          default = {};
          example = {
            v1 = {
              Namespace.argocd = {};
              ConfigMap.argocd-cmd-params-cm = {
                metadata.namespace = "argocd";
                data."server.insecure" = "true";
              };
            };
          };
          description = ''
            Resources that make up the application.

            They should be declared in the form `<apiVersion>.<kind>.<name>`.

            For example the following namespace resource:

            ```yaml
            apiVersion: v1
            kind: Namespace
            metadata:
              name: argocd
            ```

            Would be declared in like this:

            ```nix
            {
              v1.Namespace.argocd = {
                # This is redundant as `metadata.name` defaults
                # to the name of the attribute for the resource.
                metadata.name = "argocd";
              };
            }
            ```
          '';
        };
      };
    };
in {
  options.applications = with lib;
    mkOption {
      type = types.attrsOf (types.submodule appOpts);
      default = {};
      description = ''
        An application describes a single Argo CD application that can be rendered using n1x.

        Usually the application is abstracted away behind a `services` option.

        It is used to render Kubernetes resources when running `n1x render` and appears in the list of applications when running `n1x list`.
      '';
      example = {
        argocd = {
          description = "Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.";
          namespace = "argocd";
          resources = {
            v1.Namespace.argocd = {};
          };
        };
      };
    };
}
