# Infrastructure Workflows

Shared GitHub Actions workflows for deploying services via Tailscale SSH.

## Usage

In your service repository, create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Service

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: yourusername/infra-workflows/.github/workflows/deploy-reusable.yml@main
    with:
      service: your-service-name
      path: /opt/your-service
      host: vps-hostname.tail751d97.ts.net
```

## Requirements

- Tailscale OIDC CI configured in your organization
- `deploy` user on target host with sudo access
- Each service has a `make build` command (can no-op)
- Each service has a `./scripts/deploy.sh` script in the deployment path
- Services expose health check on port 8080 (or adjust workflow)

## Service Setup

Each service should have:
1. `Makefile` with `build` target
2. `scripts/deploy.sh` deployment script
3. Health check endpoint (optional)