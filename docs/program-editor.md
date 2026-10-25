# Program workspace — Lua API v1

The player guide is [Editor, source revisions and recovery](player/editor.md).
This page describes the host UI architecture and focused verification. No guest
method/event/language/runtime or filesystem is added by this redesign. Factorio
**2.0.77** remains pinned; native client appearance, typing, clipboard, caret/focus
and multiplayer delivery remain **unverified user-owned playtesting**.

## Native hierarchy and design

The editor is a draggable, screen-clamped native frame, not the planning HTML.
Its restrained native frame/tab/input styles use Factorio's steel/charcoal panels,
amber selected tabs and a declared `tc-editor-mono` font. That FontPrototype uses
`from='default-mono'`, a family in the pinned engine's `core/locale/en/info.json`
(Noto Mono first). It does not refer to a nonexistent `default-mono` FontPrototype.
The data-stage fixture checks every explicit `tc_` style font against `data.raw.font`.
Headless loading is not proof of client font rendering.

```text
frame: tc_program_editor (player / token / id / generation / ui_version tags)
  title: heading + drag space → frame, status, Focus / Exit focus, Close
  content: native tabbed-pane
    Editor: source, empty-draft starter invitation, one action row,
            saved/unsaved status, contextual feedback / Review conflict
    Console: Go to source line, Follow, bounded live output, diagnostics
    Peripherals: Red / Green selector, automatic icon/name/type/state rows,
                 selected opaque identity details
    Reference: Search / category / topic, selectable structured document blocks
    Maintenance: revision review/rebase/reload, active-source review/copy,
                 retained-draft review/copy/confirmed forget, stopped-only reset
```

Editor is selected on explicit open. Focus saves the previous tab, selects Editor,
hides tab widgets/nonessential status chrome, and keeps all four action buttons.
Exiting restores the previous tab. The source remains in its original parent and
is never destroyed/recreated by tab/focus/resize/status operations. Source assignment
occurs only on explicit source replacement or refused over-limit input restoration;
normal Save/Validate/Run/Stop do not rewrite the text widget. No unsupported caret
readback/free-resize API or automatic focus restoration is promised.

The visual decision is concentrated in the quiet code surface, not dashboard cards.
Supporting tasks have their own tab rather than competing with source in a global
scroll column. Maintenance and Reference can scroll their long document content.

## Layout contract (model evidence, not graphical acceptance)

`scripts/ui/editor-layout.lua` is pure geometry. GUI style dimensions use effective
GUI units; `frame.location` clamps in physical pixels using display scale. Sizing
keeps a 32-unit screen allowance, caps the window at 1040×940 and preserves a dragged
position rather than re-centering on refresh/resize. On first open it is centered.
There is no resize handle. Minimum supported effective screen is **760×480**;
smaller displays may require reducing GUI scale and are not claimed usable.

Native styles explicitly fix frame padding, tab top margin/header height and compact
button height rather than relying on hidden inherited spacing. The modeled source
height is window height minus 200 normally, or minus 108 in focus. Normal code
height is at least 70% of usable tab content at all four required nonempty layouts;
focus exceeds 85%. The empty-draft starter invitation shares the contextual message
row instead of taking space from source or adding a fifth toolbar button.

| Physical resolution | GUI scale | Window (GUI units) | Normal source height | Focus source height |
| --- | --- | --- | --- | --- |
| 1280×720 | 100% | 1040×688 | 488 | 580 |
| 1280×720 | 150% | 821×448 | 248 | 340 |
| 1920×1080 | 100% | 1040×940 | 740 | 832 |
| 1920×1080 | 150% | 1040×688 | 488 | 580 |

These dimensions are asserted in table-backed construction/layout tests. They do
not prove that the native client's tab visibility, caret, scrollbars, hover, font
rasterization or physical controls render/behave as intended. See the concise
[client checklist](player/editor.md#short-native-client-playtest-not-yet-performed).

## Authority, durable drafts and event routing

`scripts.ui.editor-model` remains the sole authoring mutation authority. Plain state
lives at `storage.tweaked_computers.player_drafts[player_index]`, with up to eight
`documents[id]={source,base_source,base_revision}` and one optional session.
No GUI/player objects, callbacks, functions or compiled code enter this storage.
`on_load` performs no editor work.

`model.open`, `current`, `edit` and `action` revalidate current force/surface/reach,
native GUI permissions, exact body unit/generation/registry binding and session
token. Save is a checked commit, separate from activation. Run/Apply can only consume
the displayed saved source; invalid replacements preserve the active generation.
Stop retains source/state/KV/display. Reset requires stopped status and a confirmed
run-generation identity. Every source snapshot/revision is rechecked before an
explicit rebase/reload/copy; no automatic conflict merge/reload is added.

The GUI adapter additionally requires the exact player's opened frame, schema tag,
token/id/generation, an actual descendant inside a bounded 16-level fixed tree, and
a visible/enabled active tab subtree. Click actions compare the **exact constructed
widget**, not just its name. Foreign/inactive/stale/hidden children cannot mutate a
backend or presentation state. Title Close / Escape may retire an unavailable
session while preserving its draft; they do not require a reachable computer.

`control.lua` registers native click, text, tab-selection, dropdown-selection and
checkbox-change handlers. `scripts.ui.interaction` is the sole world-opening route:
the shared Ctrl + left-click input opens a computer, activates a monitor cell, or
opens recovery on empty ground. Held items/wires, cursor ghosts and another open
GUI refuse the gesture. Native open events never create workspaces; native device
shell/socket dialogs are suppressed without closing other entity dialogs. The old
linked Open GUI and Ctrl+Shift+E bindings are removed. Close/player-unavailable/display-size
routes remain. Native tab changes are explicitly handled; a click-only handler is
not sufficient. Closing never reopens the workspace over another GUI.

An older saved GUI tree lacking the current `ui_version=5` is retired on the next admitted
refresh/size event, never on load. Its draft is retained and the player is asked to
reopen. It is not navigated/rebuilt invisibly into an active editing session.

## Bounded host presentation

Session presentation fields are bounded scalars/indexes: selected tab, prior focus
tab, focus, Console follow, red/green channel, reference category/topic, search
(maximum 128 bytes) and topic indexes (the finite shipped help inventory).
Peripherals retains at most one channel's complete `network_nodes` descriptor
snapshot or a diagnostic. It stores generated opaque IDs, fixed type names and
power booleans, not arbitrary guest labels. Recovery/revision previews use the
player's aggregate draft storage, and identity/source bytes are rechecked before replacement or
confirmed deletion. Changing a recovery selection invalidates its review/confirmation.
Older pending forget records without the new reviewed-byte marker safely refuse.
The open document cannot be forgotten.

A charged scheduler render hook updates open frames at 4 Hz. It never assigns source,
focuses a widget or changes tabs. Only the selected supporting tab refreshes its
presentation; no background discovery graph or hidden recovery/help rebuild occurs.
The active status/Console fault marker may update without stealing navigation.

Console retains the runtime's newest output within `tc-console-bytes` (default
16,384 accounted bytes, including 64 metadata bytes per entry), without a separate
entry-count ceiling. Lowering the setting alone preserves accepted history;
the next fitting entry evicts oldest entries as needed. With Follow off,
the single selectable text box stays live without automatic scrolling. Incoming
changed text may reset native selection; unchanged text is not reassigned, so copy
works between updates. Follow resumes tailing. Older ring entries remain
discarded. No terminal, REPL or unsupported Clear command is implied. Source-line
navigation is explicit, selects a line using the pinned `select` API, and refuses an
active diagnostic that belongs to a different draft. Source/diagnostic/help fields
have rich text disabled; diagnostic tooltip brackets are escaped for presentation.

Peripherals calls the one parsing-time registered inspector on opening its tab,
choosing a channel and admitted scheduler updates while visible. `register_inspector(fn)` accepts the
existing fixed host callback `fn(record,wire,tick)` → complete dense
`{name,type,powered}` descriptors or `nil,diagnostic`. The production
`scripts.ui.network-inspector` uses the real peripheral traversal and shared work
admission, not a second UI graph/cache. It must never return an incomplete prefix.
The UI distinguishes complete-empty, unpowered, disconnected-from-the-refreshed-path
and pending/refused/unknown. It omits snapshot tick clutter and does not claim continuous
live authorization. Friendly labels never replace API names or mix red and green.

Reference derives native heading/prose/signature blocks from the complete `help.text`;
concatenating non-tutorial topic text reproduces that source byte-for-byte. Tutorial
metadata lives in `scripts.ui.tutorials`; code is required directly from the shipped
examples (the starter remains byte-checked against `function-program`). No duplicate
guest source or external-file dependency is introduced. Search includes instructional
and literal code text and remains literal, not a guest pattern.

`scripts.ui.reference` renders every useful block as a read-only native text box,
including headings and prose, so manual selection/copy remains available everywhere.
Wrapped prose and signatures use conservative font/width sizing; literal monospaced
code preserves exact bytes and uses bounded nested scrollbars. The outer document
never scrolls horizontally. Unchanged topic widgets survive navigation/resize;
admitted routine refresh never rebuilds Reference. There are no Reference action
buttons or draft-mutation handlers. The empty-only starter remains in Editor.

## Complete action map

| Action(s) | Exact location / safeguard |
| --- | --- |
| validate / save / run-or-apply / stop | Editor's only action row; no implicit Save-and-Run |
| template | Empty Editor invitation only; empty-only |
| review / rebase / reload | Maintenance saved-source review; Editor conflict button opens that reviewed workflow |
| review-active / copy-active | Maintenance active-snapshot preview; copy only after current-snapshot recheck |
| review-recovery / recover | Maintenance retained identity → preview → explicit draft replacement; no save/run |
| forget / confirm-forget / cancel-forget | Maintenance identity-specific review and separate confirmation; never open document |
| reset / confirm-reset / cancel-reset | Maintenance stopped-only application-state section; run-generation confirmation |
| open_recovery / recovery_action | Independent viewer without an accessible computer; review/select/native copy and confirmed forget only |
| close / native Escape | Title / close event; retain draft, do not stop |
| text edit | Mounted Editor source; exact session/identity and aggregate draft storage |
| inspect / wire selection | Peripherals; one explicit color and timestamped complete/deferred result |
| follow / show-location | Console; live output without automatic scrolling when Follow is off / explicit matching-source navigation |
| tab / focus / search / category / topic | Bounded host presentation only; same ownership checks |

`api/compatibility.md` in the redesign change preserves the original action placement
contract. `review-recovery` adds the explicit reviewed preview required there, not
a new guest API.

## Focused automated checks

- `tests.editor_contract`: original 12 authoring/runtime/model/GUI-mock groups,
  updated for nested widgets and one contextual activation button. Checks draft
  consumption, real runtime effects, conflicts/rechecks, invalid candidates, reset,
  permissions, capacity, body replacement, dirty close/reopen and healthy-peer safety.
- `tests.editor_workspace`: native hierarchy and scale geometry **via mocks**, source
  identity/write-count checks, separate starter/validation/save/activation, paused
  Console snapshots, full reference inventory, real engine red/green connector
  discovery/disconnection and shared-credit refusal, every Maintenance action,
  strict nested event ownership, explicit diagnostic navigation and old-GUI retirement.
  It explicitly reports no client-created player rather than fabricating GUI evidence.
- `tests.editor_cold`: actual powered body in two separate official engine processes;
  table-backed GUI source edit/save/run, dirty/saved/active divergence, saved focus/
  prior tab/search/category/topic/follow/review, plain durable state, exhausted same-tick
  compile admission, cold readback **before resumed work**, no load mutation/startup
  replay and once-only original timer. Explicit reopen starts in Editor with the same
  draft. Save-readability and acknowledged `/quit` are required; forced kill is failure.
- `tests.candidate_data`: packaged prototype/frame/font references. GUI mocks additionally
  enforce pinned write-only LuaStyle size aliases and text-only rich-text style use.
  These checks still are not actual graphical widget construction.

Build with `python3 tools/build.py --output <outside-repo-dir>` and run the existing
`tools/smoke.py` against the exact ZIP, fixture `tests.editor_workspace`, then
`tests.editor_cold --cold`, in base and Space Age. Do not substitute a checkout source
loader for the packaged GUI. `tests.integration_engine` and `tests.logic_engine`
use the new nested widget paths; RD5 owns the later integrated candidate matrix.
