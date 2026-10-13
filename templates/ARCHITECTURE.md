# Architecture and product boundaries

Replace this outline with links to the existing architecture where available.
Record observed product structure before proposing changes. Scaffolding does not
create a service boundary or prove that products can release independently.

## Maintained map

| Module/product | Responsibility and owner | Public contract | Dependencies and consumers | Required checks/lane |
| --- | --- | --- | --- | --- |
| UNCONFIGURED | Inventory the actual product | Link interfaces/schemas | Link native manifests | Existing commands/workflow |

Include standalone modules/interfaces even when they are not deployable products.
Keep native dependency declarations authoritative. Explain intended dependency
direction and cycles that need resolution. Link generated code to its source and
generator. Changes to the impact map itself warrant broader verification.

## Decision guidance

Prefer cohesive modules with explicit public interfaces and tests at meaningful
boundaries. A new service is justified by evidence such as independent release
needs, incompatible runtimes, or a demonstrated operational constraint. Avoid
splitting deployables merely to fit agent assignments or CI lanes.

Use the delegated architecture authority in `{{GOVERNANCE_PATH}}`. Record
consequential choices with context, alternatives, consequences, owner, and review
trigger in existing decision records. Routine internal changes need no separate
ADR. Temporary cross-boundary dependencies/debt need bounded dispositions.

## Compatibility and release impact

For actual public interfaces, persisted formats, or independently deployed
consumers, record supported versions and compatibility promises. Today's source
dependency graph does not enumerate older supported clients. Identify deployment
order and required coexistence behavior. Breaking changes follow accepted scope
and the product's migration/support procedure.

Use changes and transitive consumers to select affected required checks, including
contracts, fixtures, schemas, generators, configuration, and toolchain inputs.
Document uncertain impact rather than treating it as empty success. Share product
commands between local work and GitHub workflows; compose lanes from the actual
boundaries above.

## Operations and support links

| Responsibility | Existing guide or actual product decision |
| --- | --- |
| Supported upgrade/data paths and rollback/roll-forward | UNCONFIGURED |
| Deployment health, observation window, owner, recovery | UNCONFIGURED |
| Production-data backup/restore where applicable | UNCONFIGURED |
| Supported versions, report intake, triage, patches/backports | UNCONFIGURED |
| End-of-support, retirement, retained data/evidence | UNCONFIGURED |

Use the work-goal release reference for the required lifecycle sequence. Create
only records applicable to the product; give an explicit rationale for absent
product capabilities instead of leaving their applicability ambiguous.
