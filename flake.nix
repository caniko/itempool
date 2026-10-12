{
  description = "Flake for the itempool crate";

  inputs = {
    harbor.url = "git+https://github.com/caniko/harbor.git?ref=feat/harbor-monorepo-components&rev=e8b1996580e4ecd51dd402edf4a16d9df88e3a1b";
    nixpkgs.follows = "harbor/nixpkgs";
    rust-overlay.follows = "harbor/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    harbor,
    flake-utils,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs =
        import (
          if system == "x86_64-darwin"
          then harbor.inputs.nixpkgs-darwin
          else nixpkgs
        ) {
          inherit system;
          overlays = [(import rust-overlay)];
        };

      inherit (pkgs) lib;

      toolchain = harbor.lib.rust.mkToolchain {
        inherit pkgs;
        toolchainProfile = "stable";
      };
      inherit (toolchain) rustToolchain craneLib;
      treefmtEval = harbor.inputs.treefmt-nix.lib.evalModule pkgs {
        imports = [harbor.treefmtModules.core-nix harbor.treefmtModules.core-toml harbor.treefmtModules.rust-rust];
        projectRootFile = "flake.nix";
        programs.rustfmt.package = rustToolchain;
      };
      buildCache = harbor.lib.rust.mkBuildCachePolicy {
        inherit pkgs;
        sccachePackage = harbor.packages.${system}.rust-sccache;
        cacheRoot = null;
        ephemeralFallback = true;
        namespaceScope = "canix-rust";
        namespaceGeneration = 5;
      };
      src = craneLib.cleanCargoSource ./.;

      # Common arguments can be set here to avoid repeating them later
      commonArgs = {
        inherit src;
        strictDeps = true;

        buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          pkgs.libiconv
        ];
      };

      # Build *just* the cargo dependencies, so we can reuse
      # all of that work (e.g. via cachix) when running in CI
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      # Build the actual crate itself, reusing the dependency
      # artifacts from above.
      my-crate = buildCache.withRustCache {
        package = craneLib.buildPackage (commonArgs
          // {
            inherit cargoArtifacts;
          });
      };
    in {
      formatter = treefmtEval.config.build.wrapper;
      checks = {
        # Build the crate as part of `nix flake check` for convenience
        inherit my-crate;

        # Run clippy (and deny all warnings) on the crate source,
        # again, reusing the dependency artifacts from above.
        my-crate-clippy = craneLib.cargoClippy (commonArgs
          // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

        # Check formatting
        my-crate-fmt = treefmtEval.config.build.check self;

        # Run tests
        my-crate-nextest = craneLib.cargoNextest (commonArgs
          // {
            inherit cargoArtifacts;
            partitions = 1;
            partitionType = "count";
          });
      };

      packages = {
        default = my-crate;
      };

      apps.default = flake-utils.lib.mkApp {
        drv = my-crate;
      };

      devShells.default = craneLib.devShell {
        # Inherit inputs from checks.
        checks = self.checks.${system};

        # Extra inputs can be added here; cargo and rustc are provided by default.
        packages = [treefmtEval.config.build.wrapper];
      };
    });
}
