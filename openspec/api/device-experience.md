# Lua and editor compatibility contract

## Public Lua remains version 1

The physical/editor redesign adds no guest method, event, filesystem, terminal or interpreter. The complete canonical contracts in this `api/` directory and `../specs/*/lua-api.md` preserve arguments, nil/tuple results, errors, limits and persistence. The later monitor-buffering and Console capabilities extend their own surfaces explicitly; neither authorizes weakening saved-handler restrictions. Player-facing `docs/` describe the actual interaction.

Preserve `computer`, `peripheral`, `colors`/`colours`, named callbacks and explicit durable state. Preserve opaque peripheral names and explicit red/green discovery arguments; a friendly UI label never replaces the authorization identity. Input/output/target roles stay distinct. Physical shell replacement must not silently assign unrelated logical IDs or replay startup callbacks.

Monitor coordinates, 64-unit tile pitch, two-unit bezel, character scale, palette, cell state, grouping and touch event payloads do not change. Marking/canceling deconstruction changes presentation only; actual removal follows the existing lifecycle.

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
| open_recovery / recovery_action | Standalone recovery entry | Still available without an accessible computer; review and confirmed forget only. |
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
