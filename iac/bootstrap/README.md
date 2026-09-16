# Azure bootstrap

These Terraform roots establish the one-time Azure foundations in dependency
order:

1. `state` uses local, git-ignored state and creates only the state resource
   group, storage account, and private containers for shared, identity, and
   application state.
2. `shared` uses the `shared-state` remote backend and creates the shared
   resource group, Basic Azure Container Registry, and separate RBAC-enabled
   vaults for deployment and AI-inspection credentials.
3. `identity` uses the `identity-state` remote backend with one workspace per
   environment. It creates the environment resource-group boundary, one
   deployment principal, and one read-only AI inspection principal. Only the
   `dev` and `prod` workspaces are accepted.

All roots default to North Europe, an EU region that accepts new subscriptions.
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

After Shared Bootstrap, apply Identity Bootstrap once for each supported
workspace:

```sh
terraform -chdir=iac/bootstrap/identity init

terraform -chdir=iac/bootstrap/identity workspace select -or-create dev
terraform -chdir=iac/bootstrap/identity plan -out=dev.tfplan
terraform -chdir=iac/bootstrap/identity apply dev.tfplan
terraform -chdir=iac/bootstrap/identity output

terraform -chdir=iac/bootstrap/identity workspace select -or-create prod
terraform -chdir=iac/bootstrap/identity plan -out=prod.tfplan
terraform -chdir=iac/bootstrap/identity apply prod.tfplan
terraform -chdir=iac/bootstrap/identity output
```

The output contains principal metadata, environment-scoped role names, and
credential secret names only. It never contains client-secret values.

## Security boundary

State containers deny anonymous blob access. The storage public endpoint stays
enabled so the local Terraform workflow can reach it; private endpoints are a
post-PoC hardening step.

The credential vaults use Azure RBAC and grant the applying identity `Key Vault
Secrets Officer` on each vault so the later identity bootstrap can write
credentials and the local deployment workflow can retrieve them. Vault public
endpoints stay enabled for that local workflow. Registry admin credentials are
disabled.

Each identity workspace creates its environment resource group before assigning
roles. The deployment principal receives `Contributor` and `User Access
Administrator` on that resource group, allowing it to deploy resources and
assign their required roles without subscription-wide access. The AI inspection
principal receives only `Reader` and `Log Analytics Reader` on the same scope.
Neither principal receives access to the shared credential vaults.

Each purpose-specific shared vault stores one JSON credential secret named
`dev` or `prod`. Terraform outputs omit the credential value. The encrypted
remote identity state necessarily contains generated values because Terraform
creates and stores the Key Vault secret.

## Validate

The root-module tests mock Azure and verify the resource boundary without
creating cloud resources:

```sh
terraform -chdir=iac/bootstrap/state test
terraform -chdir=iac/bootstrap/shared test

terraform -chdir=iac/bootstrap/identity workspace select dev
terraform -chdir=iac/bootstrap/identity test
terraform -chdir=iac/bootstrap/identity workspace select prod
terraform -chdir=iac/bootstrap/identity test
```

## Applied evidence

Both workspaces were applied and checked for drift on 16 September 2026:

- `dev`: scope `rg-novabank-dev-c770945f`; deployment principal
  `f94f7d96-4cdc-416d-bd54-3d162b2e7528` has `Contributor` and `User Access
  Administrator`; AI inspection principal
  `3bcbff23-9945-43b1-ad35-68139876e2be` has `Reader` and `Log Analytics
  Reader`.
- `prod`: scope `rg-novabank-prod-c770945f`; deployment principal
  `c7ef4c00-5788-401d-81e7-e0de2b2765e3` has `Contributor` and `User Access
  Administrator`; AI inspection principal
  `4bf4edf4-7205-4b0c-86b3-f48653906bbf` has `Reader` and `Log Analytics
  Reader`.
- Each purpose-specific vault contains an enabled `application/json` secret
  named for its environment. Secret values were not read or emitted.
- A fresh plan in each workspace reported no changes.

After applying, capture redacted evidence without reading secret values:

```sh
terraform -chdir=iac/bootstrap/identity workspace select dev
terraform -chdir=iac/bootstrap/identity output -json
az keyvault secret show \
  --vault-name kv-novaba-dep-c770945f \
  --name dev \
  --query '{id:id,name:name}' \
  --output json
az keyvault secret show \
  --vault-name kv-novaba-ai-c770945f \
  --name dev \
  --query '{id:id,name:name}' \
  --output json

terraform -chdir=iac/bootstrap/identity workspace select prod
terraform -chdir=iac/bootstrap/identity output -json
az keyvault secret show \
  --vault-name kv-novaba-dep-c770945f \
  --name prod \
  --query '{id:id,name:name}' \
  --output json
az keyvault secret show \
  --vault-name kv-novaba-ai-c770945f \
  --name prod \
  --query '{id:id,name:name}' \
  --output json
```
