{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sloth-runner;

  # Build sloth-runner package
  sloth-runner = pkgs.buildGoModule rec {
    pname = "sloth-runner";
    version = "0.1.0";

    src = ../../.;

    vendorHash = null; # Will be calculated automatically

    subPackages = [ "cmd/sloth-runner" ];

    # CGO is required for SQLite support
    CGO_ENABLED = 1;

    buildInputs = with pkgs; [ sqlite ];

    nativeBuildInputs = with pkgs; [ pkg-config ];

    ldflags = [
      "-s" "-w"
      "-X main.version=${version}"
    ];

    meta = with lib; {
      description = "A Lua-based task automation and orchestration system";
      homepage = "https://github.com/chalkan3/sloth-runner";
      license = licenses.mit;
      platforms = platforms.linux ++ platforms.darwin;
    };
  };

  # Generate configuration file
  configFile = pkgs.writeText "sloth-runner.yaml" ''
    mode: ${cfg.mode}
    ${optionalString (cfg.mode == "agent") ''
    master: ${cfg.master}
    agent:
      name: ${cfg.agentName}
      bind_address: ${cfg.bindAddress}
      port: ${toString cfg.port}
      ${optionalString (cfg.reportAddress != null) "report_address: ${cfg.reportAddress}"}
    ''}
    ${optionalString (cfg.mode == "master") ''
    master:
      bind_address: ${cfg.bindAddress}
      port: ${toString cfg.port}
    ''}
    ${optionalString (cfg.dataDir != null) "data_dir: ${cfg.dataDir}"}
    ${optionalString (cfg.logLevel != null) "log_level: ${cfg.logLevel}"}
  '';

in {

  ###### Interface

  options.services.sloth-runner = {

    enable = mkEnableOption "Sloth Runner automation system";

    mode = mkOption {
      type = types.enum [ "master" "agent" ];
      default = "agent";
      description = ''
        Operation mode for sloth-runner.
        - master: Runs as master node accepting tasks
        - agent: Runs as agent node executing delegated tasks
      '';
    };

    package = mkOption {
      type = types.package;
      default = sloth-runner;
      defaultText = literalExpression "pkgs.sloth-runner";
      description = "The sloth-runner package to use.";
    };

    master = mkOption {
      type = types.str;
      default = "localhost:50053";
      description = ''
        Master node address (required for agent mode).
        Format: host:port
      '';
    };

    agentName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = literalExpression "config.networking.hostName";
      description = "Name of this agent (used for agent mode).";
    };

    bindAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to bind the gRPC server to.";
    };

    port = mkOption {
      type = types.port;
      default = if cfg.mode == "master" then 50053 else 50051;
      defaultText = literalExpression "50053 for master, 50051 for agent";
      description = "Port for the gRPC server.";
    };

    reportAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "192.168.1.100:50051";
      description = ''
        External address that the master should use to connect back to this agent.
        Only relevant for agent mode. If null, the master will use the source IP.
      '';
    };

    dataDir = mkOption {
      type = types.nullOr types.path;
      default = "/var/lib/sloth-runner";
      description = "Directory for sloth-runner data and state.";
    };

    logLevel = mkOption {
      type = types.nullOr (types.enum [ "debug" "info" "warn" "error" ]);
      default = "info";
      description = "Logging level.";
    };

    user = mkOption {
      type = types.str;
      default = "sloth-runner";
      description = "User account under which sloth-runner runs.";
    };

    group = mkOption {
      type = types.str;
      default = "sloth-runner";
      description = "Group account under which sloth-runner runs.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for sloth-runner port.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/sloth-runner-env";
      description = ''
        Path to file containing environment variables for sloth-runner.
        Useful for secrets like SLOTH_RUNNER_TOKEN.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "--verbose" "--telemetry" ];
      description = "Extra command-line arguments to pass to sloth-runner.";
    };

  };

  ###### Implementation

  config = mkIf cfg.enable {

    # Create user and group
    users.users = mkIf (cfg.user == "sloth-runner") {
      sloth-runner = {
        isSystemUser = true;
        group = cfg.group;
        description = "Sloth Runner service user";
        home = cfg.dataDir;
        createHome = true;
      };
    };

    users.groups = mkIf (cfg.group == "sloth-runner") {
      sloth-runner = {};
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    # Open firewall if requested
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # SystemD service
    systemd.services."sloth-runner-${cfg.mode}" = {
      description = "Sloth Runner ${cfg.mode} service";
      documentation = [ "https://github.com/chalkan3/sloth-runner" ];

      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        ExecStart =
          let
            args = if cfg.mode == "master" then [
              "master"
              "--bind-address" cfg.bindAddress
              "--port" (toString cfg.port)
            ] else [
              "agent"
              "start"
              "--name" cfg.agentName
              "--master" cfg.master
              "--bind-address" cfg.bindAddress
              "--port" (toString cfg.port)
            ] ++ (optionals (cfg.reportAddress != null) [
              "--report-address" cfg.reportAddress
            ]) ++ cfg.extraArgs;
          in
          "${cfg.package}/bin/sloth-runner ${concatStringsSep " " args}";

        # Environment
        Environment = [
          "SLOTH_RUNNER_MODE=${cfg.mode}"
          "SLOTH_RUNNER_DATA_DIR=${cfg.dataDir}"
        ] ++ (optional (cfg.mode == "agent") "SLOTH_RUNNER_MASTER_ADDR=${cfg.master}");

        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;

        # Security
        WorkingDirectory = cfg.dataDir;

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5s";

        # Process limits
        LimitNOFILE = 65536;

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Logging
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "sloth-runner-${cfg.mode}";
      };

      # Health check (optional)
      unitConfig = {
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
    };

    # Install sloth-runner binary globally
    environment.systemPackages = [ cfg.package ];

  };

  meta.maintainers = with lib.maintainers; [ ];

}
