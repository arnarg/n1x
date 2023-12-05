{
  lib,
  config,
  ...
}: let
  cfg = config.networking.cilium;

  chart = lib.kube.downloadHelmChart {
    repo = "https://helm.cilium.io/";
    chart = "cilium";
    version = "1.14.4";
    chartHash = "sha256-5pT7UUqhnaNsjqhJvmrd4WPc2ee8IkqTm8NiSpnIhoA=";
  };
in {
  options.networking.cilium = with lib;
    mkServiceOptions "cilium" "kube-system" {
      enable = mkOption {
        type = types.bool;
        default = config.networking.cni == "cilium";
        internal = true;
        description = "Whether or not to enable the cilium application.";
      };
      ipamMode = mkOption {
        type = types.enum ["cluster-pool" "kubernetes" "eni"];
        default = "cluster-pool";
        description = "IP Address Management mode for cilium to use.";
      };
      podCidrs = mkOption {
        type = types.listOf types.str;
        default = ["10.0.0.0/8"];
        description = "IPv4 CIDR list range to delegate to individual nodes for IPAM.";
      };
      podCidrsv6 = mkOption {
        type = types.listOf types.str;
        default = ["fd00::/104"];
        description = "IPv6 CIDR mask size to delegate to individual nodes for IPAM.";
      };
      enableIpv4 = mkOption {
        type = types.bool;
        default = true;
        description = "Enable IPv4 support in cilium.";
      };
      enableIpv6 = mkOption {
        type = types.bool;
        default = false;
        description = "Enable IPv6 support in cilium.";
      };
      policyEnforcementMode = mkOption {
        type = types.enum ["default" "always" "never"];
        default = "default";
        description = ''
          Policy enforcement mode for cilium to use.

          See: https://docs.cilium.io/en/latest/security/policy/intro/#policy-enforcement-modes
        '';
      };
      policyAuditMode = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable policy audit mode in cilium.
        '';
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the cilium helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications.cilium = {
      description = "eBPF-based Networking, Security, and Observability.";
      namespace = cfg.namespace;
      resources = lib.kube.renderHelmChart {
        inherit chart;
        inherit (cfg) extraYAMLs name namespace;
        values =
          {
            ipam.mode = cfg.ipamMode;
            ipam.operator.clusterPoolIPv4PodCIDRList = cfg.podCidrs;
            policyEnforcementMode = cfg.policyEnforcementMode;
            policyAuditMode = cfg.policyAuditMode;
          }
          // cfg.values;
      };
    };

    # If ArgoCD is enabled we want to set resource exclusion for
    # CiliumIdentity
    services.argocd.values.configs.cm."resource.exclusions" = ''
      - apiGroups:
        - cilium.io
        kinds:
        - CiliumIdentity
        clusters:
        - "*"
    '';
  };
}
