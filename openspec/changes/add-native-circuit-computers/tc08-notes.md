# TC08 — persistent local KV, implementation/evidence

Scope: task 3.1 / 3.2 / implementation of 3.3, `kv-database` capability.
Target: exactly Factorio 2.0.77, base and optional Space Age.

## Parent and owned implementation

Ordinarily merged (fast-forward) TC05 commit
`3e987008fe15f5989f42135eb23fadfa39911567`; verified its ancestry before edits.
This brings the required physical/network/runtime parents, not unrelated sibling
features. All edits are in the preserved TC08 worktree/branch.

- `scripts/services/kv.lua`: complete closed Redis-inspired string/hash/key-expiry
  method table bound through TC05's per-call physical authority bridge. All values
  remain plain strings; readback never exposes a retained entry/field table.
- Exact arity, duplicate operands, one-nil absence, count/sentinel, WRONGTYPE,
  empty/NUL, type replacement and last-field deletion semantics.
- Absolute saved simulation deadlines, safe integer expiry arithmetic, quotient /
  remainder nearest-second TTL rounding, no power/load/carry renewal.
- Immutable command candidates, operand/type/work/capacity validation before
  publication, full bounded live-capacity accounting independent of cleanup.
- Versioned plain indexes/counters and fair bounded reclamation using the existing
  maintenance phase/ledger. No scheduler replacement or larger aggregate budget.
- Separate reserved snapshot metadata, strict bounded dense record import,
  duplicate/unknown/type/arity/deadline/content/cycle/function refusals and
  defensive item restoration. No silent truncation or unknown-header reset.
- A fixed host-only `lifecycle.register_item_adapter` for KV material items;
  registered trusted services are not a player extension API. Body ownership and
  physical cleanup remain in the existing lifecycle module.
- Player/robot mining writes the single tagged result before retiring the exact
  body/ports. Replacement has a new identity and old absolute deadlines. Failed
  restoration refunds the original tagged material item; duplicate builds never
  replay its snapshot over later data. Ghost-only tags and native clones are
  empty. Computer mining remains guarded until TC12 installs its own adapter.
- Full API/limits/help in `docs/kv-database.md`, `locale/en/kv.cfg`, executed native
  example `examples/kv-program.lua`, compact `tests/kv_engine.lua` in the existing
  packaged-engine harness. Only 3.1–3.3 checklist rows were updated.

The hash-byte ceiling (8192) is independently published alongside total content
(16384), rather than accepting a whole hash which cannot fit fresh defensive
readback allocation headroom. All shared sandbox/aggregate ceilings are unchanged.
Initial numbers are alpha tuning, not a graphical/aggregate latency promise.

## Exact tested artifact and commands

Archive:
`/home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-artifacts-final/tweaked-computers_0.1.0.zip`

SHA256:
`dc8f52cbcf5182dba1385da80a500a9a28d3557e405cdfff9466ab9651f2309e`

The deterministic build has 51 packaged files. OpenSpec notes/checklist are not
in the runtime inventory; these final evidence edits do not change the archive.

```
python3 tools/build.py --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-artifacts-final
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-artifacts-final/tweaked-computers_0.1.0.zip \
  --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-smoke-final \
  --fixture tests.kv_engine --mode both --cold
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-artifacts-final/tweaked-computers_0.1.0.zip \
  --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-network-regression-final \
  --fixture tests.network_engine --mode base --cold
python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-artifacts-final/tweaked-computers_0.1.0.zip \
  --output /home/siredvin/.hermes/profiles/albina/cache/scratch/tc08-device-regression-final \
  --fixture tests.device_engine --mode base --cold --upgrade-fixture
```

All passed: 11 KV contract groups per base/Space Age mode, plus 12 network and 12
physical-device regression groups in base (46 grouped passes total). Counted
markers/totals are verified by the existing harness, not counted by eye. Nine
cold/configuration processes all returned exit 0, verified console `/quit` and
`Goodbye`; no signal fallback or forced kill. Four native KV cold phases preserve
maximum contents, genuine carried item bytes and absolute expiry while an
unpowered physical database retains the exact saved database alias. Network /
physical parent checks protect shared hooks without rerunning unrelated suites.

## Evidence distinctions

- Native command tables use actual Factorio Lua strings and owned physical
  records. These are host contract checks, not a graphical API editor.
- Compiled source executes real copied service facades, empty/NUL content,
  wrong-type/invalid-value refusal, shared two-computer reads/writes, static
  unpowered limits and a full accepted 8192-byte hash readback.
- The packaged example uses the real runtime Save/activation/start dispatch and
  creates its actual hash owner/deadline/named timer. It is not client typing or
  the final shared-telemetry controller of 3.4.
- Maximum live-content/metadata snapshots include 128 keys and 16384 bytes of NUL
  values. Player and robot-shaped event route contracts use genuine native
  inventories/stacks; these table events alone are not native player/robot action
  evidence.
- Independently, a real native construction robot deconstructs the maximum
  database, the actual on_robot_mined_entity handler tags its engine buffer, and
  the robot transfers that item into an actual storage chest. Retained logs
  contain `TC_KV_NATIVE_ROBOT_MINED` / `TC_KV_NATIVE_ROBOT_TRANSFER_OK`.
- That genuine item survives the cold process. After its original deadline, a
  real ghost is created and a real construction robot places the tagged item,
  producing `TC_KV_NATIVE_ROBOT_BUILT`; unchanged persistent keys retain exact
  NUL bytes and the expired key remains absent without renewed TTL.
- Native cloning in on_tick emits the actual event and yields an empty new
  registered identity (`TC_KV_NATIVE_CLONE_OK`). The initialization clone route
  is explicitly table-backed because that initial clone did not invoke its event.
- Invalid snapshot replacement/refund uses real entities/robot cargo but a
  table-backed build event; retained original/refunded tags are read back exactly.
  Unsupported headers keep recovery content and disable mining.
- `on_load` performs only fixture read-only comparisons. Production has no
  on_load handler and no guest source replay. The snapshot waits for a readable
  ZIP, freezes the fixture, and never reports reload completion in process one.

Early retained failures (`tc08-smoke-1`, `-2`, `-3`) were fixture issues: an
incorrect authored entity name, assuming initialization clone-event delivery,
and clearing the cold-resume flag before the carried deadline. The latter ended
with acknowledged clean quit but a failed completion gate; it remains recorded.
They were corrected without relaxing deadlines, production budgets or contracts.
Later scratch runs `-4` / `-5` established the direct cold path and actual robot
rebuild respectively; the final exact archive passes all final checks above.

## Integration and intentionally deferred verification

- hotspot: `scripts/lifecycle.lua` — preserve the KV fixed material-item adapter,
  duplicate-build guard and snapshot-before-removal ordering. TC12 owns complete
  whole-family source/state/blueprint/clone/helper lifecycle reconciliation;
  extend the existing route rather than replacing KV preservation.
- hotspot: `control.lua` — retain the trusted KV parsing-time import, synchronized
  init/configuration initialization and shared clone-event forwarding alongside
  sibling editor/logic/monitor/configurator registrations. Never run this setup
  or player code in on_load.
- Use TC05's existing fixed binding contract; methods receive
  `(computer, target, wire, tick, spend, ...)`. KV snapshot/import is host-only and
  must not be exposed in public `getMethods` or arbitrary remote interfaces.
- The tag key is `tc_kv`, version 1, with a dense entries array. Snapshot strings
  are values, not dynamic serialized table keys; empty/NUL keys are preserved.
  The entire importer validates before installing a new database.
- TC12 still owns whole-family lifecycle integration and configuration-change
  recovery checks with merged sibling features; TC13 owns the aggregate envelope;
  the final integration milestone owns controller telemetry task 3.4.
- No graphical client, screenshots, UI automation or multiplayer joining ran.
  Native player mining/build interaction and the real editor Save/Run flow remain
  user-deferred. Task 3.3's mixed client checkbox is deliberately open although
  implementation is complete. This is not a release or Mod Portal publication.
