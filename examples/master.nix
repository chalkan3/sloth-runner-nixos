# Example: Sloth Runner Master Node Configuration
#
# This example shows how to configure a NixOS system as a Sloth Runner master node.
# The master node accepts task submissions and coordinates agent execution.

{ config, pkgs, ... }:

{
  imports = [
    ../modules/sloth-runner.nix
  ];

  # Configure sloth-runner as master
  services.sloth-runner = {
    enable = true;
    mode = "master";

    # Network configuration
    bindAddress = "0.0.0.0";  # Listen on all interfaces
    port = 50053;              # Default master port

    # Open firewall for incoming connections
    openFirewall = true;

    # Data directory
    dataDir = "/var/lib/sloth-runner";

    # Logging
    logLevel = "info";

    # Optional: Extra arguments
    # extraArgs = [ "--telemetry" "--metrics-port" "9090" ];
  };

  # Optional: Configure firewall rules if not using openFirewall
  # networking.firewall.allowedTCPPorts = [ 50053 ];

  # Optional: Add monitoring
  # services.prometheus.exporters.sloth-runner = {
  #   enable = true;
  #   port = 9090;
  # };
}
