pkgs: nixpkgslib: kubelib: let
  renderResourceList = extraYAMLs: ress: let
    parsedYAMLs =
      nixpkgslib.flatten
      (map
        kubelib.fromYAML
        extraYAMLs);

    resources = ress ++ parsedYAMLs;
  in
    nixpkgslib.attrsets.updateManyAttrsByPath (builtins.map (
        res: {
          path = [res.apiVersion res.kind res.metadata.name];
          update = _: builtins.removeAttrs res ["apiVersion" "kind"];
        }
      )
      resources) {};

  n1xLib = rec {
    # Thin wrapper around nix-kube-generators' `downloadHelmChart`
    # to store parameters in `_meta`.
    downloadHelmChart = {
      repo,
      chart,
      version,
      chartHash,
    } @ args:
      (kubelib.downloadHelmChart args)
      // {_meta = args;};

    renderHelmChart = {extraYAMLs ? [], ...} @ args:
      renderResourceList
      extraYAMLs
      (kubelib.fromHelm (removeAttrs args ["extraYAMLs"]));

    buildKustomization = {
      name,
      src,
      path,
      namespace ? null,
    }: let
      sanitizedPath = nixpkgslib.removePrefix "/" path;
    in
      pkgs.stdenv.mkDerivation {
        inherit src;
        name = "kustomize-${name}";

        phases = ["unpackPhase" "patchPhase" "installPhase"];

        patchPhase = nixpkgslib.optionalString (!builtins.isNull namespace) ''
          ${pkgs.yq-go}/bin/yq -i '.namespace = "${namespace}"' "${sanitizedPath}/kustomization.yaml"
        '';

        installPhase = ''
          ${pkgs.kubectl}/bin/kubectl kustomize "${sanitizedPath}" -o "$out"
        '';
      };

    renderKustomization = {extraYAMLs ? [], ...} @ args:
      pkgs.lib.pipe
      (removeAttrs args ["extraYAMLs"]) [
        buildKustomization
        builtins.readFile
        kubelib.fromYAML
        (renderResourceList extraYAMLs)
      ];
  };
in
  nixpkgslib.extend (_: _: {
    mkServiceOptions = name: namespace: rest:
      with nixpkgslib;
        {
          enable = mkEnableOption name;
          name = mkOption {
            type = types.str;
            default = name;
            description = "Name of the application for ${name}.";
          };
          namespace = mkOption {
            type = types.str;
            default = namespace;
            description = "Destination namespace for ${name}.";
          };
          extraYAMLs = mkOption {
            type = types.listOf types.lines;
            default = [];
            example = [
              ''
                apiVersion: v1
                kind: Namespace
                metadata:
                  name: ${namespace}
              ''
              ''
                apiVersion: v1
                kind: ConfigMap
                metadata:
                  name: my-config
                  namespace: ${namespace}
                ---
                apiVersion: v1
                kind: ConfigMap
                metadata:
                  name: my-files
                  namespace: ${namespace}
                data:
                  file.txt: |
                    some data here.
              ''
            ];
            description = ''
              Extra resources defined in YAML that will be parsed and merged with the rest of the resources.
            '';
          };
        }
        // rest;

    mkHelmApplication = {
      description,
      name,
      namespace,
      chart,
      values ? {},
      extraResources ? null,
      extraYAMLs ? [],
    }: let
      rendered = n1xLib.renderHelmChart {
        inherit chart name namespace values extraYAMLs;
      };

      merged =
        if !isNull extraResources
        then nixpkgslib.mkMerge [rendered extraResources]
        else rendered;
    in {
      inherit description namespace;
      resources = merged;
      meta = with nixpkgslib;
        {
          _type = "helm";
        }
        // (
          if (hasAttrByPath ["_meta"] chart)
          then {
            repository = chart._meta.repo;
            chart = chart._meta.chart;
            version = chart._meta.version;
            appVersion = chart._meta.appVersion or "unknown";
          }
          else {}
        );
    };

    mkKustomizeApplication = {
      description,
      name,
      namespace,
      kustomization,
      path,
      extraResources ? null,
      extraYAMLs ? [],
    }: let
      rendered = n1xLib.renderKustomization {
        inherit name namespace extraYAMLs path;
        src = kustomization;
      };

      merged =
        if !isNull extraResources
        then nixpkgslib.mkMerge [rendered extraResources]
        else rendered;
    in {
      inherit description namespace;
      resources = merged;
      meta = {
        _type = "kustomize";
        source = kustomization.meta.homepage;
        path = path;
        revision = kustomization.rev;
      };
    };

    kube = kubelib // n1xLib;
  })
