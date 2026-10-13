# Source and design map

This map distinguishes platform behavior, open formats, standards and practice
references, and project conventions. Check the linked upstream documentation
when changing an integration; native discovery and effective configuration still
require the adopting installation's client. The Bash initializer does not
validate JSON or TOML syntax.

## Native formats and mechanisms

| Surface or behavior | Primary documentation | Implementation decision |
| --- | --- | --- |
| External `git-agent` dispatch | [Git](https://git-scm.com/docs/git) | One initializer dispatching `init`; use `git agent -h` for its usage because Git may route `git agent --help` to a manual viewer. Normal Git/skills handle daily operations. |
| Repository initialization and discovery | [git-init](https://git-scm.com/docs/git-init), [repository layout](https://git-scm.com/docs/gitrepository-layout), [git-rev-parse](https://git-scm.com/docs/git-rev-parse) | Discover through Git; support linked `.git` files; create ordinary worktree files and preserve the index. |
| Worktrees and shared state | [git-worktree](https://git-scm.com/docs/git-worktree), [git-stash](https://git-scm.com/docs/git-stash) | Preserve branch safeguards; explicitly coordinate shared Git administration and exact stash ownership. |
| `AGENTS.md` | [Open format](https://agents.md/), [OpenAI loading](https://learn.chatgpt.com/docs/agent-configuration/agents-md) | Short entry point with scoped linked guidance; verify effective instruction chain after adoption. |
| `.agents/skills/<name>/SKILL.md` | [Agent Skills specification](https://agentskills.io/specification), [OpenAI skills](https://learn.chatgpt.com/docs/build-skills) | Exactly two instruction-only baseline skills with name/description frontmatter and Markdown references. |
| `.codex/config.toml` | [OpenAI config reference](https://learn.chatgpt.com/docs/config-file/config-reference) | Supported native settings only; models inherit, credentials remain external. |
| `.codex/agents/<role>.toml` | [OpenAI subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) | Native name/description/developer_instructions for two generic reviewers. |
| Runtime permissions | [OpenAI approvals/security](https://learn.chatgpt.com/docs/agent-approvals-security), [subagent inheritance](https://learn.chatgpt.com/docs/agent-configuration/subagents) | Verify actual effective controls; role prose is not a technical boundary. |
| Living execution plans | [OpenAI ExecPlans cookbook](https://developers.openai.com/cookbook/articles/codex_exec_plans) | Adapt the reference pattern; plan fields are project conventions. |
| Existing editor execution | [VS Code tasks](https://code.visualstudio.com/docs/debugtest/tasks), [debug configuration](https://code.visualstudio.com/docs/debugtest/debugging-configuration) | Use native product commands; do not add a required execution adapter. |

### Bash distribution and native utilities

The command, build, installer, and test tooling use Bash and stock shell
utilities. Bash 3.2+ and Git 2.31+ are the
declared minimums. These are project support choices; consult
[verification.md](verification.md) for the versions actually exercised and the
remaining platform checks.

| Mechanism | Primary documentation | Implementation decision |
| --- | --- | --- |
| Bash language and literal heredocs | [Bash reference manual, section 3.6.6](https://www.gnu.org/s/bash/manual/bash.html#Here-Documents) | Embed reviewed text in quoted heredocs; do not expand or execute template bodies. The build chooses a delimiter absent as a complete content line. |
| Private temporary directories | [GNU mktemp](https://www.gnu.org/s/coreutils/manual/html_node/mktemp-invocation.html) | Use `mktemp -d` with an explicit path ending in six `X` characters. Avoid predicted names, `mktemp -u`, and GNU-only temporary-directory flags. |
| Create-only hard-link publication | [POSIX/SUS ln](https://pubs.opengroup.org/onlinepubs/7908799/xcu/ln.html) | Stage the complete file under its final basename in a private directory inside the destination parent, then link into the explicit parent directory without a force flag. |
| Literal Git object identity | [git-hash-object](https://git-scm.com/docs/git-hash-object), [Git environment variables](https://git-scm.com/docs/git#_environment_variables) | Use Git's existing blob identity calculation without writing objects. Template IDs are explicitly labelled `git-blob-sha1`; inputs include ordered paths and bodies. |
| Line-ending control | [gitattributes](https://git-scm.com/docs/gitattributes) | Retain LF checkout rules for Bash source, generated executable, and templates. |
| Windows shell environment | [Git for Windows](https://gitforwindows.org/), [MinGit exclusions](https://gitforwindows.org/mingit) | Support Git Bash from full Git for Windows. MinGit and PowerShell alone do not satisfy the Bash requirement. |

`git hash-object --stdin` hashes literal stream content without attribute filters
when no `--path` is supplied. The initializer feeds each fixed relative template
path, a NUL separator, its exact body, and a final NUL in declared order. It uses
an isolated SHA-1 Git context so the identity does not depend on the target
repository's SHA-1 or SHA-256 object format. The builder labels its generated-file
identity as a Git blob SHA-1 value as well. These identifiers support comparison;
they are not SHA-256 claims or publisher signatures.

Publication is per file: completed bytes become visible together on filesystems
supporting the required hard-link operation. There is no `fsync` guarantee,
multi-file transaction, persistent semaphore, or hostile-process isolation
claim. Existing identical output remains unchanged; differing content requires
review. Recovery relies on the product's retained checkpoints and restore
demonstrations.

The command inventories relevant manifests and configuration while leaving
syntax and declared-command verification to the project's maintained validators
and the installed Codex client. It does not require a JSON/TOML parser package,
execute discovered product commands, or infer successful adoption from file
presence. The Bash/native utility references support implementation mechanics;
they do not prescribe the project's governance workflow.

### Native model and reviewer configuration

`agents.enabled` and `agents.max_concurrent_threads_per_session` are native fields.
Capacity excludes the primary thread. Required review count N and round limit R
remain prose policy. Standalone roles require name, description and
developer_instructions. A role may explicitly select supported model/effort;
these templates inherit. Parent live runtime overrides can affect a spawned
role's effective permissions. Verify actual installed behavior and trust.

Model variability and calibration use [OpenAI prompt-engineering
guidance](https://developers.openai.com/api/docs/guides/prompt-engineering) and
[evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices).
No deterministic-output or permanently available hosted-model promise is made.

## GitHub integration and release

| Concern | Primary documentation |
| --- | --- |
| Reusable product lanes | [Reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) |
| Required-check outcomes, skipped jobs and path filters | [Troubleshooting required checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks) |
| Merge-queue and other workflow events | [Workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) |
| Current human approval and PR-author restriction | [Required PR reviews](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews) |
| Branch/tag rules, ownership, availability | [Available rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets), [ruleset availability](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets), [CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) |
| Environment approval versus merge approval | [Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) |
| GITHUB_TOKEN event limitations | [Triggering workflows](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) |
| Minimum permissions and executable dependency pinning | [Secure use](https://docs.github.com/en/actions/reference/security/secure-use) |
| Scoped cancellation | [Workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) |
| Changing runner images | [GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners) |
| Artifact retention and removal | [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts), [removing artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts) |
| Repository material and access recovery | [Repository backups](https://docs.github.com/en/repositories/archiving-a-github-repository/backing-up-a-repository), [2FA recovery](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa/configuring-two-factor-authentication-recovery-methods) |

No passing CI scaffold is generated for an unknown product. Workflow settings,
eligible human identities, release credentials and runtime isolation must be
demonstrated in the adopting product. The user requires human review before
every version-producing merge; this is project policy using native mechanisms.

## Lifecycle and quality references

| Reference | How the templates use it |
| --- | --- |
| [ISO/IEC/IEEE 12207:2026](https://www.iso.org/standard/90219.html) | Public lifecycle scope: conception through operations, support and retirement. |
| [ISO/IEC/IEEE 29148:2018](https://www.iso.org/standard/72089.html) | Requirements-engineering scope and accepted intent. |
| [ISO/IEC 25010:2023](https://www.iso.org/standard/78176.html) | Product-quality scope; choose applicable measurable criteria. |
| [NASA product validation](https://www.nasa.gov/reference/5-4-product-validation/) | Distinguish criterion verification from intended-use validation. |
| [NIST SP 800-218 SSDF 1.1](https://csrc.nist.gov/pubs/sp/800/218/final) | Secure-development responsibilities, criteria, environments, review/testing, retained release integrity and vulnerability response. |
| [NIST RPO](https://csrc.nist.gov/glossary/term/recovery_point_objective), [RTO](https://csrc.nist.gov/glossary/term/recovery_time_objective), [contingency planning](https://csrc.nist.gov/pubs/sp/800/34/r1/upd1/final) | Product-set loss/resumption targets and exercised restoration. |
| [IETF RFC 6265 section 8.5](https://www.rfc-editor.org/rfc/rfc6265.html#section-8.5) | Ports alone do not establish cookie isolation. |
| [DORA small batches](https://dora.dev/capabilities/working-in-small-batches/) | Early accepted integration and feedback; measure actual pilot results. |
| [AWS rollback safety](https://d1.awsstatic.com/builderslibrary/pdfs/ensuring-rollback-safety-during-deployments.pdf) | Deployment transitions and applicable coexistence/recovery. |
| [Google SRE canaries](https://sre.google/workbook/canarying-releases/) | Observed deployed health and controlled recovery. |
| [Playwright retries](https://playwright.dev/docs/test-retries) | Example of distinct passed/flaky/failed outcomes; no mandatory test stack. |

ISO public abstracts/scopes were used, not a normative conformance assessment.
SSDF is a secure-development reference, not a general lifecycle certification.
Vendor guides and DORA research have different authority from standards.

## Project conventions

`git agent init`, the two skill names, goal/branch ownership, state vocabulary,
canonical coordination records, N/R defaults, review guides, bounded exceptions,
S/E/M/D identities, and A01-A14 acceptance demonstrations are this project's
design. They are not invented OpenAI configuration keys or claims that a standards
body prescribes this particular workflow. Execution uses existing Git, OS,
VS Code, Codex, and product facilities. Product acceptance remains unverified
until actual demonstrations.
