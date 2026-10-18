# Proposal

## Why

The Console currently displays output but cannot run a small experiment without replacing or editing a saved handler program. An interactive Lua prompt would let players discover peripherals, retain a binding such as `p = peripheral.wrap(name, "red")`, and inspect or exercise it before building a larger controller.

## What Changes

- Add a single-line command field at the bottom of the existing Console tab, with Enter submission and an Execute button. Keep selectable bounded output, Follow, the existing editor, and its draft/revision controls. Command history was removed by explicit user approval on 2026-10-18 after native focused arrows failed the feasibility gate.
- Execute statements and expressions in a separate scratch environment shared by all authorized players of that computer. Run commands on powered computers whether their saved program is stopped or running; do not implicitly Save, Run, or replace that program.
- Add shell-local `print(...)`, command echo, expression-result display, and recoverable command diagnostics. Peripheral operations have real factory effects, not dry-run semantics.
- Persist bounded shell values for multiplayer correctness. They survive window close/reopen and save/load. A computer restart or explicit Reset Shell clears the session. This supersedes the initial request for memory-only variables, following the user's explicit approval.
- Preserve the native guarded execution model and existing language restrictions. Retained shell values include ordinary serializable data and symbolic peripheral bindings; raw host functions, executable closures, and LuaObjects are never saved. General persistent user-defined closures are outside this first shell capability.
- Keep shell ownership separate from program ownership, while sharing the same computer admission ledger and live authority checks. Shell errors must not fault an unrelated running program.
- Require actual client verification of focused text entry, paste, caret movement and Enter; no history navigation is provided.

## Capabilities

### New Capabilities

- `console-shell`: Interactive single-line Lua evaluation, a shared durable scratch environment, live peripheral access, and its authority/resource/lifecycle contract within the Console tab.

### Modified Capabilities

None in the canonical inventory: `openspec list --specs` currently reports no specs. Related contracts exist only in the unarchived `add-native-circuit-computers` and `redesign-device-experience` changes. This proposal does not rename, duplicate, archive, or edit those capabilities. The new capability explicitly scopes its exception to their no-shell/no-global-write rules to Console evaluation; saved handler programs remain unchanged. Reconcile those statements when the related capabilities are promoted to main specs.

## Impact

- Runtime/compiler: `scripts/runtime/compiler.lua`, `sandbox.lua`, `computer.lua`, `limits.lua`, admission and the shared scheduler; introduce a focused shell module rather than a VM or OS.
- Services/lifecycle: the peripheral facade boundary, writer ownership and cleanup in logic/monitor services, registry initialization, and deliberate exclusion of sessions from item/blueprint/clone payloads.
- GUI: `scripts/ui/editor.lua`, `editor-model.lua`, layout/help, `prototypes/editor.lua`, `control.lua` event registrations, and English localization.
- Tests/docs: extend packaged runtime/editor contracts, add shell and cold-reload fixtures, document the shell language/value/API boundary, and verify focused keys plus real multiplayer late joining.
- No new runtime dependency, filesystem, background shell scheduler, coroutine support, budget increase, or change to existing program source syntax is proposed. SH1 subsequently authorizes implementation and PR publication; independent acceptance/merge and release remain downstream responsibilities.
