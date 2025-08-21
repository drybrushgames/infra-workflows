# Infrastructure Workflows

Centralized GitHub Actions workflows for deploying services via Tailscale SSH.

## Overview

This repository provides a **reusable deployment workflow** that automatically:
- Connects to your Tailscale network using centralized OAuth credentials
- Auto-detects service name and deployment path from repository name
- Builds and deploys services to your OVH server
- Performs health checks on service-specific ports

## Quick Start

### For New Services

1. **Create provision workflow** in your service repo at `.github/workflows/provision.yml`:

```yaml
name: Provision (one-time)
on:
  workflow_dispatch:
    inputs:
      type:
        description: "node|go|python"
        required: true
        default: node
      mode:
        description: "tcp|socket (start with tcp)"
        required: true
        default: tcp

jobs:
  provision:
    uses: nhillen/infra-workflows/.github/workflows/provision-reusable.yml@main
    with:
      type:  ${{ inputs.type }}
      mode:  ${{ inputs.mode }}
```

2. **Create deployment workflow** in your service repo at `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: nhillen/infra-workflows/.github/workflows/deploy-reusable.yml@main
```

3. **Add required files** to your service repo:
   - `Makefile` with `build` target (can be no-op)
   - `/health` endpoint (returns 200 OK)

4. **Run provision workflow** (one-time):
   - Go to Actions → Provision (one-time)
   - Choose service type (node/go/python) and mode (tcp/socket)
   - Click "Run workflow"

5. **Deploy**: Push to main branch to trigger deployment.

That's it! The provision workflow sets up everything on the server, then deployments are automatic.

### For Existing Services

Services already using this workflow: `menagerie`, `pirateplunder`, `quietpm`

To migrate from legacy workflows:
1. Replace your deploy job with the simple version above
2. Remove manual input parameters (auto-detected now)
3. Remove Tailscale secrets from service repos (centralized now)

## How It Works

### Auto-Detection
- **Service Name**: `owner/repo-name` → `repo-name`
- **Deployment Path**: `/opt/repo-name`
- **Health Check**: Service-specific ports (8080, 3001, 8000, etc.)

### Centralized Configuration
All Tailscale and server configuration is managed in this `infra-workflows` repository:
- **Tailscale OAuth**: `TAILSCALE_OAUTH_CLIENT_ID` + `TAILSCALE_OAUTH_CLIENT_SECRET`
- **Server Host**: `OVH_HOST` (Tailscale hostname)
- **Environment**: `prod` environment in this repo

### Provision Flow (One-Time)
1. Run provision workflow from service repo Actions
2. Connects to Tailscale and SSH to server
3. Creates `/opt/{service}` directory structure
4. Creates PostgreSQL database for the service
5. Generates `.env` file with database connection
6. Creates `scripts/deploy.sh` deployment script
7. Installs systemd service (TCP or Unix socket mode)
8. Optionally configures Caddy for socket mode

### Deployment Flow (Every Push)
1. Service repo pushes to `main`
2. Calls reusable workflow from `infra-workflows`
3. Workflow connects to Tailscale
4. SSH to `deploy@{OVH_HOST}`
5. Executes `/opt/{service}/scripts/deploy.sh`
6. Restarts systemd service

## Server Setup

### Prerequisites on OVH Server

1. **Create `deploy` user**:
```bash
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy
```

2. **Set up SSH access**:
```bash
# Add Tailscale GitHub runner to authorized_keys
sudo mkdir -p /home/deploy/.ssh
sudo chown deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
```

3. **Create service directories**:
```bash
sudo mkdir -p /opt/{menagerie,pirateplunder,quietpm}
sudo chown -R deploy:deploy /opt/
```

### Service Deployment Scripts

Each service needs a deployment script at `/opt/{service}/scripts/deploy.sh`:

```bash
#!/bin/bash
# Example deployment script
set -e

echo "Deploying {service}..."

# Service-specific deployment logic
# - Pull from git
# - Install dependencies  
# - Build if needed
# - Restart service
# - Health check

echo "Deployment complete!"
```

## Repository Structure

```
infra-workflows/
├── .github/workflows/
│   └── deploy-reusable.yml    # Centralized deployment workflow
└── README.md                  # This file
```

## Configuration

### In This Repository (`infra-workflows`)

Configure in Settings → Environments → `prod`:

**Variables:**
- `OVH_HOST`: Your Tailscale hostname (e.g., `vps-hostname.tail751d97.ts.net`)

**Secrets:**
- `TAILSCALE_OAUTH_CLIENT_ID`: OAuth client ID from Tailscale admin
- `TAILSCALE_OAUTH_CLIENT_SECRET`: OAuth client secret from Tailscale admin

### In Service Repositories

**Required files:**
- `.github/workflows/deploy.yml` (see Quick Start)
- `Makefile` with `build` target
- Health endpoint at `/health` (returns 200 OK)

**Optional:**
- Custom deployment logic via server-side `scripts/deploy.sh`

## Health Checks

The workflow automatically health checks services on their known ports:
- `menagerie`: port 8080
- `pirateplunder`: port 3001  
- `quietpm`: port 8000
- Default: port 8080

Health checks are optional and won't fail the deployment if they don't respond.

## Troubleshooting

### Common Issues

1. **SSH connection failed**: Check Tailscale connectivity and `deploy` user setup
2. **Build failed**: Ensure `Makefile` exists with `build` target (can be no-op)
3. **Health check failed**: Optional - check service is running on expected port
4. **Permission denied**: Ensure `deploy` user has access to `/opt/{service}`

### Debug Steps

1. Check Tailscale connection in workflow logs
2. Verify SSH access: `tailscale ssh deploy@{OVH_HOST}`
3. Check deployment script exists and is executable
4. Test health endpoint manually: `curl http://{OVH_HOST}:{port}/health`

## Adding New Services

1. Create service repository following naming convention
2. Add deployment workflow (see Quick Start)
3. Add `Makefile` and `/health` endpoint
4. Set up `/opt/{service}` directory on server
5. Create deployment script
6. Push to main to test deployment

The reusable workflow will automatically detect the new service and deploy it appropriately.