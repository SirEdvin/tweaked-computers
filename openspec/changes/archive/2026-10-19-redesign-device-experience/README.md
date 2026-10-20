# Device experience redesign — review package

Status: implementation approved on 2026-10-15; RD1–RD5 integrated, RD6 authorized to publish 0.1.2 ALPHA. Native graphical review remains user-owned and deferred. The original browser review is a historical planning artifact, not a native-client screenshot.

Start with [review.html](review.html) in a browser: a native-styled tab/focus layout concept and schematic silhouettes for all five devices. It is not a native screenshot, final game art or a playable prototype.

## Approved milestones

| Milestone | Outcome | Prerequisites |
| --- | --- | --- |
| RD1 | Direct device wiring, role layout and safe existing-alpha interaction migration | None |
| RD2 | Five distinct industrial device designs, all directions/icons/states | RD1 |
| RD3 | Complete code-first tabbed computer UI with preserved recovery/authority | None |
| RD4 | Correct monitor layers and native deconstruction feedback | RD1, RD2 |
| RD5 | Integrated candidate, player documentation and source-grounded developer OpenWiki | RD2, RD3, RD4 |
| RD6 | Actual 0.1.2 ALPHA portal/GitHub release and live player documentation | RD5 |

Kanban implementation/release cards (the original blocked planning hold is superseded):

| Milestone | Card |
| --- | --- |
| RD1 | `t_af128150` |
| RD2 | `t_8cfd8907` |
| RD3 | `t_43cde3d0` |
| RD4 | `t_6c52f091` |
| RD5 | `t_d31d7ca7` |
| RD6 | `t_f930ba9e` |

Full checked graph, checklist ownership and isolated worktrees are recorded in `task-map.json`. Each milestone owns its focused checks and documentation; RD5 verifies integration rather than deferring all testing to the end.

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

The user explicitly approved the redesign and requested an actual 0.1.2 release on 2026-10-15. This supersedes the frozen planning hold/no-release wording in the original review and task-map snapshot. RD1–RD5 deliver integrated implementation; RD6 owns publication, immutable source and live docs. See `tasks.md` and the release notes. Default-branch merge, PR #1 merge, protection changes and OpenSpec archival remain unauthorized. Deferred native-client checks are not marked passed or imposed as a new publication gate.
