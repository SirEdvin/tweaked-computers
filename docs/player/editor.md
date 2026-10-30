# Editor, source revisions and recovery

A computer has one Lua source document, not files or a terminal. With an empty
cursor and no GUI open, **Ctrl + left-click the computer** to open its workspace.
Ordinary clicks do not open it and remain available for wiring. Ctrl + left-click
on empty ground does nothing, even with retained drafts; on a monitor cell, the same gesture
activates the cell instead. The shared interaction action is rebindable in Controls;
the old normal-open and Ctrl+Shift+E actions were removed in 0.1.4. Held items/wires
and cursor ghosts refuse opening. Native buttons inside the workspace still use
normal clicks.

The workspace uses native text entry and buttons. The Console candidate includes
an isolated native typing/paste smoke; **full native workflow, sizing and appearance
acceptance remain independent review/playtest gates**. Headless GUI checks use
table-backed mocks and are not graphical-client evidence.

## Five workspaces

| Tab | What to do there |
| --- | --- |
| **Editor** | Write your document; Validate, Save, Run / Apply and Stop in one row. See saved/unsaved status and a compact conflict/validation message. |
| **Console** | Read bounded live output and diagnostics, or try a live single-line Lua command with Enter / Execute. [Shell values and effects](console.md) are shared per computer, independent of the saved program. Follow-off stops automatic scrolling, not arrivals; changed text may clear native selection. |
| **Peripherals** | Choose **Red** or **Green**. Rows update automatically and show actual API name, type, icon and availability. Click a row for details; click that selected row again for its Reference topic, with no double-click timer. Pending/errors remain explicit; observations are not continuous authorization. |
| **Reference** | Search all Lua v1 guidance and literal code by category/topic. Manually select/copy headings, paragraphs, signatures or complete code boxes. Six self-contained mini-tutorials include setup and expected results. No action buttons, draft edits or execution. |
| **Maintenance** | Review current/active source, resolve conflicts, review/copy/forget retained drafts, and deliberately reset a stopped computer's state. |

The title bar is draggable. **Focus** temporarily shows only Editor and the
essential action row; **Exit focus** restores navigation and the previous tab.
The same source widget stays mounted across tabs, focus toggles, status updates
and display-size changes. Those actions do not save, run or replace your text.
Errors may mark Console with **(!)**, but never switch tabs or grab typing focus.
In focus mode, hover the title status for dirty/action detail.

At an effective display of at least **760 × 480 GUI units** (physical resolution
divided by GUI scale), the window is clamped to the screen and the Editor action
row is reachable without scrolling the whole window. A small screen or larger
GUI scale below this threshold is not supported: reduce GUI scale. There is no
free-resize handle; use Focus or change the game GUI scale. Caret/selection
restoration is not promised when explicitly replacing source.

## Draft, saved, active

Each player has a private draft and base saved revision. The computer has committed
saved source and a possibly different active snapshot. Numeric revision tracking
stays internal for conflict checks; Maintenance offers separate source previews.

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

If the original computer is gone, **Ctrl + left-click another accessible computer**
with an empty cursor and open **Maintenance** to review/copy/forget its retained
draft. Empty ground, unrelated entities, ghosts and private helpers do not open
computer UI. If all eight slots are occupied, opening a new computer instead
shows standalone recovery: select a draft, review it, **Select text** and use
native Copy, or confirm forgetting a reviewed slot before reopening the computer.
No automatic clipboard access is claimed. This capacity viewer cannot run a
computer or reset application data.

A mined computer item is plain hardware: ordinary placement is blank and stopped,
with a new ID. Native undo of an eligible removal restores saved source/label and
explicit state into a new stopped identity, not the old process. **Review active
snapshot** and **Copy snapshot to draft** in Maintenance recover different formerly
active source without saving or running. Private drafts remain tied to their old
identity; undo does not replace or adopt them. Blueprint/clipboard copies carry only
saved source/label, never application state or active source. Old computer-item
payloads are ignored, with no item-data recovery. See [lifecycle](lifecycle.md).

## Diagnostics and discovery

`computer.log(text)` writes plain text into a ring of **64 entries / 16,384 bytes**;
older output is discarded even when Follow is off. Re-enabling Follow cannot retrieve
those discarded entries. The [live Console](console.md) evaluates bounded Lua
lines; Reset Shell clears scratch values, not historical logs. There is no Clear command.

Validation identifies the candidate/base revision. Runtime diagnostics identify the
active revision, handler and original line/column when available. **Go to source
line** explicitly selects a matching draft's line in Editor. A runtime diagnostic
for different source refuses navigation: review the active snapshot in Maintenance
first. Program/source/help text is displayed without interpreting rich-text tags.

Peripherals distinguishes complete inventory, pending/refused inspection and an
empty complete inventory. It does not turn deferred work into successful discovery.
The open tab updates automatically after wiring or availability changes. A previously selected device missing from a
complete refreshed path is shown as disconnected; if inspection is pending, presence
is unknown instead. Red and green never silently mix. Use the exact displayed name
and wire with `peripheral.wrap(name, wire)`; calls recheck live authority.

Clicking a selected row again opens its exact device-type topic in **Reference**,
even after a delay or a native device's power loss. This clears Reference
Search, selects the Peripherals category, synchronizes both visible filters and
reveals the topic from its beginning. Unknown types keep useful details and report
documentation unavailable instead of opening an unrelated topic. This is static
help navigation: no guest method, Save, Run, reset or peripheral write occurs.
Your mounted source widget, dirty draft, saved/active revisions and shell values stay.

Changing discovery wire disarms repeat-click navigation, even for a name present
on both colors. Missing, pending or failed refreshed inventories disarm it too;
the next click selects again. A successful same-wire refresh retains selection by
name, not row position. A new editor session starts unselected.

Every Reference topic uses native headings and wrapped paragraphs. Discovery and
every shipped family (including [radar modems](api/modem.md) and [speakers](api/speaker.md))
have distinct selectable signatures and result/argument/caveat blocks. Aliases have
their own entries; overloads stay together. Shared wiring, native electricity, persistence and
event notes remain separate. There is no raw Markdown or Reference action toolbar.

To copy, click inside the desired paragraph or code box and manually select text
(or use native Select all), then native Copy. Switch to Editor and paste into your
draft. Code preserves indentation, newlines and literal brackets; prose wraps only
visually. Long code boxes have their own scrollbars. Unchanged topics retain their
mounted widgets when switching away/back; ordinary status updates never rebuild help.

The Examples category contains Starter controller, One speaker note, Stock-controlled
inserter, Find iron plate recipes, Small factory dashboard and Two-computer shared
data. Each provides research, entities, native-target electricity where needed, exact wire roles/colors,
complete source, Validate/Save/Run steps, expected visible results and failures.
Shared data includes separate writer/observer programs for two computers and two
physical databases. These small lessons need no external file; larger programs
on the [examples page](examples.md) are supplementary. The empty-draft **Starter
example** invitation remains in Editor, not Reference.

For a fault: read Console's first error, Stop if necessary, repair source/wiring/
physical validity, Validate, Save and Run. Reset State is a deliberate last step for application
data, not a wiring fix or a way to clear a database.

## Integrated redesign playtest

This short user-owned native-client review is not yet performed. Use the exact
candidate or release under review and a backed-up test save, retaining the old
mod/world for rollback.

- Place/rotate all five devices; check ordinary-zoom silhouettes, icons/status,
  ordinary-click red/green wiring without a workspace opening, then clear the
  cursor and Ctrl + left-click a computer to open it. Check empty-ground clicks remain inert,
  monitor cell activation and that held wires/items/ghosts do not open a workspace.
  Check direct red/green Network contacts and distinct logic Input/Output / configurator
  Factory targets. Open/mine/mark the visible body, not a private power helper.
- At **1280×720** and **1920×1080**, try **100%** and **150%** GUI scale. Drag the
  window; change scale/resolution and check clamping, readable tabs, close and
  the complete Editor action row. At 1280×720 / 150%, expect a compact code area.
- Type and paste multiline Lua, including a non-ASCII character; select/copy,
  move the caret and keep an unsaved edit while visiting all tabs and toggling
  Focus. Confirm exact text, native typing focus and no surprise tab changes.
- Validate, Save, then Run separately. Edit again while logs arrive; pause Console
  Follow, scroll/select and switch away/back. New output stays live; selection may
  reset on arrival. Resume Follow and test Go to source line.
- Wire a device on each color, inspect/select it, disconnect it, and observe automatic updates.
  Try reviewed rebase/reload, cancel reset/forget, then close/reopen a dirty draft.
  Recover the removed computer's draft through another computer's Maintenance;
  check standalone recovery when opening a ninth computer with eight retained slots.
- On an electricity-free 2×2 monitor, keep text/background/cursor changing; mark one
  non-anchor tile and confirm the genuine native red X remains visible. Repeat
  outside electric coverage and rotated. Save/load, cancel and check retained
  image/palette/cursor and Ctrl+click coordinates. Then allow robot removal and
  check normal splitting with no floating fragments or extra drops.
- Upgrade a copy of a populated 0.1.1 world; inspect existing role/color wires,
  source/state/KV/display and retained drafts. Reopen the editor; conversion must
  not replay startup. Report a failure with version/hash, orientation, power,
  wiring and a screenshot, with private source literals removed.

These are small user checks of native delivery/rendering, not a request for a broad
client, multiplayer or stress matrix. Automated layout/model checks do not pass them.
