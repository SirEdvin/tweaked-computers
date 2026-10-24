# Configurator resource integration

Configuration schema removal and durable transaction admission are separate gates.
Task 7.2 covers native-capacity schemas, generated contracts and native adapter
boundary fixtures. Task 7.3 remains open: guest mutations still refuse before
effects because the common transaction admission hook is absent.

## Implemented interface

The configurator binding now uses the existing `with_guard` peripheral dispatch. `M.methods` remains the synchronous host-fixture interface; `M.guarded_methods` is the actual registered provider.

- With the baseline guard (no `job`), the provider retains the existing metered, synchronous path. This is compatibility, not resource-policy acceptance.
- With `guard.job(name, initial)` and `guard.suspend()`, mutations retain a plain `{id, wire, phase, prepare?, plan?}` job named `configurator.<method>`. Preparation caches the detached request, per-field validation cursor, converted changes and duplicate-filter proof. Each validation step is charged before advancing. A completed plan suspends before commit. No entity, connector, iterator or closure is stored in this job.
- A guard with `job` but without the following commit hook fails **before preparation/effects**, with E_BUSY. It never falls back to an unreserved mutation.

Required common-runtime hook:

```lua
guard.commit_configuration(configurator_record, plan, function(commit_spend)
  -- Fresh target-side path proof, native state/protection revalidation,
  -- then indivisible native mutation/readback/possible restoration.
  return complete_native_result
end)
```

This is a required integration contract, **not an implemented common-runtime API**. The callback is transient, never saved. It must be invoked only after common ownership/result/recovery admission, and cannot suspend after the first native effect. Its returned value must be transferred into the already-admitted durable service result, including a cold boundary before caller delivery. Do not merely call `guard.prepare_result` after the callback, or return a fabricated pre-effect result instead of native readback.

Plan shapes:

- Configuration: `{id, behavior, changes={field={native, expected}|{clear=true}}, patch, before={values,unset,observations}, work}`.
- Sections: `{id, operation="set"|"add"|"remove", index?, values?, request, before=SectionInfo[], work}`.

`work` is weighted setter/readback/restoration work, **not a retained-byte estimate**. Common accounting must walk actual plain plan graphs with alias deduplication. Retained ownership includes the copied request, schema cursor stack, converted candidate, prior snapshot and any recovery record. Peak ownership additionally includes native getter data, normalized readback, verification and possible restoration data, and the durable return tuple. Reserve these peaks before effects. Release job ownership only on completion/cancellation; transfer failed-restoration records to the configurator's persistent host owner, never evict them. A native group join may reveal filters absent from the request, so its result envelope still needs a read-only native group proof or another demonstrably safe admission method. The pinned `LuaForce.get_logistic_group` also returns members; do not treat that native materialization as free.

## Remaining integration gates

1. Supply and exercise `commit_configuration` through the real durable runtime, not the fixture double. Reprove computer-to-configurator authority/power/run identity on every resume as well as the target-side proof inside the callback. Insufficient full-slice commit work must refuse with setting guidance, not retry forever. The existing fixture only establishes host-side staging, revalidation and native effects.
2. Common byte-bounded `data.copy` now removes the former node/string/table shape ceilings, and durable result copying retains its paid cursor. Configurator copies pass effective `host_memory_bytes`, rather than the removed 16 KiB configuration cap. The strict `tests.configurator_large_engine` crosses 33 native sections; its original shared 64 KiB fallback failure is historical, not a current refusal oracle. Native schema metadata still repeats per section and contributes to retained size; this does not prove transaction peak admission or close aggregate ownership task 2.2.
3. Validation is incremental, but initial Data copying, native normalization and complete snapshots still contain indivisible work. Target traversal and inspector projection remain complete synchronous observations with work charging. They no longer have independent graph ceilings, but a durable read/traversal cursor and retained-host admission are still required for observations that cannot fit a slice. `inspect(rec,tick,spend)` returns both colors together or errors; never publish a partially gathered color or a partial unique count. UI must expose pending/stale state.
4. `getLimits` now uses the shared policy-v2 provider with the seven applicable work/memory/depth descriptors and no unrelated settings or legacy count/shape keys. The native read-only fixture below verifies the public durable path; this does not complete transaction admission.
5. Generated player settings/schema pages and Reference now agree with the native-capacity catalog: no generic 256-byte/128-entry gates, uint16 filter indexes and item-specific import defaults. `tools/test_configuration_resource_contracts.py` checks generated contracts without dropping native range/type/prototype restrictions. Full native UI acceptance is separate.

## Schema gate (task 7.2)

`configuration_catalog.py --check` verifies the generated native schemas and
coverage ledger. The player-contract regression first fails on the stale
128-entry/256-byte prose and filter index range, then passes after regeneration.
No execution budgets or native adapters change in this contract reconciliation.

The packaged base/Space Age matrix uses `configurator_large_engine` for complete
33-section reads, update, cold retention and removal; `configurator_resource_engine`
for 129 distinct filters, 129 decider conditions, long group names, native numeric
ranges and paid validation across cold load; and `configurator_policy` for actual
scheduled guest reads and defensive capability snapshots. The resource fixture
checks every filter's item-specific import default and rejects sparse arrays,
duplicate indexes, unknown fields and unknown prototypes without changing the
target or creating recovery records. Existing adapter-family fixtures remain in
the matrix. Source/archive hashes and complete receipts are preserved outside git
under `/home/siredvin/artifacts/tweaked-computers/resource-policy-configurator-schemas/`.

These native mutation tests call adapters directly or use the explicitly labelled
host guard double. They prove schema removal, not public durable write admission.
No test double is promoted to production, and task 7.3 remains fail-closed.

## Scoped native evidence

### Integrated policy and large native reads

`tests.configurator_policy` runs actual compiled guest code through wired native
devices, the production scheduler and the real continuation/memory guard. It
checks both discovery colors, separate target-port/color isolation, device and
capability reads, 129 native decider conditions and all 33 constant-combinator
sections with 129 distinct native filters. The fixture freezes during the paid
section-result copy, resumes in a separate process, then verifies complete
defensive readback and powered/unpowered policy access with strict arity and
exact descriptor fields. Final native settings must equal the original snapshots.
No transaction guard, native target or result provider is replaced by a double.

The new policy assertion first fails against the old flat limits response.
The corrected provider passes both content modes and cold reload without changing
production budgets. The independent strict `configurator_large_engine` remains
a native adapter mutation test, not durable guest mutation admission. The shared
Data-cap failure recorded below is historical; the current integrated read test
crosses that old boundary. CI runs these two fixtures before legacy integration,
without omitting the existing Configurator or speaker cases.

The common transaction hook remains absent and guest writes remain fail-closed.
Native/normalized/readback peaks, pre-effect result carriers, persistent recovery
ownership and release still need their own complete proof. In particular, the
weighted `plan.work` value must not be multiplied into a guessed memory allowance
or used as permission to publish a result after an unreserved native effect.
Task 7.3 and full acceptance remain open. Exact archives, failures and local
receipts for this checkpoint are kept outside git under
`/home/siredvin/artifacts/tweaked-computers/resource-policy-configurator-reads/`.

### Earlier adapter and host-double checks

- `tests.configurator_engine`: ordinary target topology, malformed/readonly/protected inputs, root-field failure/restoration/recovery, actual compiled facade, cold recovery aliases; target graph now exceeds the former connector/edge envelope.
- `tests.configurator_full_engine` plus `tests.configurator_full_data`: every existing adapter family, nonmanual host double, shared groups, section rollback/recovery, actual compiled facade, base/Space Age cold reload.
- `tests.configurator_resource_engine`: native 129 distinct filters, 129 decider conditions, long group names, float32 values beyond the old generic numeric bound; paid validation cursor and staged plans across cold reload; competing writers/disconnection/shared detach; complete inspector results; 257 labelled retained recovery records. Its `commit_configuration` is explicitly a **host test double**, not proof of common memory/result admission.
- `tests.configurator_large_engine`: strict positive 33-section read/update/cold test, intentionally left as an integration gate rather than asserting the old shared refusal as success.

The large filter test exposed an existing Space Age normalization error: default imports are item-prototype-specific, not always Nauvis. The adapter now reads `LuaItemPrototype.default_import_location`. Slot indexes retain the pinned native `LogisticFilterIndex` uint16 domain, and multiplier schemas retain finite float32 bounds. These were checked against the pinned 2.0.77 runtime API and real engine readback.

Archive hashes, exact commands, process exits and failure logs are preserved outside git in the evidence directory reported by the lane. No public futures, partial totals, native distributions, settings changes or shared task checkboxes were added.
