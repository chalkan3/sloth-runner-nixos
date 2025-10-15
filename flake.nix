{
  description = "NixOS module for Sloth Runner - Lua-based task automation system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Systems to support
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Build sloth-runner package
        sloth-runner = pkgs.buildGoModule rec {
          pname = "sloth-runner";
          version = "0.1.0";

          # Point to parent directory (main sloth-runner repo)
          src = ../.;

          vendorHash = null; # Will be calculated on first build

          subPackages = [ "cmd/sloth-runner" ];

          # CGO is required for SQLite
          CGO_ENABLED = 1;

          buildInputs = with pkgs; [ sqlite ];
          nativeBuildInputs = with pkgs; [ pkg-config ];

          ldflags = [
            "-s"
            "-w"
            "-X main.version=${version}"
          ];

          meta = with pkgs.lib; {
            description = "Lua-based task automation and orchestration system";
            homepage = "https://github.com/chalkan3/sloth-runner";
            license = licenses.mit;
            platforms = platforms.linux ++ platforms.darwin;
            maintainers = [ ];
          };
        };

      in
      {
        # Package outputs
        packages = {
          default = sloth-runner;
          sloth-runner = sloth-runner;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
            sqlite
            pkg-config
          ];

          shellHook = ''
            echo "Sloth Runner NixOS Module Development"
            echo "======================================"
            echo ""
            echo "Available commands:"
            echo "  - nixos-rebuild test    # Test configuration"
            echo "  - nixos-rebuild switch  # Apply configuration"
            echo ""
            echo "See examples/ for configuration samples"
          '';
        };

        # Apps that can be run with 'nix run'
        apps.default = {
          type = "app";
          program = "${sloth-runner}/bin/sloth-runner";
        };
      }
    ) // {
      # NixOS module output (system-independent)
      nixosModules = {
        default = import ./modules/sloth-runner.nix;
        sloth-runner = import ./modules/sloth-runner.nix;
      };

      # Overlay for adding sloth-runner to nixpkgs
      overlays.default = final: prev: {
        sloth-runner = self.packages.${final.system}.sloth-runner;
      };

      # Example configurations
      nixosConfigurations = {
        # Example master node
        master-example = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            {
              services.sloth-runner = {
                enable = true;
                mode = "master";
                port = 50053;
                bindAddress = "0.0.0.0";
                openFirewall = true;
              };
            }
          ];
        };

        # Example agent node
        agent-example = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            {
              services.sloth-runner = {
                enable = true;
                mode = "agent";
                master = "192.168.1.29:50053";
                agentName = "example-agent";
                port = 50051;
                bindAddress = "0.0.0.0";
                openFirewall = true;
              };
            }
          ];
        };
      };

      # Hydra jobs for CI
      hydraJobs = {
        inherit (self) packages;
      };
    };
}
