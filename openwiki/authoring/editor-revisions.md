---
type: workflow
title: Editor revisions, authority and recovery
description: The native GUI and plain editor model keep drafts, saved revisions and active execution separate while rechecking player and entity authority.
tags: [editor, revisions, authorization, recovery]
sources:
  - id: openwiki-source-0ddacafef71462f8b63089cd
    resource: repo://scripts/runtime/computer.lua
  - id: openwiki-source-92ddf1aa156aebd2c038aa1c
    resource: repo://scripts/ui/editor-layout.lua
  - id: openwiki-source-9bdd101d2a3d48be3d3699c7
    resource: repo://scripts/ui/editor-model.lua
  - id: openwiki-source-56946c7bbf28112aad8ee479
    resource: repo://scripts/ui/editor.lua
generated: { by: "hermes", at: "2026-10-15T13:11:13.133Z" }
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T13:11:13.133Z
---

# Editor revisions, authority and recovery

## Three different documents

The model in `scripts/ui/editor-model.lua` owns per-player documents under `root.player_drafts`; the GUI in `scripts/ui/editor.lua` is a view/controller, not a guest service. A draft records `source`, `base_source` and `base_revision`. The computer separately owns `saved_source`/`saved_revision` and its active source snapshot. These are deliberately independent:

- Validate compiles the draft using the computer's shared admission context; it does not save or execute it.
- Save calls `runtime.save` with the draft's base revision, then updates that baseline. Running code is unchanged.
- Run/Apply require the draft baseline to equal the current saved revision and its text to equal saved text. They activate that saved revision, never unseen edits.
- A failed candidate validation occurs before retiring the old generation. Successful activation gives a new run ID and cleans up the old run's outputs and registrations.

Do not collapse these transitions into a single text-change handler. Editing is authoring, not implicit execution.

## Authority is checked at the point of action

Opening requires a live computer whose body still maps to the exact registry record, matching force/surface, player reach and relevant permission-group actions. A session stores body unit number, generation and a monotonic token. Every model edit/action revalidates these values; stale windows cannot retarget a replacement entity.

The GUI adds its own envelope checks: event player, frame tags/token, currently opened frame, valid element and bounded ancestor walk to the owned frame. Text edits are accepted only from the actual source widget. A rejected oversized edit restores the previous model draft in the widget. Custom input does not hijack another opened GUI; closing/unavailable-player handlers remove sessions and native frames, not retained documents.

## Conflicts and recovery are deliberate

Save is optimistic concurrency: stale expected revision produces `E_BUSY`. Review captures the current saved revision and text. Rebase keeps local draft text but moves its baseline to that reviewed revision; Reload replaces draft text. Both recheck that the reviewed snapshot is still current. Neither is an unconditional overwrite button.

Each player has eight retained draft slots. Capacity failure asks for an explicit Forget decision rather than evicting a dirty or removed-device draft. Closing a session preserves documents even after destruction, disconnect or force changes. Recovery mode can review/forget retained documents; Forget requires a second confirmation. Recover copies text into a current draft without Save or Run.

Formerly active source has a distinct review/copy path: the copy verifies the active snapshot still matches the review, then changes only draft text. This matters after material placement or unsupported-run recovery, where an active source snapshot may be useful text but is not a currently executing program.

Reset also has a two-step model transition. The GUI requires `stopped`, captures run generation, and rechecks both on confirmation. Runtime reset clears only explicit computer state, not the separate physical KV database. Ordinary Stop retains source/state and calls teardown.

## Five tabs without replacing the document

`editor.lua` creates a native tabbed pane with Editor, Console, Peripherals, Reference and Maintenance. The source stays mounted across navigation, Focus and routine refresh; only an explicit reviewed source replacement changes its text. Editor has one Validate/Save/contextual Run-or-Apply/Stop row. Focus hides supporting navigation and remembers the prior tab. `editor-layout.lua` clamps physical window position using GUI scale; the minimum supported effective size is 760×480 GUI units. Four resolution/scale calculations and schema-aware table-backed construction are not native visual acceptance.

Console Follow off retains its selectable snapshot until explicit Refresh/resume. Peripherals performs real selected-color inspection and separates refused/pending from empty inventories. Reference uses bounded search/category/topic state and native text selection; the starter inserts only into an empty draft. Maintenance holds reviewed saved/active/retained source and identity-specific destructive confirmations. New tab/selection/checkbox routes pass through the same owned-frame envelope and exact widget checks as clicks/text.

## Refresh and extension seams

Live status/output refresh is registered in the render phase every 15 ticks and charged through maintenance admission. Display-size changes resize/reflow widgets without rewriting `player.opened` or focus. Add actions in both the model and view; keep all data-loss/activation decisions in the model so mocks can test them without pretending to prove native client focus.

The optional network inspector is registered during control parsing and reports red/green results independently. Help and template insertion remain host authoring aids; a template only replaces an empty draft. They do not enlarge guest authority.

`tests/editor_contract.lua`, `tests/editor_workspace.lua` and `tests/editor_cold.lua` exercise revision/recovery, tab/focus/ownership/layout and cold retention; integration/lifecycle fixtures cover Save/Run and material recovery. The [integrated candidate](../../docs/rd5-candidate.md) identifies exact packaged checks. Native typing, paste/focus, button delivery, graphical layout and multiplayer editing remain user-owned client checks; headless and GUI mocks do not pass them.

Related: [runtime activation](../architecture/runtime-and-state.md), [material lifecycle](../devices/ownership-and-lifecycle.md), [operations and verification boundaries](../operations/build-test-and-assets.md).
