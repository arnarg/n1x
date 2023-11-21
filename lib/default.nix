pkgs: nixpkgslib: kubelib: let
  renderResourceList = ress:
    nixpkgslib.attrsets.updateManyAttrsByPath (builtins.map (
        res: {
          path = [res.apiVersion res.kind res.metadata.name];
          update = _: builtins.removeAttrs res ["apiVersion" "kind"];
        }
      )
      ress) {};

  n1xLib = rec {
    renderHelmChart = args:
      renderResourceList (kubelib.fromHelm args);

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

    renderKustomization = args:
      pkgs.lib.pipe args [
        buildKustomization
        builtins.readFile
        kubelib.fromYAML
        renderResourceList
      ];
  };
in
  nixpkgslib.extend (_: _: {
    mkServiceOptions = name: namespace: rest:
      with nixpkgslib;
        {
          enable = mkEnableOption name;
          namespace = mkOption {
            type = types.str;
            default = namespace;
            description = "Destination namespace for ${name}.";
          };
        }
        // rest;

    kube = kubelib // n1xLib;
  })
