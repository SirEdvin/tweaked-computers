# Proposal

## Why

<!-- Explain the motivation for this change. What problem does this solve? Why now? -->

## What Changes

<!-- Describe what will change. Be specific about new capabilities, modifications, or removals. -->

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. Name each capability for a cohesive system
     behavior that can own related requirements as the system evolves. Do not name
     implementation tasks or proposal sections. Avoid broad catch-all names. Use
     kebab-case for path segments you introduce (e.g., user-auth or identity/user-auth)
     that follow the project's existing spec organization. Each creates
     specs/<capability-path>/spec.md. -->
- `<capability-path>`: <brief description of what this capability covers>

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec file.
     Use the exact existing path under openspec/specs/. Leave empty if no requirement
     changes. A change with no capabilities at all (pure refactor, tooling, docs)
     must set `skip_specs: true` in its .openspec.yaml - openspec validate rejects
     a zero-delta change without that marker. Do not invent a requirement just to
     satisfy validation. -->
- `<existing-capability-path>`: <what requirement is changing>

## Impact

<!-- Affected code, APIs, dependencies, systems -->

## API Impact

Status: changed
Reason: <why the public contract changes, or why it does not>
Compatibility: <callers, removals and migration, or no public change>

<!-- For changed: include EVERY affected canonical file. Use '-' for no removed
     identities, otherwise comma-separated exact public identities (including
     members as Type.field). No signatures belong in this inventory. -->
| Canonical path | Disposition | Removed identities |
| --- | --- | --- |
| api/<file>.d.lua | added/modified/removed | - |

<!-- For none: remove the table, set Status: none, explain the review above and
     add Reviewed-source: <SHA-256 from api_changes.review_fingerprint>. No fake
     declaration files. See docs/documentation-maintenance.md for the command.
     Refresh after reviewing later source, proposal or design changes. -->
