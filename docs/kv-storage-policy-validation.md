# KV storage and material transport checkpoint

## Scope

This storage-lane checkpoint wires the ten registered `kv_*` effective settings,
returns policy-v2 KV metadata, separates structural retention validation from
new-growth admission, and reserves KV snapshot metadata before writes. Existing
keys/fields can be read, reduced, expired and deleted while grandfathered.
Export/import never reapplies the current growth ceiling. Computer material
snapshots retain shape validation without independent source/label/state/node or
131072-byte transport ceilings. Runtime continuation/ownership is not part of
the closed item format. Reclamation uses paid constant-size swap/pop steps and
fair persisted device cursors instead of fixed throughput batches.

`getLimits().usage` is logical retained KV inventory, **not** shared host heap
accounting. Expired entries remain in this inventory until reclaimed. The
snapshot headroom formula is content + 80/key + 48/hash field + 128 header units.
A minimal recovery command can exceed a lowered argument setting; larger
batches must be split. Recovery input bytes may use the retained database byte
footprint. New writes after expiry are new admission, not grandfathered revival.

## Reproducible native gate

Run from the storage checkout with a fresh scratch output:

```sh
python tools/build.py --output "$WORK/package" > "$WORK/build.json"
flock /home/siredvin/.hermes/profiles/albina/cache/scratch/tc-policy-parallel-QqFKCi/native.lock \
  python tests/run_kv_policy.py \
  --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive "$(jq -er .path "$WORK/build.json")" --output "$WORK/policy"
```

The runner redirects only `tests/resource_policy_settings.lua` in a copied ZIP
to the packaged `tests.kv_policy_engine` fixture. Every other ZIP payload is
verified byte-identical. This uses an existing production-context hook without
editing shared control/smoke files: Factorio forbids a companion mod from
changing settings owned by the production mod. Both source and tested ZIP
hashes are recorded in `provenance.json`. Native runs use isolated configs,
mods, inventories and saves, localhost-only servers, and acknowledged `/quit`.
No player data is used.

The fixture checks:

- All ten real settings: effective query, atomic refusal, increase, and defensive metadata.
- Above-old-limit inventory: 302 keys, 300 hash fields, a 300-byte key and a
  9000-byte value; full host browser inspection and shrink after lowering.
- Every precommit work-callback refusal of a multifield HSET; partial paid
  reclamation followed by completion; unchanged deadlines on refusal.
- Maximum-default KV content (128 keys / 16384 bytes) and computer state
  (65536 logical bytes), lowered to one-unit settings before actual robot mining.
- Cold save with real tagged items and retained live aliases; lower/read/shrink/
  delete/raise behavior; actual robot replacement under low settings after expiry.
- New identities, stopped computers, distinct saved/active source, empty queues,
  timers/subscriptions, source-only native clone/blueprint isolation.
- Malformed Data rejection without replacing prior state, iterative deep Data,
  and native item serialization with a 140000-byte source above the old transport
  cap. This large source is a material-format fixture, **not** evidence that the
  unchanged runtime compiler admitted/executed a source that size.

## Executed receipts

Preserved bundle:
`/home/siredvin/artifacts/tweaked-computers/resource-policy-kv-storage-2026-10-23/`.

- Source ZIP: `final/package/tweaked-computers_0.1.13.zip`, SHA-256
  `293c49902d4b15cbe2b8e70d6d86423dc7fbb3f36793576a20f0e268e20538de`.
- Policy test ZIP: `final/policy/tweaked-computers_0.1.13.zip`, SHA-256
  `8c6c448b4a6064b9b3add617a48207699650b238ac3bcb553cd6c4216ab86ddc`.
  The only changed payload is the documented test-entry redirect.
- `receipt.json` verifies 180 current script/test/control/settings payloads
  against the packaged source, all eight fixture/mode cases and all 24 native
  process exits. Both cold phases of every case passed with acknowledged
  `/quit`, no SIGINT/forced kill, and no owned engine processes remaining.
- `final/policy/smoke/summary.json`: `kv_policy_engine`, six on-init contract
  groups per mode, plus native clone/mining/cold/replacement markers.
- `final/kv_engine/summary.json`: unchanged guest/example/default contracts
  (apart from the required work-driven reclamation expectation), 11 groups per
  mode, both cold phases passed.
- `final/resource_policy_results-final/summary.json`: five groups per mode,
  including real sandbox result refusal before every KV mutator; cold passed.
- `final/lifecycle_engine-final/summary.json`: nine groups per mode in the
  production context, native lifecycle and cold passed.

The latter three gates used the source ZIP, `tools/smoke.py --mode both --cold`
and respectively `--fixture tests.kv_engine`,
`--fixture tests.resource_policy_results`, and
`--fixture tests.lifecycle_engine --production-context`, under the same lock
and engine as the command above. Exact native commands, logs, saves and per-phase
cleanup receipts are retained in each case directory. Receipt prose was added
after packaging; production/test payloads were not changed afterward.

Failed attempts remain separate: `failed-owning-mod-context/` and its log show
the companion-mod settings rejection; `failed-zipinfo-crc.log` records an initial
runner bug (fixed by copying ZipInfo before writing the redirected payload).
A combined foreground command reached the tool deadline after the policy and
legacy KV matrices completed. No owned processes remained; the other two
fixtures were rerun as separately tracked jobs to successful completion.

## Outstanding shared-core acceptance

This is not completion of all of OpenSpec tasks 10.1/10.3:

1. KV command preparation and snapshot/browser traversal are still synchronous.
   Durable `guard.job`/`guard.suspend` integration must meter/save each preparation
   cursor and revalidate database identity/current tick before publication. The
   existing pre-effect `prepare_result` path remains in place and is tested;
   this is not a claim of resumable large-command preparation.
2. Shared-host retained ownership and temporary peaks are not connected here.
   The baseline memory ledger is per-runtime, and this lane does not invent a
   second ledger or report fictional host usage. Foundation integration must
   own the live database, candidate/index/field copies, detached inspection,
   import/export copies and native item tags; admit the preparation peak before
   allocating/publishing, release scratch on refusal/cancellation, and transfer
   existing ownership without treating grandfathered material as new growth.
   Existing and candidate database records share immutable values/field maps;
   a hash mutation copies only the affected field map, plus the database index.
   Mining temporarily retains the old database, its dense snapshot and an
   imported validation copy. Computer snapshots retain a detached state copy
   and state accounting maps in addition to the live source/state.
3. The iterative material Data copier is local because the baseline shared
   `data.copy` still enforces current state/shape ceilings. Consolidate it with
   the foundation's structurally validating, ownership-accounted transport copy
   once that contract exists; do not restore current-setting validation here.
4. No graphical browser/GUI, connected multiplayer, suspended-computer clone,
   or final integrated host-memory pressure gate was run by this lane. Native
   maximum-state tests exercise material storage, not new runtime ownership.

Parent integration owns shared policy metadata, runtime/lifecycle ledgers,
settings/control hooks, generated player documentation and final acceptance.
No shared OpenSpec checkboxes are changed here.
