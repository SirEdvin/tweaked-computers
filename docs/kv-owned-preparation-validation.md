# Owned KV preparation checkpoint

This is a scoped integration checkpoint, not completion of transport ownership or
OpenSpec 10.1/10.3. The older `kv-storage-policy-validation.md` receipts remain
historical; no shared task checkboxes or runtime/UI files were changed here.

## Implemented

- KV commands retain paid argument/validation, index-copy, hash-copy/edit/count,
  byte-comparison merge-sort, publication-count and ownership cursors in real
  `guard.job` state. `hgetall`, `exists` and `getLimits` retain read traversal.
  No coroutine, saved iterator closure or restart of completed copy/sort phases.
  The byte comparator saves its decision before the separately paid append.
- Before re-entry/publication, device identity/generation, database revision,
  relevant expiry and the ten effective KV settings must still agree. A change
  returns `E_BUSY` without publishing the old candidate. Positive EXPIRE uses
  the eventual publication tick, not the initial preparation tick. Provider
  reachability/power validation remains the peripheral dispatcher's authority.
- `kv-memory.lua` obtains the actual `resource-policy.host_account(spend)` and
  creates separate KV lifecycle/preparation owners on that same account. It
  does not reuse the radar owner or create a second host ledger. Live tables,
  index roots, immutable entry/field maps and strings use the existing memory
  module's object/link accounting. Candidate ownership links share immutable
  records; only changed hashes and database indices are copied.
- A conservative host reservation precedes command candidate allocation. Exact
  candidate graph links are acquired incrementally before result preparation
  and publication. Result refusal closes the candidate owner. Publication
  transfers that owner to the live database; superseded owners retain their
  objects until paid retirement closes them. Stop/device cleanup cancels pending
  owners; maintenance also detects removed devices/changed computer runs.
- Structurally valid legacy/restored databases are adopted as existing host debt,
  without applying current KV or host growth ceilings to the carried contents.
  This adoption uses the existing private-graph admission helper. New command
  peaks still require actual headroom; debt does not grant new allocation.
- Monitor material settings accept non-half-step positive finite scales, call
  the model size helper, reject unsafe integer dimensions/native coordinate
  extents and preserve the existing cell envelope. The coordinate-domain check
  uses Factorio 2.0.77's signed 24.8 MapPosition representation. Complete tile
  and group candidates are validated before either existing settings/model is
  replaced. Rejected paste leaves settings, palette, cells and group identity
  untouched. No monitor-lane source file was edited.

## Dedicated native fixture

`tests.kv_owned_engine` uses the real sandbox, work ledger, runtime memory owner,
shared host account and native KV entities. It does **not** substitute a fake
job implementation, no-op ownership adapter or independent host ledger.

It checks one-credit sorting (including empty/NUL/high-byte keys and long common
prefixes), owned read traversals, shared immutable records, host-peak refusal,
pre-effect result refusal and reservation release, generation replacement,
expiry during preparation, grandfathered imports, explicit `guard.suspend`
inside index copying, unchanged cold state and exactly-once result/effect replay.
Monitor cases cover native item tags, fractional scales, group-capacity refusal
atomicity and native sprite scale readback, including a coordinate-domain edge.
Sprite creation/readback is not graphical/GPU validation.

Reproduce with the packaged ZIP and the shared native lock:

```sh
flock /home/siredvin/.hermes/profiles/albina/cache/scratch/tc-policy-parallel-QqFKCi/native.lock \
  python tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio \
  --archive "$ARCHIVE" --output "$WORK/owned" \
  --fixture tests.kv_owned_engine --mode both --cold
```

## Executed receipts

Preserved bundle:
`/home/siredvin/artifacts/tweaked-computers/resource-policy-kv-owned-2026-10-23/`.

- Final source ZIP: `final/package/tweaked-computers_0.1.13.zip`, SHA-256
  `89011145b52215c3dcf9a501d4f8a252afe1d2900c1a6826827817e6130703d7`.
- Policy redirect ZIP: `final/policy/tweaked-computers_0.1.13.zip`, SHA-256
  `c25794647afdaec929067e04b84599ce8fe2c728ef3dda57f4a585d20764db15`.
  Its only changed payload is the existing allowlisted test entry; the runner
  verifies every other payload is byte-identical.
- `final/receipt.json` verifies 191 current script/test/control/settings payloads
  against the source archive, eight passing fixture/mode cases and all 24
  passing native process exits. Every cold process acknowledged `/quit`; none
  required SIGINT/forced kill. No owned engine process remained.
- `final/owned/summary.json`: seven initialization groups per mode, plus the
  cold explicit-suspend/unchanged-owner-state/exactly-once completion marker.
- `final/policy/smoke/summary.json`: six groups per mode; unchanged ten-setting,
  above-old-limit, maximum-state native mining/replacement and cold contracts.
- `final/results/summary.json`: five groups per mode; unchanged real sandbox
  pre-effect result-refusal gates and cold phases.
- `final/lifecycle/summary.json`: nine groups per mode in production context;
  native material lifecycle and both cold phases passed.
- `final/dispatch-gap.log` retains the exact failing unchanged `tests.kv_engine`
  gate: nine Base initialization groups passed, then line 217 failed for the
  missing real runtime memory owner. Space Age/cold dispatch phases were not
  reached. This failure is not included in the passing totals. The earlier
  discovery archive/log is retained separately in `initial-dispatch-failure/`.

The source ZIP was built after all code/test changes. Only this receipt prose
was added afterward. Commands, snapshots, logs, archive hashes and per-process
cleanup reports are retained in the bundle; no budgets or deadlines were raised.

## Still required before integrated acceptance

1. **Public durable dispatch is not connected.** The unchanged `tests.kv_engine`
   runtime-activation path reaches `private service job growth requires a memory
   owner`. The service deliberately uses the current-job resize API that rejects
   this missing owner rather than silently claiming ownership. The owned-guard
   fixture proves service preparation, not production VM/compiler integration.
2. **Cancellation before provider entry needs a foundation hook.** If a suspended
   call is rejected by peripheral authority lookup before KV is invoked, the KV
   wrapper cannot close its owner immediately. Run/device cleanup eventually
   closes it, but a caught revocation while the same run continues needs the
   finalized/cancelled-call lifecycle hook to call `kv-memory.cancel(owner_id)`.
   Do not enable production ownership without this edge.
3. **Transport ownership is not complete.** Detached inspector snapshots,
   snapshot/import validation copies, computer material Data/accounting maps,
   export copies and actual native item tags have no end-to-end ownership lease
   here. The lifecycle adapter API supplies snapshot/restore but no native-tag
   publication/transfer/retirement acknowledgement. Releasing at snapshot return
   would undercount retained tags; retaining forever would leak. This lane adds
   neither fiction. Existing native mining/replacement remains data-preserving,
   but is not proof of host-memory admission for those copies.
4. **Host traversal is not universally resumable.** Initial legacy graph adoption,
   ownership reconciliation after reclamation and browser/material snapshot/
   import/export traversal remain synchronous. Very large legacy adoption can
   still exceed a tiny maintenance slice. Cancellation currently closes its
   candidate synchronously; incremental cancellation needs shared lifecycle
   retirement authority. The resumable claim applies to command preparation.
5. **Monitor integration still needs the shared model contract.** The lifecycle
   native-coordinate preflight must be consolidated with the monitor lane's
   positive-finite geometry helper and its new ownership replacement hook. This
   checkout deliberately does not edit that lane. The old public scale setter
   in this baseline still has its old half-step restriction. No graphical
   extreme-scale, connected multiplayer or final total-host-pressure gate ran.
6. The parent owns consolidation of the local material Data copier with the
   shared structurally validating transport copy. Do not reapply current state
   growth limits to accepted material items or restore the old transport cap.
   Also verify KV-only legacy bootstrap below the shared account's metadata
   floor: the current foundation bootstrap explicitly adopts radar inventory,
   while this lane's tested one-byte-limit import starts with an existing host
   account. That test is not proof of first-account creation in a legacy save.
