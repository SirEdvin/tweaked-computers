# Editor-related Lua contract and authoring cases

Normative companion to [spec.md](spec.md). The editor deliberately does not introduce a guest filesystem API. A computer has one source document, an optional per-player draft, a saved revision and an active revision. Saved-program authoring has no filenames, `disk.*`, `fs.*`, operating-system commands, `require`, `loadfile` or executable file imports. The independent [Console](../console-shell/lua-api.md) accepts bounded synchronous Lua commands without altering these saved-source rules. Task-specific tabs and the complete preserved action mapping are documented in [device-experience.md](../../api/device-experience.md).

## Source entry and lifecycle

Use the function-declaration grammar in [program-source/lua-api.md](../program-source/lua-api.md). The editor supplies templates and API help, not hidden startup files. Source is compiled/validated only through the approved native pipeline.

| Player action | Source effect | Execution effect | Persistent data |
| --- | --- | --- | --- |
| Open/type/paste | Change that player's draft | None | Unchanged |
| Validate | Report syntax/subset/capacity diagnostics | None; no factory effects | Unchanged |
| Save | Revision-checked commit of draft to saved source | Existing active revision continues | Unchanged |
| Run/Apply | Validate selected saved revision | Retire old run only after successful validation; create new run and `start` | Explicit state retained |
| Stop | No source change | Cancel current work and clear still-owned logic output | State/KV/display retained |
| Reset State | No source change | Requires stopped state and explicit confirmation | Clear only this computer's explicit state |
| Close | Save/Discard/Cancel or retained draft | No implicit run/stop | No silent loss |

The UI identifies when a saved revision differs from the running revision. A rejected or conflicted edit remains available for recovery. Rebase/reload must be an explicit reviewed user action; it is not permission to overwrite newer source. GUI events must prove the opened editor belongs to this player/computer and that force/interaction authority still holds.

## Guest-visible diagnostics

`computer.log(text)` writes bounded plain text to the output pane. It is not a character-cell terminal, and it never interprets Factorio rich-text control strings from a program. Runtime errors show original line/column where available, handler, active source revision and code. Validation highlights the candidate source revision instead of blaming the previous running program.

There is no guest API to read other players' drafts, inject editor input, run another computer or reset another computer's state. Source extraction/import for tests is host tooling only, not part of gameplay.

## Minimal in-game program

```lua
function start(event)
  computer.log("Controller started")
  computer.on("peripheral_attach", "attached")
end

function attached(event)
  computer.log(event.peripheral .. " attached on " .. event.wire)
end
```

Acceptance must type/paste this through the real editor, save and run that saved text, wire a peripheral and observe the output. Executing an untouched bundled fixture is not proof that the editor-to-program path works. Repeat with a syntax error, unsupported feature, conflicting second editor, dirty close, native text-field focus and Stop/Run buttons. Verify source and state through a cold save/load with both an active old revision and a different saved revision.
