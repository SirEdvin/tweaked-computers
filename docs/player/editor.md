# Editor, source revisions and recovery

A computer has one Lua source document, not files or a terminal. Select the
computer and use the normal open action, or **Open computer editor / recovery
drafts** (initially **Ctrl+Shift+E**, rebindable in Controls). With no selected
computer and no other GUI open, the latter opens standalone recovery drafts.

The workspace uses native text entry and buttons. **Native client typing, paste,
focus and appearance are still awaiting your playtest**; the implementation's
headless GUI checks use table-backed mocks, not a graphical client.

## Five workspaces

| Tab | What to do there |
| --- | --- |
| **Editor** | Write your document; Validate, Save, Run / Apply and Stop in one row. See draft/saved/active revisions and a compact conflict/validation message. |
| **Console** | Read selectable, bounded output and full diagnostics. Disable **Follow new output** to hold a snapshot without scroll fighting. **Refresh** updates it once; enabling Follow resumes updates. |
| **Peripherals** | Choose **Red** or **Green**, then **Refresh peripherals**. Rows show actual API name, type, icon and power. Select a row for its channel/details. This is a timestamped snapshot, not a live presence guarantee. |
| **Reference** | Search and filter the existing Lua v1 help by category and topic. **Select text**, then use native Copy. The starter can be inserted only into an empty draft. |
| **Maintenance** | Review current/active source, resolve conflicts, review/copy/forget retained drafts, and deliberately reset a stopped computer's state. |

The title bar is draggable. **Focus** temporarily shows only Editor and the
essential action row; **Exit focus** restores navigation and the previous tab.
The same source widget stays mounted across tabs, focus toggles, status updates
and display-size changes. Those actions do not save, run or replace your text.
Errors may mark Console with **(!)**, but never switch tabs or grab typing focus.
In focus mode, hover the title status for revision/action detail.

At an effective display of at least **760 × 480 GUI units** (physical resolution
divided by GUI scale), the window is clamped to the screen and the Editor action
row is reachable without scrolling the whole window. A small screen or larger
GUI scale below this threshold is not supported: reduce GUI scale. There is no
free-resize handle; use Focus or change the game GUI scale. Caret/selection
restoration is not promised when explicitly replacing source.

## Draft, saved, active

Each player has a private draft and base saved revision. The computer has committed
saved source and a possibly different active snapshot. Editor displays these
revisions separately; Maintenance offers source previews.

| Action | Source | Execution and data |
| --- | --- | --- |
| Type/paste or **Starter example** | Edit your draft; starter needs an empty draft | No factory effect |
| **Validate** | Check draft syntax, supported language and bounds | Does not save, execute, reset or replace a run |
| **Save** | Commit exact draft with a revision check; invalid source can be saved | Existing active source continues |
| **Run / Apply** (one contextual button) | Validate the displayed saved revision; save dirty text first | Only successful validation retires old work and queues new `start`; state survives |
| **Stop** | Keep source snapshots and logs | Cancel timers/subscriptions/queued work; clear only still-owned output; keep state/KV/display |
| **Reset State**, then **Confirm Reset State** (Maintenance) | No source change | Stop first; clear only this computer's explicit state, not a database or monitor |
| **Close / Escape** | Retain draft | No implicit Save, Run or Stop |

Disabled Save/Run/Reset controls explain their requirement in a tooltip. Essential
actions are native buttons even while the source has focus; no custom shortcut is
required. Cancel, reopening, editing or changing runs expires Reset confirmation.
A new run's startup failure faults that new run; it does not restore the old run.
Earlier successful effects are not rolled back. An invalid candidate does not
retire the current run. See [supported Lua](api/language.md) and
[runnable programs](examples.md).

## Conflicting editors

A stale Save refuses to overwrite another player's newer source and retains your
draft. Status refresh never reloads it automatically.

1. Click **Review conflict** in Editor, or **Review current saved source** in
   Maintenance. Only this explicit click navigates to Maintenance.
2. Read the preview, then choose **Rebase, keep draft** to adopt that revision as
   your draft's base without changing your text. This is a deliberate overwrite
   decision, not an automatic merge. Save is still necessary.
3. Or choose **Reload, discard draft** to replace your draft with reviewed source.
4. Both choices recheck source/revision. If somebody saved since the review,
   review again. Run / Apply never activates an unseen newer revision.

Closing, disconnecting, dying or changing force/surface retains documents. Computer
access still requires your current force/surface, reach and native permissions.
Old events cannot operate a replacement computer. When an older saved GUI is
retired after a mod update, reopen the workspace; its accepted draft is retained.

## Retained drafts and mined computers

Eight slots per player each retain up to 16,384 draft bytes and a bounded base-source
snapshot. Dirty documents are never silently evicted. A ninth computer opens
standalone recovery: explicitly forget a reviewed slot first. Over-limit input
restores the previous accepted draft, not a truncated version. Save the game to
persist drafts; an unsaved game cannot promise crash recovery.

Reopening the same identity restores its draft. Removal/replacement does not
retarget it. In **Maintenance**, select a retained identity, **Review selected
draft**, then **Copy reviewed draft** to replace the current draft. This does not
save or run it. **Forget reviewed draft** requires **Confirm forget**, showing the
affected identity. Selection changes cancel the pending review/forget, and the
reviewed bytes are checked again before copying or deletion. You cannot forget
the currently open document; use reviewed Reload instead.

With no accessible computer, **Ctrl+Shift+E** opens independent recovery. Select a
draft, review it, **Select text** and use native Copy; no automatic clipboard access
is claimed. This viewer can confirm forgetting a reviewed slot, but cannot run a
computer or reset application data.

A mined computer item contains committed source/state, not your private draft.
Replacement is stopped with a new ID. **Review active snapshot** and **Copy snapshot
to draft** in Maintenance recover formerly active source without saving or running.
See [lifecycle](lifecycle.md).

## Diagnostics and discovery

`computer.log(text)` writes plain text into a ring of **64 entries / 16,384 bytes**;
older output is discarded even when Follow is off. Refresh/resume cannot retrieve
those discarded entries. Console is not a REPL and has no invented Clear command.

Validation identifies the candidate/base revision. Runtime diagnostics identify the
active revision, handler and original line/column when available. **Go to source
line** explicitly selects a matching draft's line in Editor. A runtime diagnostic
for different source refuses navigation: review the active snapshot in Maintenance
first. Program/source/help text is displayed without interpreting rich-text tags.

Peripherals distinguishes complete inventory, pending/refused inspection and an
empty complete inventory. It does not turn deferred work into successful discovery.
Refresh after wiring or power changes. A previously selected device missing from a
complete refreshed path is shown as disconnected; if inspection is pending, presence
is unknown instead. Red and green never silently mix. Use the exact displayed name
and wire with `peripheral.wrap(name, wire)`; calls recheck live authority.

For a fault: read Console's first error, Stop if necessary, repair source/wiring/
power, Validate, Save and Run. Reset State is a deliberate last step for application
data, not a wiring fix or a way to clear a database.

## Short native-client playtest (not yet performed)

- At **1280×720** and **1920×1080**, try **100%** and **150%** GUI scale. Drag the
  window; change scale/resolution and check clamping, readable tabs, close and
  the complete Editor action row. At 1280×720 / 150%, expect a compact code area.
- Type and paste multiline Lua, including a non-ASCII character; select/copy,
  move the caret and keep an unsaved edit while visiting all tabs and toggling
  Focus. Confirm exact text, native typing focus and no surprise tab changes.
- Validate, Save, then Run separately. Edit again while logs arrive; pause Console
  Follow, scroll/select, switch away/back, then Refresh. Test Go to source line.
- Wire a device on each color, inspect/select it, disconnect it, and Refresh.
  Try reviewed rebase/reload, cancel reset/forget, then close/reopen a dirty draft.
  Open standalone recovery after the original computer is unavailable.

These are small user checks of native delivery/rendering, not a request for a broad
client, multiplayer or stress matrix. Automated layout/model checks do not pass them.
