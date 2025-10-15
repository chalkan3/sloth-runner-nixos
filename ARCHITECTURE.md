# Architecture and Build Strategy

## Overview

This document explains the architectural decisions and build strategy for the Sloth Runner NixOS module, specifically focusing on how package builds are handled efficiently.

## Problem: Build Location Matters

In the initial design, the package build was defined inline within the module:

```nix
# ❌ Problematic approach
let
  sloth-runner = pkgs.buildGoModule rec {
    pname = "sloth-runner";
    # ... build definition
  };
in
{
  options.services.sloth-runner = {
    # ... options
  };
}
```

### Issues with Inline Package Definition

1. **No Binary Cache**: Builds happen locally on every machine
2. **No Reusability**: Package can't be used outside the module
3. **No Cross-Compilation**: Difficult to build for different architectures
4. **Poor CI/CD**: Can't pre-build and cache binaries
5. **Slow Deployments**: Every `nixos-rebuild` triggers a full rebuild

## Solution: Separated Package Architecture

We've restructured to follow NixOS best practices:

```
sloth-runner-nixos/
├── packages/
│   ├── sloth-runner.nix    # Package definition
│   └── default.nix         # Package exports
├── modules/
│   └── sloth-runner.nix    # NixOS module (references package)
├── flake.nix               # Flake with overlay
└── examples/               # Example configurations
```

### How It Works

#### 1. Package Definition (`packages/sloth-runner.nix`)

```nix
{ buildGoModule, fetchFromGitHub, ... }:

buildGoModule rec {
  pname = "sloth-runner";
  version = "0.1.0";

  # Fetch from GitHub (not local source)
  src = fetchFromGitHub {
    owner = "chalkan3";
    repo = "sloth-runner";
    rev = "master";
    sha256 = "...";
  };

  # Build configuration
  # ...
}
```

**Key Points:**
- Self-contained package definition
- Uses `fetchFromGitHub` for reproducible source
- Can be built independently: `nix build .#sloth-runner`
- Eligible for binary caching

#### 2. Flake Exports (`flake.nix`)

```nix
{
  outputs = { self, nixpkgs, ... }:
    {
      # Package outputs
      packages.<system>.sloth-runner = ...;

      # Overlay for adding to nixpkgs
      overlays.default = final: prev: {
        sloth-runner = self.packages.${final.system}.sloth-runner;
      };

      # NixOS module
      nixosModules.default = import ./modules/sloth-runner.nix;
    };
}
```

**Key Points:**
- Package available as flake output
- Overlay makes `pkgs.sloth-runner` available
- Module references `pkgs.sloth-runner`, not inline build

#### 3. Module References Package (`modules/sloth-runner.nix`)

```nix
{ config, lib, pkgs, ... }:

{
  options.services.sloth-runner = {
    package = mkOption {
      type = types.package;
      default = pkgs.sloth-runner;  # From overlay
      description = "The sloth-runner package to use.";
    };
    # ... other options
  };

  config = mkIf cfg.enable {
    # Use cfg.package instead of inline build
    systemd.services."sloth-runner-${cfg.mode}" = {
      serviceConfig.ExecStart = "${cfg.package}/bin/sloth-runner ...";
    };
  };
}
```

**Key Points:**
- Module doesn't build anything
- References pre-built package from pkgs
- Users can override with custom builds if needed

## Benefits of This Architecture

### 1. Binary Caching

When using a binary cache (Cachix, Hydra, etc.):

```bash
# First user builds (or cache hit)
$ nixos-rebuild switch
# Downloads from cache: 2 seconds

# Without separated package:
$ nixos-rebuild switch
# Full Go build: 5 minutes
```

### 2. Build Once, Deploy Everywhere

```bash
# CI/CD builds the package
$ nix build .#sloth-runner
$ cachix push my-cache ./result

# All machines pull from cache
$ nixos-rebuild switch  # Instant
```

### 3. Cross-Compilation Support

```bash
# Build for ARM64 from x86_64
$ nix build .#sloth-runner --system aarch64-linux

# Build for multiple architectures in CI
$ nix build .#sloth-runner.x86_64-linux
$ nix build .#sloth-runner.aarch64-linux
```

### 4. Package Independence

```nix
# Use package without the module
{
  environment.systemPackages = [ pkgs.sloth-runner ];
}

# Or in a devShell
{
  devShells.default = pkgs.mkShell {
    packages = [ pkgs.sloth-runner ];
  };
}
```

### 5. Easier Testing

```bash
# Test package independently
$ nix build .#sloth-runner
$ ./result/bin/sloth-runner --version

# Test module separately
$ nixos-rebuild test
```

## Usage Patterns

### With Flakes (Automatic Overlay)

```nix
{
  inputs.sloth-runner-nixos.url = "github:chalkan3/sloth-runner-nixos";

  outputs = { self, nixpkgs, sloth-runner-nixos }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        # Overlay adds pkgs.sloth-runner
        { nixpkgs.overlays = [ sloth-runner-nixos.overlays.default ]; }

        # Module uses pkgs.sloth-runner
        sloth-runner-nixos.nixosModules.default

        # Configure
        {
          services.sloth-runner = {
            enable = true;
            mode = "agent";
          };
        }
      ];
    };
  };
}
```

### Without Flakes (Manual Package Import)

```nix
{ config, pkgs, ... }:

let
  sloth-runner-nixos = fetchGit {
    url = "https://github.com/chalkan3/sloth-runner-nixos";
    ref = "main";
  };

  sloth-runner-pkg = pkgs.callPackage "${sloth-runner-nixos}/packages/sloth-runner.nix" { };
in
{
  imports = [ "${sloth-runner-nixos}/modules/sloth-runner.nix" ];

  services.sloth-runner = {
    enable = true;
    package = sloth-runner-pkg;  # Explicit package
    mode = "agent";
  };
}
```

### Custom Package Build

```nix
{
  services.sloth-runner = {
    enable = true;

    # Override with custom build
    package = pkgs.sloth-runner.overrideAttrs (old: {
      version = "custom";
      src = pkgs.fetchFromGitHub {
        owner = "your-fork";
        repo = "sloth-runner";
        rev = "feature-branch";
        sha256 = "...";
      };
    });
  };
}
```

## Build Performance Comparison

| Scenario | Inline Build | Separated Package |
|----------|-------------|-------------------|
| First build | 5 minutes | 5 minutes |
| Rebuild (no changes) | 5 minutes | < 1 second (cache) |
| 10 machines | 50 minutes | 5 minutes + 10 sec |
| CI/CD pre-build | Not possible | Yes, cache for all |
| Cross-compile | Difficult | Native support |
| Package-only update | Full rebuild | Incremental |

## CI/CD Integration Example

```yaml
# .github/workflows/build.yml
name: Build and Cache

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: cachix/install-nix-action@v22
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes

      - uses: cachix/cachix-action@v12
        with:
          name: sloth-runner
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'

      # Build and push to cache
      - run: nix build .#sloth-runner
      - run: cachix push sloth-runner ./result

      # Build for multiple architectures
      - run: |
          nix build .#sloth-runner --system x86_64-linux
          nix build .#sloth-runner --system aarch64-linux
```

Now all machines using this flake will pull pre-built binaries from Cachix instead of building locally.

## Future Enhancements

1. **Hydra Integration**: Automatic builds for all supported systems
2. **Binary Releases**: GitHub releases with pre-built binaries
3. **nixpkgs Submission**: Submit package to official nixpkgs
4. **Multiple Versions**: Support multiple sloth-runner versions
5. **Dev Packages**: Separate unstable/beta builds

## Conclusion

The separated package architecture provides:

- ✅ Faster deployments via binary caching
- ✅ Better separation of concerns
- ✅ Improved CI/CD integration
- ✅ Cross-compilation support
- ✅ Package reusability
- ✅ Standard NixOS practices

This is the recommended approach for all NixOS modules that build software.

## References

- [Nix Package Manager Guide](https://nixos.org/manual/nix/stable/)
- [NixOS Module System](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Binary Caching with Cachix](https://cachix.org/)
