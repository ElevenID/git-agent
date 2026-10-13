# Development governance

This is a proposed baseline until adopted by the project's authority. Replace
unconfigured assignments with actual owners or links to established policy.
Initializing files does not grant credentials, accept a plan, or activate GitHub
rules. This document contains project policy, not Codex configuration keys.

## Authority and decisions

| Assignment | Current owner or established authority |
| --- | --- |
| Scope, acceptance criteria, and policy adoption | UNCONFIGURED |
| Architecture and compatibility decisions | UNCONFIGURED |
| Repository administration across goals | UNCONFIGURED |
| Human release review and operational authority | UNCONFIGURED |

Each goal assigns its integration owner; each branch has one writing owner.
The repository administration owner coordinates shared configuration, destructive
ref operations, and cleanup across active goals. One person or session may hold
several assignments. An elapsed timestamp does not authorize taking over a live
writer's branch.

Prefer the accepted user outcome, correctness, compatibility, and maintainability.
Within accepted scope, agents may refine steps, change internal implementation,
improve focused tests, and use established dependencies. Prefer cohesive modules
with explicit interfaces: they keep ownership and verification understandable.
A new service, dependency, public-contract break, or wider data/capability use
needs the applicable delegated authority; the accepted plan can already provide
that authority. Explain evidence, alternatives, and consequences when proposing
such a change. Record consequential decisions in the plan or existing ADRs.

Use the current user's authorization and higher-priority rules. Do not request
permission again for an already authorized action. Prepare a concrete reviewable
proposal when a necessary decision exceeds delegated authority, and continue
independent authorized work.

## Governing baseline and exceptions

Every goal records its accepted instructions/policy revision. Changes to skills,
roles, instructions, reviewer counts/guides, permissions, ownership, required
checks, or acceptance criteria remain proposals until properly adopted. Review
them under the preceding accepted rules. A candidate cannot silently weaken its
own acceptance conditions.

At start/resume/handoff identify actual instruction sources, relevant skills,
pending control changes, and observable effective model/role/permissions. Do not
copy secrets or unrelated private instructions. Verify supported reload/restart
behavior after adoption; inspect proposed controls from a trusted prior context.
Protect controls using actual native permissions and applicable GitHub review
rules. An instruction path alone does not imply protection.

Record each material exception or temporary debt with scope, authority,
rationale, mitigation, owner, and expiry or reconsideration trigger. Recheck it
at start/resume/handoff and release. Exceptions cannot silently waive required
criteria or the human release rule.

## Independent review policy

Initial defaults upon adoption; change through the preceding baseline:

| Setting | Policy |
| --- | --- |
| Required reviewers N for the final candidate | 2 |
| Maximum rounds R, including initial review | 3 |
| Assignment 1 | `contract-reviewer`: acceptance and correctness guide |
| Assignment 2 | `adversarial-reviewer`: architecture, integration, evidence guide |
| Shared guide | `.agents/skills/work-goal/references/review-guide.md` |
| Additional risk profiles/stack guides | Record as applicable in the accepted plan |

N and R are positive project-policy integers. Native Codex capacity C is
`agents.max_concurrent_threads_per_session`; it counts spawned threads and
excludes the primary. C does not change N or R. Schedule independent reviews
sequentially if capacity is limited. Local runtime/test-worker limits are separate.

Give reviewers the fixed candidate, accepted baseline, criteria, assigned guide,
and raw evidence. Collect independent first findings before reconciliation.
Reviewers do not edit implementation or rewrite criteria. Missing/unavailable
reviewers do not count. Reuse applicable native evidence; run targeted checks
when needed instead of rerunning every suite once per reviewer.

Block on unresolved acceptance failures, reproducible defects, material missing
evidence, or violated applicable policy. A majority cannot erase a valid blocker.
Record dispositions with evidence, including rejected false positives. Fixes
create a new candidate with renewed applicable verification and review coverage.
After R rounds, unresolved work is `needs-decision`, never an automatic pass.

Before claiming ready, require the selected checks, all N completed applicable
reviews, resolved blockers, applicable intended-use validation, and current
exception dispositions for the candidate.

## Actual capabilities

| Activity | Intended boundary; verify with native controls |
| --- | --- |
| Review | Assigned source/evidence; scoped verification if authorized |
| Implement/test | Assigned workspace and development resources |
| Publish checkpoint | Authorized work refs; no release/admin bypass |
| Release | Approved inputs and narrowly scoped authorized GitHub jobs |
| Human approval | Eligible human; approval credentials unavailable to agents |

Routine development must not inherit production, release, or human-approval
credentials. Document actual permissions and demonstrate an allowed operation and
a harmless forbidden operation. Scope external effects to development. A note
does not narrow an existing token's rights; a reviewer instruction is no sandbox.
Use minimum GitHub job permissions and avoid privileged execution of untrusted
candidate code or unvalidated artifacts.

## Human release gate

Human review must precede every merge intended to produce a tagged version,
including emergency fixes. Verify the actual eligible-human approval path and
current candidate. Agent-written approval, owner bypass, or post-merge review
cannot satisfy this gate. GitHub PR authors cannot approve their own PR; a solo
developer must settle the account arrangement or accurately describe a manual
human handoff without claiming an enforced required-review gate.

Use current integration checks, applicable ownership, stale-approval dismissal,
and protected release controls where supported. Workflow files do not activate
repository settings. Environment approval is an additional deployment gate, not
approval of an earlier merge. Follow the exact release sequence in the work-goal
release reference and the product's established release procedure.

## Model and tool changes

Models inherit native effective defaults unless supported settings explicitly
bind them. Record actual model/effort where observable; do not claim deterministic
output. Before adopting material model, skill, guide, Codex/extension, or execution
changes, use representative known-good/bad cases and a relevant human sample.
Include a contract defect, empty test selection, stale review, false positive,
rule weakening, and incomplete checkpoint. Preserve expected outcomes and actual
before/after evidence. A configuration loading successfully is insufficient.
