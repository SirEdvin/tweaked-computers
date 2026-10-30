# Computer runtime v1 (development)

Current verification target: Factorio 2.1.23. Native named callbacks only: no interpreter, OS,
filesystem, coroutine suspension or host-object API. The normative contracts
are `openspec/api/{common,native-language}.md`
and `openspec/specs/computer-runtime/lua-api.md` in the source repository.
The `openspec/specs/program-source/{spec,lua-api}.md` contract defines the saved-program grammar.

## Player contract

One saved source document declares exported `function name(...) ... end`
functions (API 1 implicit). No top-level returns, effects or initializers. Optional
top-level `local function` helpers have ordinary lexical scope and are not exports.
Public bindings are immutable; genuine locals/parameters may shadow them.

`start` is optional. Handlers finish or fault; each dispatch receives a fresh
environment and copied event. Local helper functions/variables never survive a
callback. Declaration exports can call each other synchronously, including
forward references, using ordinary arguments/results and the same guard, budget,
authority and run. Direct calls neither enqueue work nor synthesize events;
calling `start(...)` directly does not activate a new run. Explicit state is the
only application continuity. Saved-program exports never enter Console bindings.

Save changes the committed source revision, not the active run. Validate does
not run candidate source. Run/Apply validates the saved revision before retiring
the old generation, then queues start once if exported. No other name auto-runs
or auto-subscribes. Stop cancels that generation's
registrations/timers/events. State, source and logs remain. Reset State requires
a stopped/faulted computer. Failed candidate validation leaves the old run intact.

Status artwork is demand-driven: static devices retain their existing render
object until their identity, geometry or status changes. Running computer status
frames are due on the existing 10-tick animation boundaries. Stop/fault cancels
that animation membership; electrical cycling does not change custom-device
status. A missing native render object is rediscovered by the existing due
physical observation, not a separate every-tick artwork sweep.

All calls use dots, not colons. Exact argument counts are enforced:

| Call | Result |
| --- | --- |
| `computer.getID()`, `getLabel()`, `getTick()` | opaque ID, optional label, simulation tick |
| `computer.setLabel(label?)` | no values; nil clears; bounded strings only |
| `computer.getLimits()` | defensive effective development limits |
| `computer.getState(key)` | one copied Data value or one nil |
| `computer.setState(key,value)` | no values; atomic copied nonnil Data replacement |
| `computer.deleteState(key)` | boolean presence/deletion |
| `computer.log(text)` | no values; bounded string diagnostic ring |
| `computer.stop()` | does not return, even inside pcall |
| `computer.on(event_name,handler_name)` | independent opaque subscription ID |
| `computer.off(id)` | boolean; another computer/run's ID is invalid |
| `computer.after(ticks,handler_name,payload?)` | one-shot timer ID |
| `computer.every(ticks,handler_name,payload?)` | recurring timer ID |
| `computer.cancelTimer(id)` | removes deadline and admitted event; boolean |

State is finite booleans/numbers/strings, dense arrays or string-keyed maps.
False/empty strings are values; deletion is separate. Cycles, metatables,
functions, mixed/sparse arrays, nonfinite numbers and host objects are refused
before mutation. Accounting includes keys/container metadata and aggregate
state nodes/bytes. Snapshots cannot mutate the original state.

General events: peripheral_attach, peripheral_detach, monitor_resize,
monitor_touch, power_restored. Logic events are registered through their owning
peripheral, not computer.on. Register handler names, never functions. Each event
has name, dispatch tick, global FIFO sequence, computer_id and run_id.
Private helpers and nested functions cannot be registered by name or value.

Timer durations are positive safe integer ticks. Equal deadlines use creation
order. Recurring overdue work coalesces, including already queued notifications:
one event retains its first scheduled_tick and accumulates missed intervals;
the next deadline stays aligned. One-shots are consumed on queue admission.
Cancellation still removes admitted work. Custom devices need no electricity:
electrical loss/restoration does not pause callbacks, discard events or clear
owned outputs. `power_restored` remains an inert compatibility registration.
Physical invalidation, stop/fault and definitive authority loss retain their
existing safety cleanup. Cold load does not replay startup or emit restoration.

An ordinary failure can be caught with pcall. Uncaught errors fault the run;
private quota/stop controls cannot be swallowed or forged by an error table.
Earlier successful effects stay committed: there is no callback transaction.
Diagnostics retain original-source statement line/column, active revision and
run ID, with bounded messages. Logs evict oldest entries to fit both limits.

## Host integration (TC04/TC06 and later cards)

Import trusted modules and register hooks during control.lua parsing. These are
host-only Lua functions, not guest globals, remote interfaces or persisted closures.
Use the one existing on_tick handler; add phase hooks instead of replacing it.

### Registry: scripts.registry

- `initialize()` is synchronized init/configuration-only. `get()` reads the root.
  `supported(root)` gates unknown schemas: they stay inert, never reset.
- `register(kind, body) -> record` requires a live numbered entity; assigns a new
  opaque ID even when an old body is reused. Kind `computer` initializes runtime
  fields; other kinds initialize a device record. Do not call from on_load.
- `record(id)` returns a host record or nil; `computer(id)` requires a computer.
  `by_entity(entity) -> record, role` validates the exact bound body/child,
  not merely its unit_number. `body` is the reserved root role.
- `bind_child(id,role,entity)`, `unbind_child(id,role) -> entity?` maintain owned
  force/surface-matched components and bindings. Child roles are unique, bounded
  names. The lifecycle module owns physical creation/destruction/rotation.
- `remove(id,reason?) -> boolean` invokes all teardown hooks before removing
  bindings. It does not destroy entities: the composite owner does that only
  after successful removal. A failed hook retains the record/recovery graph
  and returns false. Removing an identity never removes same-tick ledger entries.
- `register_cleanup(name, function(record, run_id, reason, removing))` installs an ephemeral
  host safety hook; `cleanup(record,run_id,reason,removing?) -> boolean` calls hooks in name
  order, catches each failure, and retains bounded cleanup_failures. Successful
  retry clears those failures. Hook work must be bounded by admitted owned
  resources, independent of guest credits/source. Never mutate scheduler order
  from a teardown callback. Clear only outputs still owned by that exact run ID.
  Registry removal passes `removing=true`; program retirement alone does not
  cancel physical-root native discovery.

Record schema: `schema_version=1, id, generation, kind, body, children,
force_index, surface_index, powered`. The root owns `entities[unit_number] =
{id,role,generation}`, `computers[id]`, `devices[id]`, insertion-order `order`,
`next_id`, `next_sequence`, `ledger`, `scheduler`, `player_drafts`.
Body/child LuaEntity references are host-only; never return these records to guests.

### Runtime: scripts.runtime.computer

- `save(id, source, expected_revision) -> saved_revision` requires the exact
  current revision; a conflict throws E_BUSY and must retain the editor draft.
- `validate(id,tick) -> plan? , diagnostic?`; `activate(id,tick,expected_revision?)
  -> run_id? , diagnostic?` charge the same shared ledger. Compile refusal does
  not retire the current run. Teardown refusal prevents replacement as well.
- `stop(id) -> cleaned`, `reset_state(id)` are explicit host actions.

- `subscribe(record,event_name,handler_name,details?,spend?) -> id` shares both
  per-computer and aggregate registration limits with trusted peripheral event
  kinds. Details are copied plain Data. `unsubscribe(record,id,spend?) -> boolean`.
- `enqueue(record,handler_name,payload,tick,spend?,metadata?) -> admitted, reason?`
  copies a named payload, overrides all BaseEvent authority fields, and assigns
  a global sequence. Metadata.timer_id is host-only timer cancellation bookkeeping.
  Queue overflow visibly faults/cleans the run, not silently drops history.
  Inactive admission returns false. Size/type errors throw.
- `emit(id,general_event_name,payload,tick,spend?) -> boolean` delivers matching
  registrations in creation order. All copy work is admitted before publication;
  maintenance deferral cannot deliver an unmarked partial subscriber prefix.
- `register_services(name, function(record,tick,guard) -> method_map)` adds
  trusted `computer`/`peripheral` methods without collisions. Construct opaque
  peripheral handles with guard.namespace and guard.service. Every peripheral
  method MUST independently prove live channel/force/surface authority, physical
  availability and native-work admission immediately before effects. Native radar/speaker
  also require their native electrical/operational checks. Never return raw host
  functions/objects. No public extension registry is added.

The active header stores exact source, revision, API/storage/compiler versions
and declared handler names, not executable functions/generated text. Compiler
ABI is 2; incompatible headers fault with source/state retained. Reconstruction
revalidates retained source under identical warm/cold costs. No on_load handler
runs, mutates queues, changes credits or recreates start registrations.
Supported declarations retain API 1/compiler 2/storage 1 and reconstruct only the
exact active source, even when newer source has been saved but not applied. Keep
complete save/mod backups before changing runtimes.

### Scheduler: scripts.scheduler

`register_phase(phase,name,fn(tick,spend))` supports lifecycle, sample,
notifications, render, each in sorted host-name order. Production order is
lifecycle/revocation, sampling, notifications, timers, fair callbacks, rendering.
Hooks must spend before input-dependent native work/mutation and retain their
own bounded cursor on deferral. `try_maintenance(fn)` catches only the private
maintenance refusal; unexpected host failures remain visible. Emit precharges
all deliveries. Native radar/speaker electrical eligibility is checked at use;
custom devices have no electrical-transition notification work.

One program callback or Console submission per computer per actual tick; FIFO
within each queue, with the existing program/Console alternation. Event publication
and Console ingress maintain a persisted generation-aware ready rotation. Each
tick freezes its current members and advances the starting member even when shared
credits refuse the entire round. A callback cannot execute a newly awakened peer
recursively or add that peer to the already frozen round. Drained/retired queues
leave the rotation; an open viewer alone is not execution demand.

Timer mutations maintain one indexed earliest deadline per computer, without
cancellation tombstones. Only due owners are visited; future timers do not cause
per-tick computer searches. Due owners retain rotating service under maintenance
pressure, equal deadlines keep timer creation order, recurring events coalesce
without moving their original scheduled tick, and cancellation also removes an
undispatched event. These memberships initialize once on init/configuration change,
not on ordinary load. Unknown scheduling versions remain inert with source,
queues, deadlines and spent credits retained for recovery.
Insufficient aggregate headroom defers untouched runs, not faults them. The
ledger retains per-ID work/compile/allocation spending until a later real tick.
Source replacement, stop, removal, repeated tick dispatch and cold load cannot
renew it. Backwards clocks are refused. Guest admission uses at most the configured
host-work ceiling minus effective reserved maintenance (4800000 guest units at
the 5000000 host / 200000 maintenance defaults); maintenance is not extra work.
Compilation, execution, allocation, maintenance and shared-host budgets are
runtime-global [Map settings](player/api/limits.md#live-mod-settings).
Maintenance requests are clamped to host work minus one, without raising host
work. Actual same-tick maintenance spending remains reserved after a decrease;
maintenance increases cannot reuse guest credits already spent. The scheduler
retains a plain alias from the admission ledger to its authoritative maintenance
state, attaching it only during synchronized admission for older saves.
Changes preserve already-spent credits, and getLimits returns current values.
If the per-computer budgets sum above the shared allowance, the scheduler reserves
at most that allowance rather than permanently starving small fitting callbacks;
actual over-budget work still faults through admission. Ready/deadline traversal
pays for live work, not a fictional full registry walk.
Safety cleanup must stay bounded independently of the offending guest.

## Focused checks and evidence boundaries

`tests/computer_contract.lua` adds grouped Data/revision/identity/timer/power/
queue/fairness/grammar/arity/control tests to the TC01 adversarial foundation.
The maximum accepted table-width computation and maximum nil-containing tuple
are isolated compiler semantics/cost checks, not factory latency benchmarks.

Use the existing archive harness with `--fixture tests.computer_cold --cold`.
The fixture initializes independent declaration programs, runs start once on a real tick, keeps saved
source different from active source, admits an event and retains timers/credits,
then freezes until the queued save is readable. A second engine process verifies
unchanged on_load state before synchronized source reconstruction, consumes the
queued event and fires the one-shot exactly once. Servers bind localhost, disable
LAN/public visibility and shut down through acknowledged console quit.
Declaration checks also compare complete active/state/log/queue/timer and shared
ledger/scheduler snapshots, alias identity, two queued events in FIFO order and
one immediate plus one timed call. Historical running-source upgrade evidence
requires a genuine function-capable baseline and separate before/after receipts.

Headless contracts use actual numbered vanilla fixture bodies, not composite
prototypes. Historical TC03 power-transition checks were host-hook evidence;
the current contract retains accepted historical events while generating no new
electrical notifications. Custom composites now require no electricity.
Editor/client focus, rendering/touch,
multiplayer joining and production envelope/latency are not claimed here. Their
client verification is intentionally deferred to the user/final release gate.
Development limits are effective safety ceilings, not frozen responsiveness or
maximum simultaneous-work guarantees. No release/deployment is authorized.
