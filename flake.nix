{
  description = "An rsync container image created using Nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {self, ...} @ inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
      };

      pkgs_arm64 = import inputs.nixpkgs {
        system = "aarch64-linux";
      };

      rsync_world = {pkgs}:
        pkgs.writeShellScriptBin ''rsync_world'' ''
          # check if the variable is defined
          # if defined check if enabled and only rsync world if dest dir is empty
          if [ -z ''${ONLY_SYNC_EMPTY+x}]; then
            if [ "$ONLY_SYNC_EMPTY" == "true" ]; then
              set -e
              [ "$(${pkgs.coreutils}/bin/ls -A $WORLD_PATH)" ] || ${pkgs.rsync}/bin/rsync -av "$WORLD_STATE_PATH/" "$WORLD_PATH/"
              set +e
              exit 0
            fi
          fi

          ${pkgs.rsync}/bin/rsync -av "$WORLD_STATE_PATH/" "$WORLD_PATH/"
        '';

      container_x86_64 = pkgs.dockerTools.buildLayeredImage {
        name = "rsync";
        tag = "latest-x86_64";
        config.Cmd = ["/bin/rsync"];
        contents = pkgs.buildEnv {
          name = "image-root";
          paths = with pkgs; [
            dockerTools.caCertificates
            (rsync_world {inherit pkgs;})
          ];
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };

      container_aarch64 = pkgs.pkgsCross.aarch64-multiplatform.dockerTools.buildLayeredImage {
        name = "rsync";
        tag = "latest-aarch64";
        config.Cmd = ["/bin/rsync"];
        contents = pkgs.pkgsCross.aarch64-multiplatform.buildEnv {
          name = "image-root";
          paths = with pkgs.pkgsCross.aarch64-multiplatform; [
            dockerTools.caCertificates
            (rsync_world {pkgs = pkgs_arm64;})
          ];
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };
    in {
      packages = {
        container_x86_64 = container_x86_64;
        container_aarch64 = container_aarch64;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.just
          pkgs.podman
        ];
      };
    });
}
