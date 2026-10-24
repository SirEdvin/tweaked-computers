# Inventory resource-policy integration and evidence

This lane removes the logic 64-signal/filter/name gates, graph node/edge gates,
peripheral find count gate and recipe 50-result/projector shape gates. It adds
plain persisted BFS/witness, mergesort, signal projection/delta and recipe
projection cursors. Public return signatures are unchanged.

## Required shared integration (not supplied by this isolated lane)

- `guard.job(name, initial)` and `guard.suspend()` from COORDINATION.md. The
  fallback without `guard.job` is for existing host/non-durable test callers;
  it is not cold continuation acceptance through the guest boundary.
  Durable guards without this contract fail closed with `E_UNSUPPORTED`.
- Generic Data and service return/tuple preparation must remove old
  `table_entries`, `identifier_bytes`, `tuple_entries` and
  `peripheral_call_bytes` shape ceilings in favor of real retained-memory
  admission. Otherwise complete provider results still fail at the shared edge.
  The total-node ceiling is now removed. Durable service argument/result copies
  retain their paid cursor and use real memory admission instead of the old
  snapshot byte ceiling; non-durable copies retain that fallback. The native
  600-product guest query and mid-copy cold boundary are separate from the
  remaining full inventory/lifecycle/upgrade acceptance. Byte-bounded host Data
  copies and memory-owned durable table growth/copy/iteration no longer impose
  the 1,024-entry ceiling. Literal constructors, non-owned/non-durable copies,
  persisted Console graphs and other string/tuple/shape gates remain incomplete.
- Maintenance event preparation needs a save-safe cursor argument:
  `runtime.prepare_event(c, handler, payload, tick, spend, metadata, job)`.
  Logic now supplies the last argument. The baseline runtime ignores it;
  without shared incremental Data/event copying, a large notification can
  repeatedly defer after its provider preparation has completed.
- `runtime.subscribe` still owns atomic subscription ID/result preparation and
  retained subscription admission. Logic supplies a complete prepared baseline,
  but must not invent a second subscription allocator in this lane.
- Parent host-memory accounting must cover `rec.logic_pending_sample`,
  `rec.logic_sample`, `sub.details.pending`, `sub.details.previous`,
  `computer.network_views[wire].prepare/job/inventory`, native `output_bank`,
  and private service jobs. Aliased baselines/samples must not be charged twice.
  Native sampling temporarily owns native tuples plus normalized tuples and
  a mergesort reference array; graph jobs own O(V+E) string-ID maps/arrays;
  recipe jobs own result metadata plus one current recipe's native plain source.
  Output staging owns the canonical bank, native filter descriptors and old bank.
  Do not ship cardinality removals without wiring this admission.
  Using the existing ledger's 64+16/entry table, 32+string-byte and 256/new-object
  ownership overhead, a 1,100-signal read job with 17-byte names is approximately
  1,972,300 accounted bytes (1.88 MiB) before fixed maps and transient native
  allocation: two signal/entry table pairs, unique names, and three reference
  arrays per signal. Both-color sampling, admitted baselines, pending change
  payloads and result copies coexist; reserve their complete ownership graph,
  not merely one array's serialized size. This is an accounting estimate, not
  a measured C++/Lua heap size or a new per-shape limit.
- Final live graph/witness proof and native section replacement remain
  indivisible, prepaid atoms. Very large atoms that cannot fit a fresh service
  or maintenance slice need the shared actionable atomic-work refusal policy,
  not endless private retry or increased work settings. Facade construction for
  a large `find` tuple also remains a final shared result-admission integration
  gate. Topology and subscription gathering still need aggregate host-account
  and traversal review once registry/subscription count guards are removed.
- UI callers can supply optional jobs to `logic.inspect_input` /
  `logic.inspect_output` and `peripheral.inventory`. No UI files were changed.
  Configurator callers retain the existing network primitive signatures;
  `network.real_edges` accepts but no longer enforces the old remaining count.
  The UI-owned in-game help still needs its old signal/graph prose updated;
  the Recipe Searcher section now describes resource policy rather than 50 results.

## Recipe Searcher limits checkpoint

`getLimits()` now reuses the shared policy-v2 registry, selecting only applicable
work/allocation/host-work, runtime/host/pending-memory and host-depth descriptors.
The returned nested maps are defensive, and remain available on a reachable
unpowered searcher. Removed shape/count limits and unrelated device settings
are absent. Player/API documentation and in-game Reference describe the breaking
introspection shape; query result shapes and production budgets are unchanged.

`tests.recipe_searcher_policy` executes compiled guest code through real wired
devices and the production continuation/memory guard in base and Space Age.
It checks both colors, powered/unpowered access, exact descriptor fields against
computer introspection, defensive nested mutations, return/argument arity and a
small native recipe query. Its explicit fixture cleanup is not lifecycle or
cold-job ownership acceptance. The complete legacy query fixture and shared
large-result/temporary ownership gates remain necessary; task 7.4 stays open.

Exact archive, local summaries, original regression failure and CI receipts for
this checkpoint are preserved outside git at
`/home/siredvin/artifacts/tweaked-computers/resource-policy-recipe-limits/`.

## Scheduled full Recipe Searcher fixture

`tests.recipe_searcher_engine` now submits its complete guest-query cases through
`runtime.save`/`activate`, queues repeat probes on the same active run, and waits
for the real scheduler rather than executing a non-durable compiler shortcut.
The live force-enabled probe explicitly retains its run identity. Captured-method
Console probes stay together because replacing a program correctly retires its
Console state; those direct shell evaluations are not GUI or durable Console
acceptance.

All native catalogue, 50/51-match, 600-product, metadata, force/surface, wiring,
power, clone/mining/replacement and captured-authority assertions remain. The
100-query protected loop now must suspend and finish exactly once on later
ticks, not fail with the superseded fatal budget error. Its independent query
peer still must complete at least 15 queries at the original 20-tick boundary;
the original 900-tick fixture deadline and production budgets are unchanged.

Cold and configuration-change processes preserve retained records, active/run
identity, native wires and spent credits before an explicitly queued new query.
The configuration-change probe is not migration from an older released archive.
CI runs this entire fixture alongside the policy/Data tests before the separately
failing speaker integration, without dropping native cases. Task 7.4 and the
full resource-policy checklist remain unfinished: other shape ceilings and
aggregate ownership gates are not proven by this fixture.

## Memory-owned table width checkpoint

The Data fixtures now also query a real native recipe with 1,100 product records,
and carry 1,100-entry arrays/maps through admitted events and defensive snapshots.
Guest checks cover single/multiple assignment, `ipairs`, insertion/removal, a
tail `unpack`, comparator sorting, state retention and deletion. The cold-copy
variant freezes within the 1,100-product service result; the state variant reloads
the retained wide table. Original 600-product and nested Data/timer checks remain.

The real memory-guard subcase refuses both single growth and a two-key assignment
that has room for only one key, before changing table membership or ownership.
It then verifies admitted growth, shrink and explicit owner release. These are
accounting checks, not proof of every production lifetime. Host byte ceilings,
plain/dense Data checks, finite numbers, safe integer indexes and depth protection
remain enforced. Queue-heavy test events are submitted serially rather than
raising the production queue allowance; the existing 300-tick deadline remains.

Task 2.2/7.4 and full integration remain open. Evidence for this checkpoint lives
outside git at `/home/siredvin/artifacts/tweaked-computers/resource-policy-data-width/`.

The follow-up snapshot regression verifies that scalar entries reuse an already
admitted traversal frame, while each descent into a nested table admits a new
frame. Payload copying and result-table growth remain charged; retained cursor
capacity may stay conservatively high until the next descent or job reclamation.
This removes redundant cursor reservations, not resource protection. It does not
resolve the mixed-chart gate, which still fails its unchanged shared-model oracle.

## Focused native regression

`tests.inventory_engine` + `tests.inventory_data` exercises native 1,100-signal
red/green snapshots (opposite signed counts), a 300-peripheral cyclic graph,
color isolation, saved mid-sort/mid-recipe cursors, 51 recipe results, 600 product
records, engine-capacity output beyond 64, strict invalid-count preservation,
long prototype names, recipe identities, expansion qualities and fail-safe power
cleanup. The cursor driver uses a smaller explicit work slice, never raises
production budgets, and freezes until a separate cold process loads the save.
This is provider/cursor evidence, **not** shared guest checkpoint or host-memory
admission acceptance. Existing logic/recipe/network fixtures remain the public
boundary and lifecycle regression gates after common-core integration.

Commands and immutable archive receipts are recorded with the final lane report.
No GUI, connected multiplayer, release-wide timing or final integrated acceptance
is implied by this fixture.

## Recorded lane evidence

Evidence root: `/home/siredvin/artifacts/tweaked-computers/inventory-resource-policy-2026-10-23/`.
The `final/package/tweaked-computers_0.1.13.zip` SHA-256 is
`4f40aa88cbc9f1d970f4c5ebff2a40df3d72dfcfb519c437d225fc6b7e159b0d`.
All 202 Lua payloads under scripts/tests/examples were compared byte-for-byte
against the final worktree after the run. Documentation receipts were added later.

Built with `python tools/build.py --output "$WORK/package"` and executed under
the coordination lock with Factorio `/home/siredvin/tools/factorio/bin/x64/factorio`
2.0.77 build 84539 (`--version` and `--help` inspected):

```sh
flock ../native.lock python tools/smoke.py --factorio "$HEADLESS" \
  --archive "$ARCHIVE" --output "$WORK/complete" --mode both \
  --fixture tests.inventory_engine --data-fixture tests.inventory_data --cold
```

`final/complete/summary.json`: base and space-age map creation plus both cold
process phases passed, every engine exit 0, console quit acknowledged, no SIGINT
or forced kill. Cold snapshots include partial signal sort, recipe projection,
native catalogue scan and graph traversal. Native read sizes 64/65/150/1,100,
both colors, quality/recipe identities and the 300-device cycle are asserted.

The same archive's `tests.logic_engine --mode both --cold` was deliberately also
run against the isolated old shared core. Base creation passed; cold-first exited
255 at tick 9 with `durable inventory job admission unavailable` (wrapper exit 1).
Space-age was not reached. This is the explicit missing `guard.job` integration
gate, **not** a passing final controller test. Before the fail-closed guard check,
`pre-guard-logic-pass/` records both modes and cold phases passing unchanged
controller deadlines and output/drop/resync regressions on archive
`2a23b04690560f8d3bb45f339b7eb79aae3b4677c2eca8a26f67db9de964234f`.

Failed attempts are retained separately: `failed-custom-table/` caught `next()`
on a native LuaCustomTable; `failed-runtime-require/` caught event-time imports.
Both root causes are fixed in the final source. No production work budgets,
controller deadlines or old acceptance counts were raised to obtain a pass.
