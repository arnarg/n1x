{
  lib,
  config,
  ...
}: let
  cfg = config.n1x;

  bootstrapApps = lib.attrsets.filterAttrs (_: app: app.enable && app.inBootstrap) config.applications;
  appOfAppsApps = lib.attrsets.filterAttrs (_: app: app.enable && app.inAppOfApps) config.applications;
in {
  options.n1x = with lib; {
    bootstrap = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the bootstrap application.";
      };
    };

    appOfApps = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the app-of-apps application.";
      };
      name = mkOption {
        type = types.str;
        default = "apps";
        description = "Name of the app-of-apps applications.";
      };
      repository = mkOption {
        type = types.str;
        description = "The source repository url to put on all generated Argo CD Applications.";
      };
      revision = mkOption {
        type = types.str;
        default = "HEAD";
        description = "The target revision to put on all generated Argo CD Applications.";
      };
    };
  };

  config = {
    # Bootstrap application
    applications.bootstrap = {
      enable = cfg.bootstrap.enable;
      description = "Application used to bootstrap an empty cluster.";
      inBootstrap = lib.mkForce false;
      inAppOfApps = lib.mkForce false;

      # Take resources of all applications with `inBootstrap = true;`
      resources = lib.mkMerge [
        (lib.attrsets.concatMapAttrs (_: app: app.resources) bootstrapApps)
        {
          "argoproj.io/v1alpha1".Application."${cfg.appOfApps.name}" = {
            metadata.namespace = config.services.argocd.namespace;
            spec = {
              project = "default";
              source = {
                repoURL = cfg.appOfApps.repository;
                targetRevision = cfg.appOfApps.revision;
                path = ".";
                plugin.parameters = [
                  {
                    name = "application";
                    string = cfg.appOfApps.name;
                  }
                ];
              };
              destination = {
                server = "https://kubernetes.default.svc";
                namespace = config.services.argocd.namespace;
              };
            };
          };
        }
      ];
    };

    # App of Apps applications
    applications."${cfg.appOfApps.name}" = {
      enable = cfg.appOfApps.enable;
      description = "Argo CD app-of-apps with all applications that have inAppOfApps enabled.";
      inAppOfApps = lib.mkForce false;

      # TODO: finish definition
      resources = {
        "argoproj.io/v1alpha1".Application =
          lib.attrsets.mapAttrs (
            n: app: {
              metadata.namespace = config.services.argocd.namespace;
              spec = {
                project = app.project;
                source = {
                  repoURL = cfg.appOfApps.repository;
                  targetRevision = cfg.appOfApps.revision;
                  path = ".";
                  plugin.parameters = [
                    {
                      name = "application";
                      string = app.name;
                    }
                  ];
                };
                destination = {
                  server = "https://kubernetes.default.svc";
                  namespace = app.namespace;
                };
              };
            }
          )
          appOfAppsApps;
      };
    };
  };
}
