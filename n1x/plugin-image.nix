{
  dockerTools,
  runCommand,
  bashInteractive,
  shadow,
  coreutils,
  nix,
  git,
  cacert,
  n1x,
}: let
  pluginConfig = ''
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: n1x-plugin
    spec:
      version: v0.1
      init:
        command: ["/bin/sh", "-c"]
        args:
        - ${n1x}/bin/n1x build ".#''\${PARAM_APPLICATION}" --out-link "/tmp/app-''\$ARGOCD_APP_NAME-''\$ARGOCD_APP_REVISION_SHORT"
      generate:
        command: ["/bin/sh", "-c"]
        args:
        - cat "/tmp/app-''\$ARGOCD_APP_NAME-''\$ARGOCD_APP_REVISION_SHORT"
      discover:
        fileName: "./flake.nix"
      parameters:
        static:
          - name: application
            title: Application name
            required: true
  '';

  etcPasswd = ''
    argocd-cmp:x:999:999:Argo CD:/home/argocd:${bashInteractive}/bin/bash
    nobody:x:65534:65534:Nobody:/var/empty:${shadow}/bin/nologin
    root:x:0:0:Admin:/root:${bashInteractive}/bin/bash
  '';

  etcGroup = ''
    argocd-cmp:x:999:argocd-cmp
    nobody:x:65534:nobody
    root:x:0:root
  '';

  etcShadow = ''
    argocd-cmp:!:1::::::
    nobody:!:1::::::
    root:!:1::::::
  '';

  nixConf = ''
    extra-experimental-features = nix-command flakes
    sandbox = false
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
  '';

  baseSystem =
    runCommand "base-system"
    {
      inherit pluginConfig etcPasswd etcGroup etcShadow nixConf;
      passAsFile = [
        "pluginConfig"
        "etcPasswd"
        "etcGroup"
        "etcShadow"
        "nixConf"
      ];
      allowSubstitues = false;
      preferLocalBuild = true;
    } ''
      env
      set -x
      mkdir -p $out/etc

      # Setup users
      cat $etcPasswdPath > $out/etc/passwd
      echo "" >> $out/etc/passwd

      cat $etcGroupPath > $out/etc/group
      echo "" >> $out/etc/group

      cat $etcShadowPath > $out/etc/shadow
      echo "" >> $out/etc/shadow

      # Write nix config
      mkdir -p $out/etc/nix
      cat $nixConfPath > $out/etc/nix/nix.conf

      # Setup tmp
      mkdir $out/tmp
      mkdir -p $out/var/tmp

      # Setup home folders
      mkdir -p $out/root
      mkdir -p $out/home/argocd

      # Setup bin directories
      mkdir -p $out/bin $out/usr/bin
      ln -s ${coreutils}/bin/env $out/usr/bin/env
      ln -s ${bashInteractive}/bin/bash $out/bin/sh

      # Write plugin config
      mkdir -p $out/lib/argocd/cmp-server/config
      cat $pluginConfigPath > $out/lib/argocd/cmp-server/config/plugin.yaml
    '';
in
  dockerTools.buildLayeredImageWithNixDb {
    name = "n1x-argocd-cmp-plugin";
    tag = "latest";

    maxLayers = 100;

    contents = [
      baseSystem
      coreutils
      nix
      git
      cacert.out
    ];

    extraCommands = ''
      rm -rf nix-support
    '';

    fakeRootCommands = ''
      chmod 1777 tmp
      chmod 1777 var/tmp

      # Single user install for user 999
      chown -R 999:999 nix
      chown -R 999:999 home/argocd
    '';

    config = {
      User = "999";
      Env = [
        "USER=argocd-cmp"
        "SSL_CERT_FILE=${cacert.out}/etc/ssl/certs/ca-bundle.crt"
        "NIX_SSL_CERT_FILE=${cacert.out}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  }
