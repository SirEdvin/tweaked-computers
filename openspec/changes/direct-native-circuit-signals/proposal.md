# Proposal

## Why

The Logic Handler wraps native circuit data in a 64-signal ceiling, normalization, sorting, repeated validation and generic Data copies that impose further limits. Replace that machinery with direct native access, without importing the unfinished general resource-policy/runtime rewrite.

## What Changes

- Read the selected native input on every call. Trust engine-produced signals: no value revalidation, reaggregation, sorting, reusable read cache or persisted processing jobs.
- **BREAKING:** signal collections have no mod-defined ordering; native signal records retain optional fields instead of being expanded into explicit type/name/quality records. All native signal categories are preserved.
- Remove mod-defined signal-count, filter-count, output-slot and signal-name ceilings, including equivalent restrictions in the circuit-specific argument, result, registration, event and inspector paths. Native output domains still apply.
- Keep subscriptions and their existing event shape. Check subscription-count admission only when the user registers; retain only the previous observation and pending event data needed by the event contract. Compare identities and counts, not array positions.
- Keep direct reads and circuit notifications independent of generic Data payload ceilings. Preserve sandbox isolation, guest execution budgets, bounded event backlog and existing overflow behavior; do not introduce a general unlimited-data API or a new resource-accounting framework.
- Preserve user-input validation, explicit wire selection, physical authority, power, atomic output replacement, ownership and fail-safe cleanup. Read the handler's own native output configuration, not a reusable bank cache or the combined output network.
- Update the Logic Handler API companion, inspector consumers, player documentation, Reference and focused native regressions together. No new settings, dependencies, peripheral methods or asynchronous APIs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `logic-handler`: direct complete native signal access, native record shape/order, admission-only subscription limits and cache-free observations.
- `computer-runtime`: a narrowly trusted circuit-data boundary that does not copy native inventories through generic Data ceilings, while retaining guest isolation and execution/backlog safety.
- `peripheral-inspection`: direct uncapped circuit observations with native-field-aware presentation; other inspector families retain their existing policy.

## Impact

The implementation starts from `main`, not `feature/resource-policy-completion`. Main's `scripts/services/logic.lua`, circuit crossings in `scripts/runtime/{sandbox,computer,compiler}.lua` and `scripts/services/peripheral.lua`, plus `scripts/ui/peripheral-inspector{,-model}.lua` are the relevant integration points. Any lifecycle/limit cleanup is confined to obsolete circuit state and guards. General compiler behavior, continuations, discovery, KV, monitors, Configurator and other peripheral policies are out of scope.

The previous branch is evidence of pitfalls only: `docs/inventory-resource-validation.md:84` records a large subscription still failing generic `data.copy` despite large-read passes. Its resumable jobs and memory framework are not dependencies of this change.

Existing programs relying on sorted arrays or always-present identity fields need adjustment. Valid saves retain subscriptions, queued observations and output ownership without replay. This change replaces the withdrawn `replace-arbitrary-limits-with-resource-policy` proposal, whose artifacts are removed from main without applying or archiving its deltas. The earlier implementation branch remains available as historical evidence and is not merged. This proposal authorizes planning only.
