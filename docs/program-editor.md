# Program editor — Lua API v1

This editor uses Factorio's native multiline text box and visible buttons. It is
one source document per computer, not a shell, OS, terminal emulator or filesystem.
Client typing/paste/focus/layout and multiplayer usability testing is deferred to
the user. Headless handler checks do not establish those client properties.

## Open and write a program

Select a computer (its owned NETWORK port also resolves to the same body), then
use the normal Open GUI control or the rebindable **Open computer editor / recovery
drafts** action, initially Ctrl+Shift+E. The linked normal-open path is implemented
but actual client delivery is unverified. Do not rely on a custom shortcut while
the source field is focused: use the native buttons.

Use **Template** in an empty draft, or copy the example from **API Help**. The
shipped example is:

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.log("Controller started")
      computer.on("peripheral_attach", "attached")
    end,
    attached = function(event)
      computer.log(event.peripheral .. " attached on " .. event.wire)
    end
  }
}
```

1. Edit the source. This changes only your draft.
2. **Validate** checks the draft through the guarded native compiler. It does not
   run a handler, commit source, replace an active run or clear application data.
3. **Save** commits the exact draft with a saved-source revision check. Saving an
   invalid program is allowed; activation is not. The existing active revision
   continues, and status shows draft base, saved and active revisions separately.
4. **Run** / **Apply** validate and activate the displayed saved revision. First
   save any unsaved edits, and resolve any stale base. Neither button silently
   saves your draft or activates another player's unseen newer revision. Only
   successful validation retires the old run and queues its named `start` handler.
5. **Stop** cancels work/timers/subscriptions and invokes host fail-safe cleanup.
   Source, application state, KV contents and display contents remain.
6. **Reset State** requires a stopped computer and the separate **Confirm Reset
   State** button. It clears only this computer's explicit state, never a KV.
   Cancel, reopening, editing or activating a new generation expires confirmation.

Callbacks use the versioned bounded native language and dot-call APIs described
in [computer-runtime.md](computer-runtime.md). No host objects or loader/IO/OS APIs
are introduced by the editor. Earlier accepted effects are not rolled back when
a later callback faults; only its still-owned fail-safe resources are cleaned up.

## Conflicts and draft recovery

Two players have independent drafts, each with a base saved revision. A stale
Save reports a conflict and retains both the committed source and rejected draft.

- **Review Current** displays a read-only snapshot of the current saved revision.
- After reading it, **Rebase — keep draft** adopts that base while preserving your
  text. It is a reviewed manual overwrite decision, not an automatic merge. Save
  is still required.
- **Reload — discard draft** replaces your text with the reviewed saved source.
- Both actions recheck the current source/revision. If another player saved since
  the review, review again; no stale acknowledgement is accepted.

Close/Escape always retains the draft; closing does not save, activate or stop.
Disconnect/death/force/surface change also retains documents. Reopening the exact
computer restores your text. A removed/replaced computer never retargets an old
draft. Select a recovery identity in the current editor and **Copy selected draft**
to import its text into the current draft; that does not save or run it.

Ctrl+Shift+E with no selected computer opens the independent recovery viewer.
You can review/copy text there even after the old body was destroyed. Forgetting
a draft requires **Forget reviewed** followed by **Confirm Forget**; cancelling
retains it. This viewer cannot activate a computer or clear application state.

There are eight document slots per player, each with at most `source_bytes`
(currently 16,384) bytes of draft text and a bounded base-source snapshot. One
review snapshot and small plain session/diagnostic records are separate. No dirty
slot is evicted automatically. When all eight are occupied, opening a ninth body
opens the recovery viewer and requests explicit deletion of a slot. Over-limit
text entry restores the previous accepted draft rather than silently truncating
it. Saving the game retains the drafts; an unsaved game cannot guarantee recovery.

## Output and help

The rolling console retains the newest `console_entries` / `console_bytes`
(currently 64 / 16,384). Its heading explicitly warns that older output is
discarded. Logs, source, review text, diagnostics and help use disabled native rich
text: player/program text is not interpreted as Factorio tags. Runtime diagnostics
show the active revision, handler and original source location when available;
candidate diagnostics identify draft/saved base revision separately.

**API Help** lists the v1 document shape, approved namespaces, state/event/timer
signatures, dot-call convention, discovery rules and the actual shipped template.
**Refresh Peripherals** inspects red and green separately, showing complete
names/types/power, or an explicit pending/error result. There is no mixed-color
path, network-ID shortcut, or apparently complete prefix. In an editor-only
checkpoint before the sibling discovery integration, the pane explicitly says
that discovery is not installed and does not claim an empty successful inventory.

## Host integration (not a guest API)

`scripts.ui.editor-model` owns plain authoring records under
`storage.tweaked_computers.player_drafts[player_index]`. Each contains `documents`
keyed by opaque computer ID and an optional session. Each document stores
`source`, `base_source`, `base_revision`; session stores exact ID/body unit/generation,
an opaque token and bounded review/confirmation state. No player/GUI objects,
functions or compiled code are persisted here. `on_load` performs no editor work.

`model.open(player,id)`, `edit(player,token,text)` and
`action(player,token,action,tick,argument?)` use the real runtime save/activate/stop/
reset methods. Actions require current force/surface, reachability, native GUI
permissions, exact registry/body identity and session token. The GUI adapter adds
proof that the event belongs to the player's exact opened frame and a real child
of it. Hidden/inactive/foreign/stale elements cannot mutate the computer.

`scripts.ui.editor.register_inspector(fn)` registers one trusted parsing-time
host callback `fn(record,wire,tick)` returning a complete dense array of plain
`{name,type,powered}` descriptors, or `nil, diagnostic`. The discovery worker's
production traversal must supply it; do not implement another graph in the UI.
The callback must bound/admit its own work and never return an incomplete prefix.
The downstream TC07 card merges editor and discovery parents and wires this
adapter before claiming the full controller milestone. No user source calls it.

Status/output refresh is a charged scheduler rendering hook, at four updates per
second while an authorized editor is actually open. Display-size events resize
and reflow controls without reopening the frame over another GUI or changing its
source/focus. Core font/style existence is checked during the data stage; actual
client rendering, font appearance and control delivery remain unverified.

## Verification boundaries

`tests.editor_contract` exercises production authoring actions plus mocked GUI
handler routes, including source consumption, conflicts/review recheck, invalid
replacement, confirmation, permissions, exact body replacement, draft capacity,
rich-text disabling, rolling output, inactive/cross-player event refusal, dirty
close/reopen and malicious active source beside a healthy peer.

`tests.editor_cold` runs these contracts and a real powered computer in two
separate official engine processes. It edits/saves/runs source through table-backed
GUI handlers, then freezes distinct active/saved/draft revisions and spent credits.
Cold readback precedes resumed work, verifies no `on_load` mutation or startup
replay, restores draft text, and completes the original timer exactly once.
This is real native runtime/persistence evidence, not evidence of physical keyboard,
clipboard, GUI focus, graphical rendering or multiplayer client delivery.
