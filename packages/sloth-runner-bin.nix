{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, sqlite
, zlib
}:

let
  version = "8.0.2";

  # Map Nix system to release platform names
  sources = {
    x86_64-linux = {
      url = "https://github.com/chalkan3/sloth-runner/releases/download/v${version}/sloth-runner_v${version}_linux_amd64.tar.gz";
      hash = "sha256-a0F8bGsdbOjiu99PCBk6lQ8rQNeKuki9FRGA0fyqrxQ=";
    };
    aarch64-linux = {
      url = "https://github.com/chalkan3/sloth-runner/releases/download/v${version}/sloth-runner_v${version}_linux_arm64.tar.gz";
      hash = "sha256-gHh4L2dKeY2HmIW2DmuEo202z4qnAdtN1iHzvZG5/YA=";
    };
    x86_64-darwin = {
      url = "https://github.com/chalkan3/sloth-runner/releases/download/v${version}/sloth-runner_v${version}_darwin_amd64.tar.gz";
      hash = "sha256-f+ZCX6qJaovJJJqylppZFANyq+Wfdh+vcbJGPSJT+PI=";
    };
    aarch64-darwin = {
      url = "https://github.com/chalkan3/sloth-runner/releases/download/v${version}/sloth-runner_v${version}_darwin_arm64.tar.gz";
      hash = "sha256-NmG1rvwvHcDcFfRthgLU1pIYF3UH0JDJqoJAP8MgSy0=";
    };
  };

  source = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
stdenv.mkDerivation rec {
  pname = "sloth-runner";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  # For Linux: automatically patch ELF binaries to fix dynamic library dependencies
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  # Runtime dependencies for Linux binaries
  buildInputs = lib.optionals stdenv.isLinux [
    sqlite
    zlib
    stdenv.cc.cc.lib  # libstdc++
  ];

  # Source is a .tar.gz, let Nix extract it automatically
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    # Create bin directory
    mkdir -p $out/bin

    # Install the binary (it's directly in the tarball root)
    install -D -m755 sloth-runner $out/bin/sloth-runner

    runHook postInstall
  '';

  meta = with lib; {
    description = "A Lua-based task automation and orchestration system (pre-compiled binary)";
    longDescription = ''
      Sloth Runner is a powerful automation platform that combines:
      - Lua-based DSL for workflow definition
      - Distributed execution via master-agent architecture
      - Built-in modules for common operations (file, package, service management)
      - Real-time telemetry and monitoring
      - State management and idempotency

      This package uses pre-compiled binaries from GitHub releases for faster installation.
    '';
    homepage = "https://github.com/chalkan3/sloth-runner";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "sloth-runner";
  };
}
