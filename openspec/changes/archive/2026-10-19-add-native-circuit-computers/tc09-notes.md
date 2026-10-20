# TC09 — merging world monitors

Scope: OpenSpec 4.1–4.4 / monitor-display. This is a feature implementation
checkpoint, not the campaign's public alpha publication or integrated factory
milestone. Pre-created TC12 (`t_9bbe7825`) consumes this branch and owns integrated
lifecycle policy; 4.5 and the complete publication candidate remain their existing
cards. Client testing is explicitly user-deferred. No interpreter/OS/filesystem,
GUI substitute, publication, PR merge or OpenSpec archive was introduced.

## Ancestry and ownership

Ordinarily merged and verified:

- network: `3e987008fe15f5989f42135eb23fadfa39911567`
- artwork: `c9c4e64eff6fe4d039811b33ec1df78828dbf314`

The artwork merge's tasks.md conflict retained both parent owners' checklist
updates. This card updates only 4.1–4.4; 4.4's mixed graphical checkbox remains
open with implementation complete/client verification deferred. The requested
selected Greg Flavored MIT assets and independent byte atlas are unchanged;
source/output/licensing hashes and notices survive the deterministic build.

Primary modules: `scripts/monitor-model.lua`, `scripts/services/monitor.lua`,
`scripts/rendering.lua`, `prototypes/monitor.lua`, plus concise API/help/example
and `tests/monitor_engine.lua`. Logical names are fresh `tc-monitor-<sequence>`
identities, separate from physical tile record IDs. Only the retained anchor can
keep a name; absorbed/removed names never alias unrelated displays.

## Implementation

- Complete deterministic world-coordinate rectangle partitions, force/surface/
  orientation compatibility, geometric split/merge/rotation and inherited models.
  Bounded plain staged jobs publish complete groups atomically; admission refusal
  preserves cursors and explicitly refuses pending discovery instead of exposing
  a partial logical inventory. Successive retired draw generations cannot pile up.
- Physical per-tile discovery reuses the parent resolver; groups add no edges,
  including between differently colored or unwired members. Calls have fresh
  physical proofs and all-member power/ownership/geometry checks.
- Every terminal API/Colour alias, palette overload/default, exact return arity,
  0.5–5 half-step scales, safe offscreen cursors, clipped literal byte writes,
  all-before-mutation blit validation, positive/negative/large scroll and resize
  clearing. Current cursor/blink/settings persist through geometry changes.
- Independently authored 256-byte sprites, dirty real world rectangles/glyphs,
  palette recoloring, rotated cell geometry and native cursor blink. Stored color
  indices remain separate from palette values. A sweep is current only when its
  starting revision still matches the latest model at completion.
- All-member power blank/restoration retains contents/settings, with live refusal
  before any active method. Render objects and exact sweep state persist; invalid
  native objects are tolerated during removal/surface loss cleanup.
- Rebindable world activation consumes the matching game action. Production input
  rejects GUI hover/opened focus, held items, borders/letterboxing/outside, foreign
  force/surface and out-of-reach members. Run-bound bounded notifications freshly
  prove red/green authority and send one event per computer subscription, not path,
  color or tile. Queued resize snapshots coalesce; a paid fixed scheduler refresh
  also normalizes dimensions immediately before callback execution, covering an
  intervening writer in the same tick.
- Monitor state version 1 is inert/readable if unsupported. All executable helpers
  are parsing-time imports/hooks, never persisted functions or on_load execution.

Development limits remain provisional: 4×4/group, 4704 cells/group, 256 admitted
physical tiles, 80000 aggregate cell ceiling, 16384 write/color-string bytes,
64 pending activations, 1024 render-cell checks/tick. The queried 256-tick latency
is a development target, not measured graphical/mixed-maximum acceptance.

## Focused executed evidence

Commands reuse `tools/build.py`, `tools/smoke.py` and `assets/check.py`, with every
output under external `$TMPDIR/tc09-*` directories, not the repository.

Final tested archive:

- `$TMPDIR/tc09-delivery/tweaked-computers_0.1.0.zip`
- SHA-256 `10c576174646b24d3b27d6604fb034b0478b06b0ea0c4c973297561e13ff6c12`
- 247 exact runtime/resource/docs/example/test files.

Executed with official `/home/siredvin/tools/factorio/bin/x64/factorio`, whose
version is checked as exactly 2.0.77 by the harness:

    python3 tools/build.py --output "$TMPDIR/tc09-delivery"
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive "$TMPDIR/tc09-delivery/tweaked-computers_0.1.0.zip" \
      --output "$TMPDIR/tc09-delivery-smoke" --fixture tests.monitor_engine --cold
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive "$TMPDIR/tc09-delivery/tweaked-computers_0.1.0.zip" \
      --output "$TMPDIR/tc09-delivery-network" --mode base --fixture tests.network_engine
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive "$TMPDIR/tc09-delivery/tweaked-computers_0.1.0.zip" \
      --output "$TMPDIR/tc09-delivery-computer" --mode base --fixture tests.computer_contract
    python3 assets/check.py --output "$TMPDIR/tc09-asset-check"

Results: monitor 10 counted groups in base and 10 in Space Age; four clean cold
server phases total. Each phase exited 0 with acknowledged console `/quit`, no
SIGINT fallback and no forced kill. Network 12 and computer/sandbox 45 affected
base regression groups pass. Harness verifies each reported group's unique count;
77 total grouped executions and four cold phases are programmatically aggregated.

Cold fixture saves a real admitted one-cell partial render sweep with exhausted
maintenance, real-tick per-machine/shared spent counters, model/render identities,
cells, palette, source/run/anchor/entity identities, and an intentionally stale
resize event. A separate process proves unchanged on_load state, paid refresh at
actual native dispatch, completed latest presentation and once-only startup.
The fixture's controlled remaining-maintenance setup is structural evidence,
not a production latency benchmark. Maximum 4×4 and all 256 native sprite slots
run in the headless engine; the packaged example's real start handler runs through
the native compiler/service boundary. No client-typed editor claim is made.

Assets: byte-exact regeneration, 32 inputs, 146 PNG outputs, 256 glyph slots,
95 ASCII/32 mosaic masks, output/decoded-alpha hashes, dimensions and ZIP notices
pass unchanged. Initial failure was a fixture missing complete active-source
headers before subscription registration; corrected without relaxing production
validation. Initial/intermediate logs and archives remain outside git.

## Integration hotspots and remaining checks

- `control.lua`: preserve the trusted monitor import/custom-input registration
  alongside sibling editor/lifecycle/logic bindings; import all during parsing.
- `data.lua`: keep the monitor sprite/custom-input registration after devices.
- `scripts/services/peripheral.lua`: fixed `available(group,spend)` checks all
  monitor members. Resolver maps physical tiles to logical records only, never
  graph neighbors. Output cleanup now pays the actual complete registry walk and
  actual owner count, preserving pre-admitted fail-closed cleanup; its focused
  proof-refusal regression uses the matching exact admission threshold.
- `scripts/lifecycle.lua`: monitor admission preflights 256 tiles before component
  publication. Power-loss walk remains fully pre-admitted using actual root order.
- `scripts/scheduler.lua`: reserve 60000 presentation work INSIDE the existing
  200000 maintenance / 1000000 total envelope. Never add an independent budget,
  reset tick credits or replace other service phases. Fixed monitor resize refresh
  reserves eight existing execution work units before touching queued dimensions.
- Monitor grouping runs after critical power/authority revocation and before the
  ordinary physical sweep. Its retained jobs may defer fairly under pressure.
  TC12 must merge these hooks rather than install another scheduler or resolver.
- Graphical layering/contrast/zoom/normal-client legibility, true player activation
  delivery/GUI focus, multi-player interactions/join and full mixed-maximum latency
  are not verified here. Activation-player objects are explicit table mocks;
  no graphical client, screenshots or UI automation ran. Keep these alpha warnings
  and the user's deferred verification policy; they are not implementation blockers.
- TC12 owns the remaining full lifecycle/blueprint/clone/configuration matrix;
  TC13 owns the combined resource candidate; TC15/TC16/TC17 own final public docs,
  developer wiki and actual alpha publication. Existing lanes are not duplicated.
