{
  lib,
  config,
  ...
}: let
  cfg = config.storage.csi.nfs;

  chart = lib.kube.downloadHelmChart {
    repo = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts";
    chart = "csi-driver-nfs";
    version = "4.5.0";
    chartHash = "sha256-iceFWy9kaLeXXiMPeUlaHybagqIn/VE+pM8Uf3jyp0s=";
  };
in {
  options.storage.csi.nfs = with lib;
    mkServiceOptions "csi-driver-nfs" "kube-system" {
      driverName = mkOption {
        type = types.str;
        default = "nfs.csi.k8s.io";
        description = "Name of the driver when deployed in the Kubernetes cluster.";
      };
      storageClass = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Automatically create a StorageClass for csi-driver-nfs.";
        };
        name = mkOption {
          type = types.str;
          default = "nfs-csi";
          description = "Name of the StorageClass to create for csi-driver-nfs.";
        };
        server = mkOption {
          type = types.str;
          description = "NFS server address to use to connect to.";
        };
        share = mkOption {
          type = types.str;
          description = "NFS share on the server to use for csi-driver-nfs.";
        };
        reclaimPolicy = mkOption {
          type = types.enum ["Delete" "Retain"];
          default = "Delete";
          description = "Reclaim policy to use for the StorageClass for csi-driver-nfs.";
        };
        volumeBindingMode = mkOption {
          type = types.enum ["Immediate" "WaitForFirstConsumer"];
          default = "Immediate";
          description = "VolumeBindingMode indicates how PersistentVolumeClaims should be provisioned and bound.";
        };
        mountOptions = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["nfsvers=4.1"];
          description = "Extra options to pass on when mounting the NFS share.";
        };
      };
      values = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Values to pass on to the csi-driver-nfs chart.";
      };
    };

  config = lib.mkIf cfg.enable {
    applications."${cfg.name}" = lib.mkHelmApplication {
      inherit chart;
      inherit (cfg) name namespace extraYAMLs;
      description = "CSI Kubernetes storage driver to use NFS server for persistent volumes.";

      values =
        {
          driver.name = cfg.driverName;
        }
        // cfg.values;

      extraResources = lib.optionalAttrs cfg.storageClass.enable {
        "storage.k8s.io/v1".StorageClass."${cfg.storageClass.name}" = {
          provisioner = cfg.driverName;
          parameters.server = cfg.storageClass.server;
          parameters.share = cfg.storageClass.share;
          reclaimPolicy = cfg.storageClass.reclaimPolicy;
          volumeBindingMode = cfg.storageClass.volumeBindingMode;
          mountOptions = cfg.storageClass.mountOptions;
        };
      };
    };
  };
}
