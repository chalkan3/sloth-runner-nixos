# Default package export
# This allows importing the package with: pkgs.callPackage ./packages { }

{ pkgs ? import <nixpkgs> { } }:

{
  sloth-runner = pkgs.callPackage ./sloth-runner.nix { };
}
