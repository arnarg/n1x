{
  modules,
  pkgs,
  lib,
  extraSpecialArgs,
  kubelib,
}: let
  extendedLib = import ../lib pkgs lib kubelib;

  n1xModules = import ./modules.nix {};

  module = lib.evalModules {
    modules = modules ++ n1xModules;
    specialArgs =
      {
        inherit pkgs;
        lib = extendedLib;
      }
      // extraSpecialArgs;
  };

  enabledApps = lib.attrsets.filterAttrs (_: app: app.enable) module.config.applications;

  mkApps = apps:
    lib.mapAttrs (
      n: v:
        extendedLib.kube.toYAMLStreamFile
        (
          lib.flatten (
            lib.mapAttrsToList (
              group: groupData:
                lib.mapAttrsToList (
                  kind: kindData:
                    lib.mapAttrsToList (
                      res: resData:
                        resData
                        // {
                          apiVersion = group;
                          kind = kind;
                          metadata = {name = res;} // (resData.metadata or {});
                        }
                    )
                    kindData
                )
                groupData
            )
            v.resources
          )
        )
    )
    apps;

  mkMeta = apps:
    lib.mapAttrs (
      _: app: {
        description = app.description;
      }
    )
    apps;
in {
  meta = mkMeta enabledApps;
  apps = mkApps enabledApps;
}
