{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.cloudflare-operator;

  src = pkgs.fetchFromGitHub {
    owner = "adyanth";
    repo = "cloudflare-operator";
    rev = "v0.10.2";
    hash = "sha256-faDLWOxirQ1Uc6mAx8YNlLKoemJxQ5aXHiRgdoVM9Nw=";
  };
in {
  options.services.cloudflare-operator = with lib;
    mkServiceOptions "cloudflare-operator" "cloudflare-operator" {};

  config = lib.mkIf cfg.enable {
    applications.cloudflare-operator = {
      description = "A Kubernetes Operator to create and manage Cloudflare Tunnels and DNS records for (HTTP/TCP/UDP*) Service Resources.";
      namespace = cfg.namespace;
      resources = lib.kube.renderKustomization {
        inherit src;
        name = "cloudflare-operator";
        path = "config/default";
        namespace = cfg.namespace;
      };
    };
  };
}
