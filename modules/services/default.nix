{...}: {
  imports = [
    ./argocd.nix
    ./traefik.nix
    ./k8s-gateway.nix
    ./tailscale-operator.nix
    ./cloudflare-operator.nix
    ./sops-secrets-operator.nix
  ];
}
