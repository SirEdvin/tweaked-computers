# TC12 — integrated device lifecycle

Owned OpenSpec rows: 6.1 and 6.2. Implementation complete; mixed client acceptance 6.1 remains unchecked. No client/screenshots/multiplayer joining was attempted.

## Ancestry and integration

Ordinary merges retain all four direct feature commits:

- logic: 5a98f6cf801b5c62f8d7efac018dc8ed9ff383df
- KV: 289a0f2d5c249ad2469d101969d7d611b36dd071
- monitor: dc8b60d5b824653c8833cca28cb8dc64b2dd4a7f
- full configurator: f1b8d7e8c9ca815d0e2d75b83ceea19f74d54d5e

Every direct SHA was checked with git merge-base --is-ancestor. Shared registration merges preserve editor, network inspector, all four peripheral services, custom inputs and both editor/monitor data-stage registrations. Source snapshots and monitor items use the fixed host-only adapter introduced by KV, not a guest management API.

## Delivered behavior

See docs/device-lifecycle.md for the full player policy and formats. Computer items retain independently saved and formerly active source, state and label while dropping all execution work. Replacements and clones never auto-run. Recover Active Source provides an explicit reviewed draft-copy path. Settings-copy revisions advance monotonically and destination application state is not silently destroyed. Monitor items carry applicable settings rather than stale group images. KV audit refuses corrupt indexed state without removing its data or running reclamation.

Native blueprints use real helper ghosts and native connector wire tuples, not guessed signal-network IDs. Hidden uncraftable role tokens make these ghosts valid without charging extra logical items. The body revives them before create_entity can delete their ghost wires. Tokens, body family, scope and exact expected role position constrain adoption. Area-cloned helpers are matched and adopted/retired under bounded maintenance. Existing role wires survive body rotation.

Destructive/force/surface cleanup is host-only and source-independent; it does not compile an affected program. The compact fixture destroys an authentic output writer after poisoning its source header and checks the bank clears. Cross-surface evidence uses actual cloning because pinned machine entities cannot be surface-teleported. Native force merge and surface deletion are asynchronous and the fixture awaits the engine transitions.

## Evidence and limits

The base candidate run at scratch/tc12-candidate-lifecycle passes seven grouped initialization contracts plus native on_tick full-family/area cloning, rotated blueprint/revival wires, force/surface transitions, malformed-source output cleanup, actual construction-robot maximum computer mining, and separate-process ordinary/configuration reload. Both source documents reach 16384 bytes and explicit state reaches its 65536-unit allowance. Snapshot aliases, KV absolute deadlines, monitor identity/model, drafts and spent counters remain unchanged before resumed work. All candidate cold processes acknowledged /quit and exited zero without signals/forced kills.

Final exact-ZIP evidence is stored outside git at scratch/tc12-final-lifecycle/summary.json and scratch/tc12-final-regressions/summary.json; the structured card handoff records the verified final archive hash and results. Commands use tools/build.py and the existing tools/smoke.py. The native lifecycle command adds --fixture tests.lifecycle_engine --production-context --cold --upgrade-fixture. Affected parent contracts are batched without graphical testing or unrelated exhaustive matrices.

The fixed opt-in production-context fixture is required for truthful native ownership checks: separately requiring lifecycle modules in tc-smoke while production handles the same events creates two competing registries/helpers. Earlier failed checkpoints preserve this harness diagnosis and the prior fixture arithmetic/geometry/asynchronous-event mistakes. They are not passing evidence. No production budgets, content quotas or fixture deadlines were raised to pass.

Player/editor delivery in these checks uses explicitly table-backed contracts; no native typing/focus claim is made. Explicit fixture stepping is structural semantics evidence, not a mixed-world latency measurement. Production limits remain provisional. Ordinary gameplay has no on_load handler, no guest loader, interpreter or dynamic remote API. TC13 remains responsible for consolidated factory examples, actual remaining device artwork integration and the final publication candidate; later cards own public docs/OpenWiki/alpha publication. OpenSpec is unarchived and no partial release or PR merge is authorized here.
