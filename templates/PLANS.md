# Accepted plans and living goal records

This is a project convention informed by OpenAI's ExecPlan pattern. It is not a
native Codex database or parsed configuration schema. Reuse existing issue/plan
files with the responsibilities below. Keep enough context in Git to resume on
a replacement computer without the previous conversation.

## Ready work

Before executing a slice, record accepted intent and authority, intended user and
observable outcome, operating/data/failure conditions, applicable measurable
quality criteria, assumptions/exclusions, validation owner/method, and selected
risk/review policy with rationale. Required unresolved criteria are planning gaps.
Refine steps within accepted scope; adopt material scope changes through the
governing baseline rather than editing success criteria to match the code.

Features, defects, incidents, dependency updates, backports and retirement use
the same contract. An urgent plan may be brief and still identifies affected
versions, scope, owner, authority, reproduction and required evidence. Every
version-producing merge retains the human review gate.

## One authority for each fact

- Accepted scope lives in its plan. A small change may combine feature and goal.
- Canonical goal-wide state lives on its declared integration ref, maintained by
  the integration owner. A single work branch can also be that ref.
- Each work branch owns its progress record, based on a recorded goal revision.
- PR discussion and CI checks hold observed development results; link them from
  concise goal records. Generated evidence and artifacts stay ignored and are
  removed locally after the feature merges.
- Essential distributable guidance stays with the product. Pin required private
  organization guidance and document access; sibling repositories are explicit
  dependencies and are not automatically discovered instructions.

Suggested paths are `features/F-0001.md`, `goals/G-0001/README.md`, and
`goals/G-0001/work/<slice>.md`; create records only when actual work exists.

## Goal record outline

```markdown
# <goal> - <observable outcome>

Accepted plan/authority/revision:
Intended user/outcome:
Operating conditions, quality limits, assumptions/exclusions:
Acceptance criteria and independent expected results:
Intended-use validation owner/method:
Governing baseline, risk/review profile, pending control changes:
Canonical repository/ref/path and integration owner:
Status and next action:

| Slice | Branch/ref | Writer/role | Plan revision | Dependencies | Included revision | PR/CI links |
| --- | --- | --- | --- | --- | --- | --- |

Progress, discoveries, consequential decisions, blockers:
Candidate S and relevant base/inputs:
Verification and validation:
Reviews N / rounds R, findings and dispositions:
Exceptions/debt with owner and expiry/reconsideration:
Release candidate and actual human approval:
Actual merged M, artifact D, version/tag, demo, deployed health/owner:

| Recovery component | Remote source ref or required release artifact | Confirmed revision/digest | Time | Retention/retrieval |
| --- | --- | --- | --- | --- |

Whole-goal coverage, confirmation age and recovery targets:
Local-only remainder and actual next action:
```

Include parallel, dependent, or alternative branches. Record which exact revisions
enter the combined candidate. Retain a disposition for abandoned alternatives;
they need not be integrated. Branch writers propose scope changes to the
integration owner rather than independently rewriting canonical goal status.

## Progress, integration and handoff

Use `planned`, `active`, `blocked`, `paused`, `ready`, `needs-decision`, `cancelled`
or `superseded` as project states. Blocked/paused work identifies the reason,
responsible owner and next action. Cancelled/superseded work retains the reason,
checkpoint, and replacement where applicable. Ready applies only to the candidate
meeting governance's verification/review gate; release and deployment remain
separate observations.

Integrate small accepted increments early while the goal remains open, respecting
the target's gates. Refresh dependent branches when contracts/base inputs change.
Changed relevant inputs reopen verification/review. At start, resume and handoff,
review stale assignments, dependencies, exceptions, and active-work limits.

Handoff records the writing owner/session, checkpoint, owned resources and next
action. Reconcile an uncertain old writer before takeover. Publish source branch
checkpoints first, then the coordinating goal record. Report recovery for every
included source component. After merge, clean transient local evidence and
artifacts; keep concise decisions and PR/CI links.
