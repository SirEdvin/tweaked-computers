# Foundation integration checkpoint

This is a tested ownership/host-channel milestone, **not completion of the resource-policy proposal**. No task checkboxes were changed and no compiler prototype integration was attempted.

## Implemented

- `ownership.lua` traverses private `pending.jobs`, encoded `pending.service_args`, prepared result tuples and their carrier, and the complete `frame.library` graph (including job/result). Private graphs preserve guest table/function/symbol/binding edges, reference keys, cycles, aliases and memory-ledger records. Malformed private values refuse before sweeping. Completed/cancelled jobs lose their ledger links on collection/owner retirement.
- Nil values are not enqueued as ownership edges. Extra empty queue records regressed the existing 1,024-credit preparation deadline; the final implementation passes that unchanged fixture.
- `memory.new(limit, control, resource?)` accepts the optional `host_memory` domain. Existing callers retain the runtime-memory default. Capacity diagnostics use the appropriate setting; metadata/link costs and grandfathered shrink semantics still come from the same ledger.
- `resource-policy.host_account(spend)` creates the shared registry account and synchronously enrolls accepted legacy radar channels. Existing data may start over the current ceiling; new empty-account metadata must fit normally. Enrollment is paid before publication and never runs in `on_load`.
- `guard.host_resize('radar-channels:'..record.id, bytes)` is installed by real `computer.services`. It supports the radio contract's zero or `128+32*channel_count` estimate; doubled payload estimates plus the retained alias cover table-slot overhead, and the ledger separately charges its own metadata. It survives calling-computer Stop, releases on registry removal, and reconciles replaced/reset channel tables one registry identity per maintenance slice. It is deliberately not a generic arbitrary-key allocator.
- `resource-policy.limits()` and `computer.getLimits()` return policy-v2 `resources` entries from the parent-owned setting definitions. Tuning entries are explicitly separated under `tuning` with `kind='tuning'`. Old raw limit fields are absent.
- `resource-policy.status(rec,tick)` and `computer.getResourceStatus()` return defensive schema projections of measured state/event/console/work counters, persistent loss counters and the last uncaught program resource refusal. Missing accounting is omitted, never reported as fictional zero. Host status reads do not reset work credits.

## Boundaries the integrating parent must retain

1. Ordinary scheduler/program/Console execution still does **not** create and attach production runtime owners. The new VM fixtures use real `context.memory_owner`, not no-op adapters, but they do not establish universal production wiring. Pre-effect private-map metadata/growth admission, temporary peaks and usable error/control reserves on that exact owner remain language/foundation integration work. GC traversal is not retroactive allocation admission.
2. `host_account` currently enrolls **radar channel storage only**, not monitor/configurator/model/compiler/cache domains. Consequently status omits total host/runtime/pending/shell/draft memory counters. First legacy enrollment is synchronous paid work, not a durable migration cursor; very large legacy enrollment under a small slice remains a follow-up.
3. Radio service commits must use the sibling lane's new helper calls. The isolated baseline radio implementation does not call `host_resize`; the new native host test invokes the real service guard through a test provider, not the full radio lane. Re-run integrated radio tests after cherry-picking that lane.
4. Safe non-event pending admission/migration, full per-computer lifecycle accounting, shell refusal persistence, reserved Status/Stop opportunity, and complete resource wait reasons are not finished. Optional `wait` is not fabricated from the last retry tick.
5. `commit_configuration` remains absent. No callback-only wrapper or post-effect result-admission fallback was installed; real readback/recovery peaks must be reserved before native effects.
6. Compiler `a98d4ee` remains quarantined. No emitted saved text or prototype reconstruction was admitted.
7. Reviewed language fixes `cedbc6f2` and `a6b0d877` each pass `git apply --check` against this checkout, but were **not** cherry-picked or included in these native receipts. Their current-job resize and re-entry fixes still need parent integration.
8. Other devices' `getLimits` methods still need routing to policy-v2. Parent-owned `tests/runtime_budget_engine.lua` contains old raw `computer.getLimits().callback_work`/maintenance expectations (lines 216, 218, 250); migrate them to `resources.<key>.limit`. This lane did not edit parent-owned setting fixtures or documentation generators.

## Verified evidence

Final packaged SHA-256: `67ae0b1a829f46d89b601612b5fea42bad1ae547a97ceb58ac8a358515481f33`.
Evidence: `/home/siredvin/artifacts/tweaked-computers/resource-policy-foundation-2026-10-23-VLyK4I/`.

Commands used `/home/siredvin/tools/factorio/bin/x64/factorio` (2.0.77 build 84539) and `flock /home/siredvin/.hermes/profiles/albina/cache/scratch/tc-policy-parallel-QqFKCi/native.lock`:

```sh
python tools/build.py --output "$WORK/package"
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/$FIXTURE" --mode both --fixture "tests.$FIXTURE" --cold
# FIXTURE: resource_policy_host, resource_policy_private_ownership,
#          resource_policy_memory, resource_policy_preparation_cold
python tools/smoke.py --factorio "$HEADLESS" --archive "$ARCHIVE" --output "$WORK/resource_policy_ownership" --mode both --fixture tests.resource_policy_ownership
python tools/test_build.py
```

All listed commands exited zero. Four cold fixtures passed both content modes and both separate-process phases with clean console shutdown; ownership passed both modes; build tests passed 18 tests. No production budget or deadline was increased.

`tests.computer_contract` separately fails at line 217 (`line=13 assertion failed`) after 79 contract markers. The untouched `cea5b10` baseline reproduces the identical failure; full logs and both archive receipts are retained separately. The resolved preparation regression and diagnostic attempts are also retained, not overwritten. Connected multiplayer, client/UI rendering, full radio/configurator integration, and universal memory exhaustion/control recovery are not verified here.
