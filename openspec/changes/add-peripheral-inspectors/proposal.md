# Proposal

## Why

Players currently have to use a computer or guest program to inspect peripheral identities and state: ordinary opening suppresses the underlying native dialogs without providing a replacement. Read-only, device-local inspectors will make wiring, stored data, circuit behavior and monitor geometry understandable without writing diagnostic code or exposing implementation controls.

## What Changes

- Give every existing peripheral family a native inspector: KV Database, Monitor, Logic Handler, Configurator and Recipe Searcher. Every inspector shows its localized device name, exact API peripheral name and availability, with a selectable read-only name and an explicit select-for-copy action using native Copy.
- Open peripheral inspectors with the normal entity-open action. Preserve Ctrl-click computer editing, Ctrl-click monitor touches, recovery entry and native inventory gestures. Computers keep their existing workspace rather than receiving a second inspector.
- Add complete read-only browsing of live KV string values and hash fields/values, including safe presentation of arbitrary bytes and explicit snapshot/expiry semantics. No database editing, deletion or expiry controls.
- List configurator target-side factory devices grouped by exact entity prototype, with unique device counts and explicit red/green connectivity. Do not substitute computer-network discovery or omit unsupported-but-connected targets.
- Present Logic Handler signals in a native-combinator-style layout: a shared Input signals area containing distinct red- and green-backed slots, alongside the handler's own Output signals. Preserve each input wire's values and quality/type identity; add no expression, filter or output-edit controls.
- Display the logical monitor's connected tile width × height and total tile count, plus terminal columns × rows and text scale. Following clarification, character cells are labelled as such, not described as pixels.
- Keep inspection bounded, authority-checked and non-mutating, with explicit empty, unpowered, pending, stale and removed states. Preserve existing guest APIs, data, output ownership, topology and rendering contracts.

## Capabilities

### New Capabilities

- `peripheral-inspection`: Device-local, read-only native inspector access, identity copying, shared authority/lifecycle behavior, refresh bounds and usable layout across the complete peripheral family.

### Modified Capabilities

- `kv-database`: Add complete read-only UI browsing of live strings and hashes without altering database or expiry semantics.
- `device-configurator`: Add a target-network inventory UI grouped by prototype, with deduplicated counts and explicit wire membership.
- `logic-handler`: Add read-only, combinator-style signal inspection without combining guest API channels or exposing native configuration.
- `monitor-display`: Add logical-display identity and tile/terminal-size inspection without changing monitor touches, grouping or drawing.

## Impact

- Primary integration points are `control.lua`, `scripts/ui/interaction.lua`, new focused inspector UI/model modules, `scripts/lifecycle.lua`, `scripts/registry.lua`, existing peripheral services and locale definitions. Existing native opening is currently blocked by `body.operable=false`, so event routing alone is insufficient; placement and existing-save reconciliation must be covered.
- Reuse `scripts/configuration/targets.lua`, KV validation/live-entry rules, Logic Handler signal normalization, monitor logical-group resolution and the synchronized maintenance ledger. Do not add a GUI framework, a new discovery cache, a synthetic computer identity or guest API methods merely to support inspection.
- Preserve the `recipe-searcher` prohibition on a dedicated recipe-search GUI: its new inspector is identity/status only. The existing per-color Logic Handler API remains explicit even though both colors appear together visually.
- Update tests that currently assert every body is inoperable or ordinary opening always produces no GUI. Add provider/UI contract coverage, packaged base/Space Age checks, existing-save/cold-load checks and actual native input/copy/visual verification; headless tests are not visual acceptance.
- This change is additive to player inspection. No guest API signature, save-data reset, device artwork replacement, dependency addition, release or publication is part of the proposal.
