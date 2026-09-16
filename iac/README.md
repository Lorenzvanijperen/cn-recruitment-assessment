# Infrastructure as Code

Terraform is organized into the agreed deployment boundaries:

- `bootstrap/state/`
- `bootstrap/shared/`
- `bootstrap/identity/`
- `application/`

The state and shared bootstrap roots are implemented and documented in
[`bootstrap/README.md`](bootstrap/README.md). Later tickets implement the
identity and application roots.
