# Installation Guide

## Prerequisites

- NixOS system (tested on 23.11 and unstable)
- Root/sudo access
- Basic familiarity with NixOS configuration

## Installation Methods

### Method 1: Direct Import (Recommended for Testing)

1. **Clone this repository**:
   ```bash
   git clone https://github.com/chalkan3/sloth-runner-nixos.git /etc/nixos/sloth-runner-nixos
   ```

2. **Add to your configuration.nix**:
   ```nix
   { config, pkgs, ... }:

   {
     imports = [
       /etc/nixos/sloth-runner-nixos/modules/sloth-runner.nix
     ];

     services.sloth-runner = {
       enable = true;
       mode = "agent";  # or "master"
       master = "192.168.1.29:50053";
       openFirewall = true;
     };
   }
   ```

3. **Apply configuration**:
   ```bash
   sudo nixos-rebuild switch
   ```

### Method 2: Using Flakes (Recommended for Production)

1. **Enable flakes** in your NixOS configuration:
   ```nix
   { config, pkgs, ... }:

   {
     nix.settings.experimental-features = [ "nix-command" "flakes" ];
   }
   ```

2. **Create or update your flake.nix**:
   ```nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
       sloth-runner-nixos.url = "github:chalkan3/sloth-runner-nixos";
     };

     outputs = { self, nixpkgs, sloth-runner-nixos }: {
       nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [
           sloth-runner-nixos.nixosModules.default
           {
             services.sloth-runner = {
               enable = true;
               mode = "agent";
               master = "192.168.1.29:50053";
               openFirewall = true;
             };
           }
         ];
       };
     };
   }
   ```

3. **Apply configuration**:
   ```bash
   sudo nixos-rebuild switch --flake .#myhost
   ```

### Method 3: Local Development

1. **Navigate to this directory**:
   ```bash
   cd sloth-runner-nixos
   ```

2. **Enter development shell**:
   ```bash
   nix develop
   ```

3. **Test configuration**:
   ```bash
   # Copy example
   cp examples/agent.nix /tmp/test-config.nix

   # Edit as needed
   vim /tmp/test-config.nix

   # Test (won't activate)
   sudo nixos-rebuild test -I nixos-config=/tmp/test-config.nix
   ```

## Quick Setup Examples

### Master Node

```nix
services.sloth-runner = {
  enable = true;
  mode = "master";
  port = 50053;
  bindAddress = "0.0.0.0";
  dataDir = "/var/lib/sloth-runner";
  logLevel = "info";
  openFirewall = true;
};
```

Apply:
```bash
sudo nixos-rebuild switch
systemctl status sloth-runner-master
```

### Agent Node

```nix
services.sloth-runner = {
  enable = true;
  mode = "agent";
  agentName = "my-agent";
  master = "192.168.1.29:50053";
  port = 50051;
  bindAddress = "0.0.0.0";
  reportAddress = "192.168.64.2:50051";  # Optional: external IP
  openFirewall = true;
};
```

Apply:
```bash
sudo nixos-rebuild switch
systemctl status sloth-runner-agent
```

## Verification

### Check Service Status

```bash
# For agent
systemctl status sloth-runner-agent

# For master
systemctl status sloth-runner-master
```

### View Logs

```bash
# Follow logs
journalctl -u sloth-runner-agent -f

# Last 100 lines
journalctl -u sloth-runner-agent -n 100
```

### Test Connectivity

```bash
# Check port is listening
ss -tlnp | grep 50051

# Test from master (for agent)
telnet agent-host 50051

# List agents (from master)
sloth-runner agent list
```

## Post-Installation

### 1. Verify Agent Registration

On the master node:
```bash
sloth-runner agent list
```

You should see your agent listed.

### 2. Run a Test Task

Create a simple test workflow:
```lua
-- test.sloth
local hello = task("hello")
    :description("Test task")
    :command(function(this, params)
        print("Hello from agent!")
        return true, "Success"
    end)
    :build()

workflow.define("test")
    :description("Test workflow")
    :version("1.0.0")
    :tasks({ hello })
```

Run it:
```bash
sloth-runner run test \
  --file test.sloth \
  --delegate-to my-agent \
  --yes
```

### 3. Configure Automatic Start

The module automatically configures systemd to start on boot. To verify:

```bash
systemctl is-enabled sloth-runner-agent
# Should output: enabled
```

## Troubleshooting

### Service Won't Start

1. Check configuration syntax:
   ```bash
   nixos-rebuild dry-build
   ```

2. View detailed error logs:
   ```bash
   journalctl -u sloth-runner-agent -n 100 --no-pager
   ```

3. Check file permissions:
   ```bash
   ls -la /var/lib/sloth-runner
   ```

### Network Issues

1. Verify firewall is open:
   ```bash
   sudo nft list ruleset | grep 50051
   ```

2. Test port binding:
   ```bash
   sudo ss -tlnp | grep 50051
   ```

3. Check connectivity:
   ```bash
   nc -zv master-host 50053
   ```

### Agent Not Registering

1. Check master address in config:
   ```bash
   systemctl cat sloth-runner-agent | grep master
   ```

2. Verify network connectivity:
   ```bash
   ping master-host
   telnet master-host 50053
   ```

3. Check agent logs:
   ```bash
   journalctl -u sloth-runner-agent -f
   ```

## Updating

### Update via Flakes

```bash
nix flake update
sudo nixos-rebuild switch --flake .#myhost
```

### Update via Direct Import

```bash
cd /etc/nixos/sloth-runner-nixos
git pull
sudo nixos-rebuild switch
```

## Uninstallation

1. **Remove from configuration**:
   ```nix
   services.sloth-runner.enable = false;
   ```

2. **Apply changes**:
   ```bash
   sudo nixos-rebuild switch
   ```

3. **Optional: Remove data**:
   ```bash
   sudo rm -rf /var/lib/sloth-runner
   ```

## Next Steps

- Read the [README](README.md) for detailed configuration options
- Check [examples/](examples/) for more configuration patterns
- Visit the [Sloth Runner documentation](https://github.com/chalkan3/sloth-runner) for workflow examples

## Support

- **Issues**: https://github.com/chalkan3/sloth-runner-nixos/issues
- **Discussions**: https://github.com/chalkan3/sloth-runner-nixos/discussions
- **Main Project**: https://github.com/chalkan3/sloth-runner
