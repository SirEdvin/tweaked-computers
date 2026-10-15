# Editor, source revisions and recovery

A computer has one source document, not files. Select the body (or its NETWORK
port), use the normal open action or **Open computer editor / recovery drafts**,
initially **Ctrl+Shift+E**, rebindable in Controls. With no selected computer, the
same action opens recovery drafts. Native buttons provide essential actions even
while the text box has focus. Client shortcut/focus usability remains unverified.

## Draft, saved, active

Each player has a private editing draft and base saved revision. The computer has
committed saved source and, while running, a possibly different active snapshot.
The status pane displays these revisions separately.

| Action | Source | Execution and data |
| --- | --- | --- |
| Type/paste or Template | Edit your draft; Template needs an empty draft | No factory effect |
| Validate | Check draft syntax, supported language and bounds | Does not save, execute, reset or replace a run |
| Save | Commit exact draft with revision check; invalid source can be saved | Existing active source continues |
| Run / Apply | Validate the displayed saved revision; save dirty text first | Only successful validation retires old work and queues new `start`; state survives |
| Stop | Keep saved/active recovery source and logs | Cancel timers/subscriptions/queued work; clear only still-owned output; keep state/KV/display |
| Reset State, then Confirm Reset State | No source change | Requires stopped/faulted status; clear only this computer's explicit state |
| Close / Escape | Retain draft | No implicit Save, Run or Stop |

Cancel, reopening, editing or changing runs expires a pending Reset confirmation.
A new run's startup failure faults that new run; it does not restore the old run.
Successful earlier effects are not rolled back. An invalid candidate, by contrast,
does not retire the current run.

Use **API Help** for a template and concise call inventory. Copy complete source
from [runnable programs](examples.md); do not paste host wrappers. **Refresh
Peripherals** inspects red and green independently, showing name/type/power or an
explicit pending/error result, never an incomplete successful inventory.

## Conflicting editors

A stale Save refuses to overwrite another player's newer saved source and keeps
your draft.

1. **Review Current** opens the current saved source read-only.
2. Read it, then choose **Rebase — keep draft** to adopt that revision as your
   draft's base without changing your text. This is a deliberate overwrite
   decision, not an automatic merge. Save is still necessary.
3. Or choose **Reload — discard draft** to replace your draft with reviewed source.
4. Both choices recheck the source/revision. If somebody saved after your review,
   review again. Neither Run nor Apply activates an unseen newer revision.

Closing, disconnecting, dying or changing force/surface retains documents. Access
to a computer still requires current force/surface, reach and native permissions.
Old UI events cannot operate a replacement computer.

## Recovery drafts and mined computers

Eight document slots per player each retain up to 16,384 draft bytes and a bounded
base-source snapshot. Dirty documents are never silently evicted. A ninth computer
opens recovery instead: explicitly forget a reviewed slot first. Over-limit typing
restores the previous accepted draft, not a truncated version. Save the game to
persist drafts; an unsaved game cannot promise crash recovery.

Reopening the same identity restores its draft. Removal/replacement does not
retarget an old draft. Select it in recovery and use **Copy selected draft** to
import text into the current computer's draft. This neither saves nor runs it.
The independent recovery viewer can show text after destruction; it cannot run a
computer or clear application data. **Forget reviewed**, then **Confirm Forget**
is required for deletion; cancel preserves it.

A mined computer item contains committed source/state, not your private draft.
Replacement is stopped with a new ID. **Recover Active Source** reviews the
formerly active snapshot if it differed from saved source; **Copy snapshot to
Draft** imports it without saving or running. See [lifecycle](lifecycle.md).

## Diagnostics

`computer.log(text)` writes plain text into a ring of 64 entries / 16,384 bytes;
older output is discarded. Validation identifies the candidate/base revision.
Runtime diagnostics identify the active revision, handler, run ID and original
line/column when available. Program/source/help text does not interpret Factorio
rich-text tags. This output pane is not a terminal or REPL.

For a fault: read the first error, Stop if necessary, repair source/wiring/power,
Validate, Save and Run. Reset State is a deliberate last step for application data,
not a general-purpose fix for wiring or a way to clear a database.
