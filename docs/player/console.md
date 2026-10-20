# Live Console

The Console can run a single bounded Lua line without editing or replacing your
saved controller. Open a powered computer with an empty cursor and Ctrl + left
click, then choose **Console**. Type or paste into the bottom input and press
**Enter** or **Execute**. The native field supports its normal caret and clipboard
controls. There is **no command history**, multiline continuation, OS or filesystem.

**This is live, not a dry run.** Commands use the existing
[peripheral authority](api/peripheral.md) and affect your real factory.
The saved program can continue running beside the prompt, or remain stopped.

## Try a monitor

Wire a powered computer NETWORK socket to a powered monitor NETWORK socket on red.
Use **Peripherals → Red → Refresh peripherals** to find the exact logical monitor
name. Replace `tc-monitor-4` below with that name. Return to Console and submit
these lines individually (do not paste the entire block at once):

```text
p = peripheral.wrap("tc-monitor-4", "red")
print(p.getSize())
p.setCursorPos(1, 1); p.write("Shell test")
size = p.getSize
print(size())
```

`p` and the captured `size` method survive commands, closing/reopening and game
save/load. Each call checks the original name, generation and wire again: a removed,
regrouped or disconnected peripheral does not silently retarget. A missing fresh
wrap returns nil. Earlier successful writes are not replayed on loading.

## Values and output

- The computer has one shared shell environment. Another authorized player can
  use your bindings. Other computers and saved-program locals remain separate.
  Each viewer's unfinished input and native caret are private.
- Expressions display their results. `false` and one `nil` are values; a call
  returning no results displays no fabricated nil. `print(false, nil, 3)` emits
  one tab-separated entry and returns no values. `print()` emits an empty entry.
  The Console displays tabs as single spaces; stored log text retains its tabs.
- Assignment retains nonreserved globals; assigning nil deletes a binding.
  Locals last only for one submission. For example, `x=5; local y=6`, then
  `print(x,y)`, prints 5 and nil.
- Finite scalars, plain tables with scalar keys, aliases/cycles, authentic
  peripheral facades and their captured methods can be retained. Ordinary API
  Data rules are unchanged: cyclic/mixed-key tables still cannot be passed to
  services that require Data.
- Local functions can calculate values within a line. User functions/closures,
  library namespaces, reference-valued table keys and host objects cannot be
  retained. `fn=function() end` fails rather than saving executable code.
- Host globals, dynamic loading, metatables, coroutines and unguarded execution
  remain unavailable. Reserved library/API names and `print` cannot be replaced.
  [Saved programs](api/language.md) accept plain declarations or legacy
  descriptors, but remain separate from Console. An active program's exported
  `sample` or `start` is not a Console binding: `sample()` cannot call it here.
  Direct calls between exports belong inside that saved program. A Console local
  function with the same name is only a new, unrelated function for that submission.

Each command echo identifies its sequence and submitting player index. Results
and diagnostics are marked **Shell**, not confused with saved-source errors.
**Go to source line** remains for saved-program/draft diagnostics, not a shell
line. Follow-off freezes selectable output without discarding shell execution;
Refresh or re-enable Follow to see its new output. Command status stays visible.

## Effects and ownership

A command stages its scratch values and publishes the complete new graph only
when execution and retention validation succeed. A failing command keeps the
previous graph. This is **not a transaction across peripherals**: earlier KV,
configurator, monitor, explicit application-state writes and printed output remain.
Ordinary shell errors do not fault the saved program.

Synchronous [computer](api/computer.md), [monitor](api/monitor.md),
[KV](api/kv.md), [logic](api/logic.md), [configurator](api/configurator.md) and
[Recipe Searcher](api/recipe-searcher.md)
operations keep their signatures and live checks. `computer.getState/setState`
explicitly address the real application state, not scratch globals.
Handler-based `on/off/after/every/cancelTimer/stop` and logic
`subscribe/unsubscribe` are unavailable in Console, including addressed calls and
captured methods. Use a saved handler program or explicit UI lifecycle actions.

Shell logic output and monitor synchronization selection have their own owner,
separate from the program run. A stopped, powered computer can retain a shell
output. Normal monitor selection exclusivity also applies between a shell and
its own program. Failure/reset releases only shell-owned transient resources,
not a later program-owned output. Model/database contents are not erased.

## Lifetime and limits

| Action | Committed shell values | Pending work / resources |
| --- | --- | --- |
| Close/reopen, save/load, late join | Retain | No replay; execution rechecks opened Console authority |
| Successful Run / Apply or explicit Stop | Clear | Cancel old session and release its transient ownership |
| Confirmed Reset Shell | Clear | Cancel shell work only; saved program/state/source keep running unchanged |
| Failed activation or automatic program fault | Retain | No shell reset |
| Power loss | Retain | Cancel pending commands and clear shell-owned outputs; no replay on restoration |
| Mining/replacement, cloning, blueprint/settings transport | No transfer to new physical identity | New computer starts without the experiment |

The two-step **Reset Shell → Confirm Reset Shell** is separate from Maintenance's
**Reset State**. Reset Shell does not erase older Console logs. Unknown future
shell schemas are refused with data intact while compatible saved programs remain
usable. Downgrading such saves is not verified; keep backups.

[Effective limits](api/limits.md) include 4,096 command bytes, 64 bindings,
16,384 encoded value units, 1,024 graph elements (including scalar edges and
private metadata), 8 pending entries / 16,384 pending source bytes, and 64 retained
session records world-wide. An admitted session occupies a slot until Reset Shell,
Run/Apply or Stop, even if its current values are empty. Encoding charges 16 units
per scalar/reference/metadata item plus string bytes; this is not measured host
memory. Existing source/AST, tuple, table, callback, output and shared tick limits
also apply. Oversized or CR/LF input is rejected, retaining the previous draft.

The shell and program use one computer ledger and one rotating scheduler, not
separate budgets. When both have work, they alternate, with at most one executable
item per computer per actual tick. Exhausted shared headroom can defer unstarted
work. Once execution begins, an error never retries its earlier effects.

## Verification boundary

Packaged contract tests use real native compilation/services and explicit table
GUI mocks. Separate-process cold checks exercise values, binding identity,
pending order, spent credits and once-only effects beside a running controller.
Those headless tests alone do not establish connected multiplayer or native keys.
Independent native-client acceptance exercised Console input/workflows in base and
Space Age, including representative 800×480/1280×720 cases and base 75%/100% UI
scales. Two real base clients verified late joining after effects, independent
drafts/carets, conflicting submissions and a separate-process server restart
without observed replay or desync. Space Age connected joining is not claimed.
The clients used llvmpipe software rendering, not representative GPU performance.
The feature PR records the reviewed evidence; see the repository's
`docs/console-shell-validation.md` for the isolated client and late-join procedure.
