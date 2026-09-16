# Demo Runbook

The dev vertical slice was deployed and proved on 16 September 2026 from
macOS. The workflow retrieved purpose-specific credentials from Key Vault at
runtime and removed its temporary Azure CLI and Docker configuration on exit.
No credential was written to the repository.

## Prerequisites

- Task 3, Terraform 1.9+, Azure CLI, Docker with Buildx, `jq`, `curl`, Git,
  and Bash
- An Azure subscription with permission to create the documented resources and
  role assignments
- An interactive `az login` as the bootstrap operator

Run every command from the repository root. The automated deploy, test, and
destroy paths accept only `ENV=dev`; production is intentionally blocked.

## Bootstrap

```sh
task bootstrap
```

Terraform found the State and Shared Bootstrap roots unchanged. Identity
Bootstrap applied the dev deployment identity's deployment-environment-scoped
Key Vault access and its narrowly scoped registry and state access.

**Expected outcome:** the shared state, registry, credential vaults, and dev
deployment identities exist or converge without drift.

## Deploy

```sh
task deploy ENV=dev
```

The workflow built and pushed the image, resolved and deployed this immutable
reference:

```text
crnovabankc770945f.azurecr.io/visit-counter@sha256:c9e391e343fd6e686c762ea2cf6090c1b7768d3fd9047f28a44e6fc8e2133d5c
```

It first applied the stack with the API disabled, then started the manual
Container Apps migration execution
`job-novaba-dev-c770945f-04xubbp`. The execution ran from `20:15:12Z` to
`20:15:36Z` with status `Succeeded`. The second apply deployed:

```text
https://ca-novabank-dev-c770945f--m1llq2x.purplecoast-33396135.northeurope.azurecontainerapps.io
```

**Expected outcome:** the command prints the Container App name, HTTPS URL, and
digest-pinned image after the migration reports `Succeeded`.

## Prove

```sh
task test ENV=dev
```

The command sent one `POST /visits` request with correlation ID
`678a4692-2d2d-6235-4af5-7f10736b4abd`. The API returned HTTP 200, echoed the
same header, and returned visit count `1`. Log Analytics then returned the matching
structured `request completed` record for
`ca-novabank-dev-c770945f`, including status `200`, visit count `1`, and
duration `8ms`.

**Expected outcome:** the command reports a positive integer count and prints
the matching Log Analytics row. It fails if the HTTP status, echoed correlation
ID, JSON count, or central log does not match.

## Destroy

The canonical teardown command is:

```sh
task destroy ENV=dev
```

It was intentionally not executed for this evidence run, so the proved dev
deployment remains available. The command removes the dev application stack,
not the shared bootstrap or identity roots. Images remain in the shared
registry.

The workflow always uses a temporary Azure CLI and Docker configuration and
removes it on exit. Terraform and versioned migrations are designed to be
rerun after an interruption; inspect the reported error and state before
retrying rather than deleting state or resources manually.

## Known limitations and failed checks

- The first State Bootstrap apply failed because Azure rejected resource
  creation in West Europe for the new subscription. North Europe was selected
  and the apply then succeeded.
- The first Container Apps apply failed because the subscription had not
  registered `Microsoft.App`. Registration followed by a rerun succeeded.
- A later plan rejected an Azure resource ID where Container Apps required a
  Key Vault secret URI. The stack now uses the versionless secret URI, and the
  deployment succeeded.
- Only dev was deployed. Prod has reviewed configuration and tests but no live
  deployment, availability result, restore result, RPO, or RTO evidence.
- `task destroy ENV=dev` was deliberately not run, so teardown is documented
  but unvalidated.
- The supported operator path is macOS/Linux Bash. Requested Windows support
  was dropped to protect the timebox.
- The ticket deliberately excluded a separate application test suite, custom
  health endpoints, and custom probes. The public container behavior was
  checked during implementation, and the deployed seam was proved by
  `task test`.
- Managed-identity PostgreSQL authentication and PostgreSQL diagnostic-log
  collection were stretch goals and were not implemented.
