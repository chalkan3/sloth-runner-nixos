{ lib
, buildGoModule
, fetchFromGitHub
, pkg-config
, sqlite
}:

buildGoModule rec {
  pname = "sloth-runner";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "chalkan3";
    repo = "sloth-runner";
    rev = "030207bfadbd37acc659de3262720b99e97f278a";  # Pin to specific commit
    hash = "sha256-/n2jwQItC+bsEpnaedc07VgEWUmq1QG5QFK+deHGYvI=";  # SRI format
  };

  # Set to null since the project doesn't vendor dependencies
  # If Go dependencies change, this may need to be set to a proper hash
  # Run: nix build .#sloth-runner 2>&1 | grep "got:" to get the correct hash
  vendorHash = null;

  subPackages = [ "cmd/sloth-runner" ];

  # CGO is required for SQLite support
  CGO_ENABLED = 1;

  buildInputs = [ sqlite ];
  nativeBuildInputs = [ pkg-config ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = "A Lua-based task automation and orchestration system with master-agent architecture";
    longDescription = ''
      Sloth Runner is a powerful automation platform that combines:
      - Lua-based DSL for workflow definition
      - Distributed execution via master-agent architecture
      - Built-in modules for common operations (file, package, service management)
      - Real-time telemetry and monitoring
      - State management and idempotency
    '';
    homepage = "https://github.com/chalkan3/sloth-runner";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "sloth-runner";
  };
}
