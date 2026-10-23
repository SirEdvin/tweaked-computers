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
  `table_entries`, `data_nodes`, `identifier_bytes`, `tuple_entries` and
  `peripheral_call_bytes` shape ceilings in favor of real retained-memory
  admission. Otherwise complete provider results still fail at the shared edge.
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
  The UI-owned in-game help still needs its old signal/graph/50-result prose
  updated (including `scripts/ui/help.lua`'s `recipe_search_results=50`).

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
