{
  description = "carlosvaz.com - personal blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hugo-bearcub = {
      url = "github:clente/hugo-bearcub";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, hugo-bearcub }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkPerSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;

          source = builtins.path {
            name = "carlosvaz.com-source";
            path = ./.;
            filter =
              path: type:
              let
                root = toString ./.;
                pathString = toString path;
                rel =
                  if pathString == root then
                    ""
                  else
                    lib.removePrefix "${root}/" pathString;
                excludedDirs = [
                  ".direnv"
                  ".git"
                  "content/drafts"
                  "content/posts"
                  "public"
                  "resources"
                ];
                excludedFiles = [
                  ".DS_Store"
                  ".hugo_build.lock"
                  "content/_index.md"
                  "content-org/drafts.org"
                  "result"
                  "themes/hugo-bearcub/.git"
                ];
              in
              !(lib.elem rel excludedFiles
                || lib.any (dir: rel == dir || lib.hasPrefix "${dir}/" rel) excludedDirs
                || lib.hasSuffix ".org.bak" rel);
          };

          emacsWithOxHugo =
            (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages
              (epkgs: [ epkgs.ox-hugo ]);

          exportOrgFile = file: ''
            ${emacsWithOxHugo}/bin/emacs --batch \
              --eval "(require 'ox-hugo)" \
              --eval "(with-current-buffer (find-file-noselect \"${file}\") (org-hugo-export-wim-to-md :all-subtrees))"
          '';

          cleanGenerated = ''
            rm -rf "$SITE_DIR"/public "$SITE_DIR"/resources "$SITE_DIR"/content/drafts
            rm -f "$SITE_DIR"/.hugo_build.lock
            rm -f "$SITE_DIR"/content/posts/*.md "$SITE_DIR"/content/_index.md
          '';

          exportPublished = ''
            ${exportOrgFile "$SITE_DIR/content-org/all-posts.org"}
          '';

          siteDir = "$(${pkgs.git}/bin/git rev-parse --show-toplevel)";

          site = pkgs.stdenvNoCC.mkDerivation {
            pname = "carlosvaz.com";
            version = "unstable";
            src = source;

            dontConfigure = true;
            dontInstall = true;

            buildPhase = ''
              runHook preBuild

              cp -R "$src" source
              chmod -R u+w source
              cd source

              rm -rf themes/hugo-bearcub
              mkdir -p themes
              cp -R ${hugo-bearcub} themes/hugo-bearcub
              chmod -R u+w themes/hugo-bearcub

              SITE_DIR=$PWD
              ${cleanGenerated}
              ${exportPublished}
              ${pkgs.hugo}/bin/hugo --source "$SITE_DIR" --destination "$out" --cleanDestinationDir

              runHook postBuild
            '';
          };

          deploy = pkgs.writeShellScriptBin "deploy" ''
            set -euo pipefail
            SITE_DIR="${siteDir}"
            DEPLOY_TARGET="''${CARLOSVAZ_DEPLOY_TARGET:-root@vaz.one:/var/www/carlosvaz.com/}"
            BUILD_OUT_LINK="''${CARLOSVAZ_BUILD_OUT_LINK:-$SITE_DIR/result}"
            RSYNC_ARGS=()

            if [ -n "''${CARLOSVAZ_DEPLOY_RSYNC_RSH:-}" ]; then
              RSYNC_ARGS+=(-e "$CARLOSVAZ_DEPLOY_RSYNC_RSH")
            fi

            echo ":: Building site with Nix..."
            ${pkgs.nix}/bin/nix build "$SITE_DIR#site" --out-link "$BUILD_OUT_LINK"

            echo ":: Deploying to VPS..."
            ${pkgs.rsync}/bin/rsync -Pacvz --delete --chmod=D755,F644 "''${RSYNC_ARGS[@]}" "$BUILD_OUT_LINK/" "$DEPLOY_TARGET"

            echo ":: Done!"
          '';

          clean = pkgs.writeShellScriptBin "clean" ''
            set -euo pipefail
            SITE_DIR="${siteDir}"

            echo ":: Cleaning generated content..."
            ${cleanGenerated}
          '';

          serve = pkgs.writeShellScriptBin "serve" ''
            set -euo pipefail
            SITE_DIR="${siteDir}"

            export_all() {
              ${cleanGenerated}
              ${exportOrgFile "$SITE_DIR/content-org/all-posts.org"}
              if [ -f "$SITE_DIR/content-org/drafts.org" ]; then
                ${exportOrgFile "$SITE_DIR/content-org/drafts.org"}
              fi
            }

            echo ":: Exporting org → markdown..."
            export_all

            # Watch org files and re-export on change
            (
              ${pkgs.fswatch}/bin/fswatch -o -l 1 \
                -e '.*' -i '\.org$' \
                "$SITE_DIR/content-org" | while read -r; do
                echo ":: Change detected, re-exporting org → markdown..."
                export_all
              done
            ) &
            WATCHER_PID=$!

            cleanup() {
              kill "$WATCHER_PID" 2>/dev/null || true
              wait "$WATCHER_PID" 2>/dev/null || true
              echo ""
              echo ":: Cleaning up generated content..."
              ${cleanGenerated}
            }
            trap cleanup EXIT INT TERM

            echo ":: Starting hugo server (http://localhost:1313)..."
            echo ":: Watching content-org/ for changes..."
            ${pkgs.hugo}/bin/hugo server --source "$SITE_DIR" --buildDrafts
          '';
        in
        {
          devShell = pkgs.mkShell {
            buildInputs = [
              pkgs.hugo
              emacsWithOxHugo
              clean
              deploy
              serve
            ];
          };

          apps = {
            clean = {
              type = "app";
              program = "${clean}/bin/clean";
              meta.description = "Remove generated Hugo and ox-hugo artifacts.";
            };

            deploy = {
              type = "app";
              program = "${deploy}/bin/deploy";
              meta.description = "Build the site and deploy it with rsync.";
            };

            serve = {
              type = "app";
              program = "${serve}/bin/serve";
              meta.description = "Serve the site locally with draft content and org export watching.";
            };
          };

          packages = {
            default = site;
            site = site;
            clean = clean;
            deploy = deploy;
            serve = serve;
          };

          checks = {
            site = site;
          };
        };
    in
    {
      devShells = forAllSystems (system: {
        default = (mkPerSystem system).devShell;
      });

      apps = forAllSystems (system: (mkPerSystem system).apps);

      packages = forAllSystems (system: (mkPerSystem system).packages);

      checks = forAllSystems (system: (mkPerSystem system).checks);
    };
}
