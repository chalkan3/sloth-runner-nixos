# Example: Multi-Agent Setup on Single Host
#
# This advanced example shows how to run multiple Sloth Runner agents
# on a single NixOS host, each with different configurations.
# This is useful for testing or running multiple isolated agents.

{ config, pkgs, lib, ... }:

let
  # Define agent configurations
  agents = {
    agent1 = {
      port = 50051;
      reportAddress = "192.168.64.2:50051";
    };
    agent2 = {
      port = 50052;
      reportAddress = "192.168.64.2:50052";
    };
  };

  # Master configuration
  masterAddr = "192.168.1.29:50053";

in {
  imports = [
    ../modules/sloth-runner.nix
  ];

  # Note: The default module supports one instance only.
  # For multiple agents, you'll need to either:
  # 1. Use the module as a template and create custom systemd services
  # 2. Use containers/VMs (recommended for production)
  # 3. Extend the module to support multiple instances

  # Example custom service for multiple agents:
  systemd.services = lib.mkMerge (lib.mapAttrsToList (name: cfg: {
    "sloth-runner-${name}" = {
      description = "Sloth Runner Agent: ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = "sloth-runner";
        Group = "sloth-runner";

        ExecStart = ''
          ${pkgs.sloth-runner}/bin/sloth-runner agent start \
            --name ${name} \
            --master ${masterAddr} \
            --bind-address 0.0.0.0 \
            --port ${toString cfg.port} \
            --report-address ${cfg.reportAddress}
        '';

        Restart = "on-failure";
        RestartSec = "5s";

        # Security
        NoNewPrivileges = true;
        PrivateTmp = true;

        # Logging
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "sloth-runner-${name}";
      };
    };
  }) agents);

  # Create user
  users.users.sloth-runner = {
    isSystemUser = true;
    group = "sloth-runner";
    description = "Sloth Runner service user";
  };

  users.groups.sloth-runner = {};

  # Open firewall for all agents
  networking.firewall.allowedTCPPorts =
    lib.mapAttrsToList (name: cfg: cfg.port) agents;

  # Note: For production multi-agent setups, consider:
  # 1. Using NixOS containers (systemd-nspawn)
  # 2. Using microVMs (microvm.nix)
  # 3. Using separate physical/virtual machines
}
