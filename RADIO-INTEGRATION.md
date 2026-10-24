# Radio integration contract

Work in progress, not acceptance.

- Providers opt into existing `with_guard=true`; every method receives guard after spend.
- `guard.job(name, initial)` / `guard.suspend()` use the coordination contract. Private plan state contains only plain data and stable record/run/generation/subscription identities, never records/native objects.
- Required shared host helper exposed through the service guard: `guard.host_resize(key, bytes)`: atomically admit/resize a retained host owner to the explicit estimated byte footprint before mutation, retaining accounting until resize to zero or lifecycle cleanup. Radar channel state owner key is `radar-channels:<record.id>`. Closing releases entry bytes, closeAll and radar removal/reset release owner. Existing legacy channel state must be enrolled before growth. Memory pressure is recoverable E_CAPACITY, never erase accepted channels. The common memory ledger must back this helper (not an independent count budget).
- Job ownership must include the entire prepared payload/route/event graph throughout preparation, publication, and cold resume. Provider uses `guard.job_resize(bytes)` before retained growth (explicit conservative byte footprint, including route/event overhead, no count ceiling). This is the single current job owner, automatically released by private-call completion/cancellation. Baseline lacks this shared helper; integrated acceptance depends on it.
- `speaker_sound_page_size` is read from effective runtime limits; prototype metadata uses fixed internal chunks, not a catalogue ceiling or runtime page-size constraint.
- Final native checks must run against the integrated shared core; explicit test doubles for guard jobs prove service state-machine semantics, not shared runtime persistence/admission.

## Shared integration still required

- This branch deliberately does **not** provide a production fallback when `host_resize`, `job_resize`, or `job` is missing. The baseline production modem fixture fails at `guard.host_resize`; do not ship the lane alone.
- `guard.host_resize` must enroll existing radar channel sets, preserve over-limit shrink/read, and release their owner on removal or force/surface reset. The channel estimate is 128 bytes plus 32 bytes per live channel; empty-set base storage belongs to the registry record.
- Broadcast retained estimates include the payload's Data bytes, stable-ID vector, current per-computer route/subscription workspace and every prepared independent event. Current workspace bytes are released after that computer's events are prepared; the plan and payload live until private-call completion/cancellation. Common Data/event/discovery preparation must account **temporary copy/inventory peaks before materialization**, not only transfer the resulting graph into job ownership afterward. The helpers must account normal ledger metadata and any actual graph footprint beyond these estimates.
- `receiver_plan`, Data copies, complete registry-ID sorting and instrument/note metadata blocks still use shared synchronous primitives. The parent must integrate their existing work-resume/atomic-resource behavior; this lane does not prove arbitrarily large preparation fits a production slice. No new count cap was introduced to conceal that dependency.
- The shared peripheral dispatcher must revalidate authority on every resumed call (invalidate callback-local caches). It must cancel an accepted broadcast's remaining suffix without replay if sender lookup fails before provider re-entry. Provider itself reproves sender and receiver authority immediately before each event.
- Parent-owned settings, policy-v2 introspection, Reference/UI text, CI smoke production-fixture allowlist, lifecycle/migration ownership, and final spec reconciliation remain integration work. The new native fixture is `tests.radio_policy_engine` with data fixture `tests.radio_policy_data` and final data fixture `tests.speaker_data_final`; it currently runs in an isolated test mod, not the production VM.
- An approval timeout blocked the attempted migration of obsolete assertions/direct-call signatures in `tests/speaker_engine.lua` and `tests/speaker_client_engine.lua`; those files remain unchanged and need authorized follow-up. `tests/speaker_admission.lua`, catalogue/data tests, modem and radar direct-call fixtures were updated separately.
- Connected multiplayer, actual-client audibility, full competition/controller gates and integrated VM job cold-load/cancellation are **not** proven by the service/guard-double matrix.

## Verified lane evidence

Evidence bundle: `/home/siredvin/artifacts/tweaked-computers/resource-policy-radio-2026-10-23-qwi0uQ/`.
Final archive SHA-256: `918a6968f8f498a80eb542b8310c64da55e2d1d0e1d3b6d93c56522c48185a1d`.
All 17 changed packaged files were compared byte-for-byte with that archive; this integration note is not packaged.

Commands used the exact 2.0.77 headless executable and the shared `native.lock`:

```sh
python tools/build.py --output "$WORK/package"
python tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio --archive "$ARCHIVE" --output "$WORK/radio" --fixture tests.radio_policy_engine --data-fixture tests.radio_policy_data --final-data-fixture tests.speaker_data_final --mode both --cold
python tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio --archive "$ARCHIVE" --output "$WORK/speaker-admission" --fixture tests.speaker_admission --mode both
python tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio --archive "$ARCHIVE" --output "$WORK/radar" --fixture tests.radar_engine --data-fixture tests.radar_data --production-context --mode both --cold --upgrade-fixture
python tools/test_build.py
```

All commands above exited zero. Radio: five contract groups in each mode, two clean separate-process cold phases each. Speaker admission: four groups each mode. Radar: six groups each mode, two cold phases and a configuration-change phase each. Every native phase exited normally with no forced cleanup. Build tests: 18 passed.

Radio fixture includes 132 open safe-integer channels with recoverable memory refusal/shrink, twelve deliveries, payload beyond 4096 bytes, more than sixteen sends, receiver queue drop counts, wire/force changes during preparation, sender detach after a four-delivery prefix, cold resume without duplicate sequence/effect submission, complete 32770-path synthetic catalogue traversal, configurable 7/73-path pages, and native 65-instrument/129-note/long-name prototypes. Guard doubles use the real memory ledger but do not prove production ownership integration.

The production `tests.modem_engine` dependency check exited 1 on the preceding archive `78b0a3cff1a60dd6f021c2aac8eb7093c64fd62aecb71b084c24fc8137fadcfc`: `attempt to call field 'host_resize' (a nil value)`. Full logs are retained under `milestone-extended/modem-shared-dependency/`. The initial require-at-runtime fixture failure and all intermediate passes are retained separately. No task checkbox, merge, release or push was performed.
