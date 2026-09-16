# Assumptions

These facts were accepted without full proof and shaped the proposed direction.
They are not production claims.

| Assumption | Design consequence | Validation before production |
|---|---|---|
| NovaBank supplies an existing Azure tenant and subscription, and an authorized bootstrap operator can create resources and role assignments. | Tenant, subscription, billing, and enterprise landing-zone creation are outside the PoC. | Confirm ownership, management-group placement, policies, quotas, and privileged-access process. |
| North Europe satisfies the EU-residency requirement for this workload. | All PoC resources use North Europe after West Europe rejected resources for the new subscription. | Have legal and compliance approve data classifications, permitted Azure services, backup locations, and support-data handling. |
| A visit is one accepted `POST /visits` request, not a person, session, or page view. | The API stores only an environment-scoped aggregate count and does not add identity or idempotency. | Confirm the real portal event, retry semantics, privacy requirements, and required data model with product stakeholders. |
| Dev may use small, non-high-availability capacity; prod requires a different capacity profile. | Dev scales the API to zero and uses Burstable PostgreSQL. Prod configuration uses at least two API replicas and zone-redundant General Purpose PostgreSQL. | Load-test representative traffic and use measured capacity, availability, and cost data to size production. |
| A 365-day Log Analytics retention setting is sufficient for the assessment's central-retention requirement. | Each environment has an isolated workspace with 365-day retention. | Define audit sources, access reviews, immutability/export requirements, legal holds, purge controls, and security-monitoring integration. |
| Password-based PostgreSQL access is acceptable for a timeboxed PoC if the generated value is kept in Key Vault and encrypted remote state. | Container Apps use managed identity for Key Vault and registry access, but the database URL contains a password. | Replace it with Microsoft Entra authentication and rotate or remove bootstrap credentials. |
| Public anonymous HTTPS ingress is acceptable only for the synthetic visit demo. | The API is reachable without customer authentication; PostgreSQL remains private. | Add identity, authorization, edge protection, rate limits, and threat-model-driven network controls. |
| The stated availability, RPO, and RTO are target outcomes rather than properties proven by configuration alone. | Prod settings show intent but are not presented as validated service levels. | Deploy prod, document dependencies and support ownership, then test failover and restore against measured objectives. |
