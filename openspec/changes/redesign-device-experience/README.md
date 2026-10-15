# Device experience redesign — review package

Status: planning only; explicit user approval is required before any new task is available for work.

Start with [review.html](review.html) in a browser: a native-styled tab/focus layout concept and schematic silhouettes for all five devices. It is not a native screenshot, final game art or a playable prototype.

## Proposed milestones

| Milestone | Outcome | Prerequisites |
| --- | --- | --- |
| RD1 | Direct device wiring, role layout and safe existing-alpha interaction migration | None |
| RD2 | Five distinct industrial device designs, all directions/icons/states | RD1 |
| RD3 | Complete code-first tabbed computer UI with preserved recovery/authority | None |
| RD4 | Correct monitor layers and native deconstruction feedback | RD1, RD2 |
| RD5 | Integrated candidate, player documentation and source-grounded developer OpenWiki | RD2, RD3, RD4 |

Kanban identifiers and verified held state are recorded in `task-map.json` after card creation. Each milestone owns its focused checks and documentation; RD5 verifies integration rather than deferring all testing to the end.

## Reading map

- [proposal.md](proposal.md): requested outcomes, scope and non-goals.
- [design.md](design.md): physical carriers, socket contract, five tabs, art family and migration.
- [research.md](research.md): pinned source findings and honestly separated hypotheses.
- [tasks.md](tasks.md): implementation checklist and approval boundary.
- [api/compatibility.md](api/compatibility.md): unchanged public Lua v1 and every current editor action's destination.
- [validation.md](validation.md): checks performed on this planning package, not the future implementation.
- `specs/`: program-editor, peripheral-network, monitor-display, device-lifecycle and new device-visual-identity requirements. Existing APIs have companion compatibility references.

## Baseline and archive ordering

Implementation baseline: `cb300e62ebad6a4a9a38a0679f21e251009f1d16`. Existing capabilities are in the still-unarchived `add-native-circuit-computers` change, not canonical `openspec/specs`. Therefore strict validation accepts these planning deltas but reports that modified requirements cannot be archived before their baseline is established. This is recorded, not hidden by treating existing capabilities as new. Do not archive the earlier change, mark deferred checks passed or synthesize canonical specs during this planning task. Reconcile baseline/spec archival in the separately authorized workflow later.

## Approval boundary

All new cards are assigned to Albina and created blocked. No timed release and no dependency promotion may substitute for explicit user validation. No redesign code has been written; no release/default-branch merge/protection change is authorized here. The old publication task is outside this redesign campaign.
