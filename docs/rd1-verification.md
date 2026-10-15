# RD1 physical interaction verification

Target: Factorio 2.0.77, base-only and Space Age. This is the physical-wiring
milestone, not the completed art/editor/monitor-layer redesign or a public release.
The package keeps its development baseline version until the release owner bumps
it. Do not replace the published 0.1.1 ZIP or install this over a valuable save.

## Focused, reproducible checks

Build once outside the checkout, then use the same immutable ZIP for all checks:

    python3 tools/build.py --output /outside/repo/rd1-artifact
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd1-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/fresh-physical --fixture tests.redesign_engine \
      --data-fixture tests.redesign_data --production-context --cold
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd1-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/fresh-network --fixture tests.network_engine --cold
    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd1-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/fresh-lifecycle --fixture tests.lifecycle_engine \
      --production-context --cold --upgrade-fixture
    python3 tools/rd1_upgrade.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd1-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/fresh-alpha-upgrade

Optional narrow author-save-run factory regression (native entities; GUI/player
input uses explicitly table-backed doubles, not native client interaction):

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /outside/repo/rd1-artifact/tweaked-computers_0.1.1.zip \
      --output /outside/repo/fresh-factory --fixture tests.integration_engine \
      --production-context --cold

Every output directory must be fresh. Each contains commands, full engine logs,
JSON results, immutable snapshots and exact archive/save hashes. Cold phases run
localhost-only servers, request console quit, wait/reap and reject forced cleanup.
The final handoff records the tested artifact hash and result-directory paths;
this document does not embed its own archive hash recursively.

Coverage:

- Physical: all five devices in all cardinal directions, installed contact data,
  private power drain, native mark/cancel state, direct red/green computer-monitor
  discovery, passive signal continuity, input/output isolation and outage cleanup.
- Safety: partial native-part allocation rollback; a later failed wire handoff
  removes only tentative wires; original identity/parts survive conversion refusal.
- Network: same-color paths, cross-color/vanilla/ghost/foreign-force/surface/role
  refusal, unchanged graph caps, facade authority, captured stale calls and cold
  topology/ledger continuity. Tiny fixture bindings are not full service evidence.
- Lifecycle: saved/active sources and maximum state, item validation, all-family
  rotation/cloning, real rotated blueprint revival, exact area helper ownership,
  native construction robot one-item mining, force/surface cleanup, cold readback.
- Upgrade: genuine alpha gameplay source at
  `cb300e62ebad6a4a9a38a0679f21e251009f1d16`, instrumented only with an opt-in
  fixture/allowlist. A populated running save is frozen, ordinarily reloaded,
  then opened by the exact candidate in a different process. A test-mod version
  change invokes the candidate's real configuration handler without modifying
  candidate bytes. State/KV/hash/deadline/screen/run/output/queue/timer/draft aliases,
  native removal marking, role/color/unsupported wires and logical IDs survive.
  Missing-part and deliberately oversized native-output fixtures exercise refusal
  before and after staging. Old rotated blueprints and old material item tags are
  then used on the new layout without duplicating state or replaying startup.

## RD2 handoff

Use `scripts/device-definitions.lua`'s `contact`, `offset`, `transform`, `points`
and `pad_box` directly for artwork/export/contact sheets. Monitor contacts are
at north y=−0.48 tile within the existing bezel; other studs are y=−0.1. Role
x positions are left-to-right centers, with red/green studs ±0.07 tile. Network
is a connector on the visible shell, even for the offset configurator Network
bay; it is not a separately selectable pad. Do not add a second geometry map or
change physical endpoints merely to fit an illustration.

## Short native-client review (user-owned, not yet performed)

1. With red and green wire tools, hover/connect the visible computer, KV and
   monitor. Confirm the device's name, direct attachment and bezel contacts;
   no anonymous NETWORK tile or native combinator dialog should appear.
2. Rotate each device through four directions. Check socket/art alignment; logic
   Input/Network/Output and configurator Network/Factory targets stay distinct.
3. Open a selected computer with normal open and Ctrl+Shift+E. Confirm the existing
   editor is reachable; check normal mining/deconstruction over the main footprint
   and exactly one logical item, without selectable private power or orphan sockets.
4. On a backed-up 0.1.1 world upgraded to the eventual version-bumped candidate,
   inspect existing wire paths and data. Reopen the editor; retained drafts remain
   available. Conversion is not a reboot or permission to lose application state.

Headless prototype metadata and native mark state do not prove hover readability,
mouse selection, focus, visible wire/art alignment or the monitor's red X. RD2
owns final sprites and RD4 owns monitor layering; those are not passed by RD1.
