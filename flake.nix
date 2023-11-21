{
  description = "Kubernetes GitOps with ArgoCD in nix";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-kube-generators.url = "github:farcaller/nix-kube-generators";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-kube-generators,
  }:
    {
      lib.n1xConfiguration = {
        modules ? [],
        pkgs,
        lib ? pkgs.lib,
        extraSpecialArgs ? {},
      }:
        import ./modules {
          inherit modules pkgs lib extraSpecialArgs;
          kubelib = nix-kube-generators.lib {inherit pkgs;};
        };
    }
    // (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      docs = import ./docs {
        inherit pkgs;
        lib = import ./lib pkgs pkgs.lib (nix-kube-generators.lib {inherit pkgs;});
      };
      n1xPackages = import ./n1x pkgs;
    in {
      packages = {
        default = n1xPackages.n1x;
        pluginImage = n1xPackages.pluginImage;
        docs = {
          opts = docs.opts;
          md = docs.md;
          html = docs.html;
        };
      };
      n1xApplications = self.lib.n1xConfiguration {
        inherit pkgs;
        modules = [
          ({...}: {
            networking.cni = "cilium";

            storage.csi.nfs.enable = true;

            services.argocd.enable = true;
            services.traefik.enable = true;
            services.k8s-gateway.enable = true;
            services.k8s-gateway.domain = "example.com";
            services.tailscale-operator.enable = true;
            services.cloudflare-operator.enable = true;

            n1x.appOfApps.enable = true;
            n1x.appOfApps.repository = "git@github.com:arnarg/n1x.git";
            n1x.bootstrap.enable = true;
          })
        ];
      };
    }));
}
