pkgs: let
  package = pkgs.callPackage ./n1x.nix {};

  pluginImage = pkgs.callPackage ./plugin-image.nix {n1x = package;};
in {
  n1x = package;
  pluginImage = pluginImage;
}
