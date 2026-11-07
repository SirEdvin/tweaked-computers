# Computer runtime v1 (development)

The current verification target is Factorio 2.1.23. The runtime uses native named callbacks only. There is no interpreter, OS,
filesystem, coroutine suspension or host-object API. The normative public contracts
are [common rules](../api/common.d.lua), [computer](../api/computer.d.lua) and
[globals](../api/globals.d.lua). Behavioral requirements remain in
`openspec/specs/`. The [language guide](player/api/language.md) explains the saved-program grammar.

## Player contract

**Run only trusted code.** Programs and Console commands use native Lua without mod execution quotas.
An infinite loop can stop the game. Temporary Lua values can use all available memory.
Stop cannot interrupt code that does not return control to the host.
Host APIs still require source validation, current authority, host-work admission, and valid data.

One saved source document declares exported `function name(...) ... end`
functions (API 1 implicit). No top-level returns, effects or initializers. Optional
top-level `local function` helpers have ordinary lexical scope and are not exports.
Public bindings are immutable. Genuine locals and parameters can shadow them.

`start` is optional. Handlers finish or fault. Each dispatch receives a fresh
environment and copied event. Local helper functions/variables never survive a
callback. Declaration exports can call each other synchronously, including
forward references, using ordinary native arguments and results in the same environment and run.
Host calls retain the same authority and shared host credits. Direct calls neither enqueue work nor create events.
Calling `start(...)` directly does not activate a new run. Explicit state is the
only application continuity. Saved-program exports never enter Console bindings.

The host shares immutable helper descriptions and stateless implementations.
Each invocation creates fresh guest functions, namespaces, authentic binding maps, authority proofs, and fatal state.
Shared implementations receive the current environment explicitly. They do not retain a previous invocation or select a module-global execution owner.

Save changes the committed source revision, not the active run. Validate does
not run candidate source. Run/Apply validates the saved revision before retiring
the old generation, then queues start once if exported. No other name auto-runs
or auto-subscribes. Stop cancels that generation's
registrations/timers/events. State, source and logs remain. Reset State requires
a stopped/faulted computer. Failed candidate validation leaves the old run intact.

Status artwork is demand-driven. Static devices keep their existing render
object until their identity, geometry or status changes. Running computer status
frames are due on the existing 10-tick animation boundaries. Stop/fault cancels
that animation membership. Electrical cycling does not change custom-device
status. A missing native render object is rediscovered by the existing due
physical observation, not a separate every-tick artwork sweep.

All calls use dots, not colons. Exact arguments and result arity are documented
in the generated [Computer reference](player/api/computer.md).

State is finite booleans/numbers/strings, dense arrays or string-keyed maps.
False/empty strings are values. Deletion is separate. Cycles, metatables,
functions, mixed/sparse arrays, nonfinite numbers and host objects are refused
before mutation. Accounting includes keys/container metadata and aggregate
state nodes/bytes. Snapshots cannot mutate the original state.

General events: peripheral_attach, peripheral_detach, monitor_resize,
monitor_touch, power_restored. Logic events are registered through their owning
peripheral, not computer.on. Register handler names, never functions. Each event
has name, dispatch tick, global FIFO sequence, computer_id and run_id.
Private helpers and nested functions cannot be registered by name or value.

Timer durations are positive safe integer ticks. Equal deadlines use creation
order. Recurring overdue work coalesces, including already queued notifications.
One event keeps its first scheduled_tick and accumulates missed intervals.
The next deadline stays aligned. One-shots are consumed on queue admission.
Cancellation still removes admitted work. Custom devices need no electricity.
Electrical loss/restoration does not pause callbacks, discard events or clear
owned outputs. `power_restored` remains an inert compatibility registration.
Physical invalidation, stop/fault and definitive authority loss retain their
existing safety cleanup. Cold load does not replay startup or emit restoration.

An ordinary failure can be caught with pcall. Uncaught errors fault the run.
An error table cannot suppress or forge private host-work refusal or stop controls.
Earlier successful effects stay committed. There is no callback transaction.
Diagnostics retain original-source lines where available, active revision, and run ID, with bounded messages.
Native diagnostics use column 1 when no column is available. Logs evict oldest entries to fit both limits.

## Host integration (TC04/TC06 and later cards)

Import trusted modules during control.lua parsing. Register hooks during that parsing. These are
host-only Lua functions, not guest globals, remote interfaces or persisted closures.
Use the one existing on_tick handler. Add phase hooks instead of a replacement handler.

### Registry: scripts.registry

- `initialize()` is synchronized init/configuration-only. `get()` reads the root.
  `supported(root)` guards unknown schemas. They stay inert, never reset.
- `register(kind, body) -> record` requires a live numbered entity. It assigns a new
  opaque ID even when an old body is reused. Kind `computer` initializes runtime
  fields. Other kinds initialize a device record. Do not call from on_load.
- `record(id)` returns a host record or nil. `computer(id)` requires a computer.
  `by_entity(entity) -> record, role` validates the exact bound body/child,
  not merely its unit_number. `body` is the reserved root role.
- `bind_child(id,role,entity)`, `unbind_child(id,role) -> entity?` maintain owned
  force/surface-matched components and bindings. Child roles are unique, bounded
  names. The lifecycle module owns physical creation/destruction/rotation.
- `remove(id,reason?) -> boolean` invokes all teardown hooks before removing
  bindings. It does not destroy entities. The composite owner does that only
  after successful removal. A failed hook retains the record/recovery graph
  and returns false. Removing an identity never removes same-tick ledger entries.
- `register_cleanup(name, function(record, run_id, reason, removing))` installs an ephemeral
  host safety hook. `cleanup(record,run_id,reason,removing?) -> boolean` calls hooks in name
  order. It catches each failure and keeps bounded cleanup_failures. Successful
  retry clears those failures. Hook work must be bounded by admitted owned
  resources, independent of guest credits/source. Never mutate scheduler order
  from a teardown callback. Clear only outputs still owned by that exact run ID.
  Registry removal passes `removing=true`. Program retirement alone does not
  cancel physical-root native discovery.

Record schema: `schema_version=1, id, generation, kind, body, children,
force_index, surface_index, powered`. The root owns `entities[unit_number] =
{id,role,generation}`, `computers[id]`, `devices[id]`, insertion-order `order`,
`next_id`, `next_sequence`, `ledger`, `scheduler`, `player_drafts`.
Body/child LuaEntity references are host-only. Never return these records to guests.

### Runtime: scripts.runtime.computer

- `save(id, source, expected_revision) -> saved_revision` requires the exact
  current revision. A conflict throws E_BUSY and must keep the editor draft.
- `validate(id,tick) -> plan? , diagnostic?` and `activate(id,tick,expected_revision?)
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
  registrations in creation order. All copy work is admitted before publication.
  Maintenance deferral cannot deliver an unmarked partial subscriber prefix.
- `register_services(name, function(record,tick,guard) -> method_map)` adds
  trusted `computer`/`peripheral` methods without collisions. Construct opaque
  peripheral handles with guard.namespace and guard.service. Every peripheral
  method requires current channel, force, surface, identity, generation, physical availability, and native-work admission before effects.
  A callback-local proof can replace duplicate physical checks only under the rules below. Native radar/speaker
  also require their native electrical/operational checks. Never return raw host
  functions/objects. No public extension registry is added.

### Callback-local authority

The owner proof retains the exact computer record, body, generation, force, surface, and program-run or Console-session identity.
Each use checks those identities and current execution ownership. An invalidated proof requires a complete physical check before reuse.
The peripheral proof adds the selected wire, physical member, logical target, and target generation. Each target lookup checks identity, generation, and scope.
These proofs exist only inside one guard. The next callback, command, or cold load starts without them.

| Reviewed boundary | Facts retained | Checks or invalidation |
| --- | --- | --- |
| `getNames`, `isPresent`, `getType`, `getMethods`, `wrap`, `find`, `getName`, `getWire` | Owner, connectors, same-color path, and target scope cannot change. | Validate arguments and requested identity. Reuse only this guard's inventory. |
| `call` and captured-method dispatch | Dispatch itself does not change physical state. | Check the selected provider before its entry. |
| Monitor methods | Model and presentation edits do not move, replace, rotate, or rewire physical members. | Retain target generation, geometry, model, allocation, and publication checks. |
| Radar channel methods and metadata | Channel state does not change physical identity or wiring. | Check native availability for each active call. Invalidate before `transmit`, which can retire a recipient. |
| Speaker metadata | Catalogue queries do not change physical state. | Check native availability. Invalidate before `playNote` and `playSound` native submissions. |
| Other methods and providers | No stability assumption. | Invalidate owner, connector, inventory, and availability proofs before entry, even when the operation throws. |

Stop, fault, replacement, and session retirement prevent further use of the admitted identity. Existing output cleanup remains separate from proof reuse.
Background discovery and retained bindings never replace current authority. Native power and method-specific requirements remain effective.

The active header stores exact source, revision, API/storage/compiler versions
and declared handler names, not executable functions/generated text. Compiler
representation is 3. Known compiler-2 headers receive synchronized source validation before scheduler checks, timer advancement, or queue consumption.
Migration preserves run IDs, active revisions, source, queues, deadlines, and accepted data. It does not execute startup.
Host-work refusal leaves unvalidated upgrade work pending. Malformed or unknown metadata stays unavailable with source and data retained.
Reconstruction retains identical warm/cold admission. No `on_load` handler runs guest code, mutates queues, changes credits, or recreates startup registrations.
Public API and storage versions remain 1. The exact active source remains authoritative after later saved-but-unapplied edits.
Back up the complete save and matching mod archive before changing runtimes. Restore both for rollback, not an in-place downgrade.

### Scheduler: scripts.scheduler

`register_phase(phase,name,fn(tick,spend),ready(root,tick))` supports lifecycle,
sample, notifications and render. Registration sorts hooks by name one time.
Production order is lifecycle/revocation, sampling, notifications, timers, fair
callbacks, rendering. The scheduler calls a hook only when its `ready` function
returns true. `ready` reads synchronized storage only. It does not allocate,
change state or call native APIs that it does not need. It returns true for state
that it cannot read, so that the hook's own validation runs. A skipped hook gets
no maintenance charge. A tick with no due timer, no ready computer and no ready
hook does constant bookkeeping and allocates no Lua memory.
Hooks must spend before input-dependent native work/mutation and retain their
own bounded cursor on deferral. `try_maintenance(fn)` catches only the private
maintenance refusal. Unexpected host failures remain visible. Emit precharges
all deliveries. Native radar/speaker electrical eligibility is checked at use.
Custom devices have no electrical-transition notification work.

Each computer executes at most one program callback or Console submission per actual tick.
Each queue uses FIFO order, with the existing program/Console alternation. Event publication
and Console ingress maintain a persisted generation-aware ready rotation. Each
tick freezes its current members and advances the starting member even when shared
credits refuse the entire round. A callback cannot execute a newly awakened peer
recursively or add that peer to the already frozen round. Drained/retired queues
leave the rotation. An open viewer alone is not execution demand.

Timer mutations maintain one indexed earliest deadline per computer, without
cancellation tombstones. Only due owners are visited. Future timers do not cause
per-tick computer searches. Due owners keep rotating service under maintenance
pressure. Equal deadlines keep timer creation order. Recurring events coalesce
without moving their original scheduled tick. Cancellation also removes an
undispatched event. These memberships initialize once on init/configuration change,
not on ordinary load. Unknown scheduling versions remain inert with source,
queues, deadlines and spent credits retained for recovery.
Preparation includes validation, environment construction, event copying, and Console graph reconstruction.
Saved-program callbacks of one run reuse host scaffolding: stdlib wrappers, API namespaces, service closures and the loaded program chunk.
The cache is process-local and is never saved. Each callback runs the program declarations again and binds new authority proofs and caches.
The first callback of a run pays compilation work. The saved `compile_paid` field of the computer records this payment. Later callbacks of the run validate the source again without a compilation charge.
A late joiner or a reloaded save without the cache gets the same charges, refusals and effects. Console commands still build a new environment for each command.
A saved-program callback buffers its `print` and `computer.log` entries and writes them to the Console once, when the callback ends.
This also occurs when the callback fails or stops, before any fault entry. The retained entries are the same as with immediate appends.
A program `print` makes two charges: the argument count before conversion, then the bytes and the entry. The first entry that overflows the Console pays the eviction work once for each callback.
Console commands keep immediate output and their earlier charges.
Earlier spending can delay preparation when its refused charge prefix fits the full current source and host allowances.
The item keeps its identity and order. Accepted preparation charges remain spent.
Deferred commands have no echo or graph publication. Every attempt checks current authority.
Preparation that cannot fit fresh allowances fails rather than waiting indefinitely.
The scheduler consumes an admitted item immediately before execution. Started code is never repeated after refusal or failure.
The ledger retains per-ID host-work and compilation spending until a later real tick.
Source replacement, stop, removal, repeated tick dispatch and cold load cannot
renew it. Backwards clocks are refused. Program and Console host admission uses at most the configured
host-work ceiling minus effective reserved maintenance. The 5000000 host / 200000 maintenance defaults leave 4800000 guest units.
Maintenance is not extra work.
Compilation, maintenance, and shared-host allowances are
runtime-global [Map settings](player/api/limits.md#live-mod-settings).
Maintenance requests are clamped to host work minus one, without raising host
work. Actual same-tick maintenance spending remains reserved after a decrease.
Maintenance increases cannot reuse guest credits already spent. The scheduler
retains a plain alias from the admission ledger to its authoritative maintenance
state, attaching it only during synchronized admission for older saves.
Changes preserve already-spent credits, and getLimits returns current values.
The scheduler does not reserve an estimated full-invocation allowance.
After execution starts, host-work refusal remains fatal. Ordinary native Lua operations do not spend host credits.
Ready/deadline traversal pays for live work, not a full registry walk.
Safety cleanup must stay bounded independently of the offending guest.

## Focused checks and evidence boundaries

`tests/computer_contract.lua` adds grouped Data/revision/identity/timer/power/
queue/fairness/grammar/arity/control tests to the TC01 adversarial foundation.
Finite computations above former temporary table, tuple, and depth limits check native behavior, not factory latency or memory containment.

Use the existing archive harness with `--fixture tests.computer_cold --cold`.
The fixture initializes independent declaration programs. It runs start once on a real tick and keeps saved
source different from active source. It admits an event and keeps timers/credits.
Then it freezes until the queued save is readable. A second engine process verifies
unchanged on_load state before synchronized source reconstruction. It consumes the
queued event and fires the one-shot exactly once. Servers bind localhost, disable
LAN/public visibility and shut down through acknowledged console quit.
Declaration checks also compare complete active/state/log/queue/timer and shared
ledger/scheduler snapshots, alias identity, two queued events in FIFO order and
one immediate plus one timed call. Historical running-source upgrade evidence
requires a genuine function-capable baseline and separate before/after receipts.

Headless contracts use actual numbered vanilla fixture bodies, not composite
prototypes. Historical TC03 power-transition checks were host-hook evidence.
The current contract retains accepted historical events while generating no new
electrical notifications. Custom composites now require no electricity.
These contract tests do not establish native editor focus, rendering, touch, connected multiplayer, or production latency.
Those behaviors require their separate acceptance checks against the final archive.
Host limits do not guarantee response time or contain native execution. No release or deployment is authorized.
