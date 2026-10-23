# Resource-policy UI lane

## Implemented presentation

- The existing workspace status label reads `scripts/runtime/resource-policy.status(record, tick)` on the host, not through a guest command. Its tooltip contains the complete resource report and the cumulative loss counter, including saturation and last-drop details. A missing shared provider is shown as **Resource status unavailable**, never zero usage.
- Recoverable refusal is distinct from fault. Complete refusal/active/Console diagnostics remain selectable in the existing Console detail box. Changing telemetry does not rewrite this box, the source widget, or the command field. Failed Console admission retains the input and keeps the diagnostic in that detail box.
- Reference search and host discovery descriptors no longer have UI field/count cuts. Source-line selection no longer depends on the removed source-byte limit.
- Logic trays render every supplied signal, with independent red/green count and sample tick. Pending, unavailable without a sample, retained stale, disconnected, and empty samples remain distinguishable. Native widget identities and independent tray scrolling are preserved. Construction admission scales with the supplied inventory; no output/subscription behavior changes.

## Protected draft helper contract

`editor-model.retention(player_index)` is read-only and returns
`{used, limit, over_limit, unit='bytes', setting='tc-draft-storage-bytes'}`.
It returns `nil` if the configured policy is absent, not an invented limit.
Accounting is deterministic retained ownership, not measured Lua/C++ heap size:
128 metadata units plus the identity's byte length per document, and the actual
UTF-8 byte length of each distinct source/base/command/review string once per
player. Shared immutable review strings are not charged twice. Old session-only
command drafts migrate into their document on synchronized open/close/recovery;
there is no mutation in `on_load`.

`open`, `edit`, `shell_edit`, saved/active review, Save, Rebase, Reload and recovery
replacement prove candidate ownership before mutation. Growth beyond the live
setting raises a recoverable `E_CAPACITY` table with `resource='draft_storage'`,
`setting`, `used`, `requested` (additional retained bytes), and `limit`. Existing
accepted documents and their order are not evicted. A lowered limit permits
non-growing/reducing edits, existing-document opens and explicit reviewed Forget.
There is no eight-document, editor-source or command-draft field-length ceiling.
The command draft still requires a single line; runtime Save/Execute admission is
a separate foundation contract, not bypassed here.

Refused native input remains in its original editable widget; it is **not**
copied into an unaccounted model field. The accepted document remains unchanged,
and Save/Validate/Run/Execute retry admission rather than using older invisible
text. Explicit Close refuses while input cannot be retained. Escape parks the
same native frame; reopening the same accessible computer restores it without
replacement. Disconnect does not destroy a frame containing refused input.
Raise storage or reduce text / explicitly forget another reviewed draft in
Maintenance, then edit or retry the action. This does not relax identity/force/
surface/permission guards. Recovery after loss of authority over a computer with
unaccepted native input remains a separate UI-accessibility gap; the widget is
preserved, but this lane does not grant offline authoring authority.

Logic inspection supplies a separate persisted `logic_jobs[wire]` cursor to the
inventory lane's optional `logic.inspect_input(rec, wire, tick, spend, job)`
argument. A budget deferral keeps that cursor; success, a hard failure, power
loss or session retirement releases it. Red and green sample timestamps come
from native acquisition, not the later widget publication tick. No output or
subscription mutation API is called by the inspector.

## Fixtures

`tests.ui_resource_status` uses explicitly labelled presentation doubles; it checks complete status/refusal formatting, saturation, no mutation, and draft accounting. `tests.editor_workspace` checks unchanged source/diagnostic widget text while resource values and loss totals change. Neither is proof of runtime counter persistence or a busy guest lane.

The existing `tests.ui_live_client_engine` fixture adds:

```lua
/c remote.call("tc-ui1", "signals", 150)
/c remote.call("tc-ui1", "open", "logic")
```

This constructs two **real** constant-combinator networks using native item signals, with different red/green values. `ui1-state.json` records native inventories separately from the inspector's acquired inventories and sample ticks; it also reports the actual policy status and retained-draft count when available. It does not supply fabricated inspector/status data. Use a smaller count only for a separately labelled compatibility test, never as the 150-signal acceptance substitute.

Prepare via `tools/shell_client.py --fixture tests.ui_live_client_engine` using the canonical absolute `gameitself` distribution path. Run only in a private display/config/mod/save tree. Prewrite input drivers before taking `native.lock`, bound the client case, request normal window close, and release the lock before inspection/editing or another case.

## Recorded validation

Evidence root:
`/home/siredvin/artifacts/tweaked-computers/ui-draft-resource-policy-2026-10-23/`.
`receipt.json` verifies the preserved files and separates final native passes
from failed/partial attempts. `native-pass-base` and `native-final-space-age`
pass the complete driver; `native-cold-base` and `native-cold-space-age` pass
separate-process native restoration of accepted documents/command drafts and
the refused editable source, followed by raising the setting and accepting it.
All four exit 0 with normal window close and no forced cleanup. The native
windows, final 150-signal trays, independent scroll, refusal and eviction captures
were inspected. All 203 Lua payloads in the UI-only tested ZIP match this source;
this evidence note was updated after packaging.

The UI-only archive SHA-256 is
`45c0fa9827666b32d414833d678faa4cd4237964629598b95be2870b71cacbd5`.
The full-client staging archive SHA-256 is
`61aaa33c64c7f648cc6a9e71215dab239dc9696dd625af11446f6b1ccca12fd5`.
It overlays only the five exact production files from inventory commit
`b68efff3b749fe1f8d682fe6528b891866344a53`; `integrated/provenance.json` records
all file hashes. This is not a merged foundation or a release artifact.

Packaged Factorio 2.0.77 base and Space Age passes on the UI-only archive:

| Fixture | Contract groups per mode | Cold phases |
| --- | ---: | --- |
| `tests.ui_draft_retention` | 2 | Both separate processes, normal `/quit` |
| `tests.editor_workspace` | 28 | Not requested |
| `tests.ui_resource_status` | 2 | Presentation double only |
| `tests.peripheral_inspector_contract` | 20 | Not requested |
| `tests.shell_contract` | 29 | Not requested |

The focused draft fixture checks thirteen retained documents, UTF-8 byte
accounting and review aliases, source/command fields beyond former limits,
atomic growth refusal, lowering/reduction/raising, original GUI widget writes,
refused close/submit/save, and accepted command/source retention across cold load.
`tests.editor_cold` remains blocked by its old assertion that a protected infinite
loop must fault immediately. The same failure was reproduced in the unchanged
prior UI archive at `editor_contract.lua:316`; the initial candidate reaches the same
assertion at line 325. Those failures are preserved, not reclassified as passes.

The staged full-client driver uses actual native input and real 150-item red and
green networks, not substituted inspector data. It verifies twelve documents,
a 20,003-byte source and 5,000-byte command draft, configured 1,024-byte refusal
without eviction, unchanged editable source on refused Close, raise-and-retry,
200-character Reference search, all 300 signal widgets and exact native signal
identities/counts, distinct increasing sample ticks, independent red scroll
through signal 150, complete diagnostic native selection/copy across refresh,
and visible log eviction. Initially empty output ownership/subscriptions remain
unchanged; this does **not** prove nonempty writer/subscription regressions.

Large external clipboard transfers were unreliable in the harness. The final
driver uses 2,000-character paste chunks and asserts the complete resulting
bytes; it does not claim one 20 KB paste succeeded. Earlier harness attempts
also exposed observer-write races, container-vs-slot counting, and the
single-player `server_save` no-op. They remain separate failed/partial evidence.
The final driver uses validated JSON reads and `game.auto_save` for native cold
snapshots. Every native process is isolated under private Xvfb and the shared
lock, and is closed normally. Xvfb/llvmpipe is appearance evidence, not GPU FPS.

## Integration gates still required

1. Real shared resource provider: waiting/refusal under a busy guest, full queues,
   Stop/Run/reset/cold loss-counter persistence, warning eviction and saturation.
   The real native client explicitly reports **Resource status unavailable**;
   no counter was fabricated.
2. Merge the inventory lane and supply its required shared host-memory and
   service-job ownership. The staged native 150-signal UI check does not prove
   these missing foundation contracts or unrestricted guest reads.
3. Foundation source/command/binding/log-field policy removal. This lane removes
   UI draft field gates, not runtime Save/Execute admission. Recovery access for
   refused native input after permanent loss of the original computer's
   authoring authority remains unresolved; accepted drafts are never evicted.
4. Connected multiplayer and broader nonempty output/subscription regressions.

The separate Ctrl-click behavior is intentionally unchanged.
