# Sloth Runner NixOS Module

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-23.11+-blue.svg)](https://nixos.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix Flakes](https://img.shields.io/badge/Nix-Flakes-informational)](https://nixos.wiki/wiki/Flakes)

**Declarative NixOS module for deploying and managing Sloth Runner**

[Features](#features) • [Quick Start](#quick-start) • [Documentation](#documentation) • [Examples](#examples)

</div>

---

## Overview

This repository provides a native **NixOS module** for [Sloth Runner](https://github.com/chalkan3/sloth-runner), a powerful Lua-based task automation and orchestration system. Deploy and manage Sloth Runner using NixOS's declarative configuration paradigm with full SystemD integration, security hardening, and automatic dependency management.

### What is Sloth Runner?

Sloth Runner is a modern automation platform that combines:
- **Lua-based DSL** for workflow definition
- **Distributed execution** via master-agent architecture
- **Built-in modules** for common operations (file, package, service management)
- **Real-time telemetry** and monitoring
- **State management** and idempotency

### Why Use This Module?

✅ **Declarative Configuration** - Define everything in `configuration.nix`
✅ **Native Integration** - Full SystemD, firewall, and journaling support
✅ **Security Hardening** - Process isolation, filesystem protection, privilege separation
✅ **Production Ready** - Automatic restarts, health checks, and monitoring
✅ **Rollback Support** - Use NixOS generations to revert changes instantly
✅ **Zero Dependencies** - Module handles all installation and configuration

---

## Features

### 🎯 Core Capabilities

- **Dual Mode Operation**: Run as master (coordinator) or agent (worker)
- **Automatic Service Management**: SystemD units with proper dependencies
- **Network Configuration**: Firewall rules, port binding, external addresses
- **Security Features**: User isolation, read-only filesystem, no privilege escalation
- **Secrets Management**: Environment file support for sensitive configuration
- **Logging Integration**: Native journald logging with structured output
- **Health Monitoring**: Automatic restart on failure with backoff
- **Resource Limits**: Configurable file descriptors and process limits

### 🔐 Security

This module implements defense-in-depth security:

| Layer | Implementation |
|-------|----------------|
| User Isolation | Dedicated `sloth-runner` system user |
| Filesystem | Read-only root, private `/tmp`, restricted `/var` |
| Privileges | `NoNewPrivileges`, drops all capabilities |
| Network | Configurable firewall integration |
| Process | Separate PID namespace, resource limits |

### 📊 Operations

- **Service Control**: Standard `systemctl` commands
- **Log Management**: `journalctl` integration with filtering
- **Configuration Updates**: `nixos-rebuild` workflow
- **Rollback**: NixOS generation management
- **Health Checks**: Built-in startup and runtime validation

---

## Quick Start

### Prerequisites

- NixOS 23.11 or later (unstable supported)
- Root/sudo access
- Basic familiarity with NixOS modules

### Installation

#### Method 1: Flakes (Recommended)

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sloth-runner-nixos = {
      url = "github:chalkan3/sloth-runner-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sloth-runner-nixos, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sloth-runner-nixos.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Configure in `configuration.nix`:

```nix
services.sloth-runner = {
  enable = true;
  mode = "agent";
  master = "192.168.1.29:50053";
  openFirewall = true;
};
```

Apply:

```bash
sudo nixos-rebuild switch --flake .#myhost
```

#### Method 2: Direct Import

```nix
{ config, pkgs, ... }:

{
  imports = [
    (fetchGit {
      url = "https://github.com/chalkan3/sloth-runner-nixos";
      ref = "main";
    } + "/modules/sloth-runner.nix")
  ];

  services.sloth-runner = {
    enable = true;
    mode = "agent";
    master = "192.168.1.29:50053";
    openFirewall = true;
  };
}
```

---

## Configuration

### Master Node

```nix
services.sloth-runner = {
  enable = true;
  mode = "master";

  # Network
  port = 50053;
  bindAddress = "0.0.0.0";

  # Storage
  dataDir = "/var/lib/sloth-runner";

  # Logging
  logLevel = "info";

  # Security
  openFirewall = true;
};
```

### Agent Node

```nix
services.sloth-runner = {
  enable = true;
  mode = "agent";

  # Identity
  agentName = config.networking.hostName;

  # Master connection
  master = "master.example.com:50053";

  # Network
  port = 50051;
  bindAddress = "0.0.0.0";
  reportAddress = "203.0.113.10:50051";  # Public IP if behind NAT

  # Security
  openFirewall = true;
  environmentFile = "/run/secrets/sloth-runner";
};
```

### Available Options

<details>
<summary><b>Click to expand full option reference</b></summary>

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable Sloth Runner service |
| `mode` | enum | `"agent"` | Operation mode: `"master"` or `"agent"` |
| `package` | package | auto | Sloth Runner package to use |
| `master` | string | `"localhost:50053"` | Master address (for agent mode) |
| `agentName` | string | hostname | Agent identifier |
| `bindAddress` | string | `"0.0.0.0"` | gRPC bind address |
| `port` | port | 50053/50051 | gRPC port (master/agent) |
| `reportAddress` | string? | null | External callback address |
| `dataDir` | path | `/var/lib/sloth-runner` | Data directory |
| `logLevel` | enum | `"info"` | Log level: debug/info/warn/error |
| `user` | string | `"sloth-runner"` | Service user |
| `group` | string | `"sloth-runner"` | Service group |
| `openFirewall` | boolean | `false` | Auto-configure firewall |
| `environmentFile` | path? | null | Secrets file |
| `extraArgs` | list | `[]` | Additional CLI arguments |

</details>

---

## Usage

### Service Management

```bash
# Check status
systemctl status sloth-runner-agent

# View logs (follow)
journalctl -u sloth-runner-agent -f

# View logs (last 100 lines)
journalctl -u sloth-runner-agent -n 100

# Restart service
systemctl restart sloth-runner-agent

# Stop service
systemctl stop sloth-runner-agent
```

### Configuration Updates

```bash
# Test configuration (doesn't activate)
sudo nixos-rebuild test

# Apply configuration
sudo nixos-rebuild switch

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# List generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
```

### Running Tasks

Once agents are deployed, submit workflows from master:

```bash
# List available agents
sloth-runner agent list

# Run workflow on specific agent
sloth-runner run my-workflow \
  --file workflow.sloth \
  --delegate-to my-agent \
  --yes

# Run with variables
sloth-runner run deploy \
  --file deploy.sloth \
  --var "env=production" \
  --delegate-to prod-agent \
  --yes
```

---

## Examples

Comprehensive examples are available in the [`examples/`](examples/) directory:

### [Master Node Configuration](examples/master.nix)

Complete setup for a Sloth Runner master node with monitoring and firewall configuration.

### [Agent Node Configuration](examples/agent.nix)

Standard agent deployment with common tools and automatic startup.

### [Multi-Agent Setup](examples/multi-agent.nix)

Advanced configuration for running multiple agents on a single host.

---

## Architecture

```
┌─────────────────────────────────────┐
│         Master Node                 │
│    (Coordinator & Task Queue)       │
│         Port: 50053                 │
└──────────────┬──────────────────────┘
               │
               │ gRPC Communication
               │
    ┌──────────┼──────────┬───────────┐
    │          │          │           │
┌───▼───┐  ┌──▼────┐  ┌──▼────┐  ┌───▼───┐
│Agent 1│  │Agent 2│  │Agent 3│  │Agent N│
│:50051 │  │:50051 │  │:50051 │  │:50051 │
└───────┘  └───────┘  └───────┘  └───────┘
  Worker     Worker     Worker     Worker
  Nodes      Nodes      Nodes      Nodes
```

### Components

- **Master**: Accepts workflow submissions, coordinates execution, manages agent registry
- **Agent**: Executes delegated tasks, reports status, handles local operations
- **gRPC**: High-performance RPC for master-agent communication
- **SQLite**: State persistence and workflow history

---

## Advanced Topics

### Using Secrets

Store sensitive configuration outside the Nix store:

```nix
services.sloth-runner = {
  enable = true;
  environmentFile = "/run/secrets/sloth-runner";
};
```

Create `/run/secrets/sloth-runner`:

```bash
SLOTH_RUNNER_TOKEN=your-secret-token
SLOTH_RUNNER_API_KEY=your-api-key
```

### Custom Package Build

Override the default package:

```nix
services.sloth-runner = {
  enable = true;
  package = pkgs.sloth-runner.overrideAttrs (old: {
    version = "custom";
    src = pkgs.fetchFromGitHub {
      owner = "your-fork";
      repo = "sloth-runner";
      rev = "custom-branch";
      sha256 = "...";
    };
  });
};
```

### NixOS Containers

Deploy isolated agents using containers:

```nix
containers.agent1 = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "192.168.100.1";
  localAddress = "192.168.100.10";

  config = { ... }: {
    imports = [ sloth-runner-nixos.nixosModules.default ];

    services.sloth-runner = {
      enable = true;
      mode = "agent";
      agentName = "container-agent-1";
      master = "192.168.100.1:50053";
    };
  };
};
```

### Monitoring Integration

Example Prometheus configuration:

```nix
services.sloth-runner = {
  enable = true;
  extraArgs = [ "--telemetry" "--metrics-port" "9090" ];
};

services.prometheus = {
  enable = true;
  scrapeConfigs = [{
    job_name = "sloth-runner";
    static_configs = [{
      targets = [ "localhost:9090" ];
    }];
  }];
};
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check service status
systemctl status sloth-runner-agent

# View full logs
journalctl -u sloth-runner-agent -n 50 --no-pager

# Check configuration syntax
nixos-rebuild dry-build
```

### Network Issues

```bash
# Verify port binding
sudo ss -tlnp | grep 50051

# Check firewall rules
sudo nft list ruleset | grep 50051

# Test connectivity to master
nc -zv master-host 50053
```

### Permission Problems

```bash
# Check data directory
ls -la /var/lib/sloth-runner

# Verify user exists
id sloth-runner

# Check service user
systemctl show sloth-runner-agent | grep User
```

### Agent Not Registering

```bash
# Verify master address
systemctl cat sloth-runner-agent | grep MASTER

# Check agent logs for connection errors
journalctl -u sloth-runner-agent | grep -i "connect\|register\|master"

# Test network path
ping master-host
traceroute master-host
```

---

## Development

### Building Locally

```bash
# Enter development shell
nix develop

# Build package
nix build .#sloth-runner

# Run binary
./result/bin/sloth-runner --version
```

### Testing Changes

```bash
# Test in VM
nixos-rebuild build-vm -I nixos-config=./examples/agent.nix

# Run VM
./result/bin/run-nixos-vm

# Test configuration without activation
sudo nixos-rebuild test
```

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Test changes with `nixos-rebuild test`
4. Update documentation if needed
5. Commit with conventional commits
6. Open a pull request

---

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/chalkan3/sloth-runner-nixos/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chalkan3/sloth-runner-nixos/discussions)
- **Main Project**: [Sloth Runner](https://github.com/chalkan3/sloth-runner)

---

## Related Projects

- **[Sloth Runner](https://github.com/chalkan3/sloth-runner)** - Main automation engine
- **[NixOS](https://nixos.org/)** - The Purely Functional Linux Distribution
- **[nixpkgs](https://github.com/NixOS/nixpkgs)** - Nix Packages collection

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built for the [NixOS](https://nixos.org/) ecosystem
- Inspired by declarative infrastructure patterns
- Thanks to the Nix community for tools and guidance

---

<div align="center">

**[⬆ Back to Top](#sloth-runner-nixos-module)**

Made with ❤️ for the NixOS community

</div>
