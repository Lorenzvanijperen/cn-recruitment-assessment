# Infrastructure as Code

Terraform is organized into the agreed deployment boundaries:

- `bootstrap/state/`
- `bootstrap/shared/`
- `bootstrap/identity/`
- `application/`

The state, shared, and workspace-driven identity bootstrap roots are implemented
and documented in [`bootstrap/README.md`](bootstrap/README.md).

The workspace-driven [`application/`](application/) root defines both
deployment environments. It reuses the environment resource group created by
Identity Bootstrap and the registry created by Shared Bootstrap. Each
environment receives isolated networking, private PostgreSQL connectivity, an
environment Key Vault, Container Apps API and migration job, and a 365-day Log
Analytics workspace.
