# Azure bootstrap

These Terraform roots establish the one-time Azure foundations in dependency
order:

1. `state` uses local, git-ignored state and creates only the state resource
   group, storage account, and private containers for shared, identity, and
   application state.
2. `shared` uses the `shared-state` remote backend and creates the shared
   resource group, Basic Azure Container Registry, and separate RBAC-enabled
   vaults for deployment and AI-inspection credentials.

Both roots default to North Europe, an EU region that accepts new subscriptions.
Resource names receive a stable suffix derived from the active Azure
subscription unless `name_suffix` is set.

## Prerequisites

- Terraform 1.9 or later
- Azure CLI authenticated to the target subscription
- Permission to create resource groups, role assignments, and the declared
  resources

Confirm the active subscription before applying:

```sh
az account show --query '{name:name, id:id}' --output table
```

## Apply

Run State Bootstrap first:

```sh
terraform -chdir=iac/bootstrap/state init
terraform -chdir=iac/bootstrap/state apply
terraform -chdir=iac/bootstrap/state output
```

Its local state is intentionally excluded by `.gitignore`. Back it up in a
restricted location because losing it makes the remote-state foundation harder
to manage.

Initialize Shared Bootstrap using the non-secret backend coordinates committed
in `shared/versions.tf`:

```sh
terraform -chdir=iac/bootstrap/shared init
terraform -chdir=iac/bootstrap/shared apply
terraform -chdir=iac/bootstrap/shared output
```

The backend uses the active Azure CLI identity. No credential or secret value
is accepted or emitted by either root.

## Security boundary

State containers deny anonymous blob access. The storage public endpoint stays
enabled so the local Terraform workflow can reach it; private endpoints are a
post-PoC hardening step.

The credential vaults use Azure RBAC and grant the applying identity `Key Vault
Secrets Officer` on each vault so the later identity bootstrap can write
credentials and the local deployment workflow can retrieve them. Vault public
endpoints stay enabled for that local workflow. Registry admin credentials are
disabled.

## Validate

The root-module tests mock Azure and verify the resource boundary without
creating cloud resources:

```sh
terraform -chdir=iac/bootstrap/state test
terraform -chdir=iac/bootstrap/shared test
```
