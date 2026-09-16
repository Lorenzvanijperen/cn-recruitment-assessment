# Time Log

AI-assisted wayfinding and human decision approval were completed before the
implementation timebox. That preparation was not timed precisely and is
therefore disclosed but excluded rather than reconstructed.

| Date | Time (CEST) | Activity |
|---|---:|---|
| 2026-09-16 | 20:47-20:58 | Established the submission skeleton in #21 and built the minimal containerized API in #22. |
| 2026-09-16 | 20:58-21:22 | Implemented and deployed the state and shared Azure foundations in #23; changed the default from West Europe to North Europe after Azure rejected the new subscription in West Europe. |
| 2026-09-16 | 21:25-21:35 | Implemented, tested, and deployed the dev and prod identity bootstrap in #24, including environment-scoped roles and vault-stored credentials. |
| 2026-09-16 | 21:36-21:55 | Defined and tested the dev and prod application stacks in #25; resolved missing `Microsoft.App` registration and an invalid Key Vault secret identifier during the first dev apply. |
| 2026-09-16 | 21:55-22:18 | Implemented the canonical Task workflow for #26, deployed the dev image by digest after a successful migration job, and proved the persistent visit and correlated Log Analytics record. |
| 2026-09-16 | 22:20-22:30 | Completed the management summary, assumptions, AI evidence, runbook, and submission index in #27. |

The work remained inside the agreed 3.5-hour implementation-and-submission
limit. To protect the working vertical slice, production deployment, teardown
execution, Windows support, PostgreSQL managed-identity authentication,
database diagnostic logs, a separate application test suite, and presentation
materials were cut. The [demo runbook](../demo/README.md#known-limitations-and-failed-checks)
records what was observed, failed, or deliberately not run. Presentation
content remains human-owned.
