# n1x

Configure your Kubernetes cluster like it's NixOS.

> Under active development. Things will change.

## Why?

It's desirable to manage Kubernetes clusters in a declarative way using a git repository as a source of truth for manifests that should be deployed into the cluster. One popular solution that is often used to achieve this goal is [Argo CD](https://argo-cd.readthedocs.io/en/stable/).

### Argo CD

Argo CD has a concept of applications. Each application has an entrypoint somewhere in your git repository that is either a Helm chart, kustomize application, jsonnet files or just a directory of YAML files. All the resources that are output when templating the helm chart, kustomizing the kustomize application or are defined in the YAML files in the directory, make up the application and are (usually) deployed into a single namespace.

For these reasons these git repositories often need quite elaborate designs once many applications should be deployed, requiring use of application sets (generator for applications) or custom Helm charts just to render all the different applications of the repository.

### NixOS

When looking at the module system of NixOS, an application in Argo CD might be comparable to a single systemd service in NixOS (declared with option `systemd.services.<name>`: [docs](https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=systemd.services)).

But users of NixOS aren't creating systemd services manually unless they're creating their own manual modules. Instead available pre-configured services are abstacted away into options such as `services.postgresql` or `programs.git` (this one doesn't create a systemd service but adds git to the system path and writes some configs).

### n1x

The idea of n1x is then to answer the question: What if we could configure our entire GitOps repository for Argo CD using a NixOS-like module system that abstracts away the creation of applications behind (hopefully) friendlier options with a (hopefully) community driven repository of applications.

As a bonus of all the applications being defined in a single (modular) configuration, n1x can automatically generate an [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) removing the need to manually discover all the different applications that Argo CD should manage.

#### Example Configuration

```nix
{config, ...}: let
  domain = "mydomain.com";
in {
  # Enable Cilium CNI application.
  networking.cni = "cilium";

  # Configure Cilium to use the default k3s pod cidr.
  networking.cilium.podCidrs = ["10.42.0.0/16"];

  # Enable traefik as ingress controller.
  services.traefik.enable = true;

  # Enable Argo CD.
  services.argocd = {
    enable = true;

    # Create an Ingress for Argo CD web UI.
    ingress = {
      enable = true;
      hosts = ["argocd.${domain}"];

      # Reference an option from another service's options.
      ingressClass = config.services.traefik.ingressClass.name;
    };

    # Pass-through values to Argo CD Helm chart.
    values = {
      # Traefik will terminate TLS traffic.
      # Disable HTTPS in argocd-server.
      configs.params."server.insecure" = "true";
    };

    # You can extend the application with arbitrary resources
    # in YAML.
    # They will be parsed and merged with the final application
    # output.
    extraYAMLs = [
      ''
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: allow-traefik-ingress
          namespace: ${config.services.argocd.namespace}
        spec:
          podSelector:
            matchLabels:
              app.kubernetes.io/name: argocd-server
          policyTypes:
          - Ingress
          ingress:
          - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: ${config.services.traefik.namespace}
              podSelector:
                matchLabels:
                  app.kubernetes.io/name: traefik
            ports:
            - protocol: TCP
              port: 8080
      ''
    ];
  };
}
```

## Non Goals

### Typed Resource Definitions

n1x does not concern itself with defining typed options for every possible Kubernetes resource like is done with [kubenix](https://github.com/hall/kubenix). This approach requires automatic generation from JSON schemas of all supported resources, and needs to be updated for every new release of Kubernetes.

That also means that it will explicitly need to support every different CRD from applications it wants to deploy.

Instead it allows for outputing any structure as long as it's under `<apiVersion>.<kind>.<name>` and let Argo CD surface the error if the data is not a valid resource.

### Define Resources for all Applications

I do not want to define the required resources to deploy an application that I need to then maintain down the line if an official Helm chart or kustomize application already exists.

Instead we should use those Helm charts or kustomize applications as a base to work on top of.

Example:

```nix
{
  lib,
  config,
  ...
}: let
  cfg = config.services.argocd;

  # Downloads a helm chart and creation a derivation with the
  # chart data (this function comes from nix-kube-generators,
  # see special thanks on the bottom of this page).
  chart = lib.kube.downloadHelmChart {
    repo = "https://argoproj.github.io/argo-helm/";
    chart = "argo-cd";
    version = "5.51.4";
    chartHash = "sha256-e2aREkDbLtD1bC/dAEHPeqnmHLG+Ch3RTMxQSWPP5PY=";
  };
in {
  options.services.argocd = with lib; {
    # Allow the user a simple enable flag to add the Argo CD
    # application to the cluster.
    enable = mkEnableOption "argocd";
    namespace = mkOption {
      type = types.str;
      default = "argocd";
      description = "Destination namespace for ArgoCD.";
    };
    # Expose useful configuration options that can be set
    # without knowing the syntax of the underlying Helm
    # value file.
    ingress = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Create an ingress for argocd-server.";
      };
      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Hostname to put in the argocd-server ingress.";
      };
      ingressClass = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Ingress class to set on the ingress for argocd-server.";
      };
    };
    # But also allow passing the underlying Helm values
    # so the user isn't limited if they need to set custom
    # options.
    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Values to pass on to the argo-cd helm chart.";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.argocd = {
      description = "Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.";
      namespace = cfg.namespace;
      resources = lib.mkMerge [
        # Render and parse the resources from a Helm chart.
        lib.kube.renderHelmChart {
          name = "argocd";
          namespace = cfg.namespace;
          chart = chart;
          values = {
            # Set custom values set with n1x options.
            server.ingress.enabled = cfg.ingress.enable;
            server.ingress.hosts = lib.optional
              (!builtins.isNull cfg.ingress.host) cfg.ingress.host;
          }
          # But also merge values set with n1x option.
          // cfg.values;
        }
        (lib.mkIf (!builtins.isNull cfg.ingress.ingressClass) {
          "networking.k8s.io/v1".Ingress.argocd-server-ingress = {
            # Merge the resources with custom options that may not
            # be possible to set with the Helm chart's values.
            spec.ingressClassName = cfg.ingress.ingressClass;
          };
        })
      ];
    };
  };
}
```

Then the user of n1x only needs to set a few options:

```nix
{config, ...}: {
  services.argocd = {
    enable = true;
    ingress = {
      enable = true;
      host = "argocd.mydomain.com";
      # Reference options across applications.
      ingressClass = config.services.traefik.ingressClassName;
    };
  };
}
```

## Special Thanks

[farcaller/nix-kube-generators](https://github.com/farcaller/nix-kube-generators) is used internally to pull and render Helm charts and the library is re-exposed under `lib.kube` in the modules.
