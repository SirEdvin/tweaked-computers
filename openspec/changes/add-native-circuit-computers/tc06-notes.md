# TC06 implementation checkpoint

Scope: OpenSpec task 2.4 / program-editor only. Parent
`13f89cfd0fe021efa8b747c0d8360c0c1cb690db` was fast-forward merged into the
assigned worktree branch; ancestry checked. No sibling/primary branch was edited.

## Implementation

- Actual Factorio native multiline text box, scalable scroll frame and visible
  Validate / Save / Run / Apply / Stop / Reset State / confirmation / API Help /
  Close controls. Normal-open linked custom input and rebindable Ctrl+Shift+E
  selected-body entry are installed; no keyboard shortcuts are needed for actions.
- Plain per-player drafts, base/saved/active revision display, exact saved-source
  runtime consumption and guarded validation-before-replacement. Save never
  activates; invalid replacements keep the old run and state.
- Conflict recovery requires displaying a current-source review and explicitly
  rebasing or reloading, with a second source/revision check before publication.
- Current body/registry/generation/unit, player force/surface/reachability/GUI
  permissions, session token and exact opened frame/ancestor ownership are checked.
- Dirty close/disconnect/death/force/surface transitions retain drafts; removed
  identities cannot retarget replacements. Eight per-player bounded slots never
  evict dirty text. Standalone recovery viewer provides review/copy and confirmed
  deletion even when every old body is gone.
- Source/output/help/review/diagnostics use disabled rich text. Output is the
  bounded rolling runtime console with a visible retention warning. Only a known
  core font/style is referenced, and both are asserted in the data stage.
- Fixed host-only inspector seam for sibling network integration; no duplicated
  UI discovery graph, raw object forwarding or guest import/evaluation endpoint.
- No VM, OS, shell, file list or gameplay filesystem. No runtime/core refactor,
  changed production quotas or destructive snapshot/mining changes.

## Evidence and limitations

The reused deterministic archive builder verifies unchanged pinned parser hashes.
`tests.editor_contract` contains 12 counted grouped checks, including production
model actions and table-backed GUI handlers, native compiler/runtime execution,
stale-review refusal, stopped-only reset, bounded drafts, exact replacement,
permissions and forged/inactive/cross-player GUI events, plaintext/rolling output,
layout/focus contracts and a budget-poisoned malicious callback beside a healthy
peer. These are NOT native player typing/paste, focus or graphical evidence.

`tests.editor_cold` adds a real powered `tc-computer` and two separate engine
processes. Text/button routes are table-backed but consume the actual saved
source. Before cold resumed work it verifies unchanged active/saved/draft source,
base revision, session, body/port identity, timer, state, sequence and spent ledger.
It rejects renewed same-tick compilation, restores the retained draft and resumes
the original active source without replaying startup; its original timer finishes
once. All authoritative persisted authoring records are plain data.

Commands (output directories are outside git):

```sh
python3 tools/build.py --output "$TMPDIR/tc06-artifacts-final"
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive "$TMPDIR/tc06-artifacts-final/tweaked-computers_0.1.0.zip" \
  --output "$TMPDIR/tc06-smoke-final" --fixture tests.editor_cold --cold
```

Exact Factorio 2.0.77 base-only and optional Space Age are the affected packaged
modes. Final results are recorded in the structured Kanban handoff and external
`tc06-smoke-final/summary.json`. Each cold phase must acknowledge `/quit`, exit 0
and require no signals/forced kill. Prior evidence is preserved: `tc06-data-first`
correctly refused the guessed `text_box` style; inspecting the pinned core source
and using its actual `textbox` parent fixed that construction error. Subsequent
`tc06-contract-first` passed 11 initial groups; `tc06-cold-first` passed 11 groups
per mode and four clean cold phases before the final replacement/layout checks.

The mixed 2.4 checkbox remains open for user-deferred native typed/pasted/focus/
visual usability and multiplayer-client verification. No graphical client,
screenshots, desktop/browser automation, join matrix or performance campaign ran.

## Integration

- Merge this committed branch with ordinary git merge. `control.lua` is a hotspot:
  preserve TC04 lifecycle/scheduler handlers, editor registrations and sibling
  network imports. `data.lua` adds only the editor prototype import.
- TC07 has both discovery and editor as pre-created parents. It must install the
  real network inspector via `editor.register_inspector(fn)` during control
  parsing, then exercise names/channels beside its real saved-source circuit
  controller. Callback shape and authority rules are in docs/program-editor.md.
  The isolated editor checkpoint explicitly reports an absent inspector instead
  of manufacturing an empty connected inventory. This seam is not claimed as
  real-wire discovery acceptance.
- Keep drafts independent from downstream mining/clone/item data snapshots; no
  player draft is exported in a blueprint/item, and removed drafts remain locally
  recoverable. Do not silently drop recovery slots during player/force cleanup.
- TC14 already owns public repository/Pages setup, TC15 full player API docs,
  TC16 developer OpenWiki and TC17 consolidated PR/alpha publication. This feature
  checkpoint does not merge their work, publish a partial mod or archive OpenSpec.
