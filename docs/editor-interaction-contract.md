# Editor interaction preservation

Host-only action placement and acceptance, not guest API declarations.
The public contract is [api/README.md](../api/README.md); source grammar and
runtime behavior remain in their behavioral specifications.

## Complete editor action placement

These are host-only adapter actions, not new guest APIs. The current model remains the authority.

| Existing action | New home | Preservation rule |
| --- | --- | --- |
| validate | Editor compact toolbar | Validate draft; do not save/activate. |
| save | Editor compact toolbar | Commit reviewed revision; do not change active run. |
| run / apply | One contextual Editor button | Only displayed saved source; dirty/conflicted drafts explain why disabled. |
| stop | Editor compact toolbar | Preserve source/state/peripheral data; existing owned-output cleanup. |
| reset / confirm-reset / cancel-reset | Maintenance danger section | Stopped only, explicit identity-specific confirmation. |
| review | Maintenance revision panel; Editor conflict shortcut | Show current saved text; no automatic reload. |
| rebase | Maintenance reviewed resolution | Preserve draft and recheck current saved revision. |
| reload | Maintenance reviewed resolution | Explicitly discard draft only after review. |
| review-active / copy-active | Maintenance source recovery | Review before replacing draft; copying never saves/runs. |
| review-recovery / recover | Maintenance retained-drafts panel | Select/review source before replacing current draft; no autoactivation. |
| forget / confirm-forget / cancel-forget | Maintenance retained-drafts panel | Explicit confirmation; never evict the open document. |
| open_recovery / recovery_action | Capacity recovery entry from an accessible computer | Eight retained slots open the viewer instead of evicting drafts; review and confirmed forget only. Removed-computer drafts remain recoverable through another computer's Maintenance; empty ground never opens UI. |
| close | Native title close / Escape | Retain draft; do not stop execution. |
| text edit | Editor source widget | Existing byte limits and exact player/frame/session/generation checks. |

New host-only presentation state: selected tab, focus mode, Console follow and Reference topic/search. It must be bounded, per-player and unable to invoke guest code by itself. Tab/focus/status updates do not recreate or overwrite the source widget. Check ownership on all new nested events rather than loosening the former bounded ancestor check.

## Concrete user workflow acceptance

1. Open a computer, paste the shipped `scripts/ui/help.lua` template, Validate, Save, then Run. These remain separate actions.
2. Edit an unsaved character; switch through all tabs and focus mode; return to exact draft text without changing the active run.
3. Resolve a real revision conflict through Review and Rebase or explicit Reload, not an automatic merge or lost draft.
4. Wire the visible computer to the visible monitor; inspect the actual opaque name on the chosen channel; existing `peripheral.wrap(name, wire)` programs keep working.
5. Mark then cancel one tile in a populated monitor array; native X becomes visible while model state and coordinate semantics remain intact.

The shipped template is used unchanged in the planning mockup; mock buttons do not execute it.

## Source entry and lifecycle

Use the function-declaration grammar in [saved-program grammar](player/api/language.md). The editor supplies templates and API help, not hidden startup files. Source is compiled/validated only through the approved native pipeline.

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

## Editor delivery acceptance

Acceptance must type/paste this through the real editor, save and run that saved text, wire a peripheral and observe the output. Executing an untouched bundled fixture is not proof that the editor-to-program path works. Repeat with a syntax error, unsupported feature, conflicting second editor, dirty close, native text-field focus and Stop/Run buttons. Verify source and state through a cold save/load with both an active old revision and a different saved revision.
