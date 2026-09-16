# AI-Assisted Delivery Evidence

The AI component is the delivery workflow itself, not a separate AI
application. Reusable skills helped turn a timeboxed assessment into decisions,
implementation, and reviewable evidence. The human remained accountable for
every architecture choice, Azure apply, and committed claim.

The skill approach is based on
[Matt Pocock's Skills for Real Engineers](https://github.com/mattpocock/skills).
For agents supported by the upstream installer:

```sh
npx skills@latest add mattpocock/skills
```

Select the required skills, including `setup-matt-pocock-skills`, then invoke
that setup skill once for the repository. During this assessment, skills were
invoked as slash commands with a focused issue or question, for example:

```text
/wayfinder https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/5
/implement https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/26
```

## Material usage

| Skill | Why and representative input | Resulting artifact | Human validation |
|---|---|---|---|
| `wayfinder` | "Chart the three-hour NovaBank Azure assessment" and resolve focused decisions such as the Version 1 runtime, environment isolation, logging, and delivery path. | [Decision map #1](https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/1) and approved decision issues [#2-#12](https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/2) | The candidate answered decision gates, rejected an initially suggested standalone AI helper, challenged service and cost choices, tightened the timebox, and explicitly approved each recorded resolution. |
| `tdd` | Test the agreed public container seams: migrate PostgreSQL, call `POST /visits`, observe persistence, correlation, logs, and error behavior. | [Visit-counter implementation](../cmd/visit-counter/) and its [public behavior](../cmd/visit-counter/README.md) | The candidate approved the seam before implementation. The issue deliberately excluded an additional application test suite; image checks and the deployed request/log proof were used instead. |
| `implement` | Build each approved story from [#21](https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/21) through [#27](https://github.com/Lorenzvanijperen/cn-recruitment-assessment/issues/27). | [Application](../cmd/visit-counter/), [Terraform](../iac/), [workflow](../scripts/workflow.sh), and this submission evidence | The candidate selected the Azure subscription, ran privileged Terraform applies, reported real Azure failures, approved scope cuts, and confirmed successful deployment before claims were recorded. |
| `code-review` | Review each implementation against repository conventions and the originating issue before commit. | Corrections and accepted trade-offs in the implementation commits; final traceability in the [management summary](../docs/architecture-summary.md) | Findings were either corrected or disclosed. Review did not substitute for Terraform tests, compilation, the live dev request, or human approval. |

Skills or research attempts that did not materially change a committed artifact
are intentionally omitted.

## Safeguards

- AI output was advisory. Architecture resolutions were recorded only after
  explicit human agreement.
- Secrets and customer data were never included in prompts or committed
  outputs. Secret values were not read for evidence.
- Technical claims were checked against Terraform plans/tests, deployed Azure
  behavior, or primary documentation. Unproven production outcomes are labeled
  **defined but not deployed** or **recommended next**.
- Failed checks and scope cuts were preserved in the
  [demo evidence](../demo/README.md#known-limitations-and-failed-checks) instead
  of being rewritten as success.
- Full transcripts were not copied into the repository. The presentation
  demonstration and interpretation remain human-owned.
