# API migration: retained verification obligations

These checklists survived retirement of the handwritten API companions. They are
verification requirements, not extra signature/type authority and not receipts of
execution. Use the current public `api/*.d.lua` contracts and Factorio 2.1.23.
Historical observations never become current native-client or multiplayer passes.

## api — Enforced boundaries

Instrumentation must account for function entry/exit, loop iterations, statement/operator work where input-dependent, indexed reads/writes, table creation/growth, argument/return movement, concatenation and helper calls. A host string metatable or captured method must not bypass the approved wrapper. Source token/node/nesting limits and compilation-work limits are enforced before native activation; generated text has its own limit.

Native helpers reserve conservative input/output and movement costs before mutation. Limits cover the largest accepted request, not just average examples. Temporary allocation/call-depth ceilings bound one callback's host-memory pressure. Source parsing and native `load` remain synchronous opaque costs with finite validated input envelopes; their real worst-accepted latency must be measured in Factorio rather than called a proven real-time bound from work counters alone.

Budget state belongs to the synchronized scheduler and survives same-tick save/load. Reconstructing a cold executable cache cannot renew credits or change guest-observable admission compared with a warm peer. `pcall` rethrows private quota/stop controls and every subsequent effect also checks the poisoned-run state. Strings, numeric-string coercion, formatting and table operations cannot obtain unpaid work through native Lua syntax.

## api — Failure and acceptance

Fatal work/call-depth/allocation exhaustion faults the run; it does not suspend the Lua stack. Earlier committed API effects remain, except host-mandated fail-safe clearing of still-owned logic outputs. Ordinary validation/API errors remain catchable. No hidden interpreter fallback is permitted if the instrumented subset cannot meet its acceptance gates.

Required adversarial cases: infinite/empty loops; direct and mutual recursion; closures returning closures; attempted `_ENV`/generated-name access; dynamic string-method bypass; library mutation; `pcall` swallowing; huge format widths, repetition and numeric-string operands; cyclic state; maximum-width argument/return lists; malicious sort comparators; rejected source beside an interactive computer; and cold/warm cache equality with exhausted same-tick budgets. Test the maximum accepted useful work, not comment-padded source. Passing syntax-only tests is not evidence of these properties.

## computer-runtime — Required contract checks

- Ordinary false/empty values versus missing state; copy isolation and invalid nested data refusal.
- Save/load after a completed state write, pending one-shot and recurring timers; no duplicated `start` or registration.
- Same-tick budget preservation, malicious loops/recursion, `pcall` quota swallowing, oversized helpers and a responsive neighboring computer.
- Power-free execution, legacy paused-run upgrade without startup replay, timer cancel after queue admission, stop cleanup and active/saved source separation.

## peripheral-network — Required cases

Same-color chain; red-to-green nonpath; vanilla/ghost/foreign-force relay refusal; both-color duplicate identity; power-free custom and powered/unpowered native discovery; invalidation between lookup/call; incomplete traversal refusal; monitor merge/split wrapper invalidation; saved names after new entity placement; shared writes; no signals encoded on discovery ports.

## kv-database — Required cases

All listed return types; empty/NUL strings; false/number/table refusal; duplicate variadic arguments; odd HSET arity; wrong-type reads and writes; SET replacing hashes/removing expiry; HSET retaining TTL; deleting the last hash field; zero/negative expiry; exact boundary and half-second TTL rounding; expired-but-unreclaimed capacity; copying snapshots; maximum accepted mining/save metadata; two computers observing one database; distinct databases; physical unavailability and cold reload without TTL renewal.

## device-lifecycle — Persistence cases to exercise

1. Run source that stores a state marker and a timer, then cold-save/reload before the deadline; inspect unchanged identities/state and once-only delivery.
2. Save different source without applying, then mine: verify a plain item and blank ordinary replacement. Separately undo removal through native history/ghost construction; verify saved source, formerly active recovery source, explicit state and a fresh stopped identity. Cold-load both before undo and before construction; no run work or startup replay returns.
3. Fill a database to its accepted content limit, mine it, advance simulation time, replace it and inspect exact retained/expired values. Include snapshot metadata in capacity tests.
4. Blueprint and clone a running setup; verify no copied state/KV/timers/output owner and no automatic factory changes.
5. Remove/rotate/revive every composite direction through player and robot paths. Verify one item, no orphan ports, no duplicated wire endpoints and no stale handle controlling a replacement.
6. Load the exact archive with base alone and with Space Age; verify quality-aware values and zero references to absent expansion prototypes.

These are required execution cases. The contract itself is not evidence that a headless, client or multiplayer lifecycle test ran; consult the artifact-bound acceptance receipts for actual modes, phases and limitations.

## device-configurator — Required cases

Catalogue completeness against pinned source; coordinates/types and unsupported devices; pole relays, connector isolation and no cross-color/surface traversal; stale IDs/paths/forces; false/unset/read-only distinctions; every writable field with actual applicable engine fixtures; enum/prototype/quality validation; invalid multi-field patch preserves prior settings; native GUI readback; constant sections and protected/shared groups; player changes after program stop; base-only plus expansion coverage and no arbitrary object escape.

## radar-modem — Required cases

Exact signatures and return arity; boundary channels; capacity/idempotency; shared computers/colors/Console calls; same-radar self-echo exclusion; two receiving radars; same-surface distances; closed channels; wrong/allied force; mixed tiers both directions; different ordinary surfaces; advanced planet/platform/in-flight routes; nil/false/invalid/oversized data; receiver-copy isolation; both-wire deduplication; multi-handler order; detach before versus after admission; incomplete proof with no prefix; fan-out/rate refusal; receiver overflow; power cycle and no replay; same-tick cold credits; save with queued events; removal/replacement/clone/force change; native hidden-wire exclusion.

## Integrated stock-controller observations

1. A real native inserter's condition readback is signal-A > 0. Inventory movement occurs below the threshold and ceases above it after normal circuit/in-flight-item settling.
2. KV telemetry contains strings and a live whole-key deadline. Stopping the controller leaves recent telemetry temporarily readable, then it expires by simulation time.
3. The merged world display shows stock/status. Touch toggles the explicit persistent enabled value and changes output after actual tick propagation.
4. Removing the current writer's discovery path clears its owned output. The monitor image and already applied inserter configuration remain. This demonstration is fail-safe on loss; it is not an automatic reconnection manager.
5. Change the threshold in the editor, Save without Apply, and prove the old revision still controls the factory. Then Apply and prove the changed saved source changes actual behavior.
6. Cold-load while enabled is false and timers/subscriptions are retained. Startup configuration is not replayed; state remains false and only retained work resumes.
7. Resize the monitor; the model clears, then the resize callback redraws it. Probe the same character coordinates visually and through a real client interaction.

The example does not promise deduplication of independently scheduled refresh timers or global transactions. Each accepted operation is serialized and bounded; queue/resource overflow remains a visible failure under the shared contract.

## Production statistics: retained reference status

Planning inspected the official Factorio 2.1.23 runtime API JSON and current service/lifecycle code. It did not execute a new feature or native-statistics fixture.

- https://lua-api.factorio.com/2.1.23/runtime-api.json
- https://lua-api.factorio.com/2.1.23/classes/LuaFlowStatistics.html
- https://lua-api.factorio.com/2.1.23/classes/LuaForce.html
- https://lua-api.factorio.com/2.1.23/classes/LuaSurface.html

Native sample parity, special pollution keys, cold loads, performance and actual client/multiplayer acceptance remain implementation gates, not facts established by this document.

## Case B: discover both colors without mixing them

Use the retained [discovery program](../examples/api-contract/peripheral-network-lua-api-1.lua). With computer --red--> database --green--> monitor, red discovery must contain the database but not the monitor, and green discovery from the computer must not invent a route. Adding an actual complete red route to the monitor permits red access; it does not retroactively authorize green-bound handles.

## Case C: precise cache expiration and type failures

Use the retained [cache program](../examples/api-contract/kv-database-lua-api-1.lua) and [protected wrong-type program](../examples/api-contract/computer-runtime-lua-api-2.lua). Verify nil versus empty strings, the WRONGTYPE table from GET of a hash, HSET preserving TTL, SET clearing it, deletion of the final field and exact deadline boundaries. Advance actual ticks; a made-up clock result is not engine evidence.

## Case D: signal events and multiple writers

Use the retained [threshold program](../examples/api-contract/logic-handler-lua-api-1.lua). Drive red and green inputs independently with identical names but distinct qualities. Check summed values, filtered deltas including disappearance, selected-color connectivity changes and sample_tick versus dispatch tick. Have A write, B overwrite and A stop: only stopping/disconnecting B may clear B's still-owned bank.

## Case E: configurator inspection and containment

Use the retained [capability-before-write program](../examples/api-contract/device-configurator-lua-api-1.lua). Include devices behind poles, an unsupported device, an isolated combinator opposite connector, a ghost and a replacement at old coordinates. Verify complete descriptions/capabilities and refusal outside current target reachability. Use a constant-combinator shared group with an out-of-network member to prove shared content cannot be changed through local target authority.
