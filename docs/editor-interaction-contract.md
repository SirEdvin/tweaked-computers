# Editor interaction preservation

This document covers host-only action placement and acceptance, not guest API declarations.
The public contract is [api/README.md](../api/README.md). Source grammar and
runtime behavior remain in their behavioral specifications.

## Complete editor action placement

These are host-only adapter actions, not new guest APIs. The current model remains the authority.

| Existing action | New home | Preservation rule |
| --- | --- | --- |
| validate | Editor compact toolbar | Validate the draft. Do not save or activate it. |
| save | Editor compact toolbar | Commit the reviewed revision. Do not change the active run. |
| run / apply | One contextual Editor button | Only displayed saved source. Dirty/conflicted drafts explain why the button is disabled. |
| stop | Editor compact toolbar | Preserve source/state/peripheral data. Use existing owned-output cleanup. |
| reset / confirm-reset / cancel-reset | Maintenance danger section | Stopped only, explicit identity-specific confirmation. |
| review | Maintenance revision panel and Editor conflict shortcut | Show current saved text. Do not reload automatically. |
| rebase | Maintenance reviewed resolution | Preserve the draft. Recheck the current saved revision. |
| reload | Maintenance reviewed resolution | Explicitly discard draft only after review. |
| review-active / copy-active | Maintenance source recovery | Review before you replace the draft. Copying never saves or runs it. |
| review-recovery / recover | Maintenance retained-drafts panel | Select the source. Review it before you replace the current draft. Do not activate automatically. |
| forget / confirm-forget / cancel-forget | Maintenance retained-drafts panel | Require explicit confirmation. Never evict the open document. |
| open_recovery / recovery_action | Capacity recovery entry from an accessible computer | Eight retained slots open the viewer instead of evicting drafts. Review and confirmed forget only. Removed-computer drafts remain recoverable through another computer's Maintenance. Empty ground never opens UI. |
| close | Native title close / Escape | Keep the draft. Do not stop execution. |
| text edit | Editor source widget | Existing byte limits and exact player/frame/session/generation checks. |

New host-only presentation state includes the selected tab, focus mode, Console follow and Reference topic/search. It must be bounded and per-player. It must not invoke guest code by itself. Tab/focus/status updates do not recreate or overwrite the source widget. Check ownership on all new nested events. Do not weaken the former bounded ancestor check.

## Concrete user workflow acceptance

1. Open a computer. Paste the supplied `scripts/ui/help.lua` template. Select Validate. Select Save. Then select Run. These remain separate actions.
2. Edit an unsaved character. Select each tab. Toggle focus mode. Return to the exact draft text without a change to the active run.
3. Resolve a real revision conflict through Review and Rebase or explicit Reload. Do not merge automatically or lose the draft.
4. Wire the visible computer to the visible monitor. Inspect the actual opaque name on the selected channel. Existing `peripheral.wrap(name, wire)` programs must continue to work.
5. Mark one tile in a populated monitor array. The native X must become visible without a change to model state or coordinate semantics. Cancel the mark. Model state and coordinate semantics must stay unchanged.

The planning mockup uses the supplied template unchanged. Mock buttons do not execute it.

## Source entry and lifecycle

Use the function-declaration grammar in [saved-program grammar](player/api/language.md). The editor supplies templates and API help, not hidden startup files. Source is compiled/validated only through the approved native pipeline.

| Player action | Source effect | Execution effect | Persistent data |
| --- | --- | --- | --- |
| Open/type/paste | Change that player's draft | None | Unchanged |
| Validate | Report syntax/subset/capacity diagnostics | None. No factory effects. | Unchanged |
| Save | Revision-checked commit of draft to saved source | Existing active revision continues | Unchanged |
| Run/Apply | Validate selected saved revision | Retire the old run only after successful validation. Create a new run and `start`. | Explicit state retained |
| Stop | No source change | Cancel current work and clear still-owned logic output | State/KV/display retained |
| Reset State | No source change | Requires stopped state and explicit confirmation | Clear only this computer's explicit state |
| Close | Save/Discard/Cancel or retained draft | No implicit run/stop | No silent loss |

The UI identifies when a saved revision differs from the running revision. A rejected or conflicted edit remains available for recovery. Rebase/reload must be an explicit reviewed user action. It does not permit an overwrite of newer source. GUI events must prove that the opened editor belongs to this player/computer and that force/interaction authority still applies.

## Editor delivery acceptance

For acceptance, type and paste this through the real editor. Save the text. Run that saved text. Wire a peripheral. Examine the output. Execution of an unchanged bundled fixture does not prove that the editor-to-program path works. Repeat with these cases:

- A syntax error
- An unsupported feature
- A conflicting second editor
- A dirty close
- Native text-field focus
- Stop/Run buttons.

Use an active old revision and a different saved revision. Verify source and state through a cold save/load.
