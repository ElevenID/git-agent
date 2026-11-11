---
name: worktree-flow
description: Create, resume, verify, checkpoint, recover, or clean up an assigned Git worktree using existing project commands and isolated development resources. Use for live reload, local integration/browser checks, interrupted sessions, and workstation recovery; do not infer runtime isolation from checkout isolation.
---

# Run an assigned worktree

Read root-relative `{{DEVELOPMENT_PATH}}`, applicable `{{GOVERNANCE_PATH}}`, and the
assigned plan/work record. Read
[isolation-and-recovery.md](references/isolation-and-recovery.md) for runtime
ownership, cleanup, checkpoints or restoration.

1. Discover the actual repository/worktree through Git. Inspect status, branch,
   worktree listing and assigned owner/base before changes. A `.git` file is
   valid; do not construct administrative paths or disable Git's same-branch
   safeguard. An unborn repository needs an intentional baseline commit.
2. Reconcile stale assignments, old processes, interrupted work and uncertain
   writers. Confirm the repository administration owner for shared config/ref
   mutations. Preserve other worktrees' state, intentional staged work and
   uncommitted changes. Inspect the goal's current PRs and overlapping branches
   before creating another copy. A worktree lock is not an agent semaphore.
3. Prefer resuming the suitable assigned checkout. Create another only for an
   actual isolation or fixed-candidate need, with an owner and removal event;
   use detached verification checkouts when a new branch is unnecessary. Use
   native Git from the recorded base and confirm resulting checkout identity.
4. Restore the documented native toolchain/dependencies/fixtures/configuration.
   Check applicable submodule, LFS, hooks, private setup and material local/CI
   differences. Report missing setup as explicit product work.
5. Verify actual capability boundaries and resource capacity. Use scoped native
   flags/settings for the instance. Check process ownership, readiness timeout,
   actual endpoint identity and external development effects. Prove two real
   instances are independent before making an isolation claim.
6. Use the maintained commands for live feedback and selected checks. Mark dirty
   or changing-input results exploratory. Hold source/build inputs fixed for
   acceptance; record actual command, environment, assertions and outcome.
7. Update only the assigned branch record, checkpoint at meaningful increments
   and handoff, and give the integration owner exact revisions/evidence. Confirm
   branch publication and PR/CI links before coordinating the whole-goal checkpoint.
8. Stop/clean only owned processes and scoped resources. Preserve required source
   refs first; reconcile the goal's checkouts at every handoff as active with
   owner, parked with verified checkpoint, removed, or deferred with a concrete
   blocker and next action. Clean completed verification copies too. Follow the
   recovery reference for safe parking/removal, leaving other worktrees usable.
   Report endpoint/resource state, evidence, remote coverage, local-only remainder
   and primary/linked checkout counts for the inspected scope.

Use OS, Git, Codex, VS Code and existing product facilities. Missing isolation
parameters belong in planned product changes. Do not add a daemon, global lock
database, runtime registry, execution adapter or required extra CLI command.
