# Package exports
# This allows importing packages with: pkgs.callPackage ./packages { }

{ pkgs ? import <nixpkgs> { } }:

{
  # Binary package (downloads pre-compiled releases) - faster, recommended
  sloth-runner = pkgs.callPackage ./sloth-runner-bin.nix { };
  sloth-runner-bin = pkgs.callPackage ./sloth-runner-bin.nix { };

  # Source package (builds from Go source) - slower, for development
  sloth-runner-source = pkgs.callPackage ./sloth-runner.nix { };
}
