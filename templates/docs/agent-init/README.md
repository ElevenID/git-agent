# Adopt the agent workflow

Generated from `git agent init` template revision `{{TEMPLATE_VERSION}}`.
Template-set digest: `{{TEMPLATE_DIGEST}}`.

This is a local scaffold for VS Code/Codex, two instruction-only skills, Git and
GitHub. The initializer exits after proposing or creating files. Use the skills
and normal product commands afterward; restoring development does not require
the global initializer or an earlier chat.

## Adopt before claiming readiness

Review the initializer's created/adopted/proposed/conflicting report. Preserve
existing controls and compare proposals deliberately. Set actual ownership and
accept the relevant baseline under the existing authority. Record the adopted
revision; a template digest identifies content, not approval or authenticity.

Paths below are relative to the repository root:

| Responsibility | Selected document |
| --- | --- |
| Authority, review N/R, capabilities, human release gate | `{{GOVERNANCE_PATH}}` |
| Real commands, isolation, CI, versions, recovery targets | `{{DEVELOPMENT_PATH}}` |
| Module contracts, product lanes, compatibility/support | `{{ARCHITECTURE_PATH}}` |
| Accepted plans, canonical goals, branch progress | `{{PLANS_PATH}}` |

Fill applicable `UNCONFIGURED` entries with actual commands, owners, settings, and
evidence. Reuse established documents; filenames do not establish semantic
completeness. Create an intentional baseline commit before a new repository's
worktree flow. Add product execution and GitHub workflows as accepted stack work;
this scaffold supplies no fictitious commands or passing workflow placeholders.

Verify installed Codex instruction/skill/role discovery from the actual working
directories, project trust, effective permissions, and model/effort. Check the
client against the current official documentation rather than inventing a schema
fallback. The native configuration inherits models; C limits spawned threads,
while N required reviewers and R rounds remain policy. A future model/provider
must have a supported host binding and behavioral calibration.

Keep private organization strategy private. Adopt pinned distributable guidance
into each product, and document any required private repository/access dependency.
GitHub settings, secure account recovery, runtime resources and large artifacts
need their own verified configuration and retention.

Configure the product `.gitignore` to exclude generated evidence and artifact
directories before starting a goal. Keep review logs and screenshots outside
Git while a PR is open, link the PR and CI checks from concise goal records,
then remove local copies after merge or terminal cancellation/supersession. Keep code comments
minimal; place historical rationale in the PR for Git blame to surface.

## Product acceptance record

These are demonstrations to perform, not completed test results. Record exact
inputs/procedure/outcome/evidence in the accepted adoption goal. Core governing,
review, human-release and recovery gates cannot be waived as not applicable.
Product-specific capabilities need an explicit scope/risk rationale.

| ID | Required demonstration |
| --- | --- |
| A01 | Init preserves existing/staged work, supports linked worktrees, dry-run, rerun and partial-write recovery; records template origin. |
| A02 | Actual Codex discovery/permissions; attempted control weakening cannot certify itself. |
| A03 | Accepted behavior, measurable quality and intended-use validation. |
| A04 | Two independent runtime instances, interruption cleanup, allowed and harmless forbidden capability checks. |
| A05 | Shared Git ownership, exact stash/ref handling, uncertain-writer handoff. |
| A06 | Clean-input setup, material updates, known baseline and calibration. |
| A07 | Known defect, empty selection, stale evidence, false positive and flaky-check dispositions. |
| A08 | N/C/R behavior, independent current-candidate reviews, fix/review renewal. |
| A09 | Early integration, dependent refresh, stale/cancelled work and bounded exceptions. |
| A10 | Partial then complete source checkpoints; PR/CI linkage, local evidence cleanup, and measured clean restore/RPO/RTO. |
| A11 | Deliberate checkpoint/candidate CI events, safe cancellation scope and measured cost/feedback. |
| A12 | Actual current human premerge approval and binding of M, D, tag, assertions and recorded demo. |
| A13 | Applicable upgrade/coexistence/interruption/recovery and observed health/bad-setting detection. |
| A14 | Applicable maintenance, support-line/backport disposition, root-cause learning and retirement. |

## Primary format and lifecycle references

Reference baseline checked 2026-10-10. OpenAI/vendor documentation describes its
own mechanisms. Standards give practice/scope references; they do not prescribe
these filenames, reviewer counts, ownership assignments, or command names. This
scaffold makes no standards-compliance or deterministic-model claim.

| Topic | Primary reference |
| --- | --- |
| Instruction format and actual Codex loading | [AGENTS.md](https://agents.md/), [OpenAI instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| Skills format and repository discovery | [Agent Skills](https://agentskills.io/specification), [OpenAI skills](https://learn.chatgpt.com/docs/build-skills) |
| Native settings and roles | [OpenAI config](https://learn.chatgpt.com/docs/config-file/config-reference), [subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [permissions](https://learn.chatgpt.com/docs/agent-approvals-security) |
| Living plans and model calibration | [ExecPlan pattern](https://developers.openai.com/cookbook/articles/codex_exec_plans), [evaluation guidance](https://developers.openai.com/api/docs/guides/evaluation-best-practices) |
| Git discovery, worktrees and shared state | [Git manual](https://git-scm.com/docs/git), [worktree](https://git-scm.com/docs/git-worktree), [stash](https://git-scm.com/docs/git-stash) |
| Existing VS Code execution | [Tasks](https://code.visualstudio.com/docs/debugtest/tasks), [debugging](https://code.visualstudio.com/docs/debugtest/debugging-configuration) |
| Required checks and merge events | [Status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks), [workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) |
| Human review and actual GitHub controls | [Required reviews](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews), [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) |
| Workflow permissions, trigger chain, concurrency | [Secure use](https://docs.github.com/en/actions/reference/security/secure-use), [triggers](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow), [concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) |
| Cookie isolation | [IETF RFC 6265 section 8.5](https://www.rfc-editor.org/rfc/rfc6265.html#section-8.5) |
| Lifecycle, requirements and quality scope | [ISO 12207](https://www.iso.org/standard/90219.html), [ISO 29148](https://www.iso.org/standard/72089.html), [ISO 25010](https://www.iso.org/standard/78176.html), [NASA validation](https://www.nasa.gov/reference/5-4-product-validation/) |
| Secure development practices | [NIST SSDF 1.1](https://csrc.nist.gov/pubs/sp/800/218/final) |
| Integration and deployment guidance | [DORA small batches](https://dora.dev/capabilities/working-in-small-batches/), [AWS rollback safety](https://d1.awsstatic.com/builderslibrary/pdfs/ensuring-rollback-safety-during-deployments.pdf), [Google SRE canaries](https://sre.google/workbook/canarying-releases/) |
| Recovery objectives and retained material | [NIST RPO](https://csrc.nist.gov/glossary/term/recovery_point_objective), [RTO](https://csrc.nist.gov/glossary/term/recovery_time_objective), [GitHub backups](https://docs.github.com/en/repositories/archiving-a-github-repository/backing-up-a-repository), [artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) |
