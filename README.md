# Tweaked Computers — native runtime and physical devices

Development mod for exactly Factorio 2.0.77, with base alone or optional Space Age.
This checkpoint includes the native compiler/sandbox, durable computer API,
registry, shared scheduler, powered independently wired device family and
same-colour peripheral discovery/facades, native single-document editor and the
complete logic-handler controller, persistent string/hash KV databases and merging in-world color monitors. Configurator service bodies and
full data-bearing lifecycle remain subsequent milestones; this is not yet the
integrated public alpha candidate. KV player/robot mining
uses guarded data-bearing snapshots; computer mining remains guarded until its
assigned lifecycle milestone, preventing destructive plain drops.

No interpreter, bytecode compiler, continuation backend, OS, filesystem or dynamic
guest loader is shipped.

Programs return a literal versioned named-handler descriptor. Each callback
receives a fresh closed environment and finishes or faults; only explicit copied
Data state, named registrations and event/timer records survive callbacks.

See docs/peripheral-network.md for the complete discovery API, explicit wire
colours, current-path authority, events and fixed per-type service binding.
examples/peripheral-program.lua ships an executed native inspection program;
localized discovery help keys are ready for the editor/help UI.
See docs/logic-handler.md and docs/program-editor.md for the saved-source controller
workflow, every logic method, quality/int32 rules, sampled events and writer cleanup.
examples/logic-controller.lua supplies the exact editable source used by the
packaged tests.logic_engine cold scenario (add --fixture tests.logic_engine --cold).
The fixture's player/editor delivery is table-backed, not client typing/focus proof.

See docs/kv-database.md for every string/hash/expiry command, exact nil/count/error
semantics, atomic capacity staging, initial limits and data-bearing lifecycle.
examples/kv-program.lua supplies its native callback example; locale/en/kv.cfg
supplies help keys. Select `--fixture tests.kv_engine --cold` to exercise compact
KV contracts plus actual robot mining/replacement and carried-time cold reload.

See docs/monitor.md for complete terminal/palette/scale methods, geometric
grouping without hidden wire bridges, power retention and monitor touch/resize
callbacks. Ctrl + left click activates a character cell with an empty cursor;
the action is rebindable in Controls. examples/monitor-program.lua supplies the
native named-callback example. tests.monitor_engine covers real headless world
draw objects and a cold mid-sweep reload; player activation checks are mocks,
not graphical/client evidence.

See docs/physical-devices.md for footprints, role wiring, initial recipes/power,
physical host integration and the interim mining guard. docs/computer-runtime.md
records the implemented computer API, registry/lifecycle/service integration and
scheduling contract. docs/runtime-foundation.md records the original compiler
ownership, limits, source diagnostics and reproducible checks. The authoritative
capability/API contracts remain in openspec/changes/add-native-circuit-computers.

Build (output must be outside this checkout):

    python3 tools/build.py --output /absolute/path/to/artifacts

Packaged official-engine smoke, with fresh output directories:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.device_engine --cold --upgrade-fixture

The smoke creates maps with base and Space Age and executes focused native
contracts from the ZIP. With --cold it runs two isolated localhost-only headless
server processes per mode, preserving an immutable snapshot and verifying cold
readback. --upgrade-fixture adds one separate base configuration-change process.
It does not launch a graphical client. Client rendering, focus, touch and multiplayer joining are
explicitly deferred to the user after implementation of every specification.

New project source is MIT licensed. Pinned Phobos parser/dependency source is
also MIT; see vendor/phobos/LICENSE.txt, NOTICE.md and manifest.json. No upstream
CC:Tweaked font bytes are included. Selected Greg Flavored MIT device artwork
and an independently authored glyph atlas are included with exact provenance,
notices and reproducible transforms in assets/README.md and assets/manifest.json.
