# Development and recovery

Adopt existing maintained setup/run/test/build instructions. Fill applicable
entries below using real product commands and evidence. `UNCONFIGURED` is a gap,
not a command or success result. No product runtime or GitHub workflow is
generated until its stack and required checks are known.

## Reconstructable product recipe

| Required information | Actual definition or maintained link |
| --- | --- |
| Supported OS, Git, Codex/extension versions | UNCONFIGURED |
| Toolchain/runtime/service/browser versions and native lockfiles | UNCONFIGURED |
| Setup, fixture preparation, existing live-reload command | UNCONFIGURED |
| Focused, contract, integration, browser and build commands | UNCONFIGURED |
| Working directory and materially relevant configuration | UNCONFIGURED |
| Local/CI differences, production-build checks | UNCONFIGURED |
| Submodules, LFS, hooks, generated sources, private setup | UNCONFIGURED |
| Development credential names and secure recovery procedure | UNCONFIGURED |

Record material host/build-mode/locale/timezone assumptions. Demonstrate setup
from clean inputs without correctness depending on an existing cache. Keep
versions/dependencies in native manifests, not a second dependency database.
Never commit secrets. Do not assume a clone restores machine settings or hooks.

## Worktree execution

Use the worktree-flow skill and its isolation/recovery reference. Record the
actual existing flags, environment settings, task, or configuration that scope:

- endpoints and callback/base URLs;
- database/schema/fixtures, queues, consumers, caches and generated output;
- browser contexts/test users and mutable temporary state;
- owned processes or containers;
- applicable email, webhook, object-store, identity and payment effects.

Use synthetic or appropriately sanitized fixtures. Different ports do not isolate
browser cookies or external effects. Prove two real instances cannot contaminate
each other and reconcile a partial startup/cleanup before calling the recipe
isolated. A missing control is a product work item.

| Execution bound | Demonstrated value and mechanism |
| --- | --- |
| Concurrent live instances / active-work limit | UNCONFIGURED |
| Test workers and shared-state serialization | UNCONFIGURED |
| Readiness and test time bounds | UNCONFIGURED |
| Endpoint identity, process ownership, interrupted cleanup | UNCONFIGURED |

Start instances on demand. Share read-only dependencies/safe caches where valid.
Stop only owned resources. Record ownership using existing session/process
handles and compact local notes; no runtime registry or global semaphore is
required. Git worktree lock protects administration, not agent ownership.

Repository-wide ref/configuration/stash effects require coordination with the
administration owner in `{{GOVERNANCE_PATH}}`. Prefer intentional checkpoint
commits. If using a stash, retain its exact object identity and owner; never use
an unqualified latest stash. Preserve Git's same-branch safeguards and retain
required work before cleanup or rewriting refs.

## Evidence and CI economy

Live-reload checks may use changing files; label them exploratory and identify
dirty inputs. Acceptance evidence uses stable source/build inputs held fixed
during execution. HEAD alone does not identify code served from a dirty worktree.
Read `.agents/skills/work-goal/references/review-guide.md` for evidence fields and
flaky-check handling.

Ignore generated evidence and artifact directories in the product `.gitignore`.
Do not stage logs, screenshots, test output, reviewer transcripts or evidence
manifests. Keep them in ignored local storage during review; use PR discussion
and hosted CI checks for concise, source-linked findings. Clean local copies
after work merges or is cancelled or superseded, once the outcome and required
decisions are recorded. Do not use code comments as a change diary; put rationale
in the PR.

| Event | Required work using maintained commands |
| --- | --- |
| Active edits | Live feedback and focused local checks |
| Stable branch increment | Applicable local integration/contract checks |
| Combined candidate | Fixed inputs and the selected required verification set |
| Reviewer | Independent inspection and warranted targeted checks |
| Candidate change | Renew applicable verification/review coverage |
| PR feedback | Reproduce findings, correct valid issues, verify the new head, and record dispositions |
| Version release | Actual merged-source, artifact, demo and promotion checks |

Use architecture's impact map, including transitive consumers and changed
schemas/fixtures/generators/config/toolchains. Unmapped or uncertain impact needs
broader checks or a visible gap. Empty selection cannot establish success.
Maintain a stable aggregate required integration check that validates selection
and success of every selected required check, including module/interface checks
and product lanes. Missing, skipped, cancelled and failed selected checks do not
pass. Verify merge-queue candidates where applicable.

Before handing off a PR for merge, read its current inline and general comments,
automated findings, and check failures. Follow the PR feedback decision rule in
`{{GOVERNANCE_PATH}}`: fix valid issues on the branch, add meaningful regression
coverage where warranted, run affected checks on the corrected head, and reply
with evidence. Reopen applicable review after material changes. Check that every
review conversation is resolved and no substantive general comment remains
undispositioned. Preserve the human maintainer's acceptance of any evidence-backed
false positive or deferral; do not wait indefinitely for an unavailable bot.

Use distinct checkpoint/candidate/release triggers. An open PR may run CI on
every push; use explicit retained checkpoint refs when needed and advance the
candidate deliberately. Cancel only superseded disposable checks, with GitHub
concurrency scoped by workflow/product/stream. Stateful deployment or migration
cancellation follows its interruption/recovery procedure.

Measure baseline and pilot feedback delay, expensive CI runs/minutes per goal,
review/rework effort, and escaped failures. State the observation window and
workload differences. Preserve required coverage when reducing duplicate work.

## Dependencies and maintenance

Record adopted origins/revisions and an update owner/trigger for templates,
initializer, executable dependencies, workflows/actions, and client/toolchain.
Pin executable CI dependencies to immutable revisions where supported and review
applicable distribution/license requirements. Updates are accepted planned work
with product checks and applicable behavioral calibration. Retain the prior usable
baseline where available; withdrawn hosted models/components need a verified
replacement, not an unsupported restoration promise.

## Recovery commitments

Baseline scenario: total workstation loss with GitHub material and independently
recoverable account access surviving. Provider/repository/account loss is a
separate scope decision. Production-data recovery is separate from development.

| Commitment | Actual value, owner, and retained evidence |
| --- | --- |
| Maximum tolerable active-work loss / RPO | UNCONFIGURED |
| Target time to resume useful development / RTO | UNCONFIGURED |
| Retained work/checkpoint refs and required private guidance | Per-goal record |
| Separately required release/operational artifact retention | UNCONFIGURED |
| Access, machine setup and native GitHub/Codex settings recovery | UNCONFIGURED |
| Restore-drill triggers and measured loss/resumption time | UNCONFIGURED |

Checkpoint completed increments, pause/handoff, and before destructive cleanup.
Publish each component/work branch before its coordinating goal record. Confirm
remote revisions and link the relevant PR/CI checks; report incomplete coverage
and local-only work. Generated development evidence is transient and ignored.
A local commit is not cloud backup.
Report confirmation time/age against targets while active. These instructions do
not provide an unattended timed backup while Codex is inactive.

Exercise a clean restore after material setup/access/dependency/recovery changes
and at the product's chosen reconsideration events. Follow the worktree-flow
recovery reference. Retrieve separately required release/operational artifacts
rather than trusting URLs. Retain source refs before cleanup. Do not invent the amount lost after a real
failure when it is unknown.
