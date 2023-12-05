{
  pkgs,
  lib,
}: let
  n1xPath = toString ./..;

  # Borrowed from home-manager :)
  gitHubDeclaration = user: repo: subpath: {
    url = "https://github.com/${user}/${repo}/blob/main/${subpath}";
    name = "${repo}/${subpath}";
  };

  options =
    (lib.evalModules {
      modules = import ../modules/modules.nix {};
      specialArgs = {
        inherit pkgs lib;
      };
    })
    .options;

  optionsDoc = pkgs.buildPackages.nixosOptionsDoc {
    options = removeAttrs options ["_module"];
    transformOptions = opt:
      opt
      // {
        declarations =
          map (
            decl:
              if lib.hasPrefix n1xPath (toString decl)
              then gitHubDeclaration "arnarg" "n1x" (lib.removePrefix "/" (lib.removePrefix n1xPath (toString decl)))
              else if decl == "lib/modules.nix"
              then gitHubDeclaration "NixOS" "nixpkgs" decl
              else decl
          )
          opt.declarations;
      };
  };

  optsMd = with lib;
    concatStringsSep "\n" ([
        ''
          # Configuration Options

        ''
      ]
      ++ (mapAttrsToList (n: opt:
        ''
          ## ${replaceStrings ["\<" ">"] ["&lt;" "&gt;"] n}

          ${opt.description}

          ***Type:***
          ${opt.type}

        ''
        + (lib.optionalString (hasAttrByPath ["default" "text"] opt) ''
          ***Default:***
          `#!nix ${opt.default.text}`

        '')
        + (lib.optionalString (hasAttrByPath ["example" "text"] opt) (''
            ***Example:***
          ''
          + (
            if
              (hasPrefix "attribute set" opt.type)
              || (hasPrefix "list of" opt.type)
            then ''

              ```nix
              ${opt.example.text}
              ```

            ''
            else ''
              `#!nix ${opt.example.text}`

            ''
          )))
        + ''
          ***Declared by:***

          ${
            concatStringsSep "\n" (map (
                decl: ''
                  - [&lt;${decl.name}&gt;](${decl.url})
                ''
              )
              opt.declarations)
          }
        '')
      optionsDoc.optionsNix));

  docsHtml = pkgs.stdenv.mkDerivation {
    inherit appsMd optsMd;

    passAsFile = ["appsMd" "optsMd"];

    name = "n1x-docs";

    src = lib.cleanSource ./..;

    buildInputs = with pkgs.python3.pkgs; [mkdocs-material mkdocs-material-extensions];

    phases = ["unpackPhase" "patchPhase" "buildPhase"];

    patchPhase = ''
      cat $optsMdPath > docs/options.md
      cat $appsMdPath > docs/applications.md

      cat <<EOF > mkdocs.yml
        site_name: n1x
        site_url: https://arnarg.github.io/n1x/
        site_dir: $out

        repo_url: https://github.com/arnarg/n1x/

        exclude_docs: |
          *.nix

        theme:
          name: material

          features:
          - content.code.annotate

          palette:
          - media: "(prefers-color-scheme: light)"
            scheme: default
            toggle:
              icon: material/brightness-7
              name: Switch to dark mode
          - media: "(prefers-color-scheme: dark)"
            scheme: slate
            toggle:
              icon: material/brightness-4
              name: Switch to light mode

        markdown_extensions:
        - toc:
            permalink: "#"
            toc_depth: 3
        - admonition
        - pymdownx.highlight
        - pymdownx.inlinehilite
        - pymdownx.superfences

        nav:
        - Home: index.md
        - 'User Guide':
          - 'Getting Started': user_guide/getting_started.md
          - 'App of Apps': user_guide/app_of_apps.md
        - Reference:
          - 'Applications': applications.md
          - 'Configuration Options': options.md
      EOF
    '';

    buildPhase = ''
      mkdir -p $out
      python -m mkdocs build
    '';
  };

  apps' = lib.evalModules {
    modules = import ../modules/modules.nix {};
    specialArgs = {
      inherit pkgs;
      lib =
        lib
        // {
          # Overridde mkServiceOptions so that all
          # applications are enabled by default.
          mkServiceOptions = n: ns: rest:
            lib.mkServiceOptions n ns (rest
              // {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                };
              });
        };
    };
  };

  applications = with lib;
    mapAttrs (
      name: value:
        value.meta
        // {
          description = value.description;
        }
    )
    (removeAttrs apps'.config.applications ["apps" "bootstrap"]);

  appsMd = with lib;
    concatStringsSep "\n" ([
        ''
          # Applications

        ''
      ]
      ++ (mapAttrsToList (
          n: meta:
            ''
              ## ${n}

              ${meta.description}

              ***Type:***
              `${meta._type}`

            ''
            + (optionalString ((meta._type == "helm") && (hasAttrByPath ["repository"] meta)) ''
              ***Chart:***

              Repository: `${meta.repository}`

              Chart: `${meta.chart}`

              Version: `${meta.version}`

            '')
            + (optionalString (meta._type == "kustomize") ''
              ***Kustomization:***

              URL: `${meta.source}//${meta.path}?rev=${meta.revision}`

            '')
        )
        applications));
in {
  evaled = applications;
  opts = optionsDoc.optionsNix;
  md = optsMd;
  html = docsHtml;
}
