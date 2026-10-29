# Proposal

## Why

Saved computer programs should have one authoring language: named function declarations. A single compiler path, consistent runnable examples and one authoritative documentation contract remove ambiguity and maintenance work throughout the repository.

## What Changes

- **BREAKING:** Accept only exported function declarations, optional private local-function declarations, comments and empty statements at the saved-program top level. Use the existing declaration compiler directly; remove alternate source-shape selection and its implementation, tests and documentation.
- Keep ordinary calls, named event registration, optional `start`, guarded native execution, the independent Console, explicit state, and all existing resource and authority protections unchanged. Do not introduce a converter, migration, compatibility option or fallback.
- Rewrite maintained example programs and behavioral fixture sources into the accepted language without discarding their functional, safety, admission, persistence or integration assertions. Replace format-specific acceptance cases with declaration-language cases where they protect a still-supported behavior.
- Make in-game Reference, generated player examples, source/API companions and package content consistent with the same grammar. Correct generator inputs, not only their generated output.
- Apply the cleanup across the entire current repository tree, including archived OpenSpec artifacts, historical release/verification prose, changelog entries, generated OpenWiki pages and their associated claim metadata. No historical-document exemption applies. Remove obsolete passages without attributing new execution results to historical receipts.
- Describe the accepted language positively in this change itself; do not embed examples of a second program format in planning artifacts, comments, diagnostics or rejection fixtures.
- Verify locally with the existing tooling and packaged Factorio harnesses. Do not restore GitHub test CI or hosted required checks.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `program-source`: Define function declarations as the only saved-program grammar; preserve callable/export semantics and supported source lifecycle; require repository-wide consistency of source examples and language references.
- `computer-runtime`: Bind native named-handler execution to that single grammar without changing scheduling, state, guard or service contracts.
- `program-editor`: Require starter, Reference and authoring guidance to expose only the accepted grammar while retaining safe draft/save/activation behavior and native copying.
- `console-shell`: Express the command-language boundary independently of saved-program source packaging, preserving its existing statement/expression and scratch-value behavior.

Other peripheral API signatures and semantics are unchanged. Their companion examples are cleanup targets, not new capabilities.

## Impact

- Compiler/sandbox: `scripts/runtime/compiler.lua`, the shared handler-preparation helper in `scripts/runtime/sandbox.lua`, and their tests. `scripts/runtime/computer.lua`, `scripts/scheduler.lua`, `scripts/runtime/shell.lua` and `scripts/ui/editor-model.lua` are callers/boundaries to verify, not invitations to redesign execution.
- Content: `examples/`, `tests/`, `scripts/ui/help.lua`, `scripts/ui/tutorials.lua`, `tools/planning_examples.py`, `tools/player_docs.py`, `docs/`, `README.md`, `changelog.txt`, `openspec/api/`, `openspec/specs/`, `openspec/changes/archive/` and `openwiki/`, including hidden generated metadata. Preserve legitimate host-module source-string wrappers, runtime handler inventories, API version fields and unrelated uses of Lua tables.
- Harnesses: source-bearing current, cold, client and historical-engine fixtures need consistent authoring. Historical mod runtimes incapable of compiling current declarations must not be given a hidden alternate compiler path; retain their independent physical/data upgrade checks with test-only host setup and use a function-capable baseline for running-program continuity.
- Delivery: no new dependency, setting, budget, runtime representation or peripheral method. The maintainer confirmed that no player programs require conversion and explicitly included historical checkout documents in the cleanup. Git history, existing release tags/assets, game distributions, player saves and external frozen evidence are outside the edit scope.
- This change contains planning only. Source cleanup, generated updates, actual engine/client runs, publication and archival have not been performed.
