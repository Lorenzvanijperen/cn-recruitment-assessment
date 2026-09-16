# Infrastructure as Code

Terraform is organized into the agreed deployment boundaries:

- `bootstrap/state/`
- `bootstrap/shared/`
- `bootstrap/identity/`
- `application/`

The state, shared, and workspace-driven identity bootstrap roots are implemented
and documented in [`bootstrap/README.md`](bootstrap/README.md). A later ticket
implements the application root.
