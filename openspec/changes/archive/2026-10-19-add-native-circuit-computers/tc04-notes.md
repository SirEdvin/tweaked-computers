# TC04 implementation/evidence handoff

Owned task entries: 1.4, 6.4. Capability slice: physical device-lifecycle,
not the later comprehensive snapshots/clone/ghost lifecycle milestone.

Parent `9db72dbbf92246ff5cdc9f01f620c80b4ac86fcd` was merged with ordinary git merge;
ancestry was verified before editing. No primary checkout or sibling worktree
was changed. No remote/publication/deployment or OpenSpec archive was performed.

Implemented: all five powered body/item/recipe prototypes; real independently
owned role endpoints; cardinal footprints and collision/selection transforms;
registry-backed staged build, duplicate-build idempotence, exact removal and
rollback/refund; same native endpoint/wire identities during rotation; critical
power/integrity loss before deferred restoration; current-power dispatch gate;
initial balance/progression, researched-force configuration unlocks and concise
host/player documentation in `docs/physical-devices.md`.

Safety integration guard: registered computer/KV bodies remain non-minable until
the downstream data-bearing snapshot implementation replaces
`mining_guard='awaiting-data-bearing-snapshots'`. Do not remove this guard alone.
This preserves the full final mining contract without exposing a destructive
plain drop during intermediate development. Explicit destruction remains loss.

## Exact checks run

- Lua 5.2.4 luac syntax check on all new Lua, control and changed scheduler: pass.
- Reference Lua 5.2.4 `tests.device_contract.run()`: six geometry/tuning groups.
- Reference `tests.computer_contract.run()`: all 44 parent regression groups pass
  after the narrow scheduler dispatch guard; no unverified native GUI claim.
- `python3 tools/build.py --output $TMPDIR/tc04-artifacts-integrated`: deterministic
  40-file ZIP, pinned parser inventory/hashes validated.
- `python3 tools/smoke.py --factorio /home/siredvin/tools/factorio/bin/x64/factorio
  --archive $TMPDIR/tc04-artifacts-integrated/tweaked-computers_0.1.0.zip
  --output $TMPDIR/tc04-smoke-integrated --fixture tests.device_engine --cold
  --upgrade-fixture`: official exact 2.0.77, base and Space Age map creation pass
  12 distinct counted contract groups each. Both modes exercise native factory
  crafting, real-wired independent role signals/mirrored bank, actual one-tick
  electrical consumption/outage/zero-output/restoration and a malicious native
  source beside a healthy computer. The two ordinary cold phases per mode and
  one additional base configuration-change phase all exit 0 via acknowledged
  console quit, with no SIGINT or forced kill.
- Cold on_load readback retains exact body/port/run/source/state/power/ledger
  identity. Native wire readback remains correct; startup does not replay.
  Configuration changes reapply already-researched unlocks, ordinary loads do not.
- Production ZIP SHA-256:
  `25831bcc42335a2447b2463f534ed46f7005e5df7dd300cf421d2aa33833ee97`.

Evidence outside git:
`/home/siredvin/.hermes/profiles/albina/cache/scratch/tc04-smoke-integrated/summary.json`
and its per-mode command/log/result JSON files;
`tc04-artifacts-integrated/tweaked-computers_0.1.0.zip`,
`tc04-parent-regression.log`, `tc04-geometry.log` in that same scratch parent.

The headless fixture uses shipped host handlers/modules and actual native bodies,
ports, factories, electrical grids and source runtime in isolated fixture storage.
It is not a client player/robot placement test. Allocation refusal is explicitly
injected through a host-only proxy; its first child and refund cargo are native.
No mock event payload is represented as actual native client event delivery.

Earlier failing checks are retained at `tc04-smoke-first`, `-second`, `-third`.
The first found the pinned technology is `advanced-circuit`, not the obsolete
`advanced-electronics` spelling. The second exposed the fixture's assumption that
both new computers must restore/dispatch on the same tick; it now waits for the
actual shared scheduler without changing budgets. The third found `/quit` saves
over its input map, invalidating reuse of the snapshot for the separate upgrade.
The shared harness now runs resumed phases from copies, preserving the immutable
original snapshot. `tc04-smoke-fourth` passed the corrected base checks; only the
later integrated ZIP above is the final artifact evidence.

## Downstream integration

Use `scripts.device-definitions` and `scripts.lifecycle.connector` plus exact
`registry.by_entity` bindings; do not infer authority from native network IDs.
Only NETWORK children are discovery vertices. Other roles remain separate.
Physical records carry the documented version/orientation/power/guard fields.
The logic worker must coordinate physical `clear_output` with its own
writer-generation metadata/cleanup hooks. Monitor/KV/configurator services must
respect current power and preserve their own outage state. The native body EEI
settings GUI is disabled; the editor worker needs its own native interaction
entry or an intercepted/guarded native open path.

Final cleared artwork is intentionally not merged from the independent artwork
card here. Temporary icon art is clearly labelled. Comprehensive mining snapshots,
clones/ghosts/blueprint/source disclosure and recovery remain assigned downstream.
Initial power/recipe values are reviewable tuning, not a measured optimum or frozen
production capacity/latency promise. All native client visuals, clickability,
editor/touch/focus and joining-peer verification remain user-deferred; no graphical
client/screenshot/multiplayer-join automation ran. Mixed checkbox 1.4 stays open;
6.4's implemented/headless balance and progression entry is checked.
