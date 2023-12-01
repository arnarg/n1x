# Getting Started

The use of n1x requires nix flakes.

## Initialize Repository

First you will need to create a `flake.nix` in the root of the cluster repository.

``` nix title="flake.nix"
{
  description = "My ArgoCD configuration with n1x.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.n1x.url = "github:arnarg/n1x";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    n1x,
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
    };
  in {
    n1xApplications = n1x.lib.n1xConfiguration {
      inherit pkgs;
      modules = [
        ./configuration.nix
      ];
    };
  }));
}
```

And a `configuration.nix`.

``` nix title="configuration.nix"
{...}: {
  # Enable Cilium as CNI
  networking.cni = "cilium";

  # This example is for a k3s cluster where the default
  # pod CIDR is 10.42.0.0/16
  networking.cilium.podCidrs = ["10.42.0.0/16"];

  # We want to enable ArgoCD
  services.argocd.enable = true;

  # We want to enable the NFS CSI driver
  storage.csi.nfs = {
    enable = true;

    # We want to automatically create a storage class
    storageClass = {
      enable = true;

      # We have an NFS server available at `nfs.local`
      # with share `/exports/kubernetes`
      server = "nfs.local";
      share = "/exports/kubernetes";

      # Set custom mount options
      mountOptions = [
        "nfsvers=4.1"
      ];
    };
  };
}
```

## List available applications

After you have enabled some services in the example config above you can run the following command in the root of the repository to list applications that are enabled and deployable.

```bash
>> nix run github:arnarg/n1x# -- list
argocd - Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.
cilium - eBPF-based Networking, Security, and Observability.
csi-driver-nfs - CSI Kubernetes storage driver to use NFS server for persistent volumes.
```

## Render a single application

From the list above we can discover applications that can be rendered with n1x.

```bash
>> nix run github:arnarg/n1x# -- render .#argocd
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
# More resources ...
```
