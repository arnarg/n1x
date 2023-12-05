{
  lib,
  config,
  ...
}: let
  cfg = config.networking.flannel;

  chart = lib.kube.downloadHelmChart {
    repo = "https://flannel-io.github.io/flannel/";
    chart = "flannel";
    version = "0.22.3";
    chartHash = "sha256-NxF3WnRn9QqJJHIrYFijPTfxl5bGa/s1xFlgmS5fU9A=";
  };
in {
  options.networking.flannel = with lib;
    mkServiceOptions "flannel" "kube-flannel" {
      enable = mkOption {
        type = types.bool;
        default = config.networking.cni == "flannel";
        internal = true;
        description = "Whether or not to enable the flannel application.";
      };
      podCidr = mkOption {
        type = types.str;
        default = "10.244.0.0/16";
        description = "IPv4 CIDR to delegate to pods.";
      };
      podCidrv6 = mkOption {
        type = types.str;
        default = "";
        description = "IPv6 CIDR to delete got pods.";
      };
      backend = mkOption {
        type = types.enum ["vxlan" "host-gw" "wireguard" "udp"];
        default = "vxlan";
        description = ''
          Backend for kube-flannel.

          See: https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md
        '';
      };
      backendPort = mkOption {
        type = types.port;
        default = 0;
        description = "Port used by the backend. 0 means default value (VXLAN: 8472, Wireguard: 51821, UDP: 8285).";
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the flannel helm chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications.flannel = {
      description = "eBPF-based Networking, Security, and Observability.";
      namespace = cfg.namespace;
      resources = lib.kube.renderHelmChart {
        inherit chart;
        inherit (cfg) extraYAMLs name namespace;
        values =
          {
            podCidr = cfg.podCidr;
            podCidrv6 = cfg.podCidrv6;
            flannel.backend = cfg.backend;
            flannel.backendPort = cfg.backendPort;
          }
          // cfg.values;
      };
    };
  };
}
