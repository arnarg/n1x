{
  lib,
  config,
  ...
}: let
  cfg = config.services.sops-secrets-operator;

  chart = lib.kube.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.17.4";
    chartHash = "sha256-8YcPhtUAnFSwdOTeG/qeejd5ECoejNU4JcskokgQIro=";
  };
in {
  options.services.sops-secrets-operator = with lib;
    mkServiceOptions "sops-secrets-operator" "sops-secrets-operator" {
      ageKeySecret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Name of a secret containing an age private key to use to decrypt SOPS secrets. Secret needs to contain a `keys.txt` data key.

          Example:
          ```yaml
          apiVersion: v1
          kind: Secret
          metadata:
            name: age-keys
            namespace: sops-secrets-operator
          stringData:
            keys.txt: |
              AGE-SECRET-KEY-123...
          ```
        '';
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the sops-secrets-operator helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications."${cfg.name}" = {
      description = "Operator which manages Kubernetes Secret Resources created from user defined SopsSecrets CRs.";
      namespace = cfg.namespace;
      resources = lib.kube.renderHelmChart {
        inherit chart;
        inherit (cfg) extraYAMLs name namespace;
        values =
          (lib.optionalAttrs (!builtins.isNull cfg.ageKeySecret) {
            # Mount secret with age keys to operator pod
            secretsAsFiles = [
              {
                name = "keys";
                mountPath = "/var/lib/sops/age";
                secretName = cfg.ageKeySecret;
              }
            ];

            # Tell the operator pod where to read age keys
            extraEnv = [
              {
                name = "SOPS_AGE_KEY_FILE";
                value = "/var/lib/sops/age/key.txt";
              }
            ];
          })
          // cfg.values;
      };
    };
  };
}
