# Logic handler API and saved-source controller

Target: Factorio 2.0.77, API v1. This alpha uses native named callbacks: no VM,
OS, gameplay files, arbitrary Factorio objects or background guest threads.
Read [program-editor.md](program-editor.md), [peripheral-network.md](peripheral-network.md)
and [physical-devices.md](physical-devices.md) for authoring and wiring.

## Build the controller

1. Research Circuit Computers, place a computer, an optional KV NETWORK relay,
   and a powered logic handler. Its cardinal 3×1 roles are INPUT / NETWORK / OUTPUT.
2. Connect the computer NETWORK to the relay NETWORK and relay NETWORK to logic
   NETWORK, all on red. No vanilla pole or color change may relay this discovery.
   The KV is only a physical relay here; the example does not need KV commands.
3. Wire a stock chest's native circuit readout to logic INPUT red. Configure the
   chest to read contents. Do not wire INPUT to NETWORK or OUTPUT unless you
   deliberately want external feedback. Input colors remain physically separate.
4. Wire logic OUTPUT red or green to a powered inserter. Set its native
   enable/disable condition to virtual signal A > 0. Aim it from the supply chest
   to the stock chest. Both output colors receive exactly the same contribution.
5. Clear the cursor and Ctrl + left-click the computer. Paste the
   document between `[[` and `]]` in `examples/logic-controller.lua` into its source
   box. Validate, Save, then Run. Save alone does not change the active run.
6. The controller enables the inserter below 100 normal-quality iron plates,
   stops at/above 100, and retains stock/sample/changes/connectivity in state.
   Peripherals automatically shows complete, separately admitted red/green inventories.
7. Stop the computer or disconnect its red discovery path. Its still-owned output
   clears independently of the guest handler. A newer writer's bank is untouched.

Actual client typing/paste/focus, visual layout, wire interaction and multiplayer
joining are user-deferred alpha checks. Packaged headless checks use the production
editor's Save/Run model with a table-backed player, real native compiler/scheduler,
physical red discovery chain, sections, powered inserter and chests. This is not
native GUI delivery evidence. The fixture uses a real constant-combinator stock
source to change thresholds deterministically, not a fabricated signal API.

## Dot-call methods

Obtain a facade with `peripheral.find("logic_handler", "red")` or
`peripheral.wrap(name, wire)`. Discovery `wire` is red/green, independent of the
explicit INPUT selector red or green. Missing, `both` and other selectors are
errors, as are extra arguments and colon calls. Output uses the facade's explicitly
selected discovery wire for authority; its shared physical bank is not split by color.

| Method | Result |
| --- | --- |
| `readSignal(input, signal)` | Signed-32-bit integer; absent is 0 |
| `readSignals(input)` | Complete fresh native `Signal[]`, with native order and optional fields |
| `getInputStatus()` | `{red_connected=boolean, green_connected=boolean}` from real input edges |
| `getOutput()` | Defensive configured contribution, not other native contributors |
| `setOutput(signals)` | Zero return values; complete replacement and writer transfer |
| `clearOutput()` | Zero return values; same as replacing with `{}` |
| `subscribe(options, handler_name)` | Run-scoped subscription string |
| `unsubscribe(id)` | Boolean; removes this binding's registration and queued samples |
| `getLimits()` | Defensive shared caps plus logic-specific limits |

Signal: `{signal={type=native_type?,name=prototype,quality=quality_name?},count=integer}`.
Missing type means item; missing quality means normal. Native records keep those
fields optional and are neither normalized nor sorted. All native signal categories
are available. Caller-supplied prototypes/qualities must exist; wildcards fail.
Counts are -2147483648 through 2147483647 without coercion. Each read queries the
selected native circuit afresh, preserving its values, sequence and fields without
combining colors. Normal/uncommon copies of an item never merge.
Duplicate effective identities (including duplicate zeros) are rejected
before mutation; zero output entries are omitted. Failed validation/admission keeps
both old bank and old writer. Output uses a private manual native section, staged
inactive, verified then enabled. Unexpected engine failure restores the prior bank;
failed restoration retains `output_recovery` for host diagnosis and clears output.

Recipe identities use installed recipe prototype names, including mod-added and
disabled recipes; they are separate from same-named item identities. Reads,
output banks and subscription filters all accept recipes.

## Named sampled subscriptions

Options: `{input="red"|"green", signals={SignalId,...}?, initial=boolean?}`.
Unknown fields, empty/duplicate filters and undeclared handler names are refused.
Omitted signals means all; initial defaults false. Filters match complete identities.
A subscription binds computer/run, handler generation and discovery color. Losing
red access cannot silently move it to green. Removing its handler or changing
computer authority revokes it. An ID from another run/binding is refused.

One production sample observes each subscribed powered handler per actual tick.
Initial=false baselines current authoritative input without an event. Initial=true
queues a snapshot on the next sampling tick, with empty previous and false selected
previous connectivity. Unchanged values/connectivity produce no event. Disappearance
produces a changes entry with current=0. Connecting/disconnecting an empty network
can produce an event with empty changes. Within-tick transients are not detectable.

Event `signal_changed` contains the normal name/tick/sequence/computer_id/run_id,
plus subscription_id, peripheral, wire, input, sample_tick, initial, resync, previous,
current, changes, previous_connected and connected. Each change is
`{signal=SignalId,previous=Int32,current=Int32}`. Only selected colors appear in
connectivity maps. `sample_tick` is observation time; `tick` is callback dispatch.
Native circuits expose previous-circuit-step signals and propagate writes natively,
not by immediate recursive callbacks.

Queue admission advances the baseline, not callback dispatch. Computer/handler
outages remove obsolete queued samples but retain their last admitted baseline and
registration. Restoration delivers current resync, not every unobserved transition;
previous may refer to a discarded callback's sample. Handler outputs stay empty
until a new successful write. Cold reload preserves valid bank/owner/subscriptions
and exact run identity without startup or write replay. Legacy subscriptions with
`both`, missing or invalid selectors fault before queued callbacks dispatch, clear
owned output and discard pending effects. Update source to explicitly select red
or green and restart; no automatic wire substitution occurs. Source/state errors cannot
suppress cleanup. New placement/clones start with empty bank/no owner.

## Bounds and failures

Native input cardinality determines the complete result; there is no mod-defined
signal/name/filter/output count ceiling. Native output slot-index and signed-count
domains still apply. Own output is read from its native section, not a cached bank.
Registration counts remain 64 per computer and 1024 globally, admitted only when
registering. There is no distinct sampled-handler or owned-output quota.
Sampling interval is 1; the 60-tick notification/topology allowance is provisional.

Circuit result, baseline and event signal graphs do not pass through generic Data
size admission. Only queue entries and event envelopes consume circuit backlog
capacity; queue bytes therefore do not measure total circuit snapshot memory.
Guest execution, arbitrary allocation, string operations, explicit state/KV and
Console persistence retain their ordinary limits. Native-array non-growing edits
are supported, but mutated requests must pass caller validation. Native work and
heap use depend on the actual circuit: fixed call charges are not a universal bound.

Use effective identities `(type or "item", name, quality or "normal")`, not array
positions or always-present defaults. Accepted subscriptions, queued observations
and native ownership survive reload without replay. Obsolete read/output caches
are retired during synchronized gameplay, never during on_load. Back up before
upgrading; rollback uses the previous package and a pre-upgrade save backup.

Argument/domain/capacity/unpowered/path failures are ordinary catchable ApiErrors.
Queue overflow visibly faults the computer and clears its exact owned outputs.
Sampling/notification maintenance refusal also visibly faults affected runs rather
than silently skipping input history. Earlier accepted state/KV/other effects remain;
this is signal fail-safe cleanup, not a whole-factory transaction.
