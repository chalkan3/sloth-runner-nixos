# Example: Sloth Runner Agent Node Configuration
#
# This example shows how to configure a NixOS system as a Sloth Runner agent node.
# Agent nodes connect to a master and execute delegated tasks.

{ config, pkgs, ... }:

{
  imports = [
    ../modules/sloth-runner.nix
  ];

  # Configure sloth-runner as agent
  services.sloth-runner = {
    enable = true;
    mode = "agent";

    # Agent identification
    agentName = "vm-nixos";  # Name this agent (defaults to hostname)

    # Master connection
    master = "192.168.1.29:50053";  # Address of the master node

    # Network configuration
    bindAddress = "0.0.0.0";         # Listen on all interfaces
    port = 50051;                     # Default agent port

    # Optional: Specify external address for master callback
    # Useful when behind NAT or in complex network setups
    reportAddress = "192.168.64.2:50051";

    # Open firewall for master connections
    openFirewall = true;

    # Data directory
    dataDir = "/var/lib/sloth-runner";

    # Logging
    logLevel = "info";

    # Optional: Extra arguments
    # extraArgs = [ "--telemetry" ];
  };

  # Ensure agent can communicate with master
  networking.firewall.allowedTCPPorts = [ 50051 ];

  # Optional: Install commonly used tools for task execution
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    jq
    vim
  ];

  # Optional: Configure automatic updates
  # system.autoUpgrade = {
  #   enable = true;
  #   allowReboot = false;
  # };
}
