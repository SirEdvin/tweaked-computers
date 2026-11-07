# lua-api-workflow Specification

## Purpose

Keep future API proposals reviewable in the same typed Lua format as the published public library, without recreating independent Markdown API contracts inside OpenSpec.

## Requirements

### Requirement: Typed API artifacts for API-changing proposals
A proposal that adds, removes or changes public API signatures, types or documented semantics SHALL include reviewable `*.d.lua` artifacts for its affected API surface. Behavioral scenarios and design rationale SHALL remain in OpenSpec Markdown; signature and type tables SHALL not become a second handwritten API contract.

#### Scenario: Propose a new or changed API member
- **WHEN** a change affects a public callable, field, type, event, default, domain or failure contract
- **THEN** its planning artifacts contain the proposed declaration changes with parameter/result/field descriptions and affected canonical destinations
- **AND** the proposal states compatibility impact rather than relying on implementation code to reveal it later.

#### Scenario: Propose a removal
- **WHEN** a change removes a public declaration or module
- **THEN** the API artifacts and design explicitly identify the removed public identities and their prior canonical destinations
- **AND** a missing file or symbol is not interpreted as an intentional removal without that reviewable declaration.

### Requirement: API artifact discovery and completeness
The project workflow SHALL discover proposed Lua API files as API artifacts separately from behavioral Markdown specs. Planning verification SHALL check every declared affected API destination and resolve proposed type references against the unaffected canonical library. Existence of one matching file SHALL not certify an incomplete multi-module API proposal.

#### Scenario: Retrieve API context for implementation
- **WHEN** instructions or implementation context are requested for an API-changing proposal
- **THEN** they expose the concrete proposed `*.d.lua` files and their relationship to canonical library files
- **AND** no API draft is hidden merely because behavioral-spec discovery only matches Markdown.

#### Scenario: Missing affected file or referenced type
- **WHEN** an API-changing proposal omits one declared affected file, introduces a duplicate identity or leaves a type reference unresolved
- **THEN** the project planning check fails with the missing or conflicting identity
- **AND** a green file-existence status alone is not accepted as complete API review.

### Requirement: Explicit applicability without invented API changes
A change with no public API impact SHALL explicitly record that determination and SHALL not be required to invent declarations or duplicate the unchanged library. Conditional omission of an API artifact SHALL not waive required behavioral specs, design or implementation tasks.

#### Scenario: Internal or presentation-only change
- **WHEN** a proposal changes implementation or presentation without altering the public API contract
- **THEN** its API applicability decision is recorded and verification accepts the absence of API declaration changes
- **AND** its other required planning artifacts and applicable tests remain required.

#### Scenario: A no-API decision becomes stale
- **WHEN** an implementation or revised design introduces public API changes after a no-API determination
- **THEN** that determination is reopened and the affected typed API artifacts must be reviewed before the change is accepted.

### Requirement: Canonical promotion is distinct from proposal history
Applying an approved API change SHALL update the canonical public declaration library and regenerate its website/game outputs as part of the same change. Proposal API files SHALL remain change-scoped review history, not live documentation inputs. Archiving SHALL not create a second authoritative API library under OpenSpec specs.

#### Scenario: Apply and then archive an API change
- **WHEN** approved typed API artifacts are implemented and the change is later archived
- **THEN** the published library and generated references already contain the accepted contract
- **AND** archived proposal files remain historical, while maintained behavioral specs refer to the canonical library rather than copied API companions.

#### Scenario: Detect mismatch before acceptance
- **WHEN** implemented declarations, proposed API artifacts and actual public behavior disagree
- **THEN** verification reports the discrepancy and acceptance remains incomplete until the proposal or implementation is deliberately reconciled
- **AND** generation does not silently choose whichever source happens to be newer.

### Requirement: Project-local workflow migration
The API-artifact workflow SHALL be configured within this project without changing installed global OpenSpec schemas or unrelated projects. Existing active changes SHALL retain their own behavioral decisions and completion evidence while their API-document destinations are reconciled with the new authority model.

#### Scenario: Create a later change
- **WHEN** a maintainer starts a new change using the project's configured workflow
- **THEN** instructions explain API applicability, the `*.d.lua` format, canonical destinations and required verification
- **AND** no instruction requests a new handwritten `lua-api.md` companion.

#### Scenario: Resume an existing change
- **WHEN** an older active change is resumed after the documentation migration
- **THEN** its useful proposed API semantics are preserved in the new format or explicitly reconciled as already canonical
- **AND** unrelated unfinished tasks are not marked complete and later sync/archive cannot resurrect retired maintained companions.
