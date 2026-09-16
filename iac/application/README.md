# Environment application stacks

This Terraform root defines the NovaBank `dev` and `prod` application stacks.
The active workspace selects the matching committed YAML file. Any other
workspace fails before resources can be planned.

`prod.yaml` is **defined but not deployed**. It records production-oriented
capacity, high availability, and backup settings so the design is reviewable
without creating production cost.

## Prerequisites

Apply the State, Shared, and Identity Bootstrap roots first. Build and push the
`visit-counter` image to the shared registry before applying this root.

The applying identity needs access to the remote state containers, deployment
rights in the environment resource group, and permission to create the
`AcrPull` assignment on the shared registry. The environment deployment
principal is deliberately scoped only to its resource group, so the initial
apply must use the bootstrap operator until the shared-registry grant is moved
to a separately privileged automation stage. The stack grants the applying
identity permission to write the generated database URL to the environment Key
Vault. Container Apps use a user-assigned managed identity to pull from the
shared registry and read that secret.

## Initialize and review

```sh
terraform -chdir=iac/application init

terraform -chdir=iac/application workspace select -or-create dev
terraform -chdir=iac/application plan -out=dev.tfplan

terraform -chdir=iac/application workspace select -or-create prod
terraform -chdir=iac/application plan -out=prod.tfplan
```

The default `bootstrap` image tag exists only to make pre-deployment plans
reviewable. Supply the immutable digest produced by the deployment workflow
when applying:

```sh
terraform -chdir=iac/application workspace select dev
terraform -chdir=iac/application apply \
  -var='image_reference=crnovabankc770945f.azurecr.io/visit-counter@sha256:<digest>'
```

Do not apply the prod workspace until NovaBank approves a production
deployment.

## Runtime shape

- The API has public HTTPS ingress, but PostgreSQL has no public network path.
- The API and manual `migrate` job read `DATABASE_URL` from the environment Key
  Vault through managed identity.
- The Container Apps environment sends structured application console logs and
  Container Apps system logs to its environment-specific Log Analytics
  workspace. Retention is 365 days.
- The Key Vault public endpoint remains enabled for the local Terraform
  workflow. Restricting it with a private endpoint is a post-PoC hardening step.

## Validate

```sh
terraform -chdir=iac/application fmt -check -recursive
terraform -chdir=iac/application validate

TF_WORKSPACE=dev terraform -chdir=iac/application test \
  -filter=tests/application_stack.tftest.hcl
TF_WORKSPACE=prod terraform -chdir=iac/application test \
  -filter=tests/application_stack.tftest.hcl
TF_WORKSPACE=unsupported terraform -chdir=iac/application test \
  -filter=tests/unsupported_workspace.tftest.hcl
```

Terraform state contains the generated PostgreSQL password and database URL.
Remote state is encrypted by the bootstrap storage account; plans and outputs
do not expose either value.
