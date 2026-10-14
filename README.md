# Tweaked Computers — native computer runtime

Development mod for exactly Factorio 2.0.77, with base alone or optional Space Age.
This checkpoint includes the native compiler/sandbox, durable computer API,
registry and shared scheduler. Physical devices, editor and peripheral services
are delivered by subsequent cards; this is not yet a playable mod. No interpreter, bytecode compiler,
continuation backend, OS, filesystem or dynamic guest loader is shipped.

Programs return a literal versioned named-handler descriptor. Each callback
receives a fresh closed environment and finishes or faults; only explicit copied
Data state, named registrations and event/timer records survive callbacks.

See docs/computer-runtime.md for the implemented API, registry/lifecycle/service
integration and scheduling contract. docs/runtime-foundation.md records the original compiler
ownership, limits, source diagnostics and reproducible checks. The authoritative
capability/API contracts remain in openspec/changes/add-native-circuit-computers.

Build (output must be outside this checkout):

    python3 tools/build.py --output /absolute/path/to/artifacts

Packaged official-engine smoke, with fresh output directories:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.computer_cold --cold

The smoke creates maps with base and Space Age and executes focused native
contracts from the ZIP. With --cold it runs two isolated localhost-only headless
server processes per mode, preserving a snapshot and verifying reconstruction.
It does not launch a graphical client. Client rendering, focus, touch and multiplayer joining are
explicitly deferred to the user after implementation of every specification.

New project source is MIT licensed. Pinned Phobos parser/dependency source is
also MIT; see vendor/phobos/LICENSE.txt, NOTICE.md and manifest.json. No upstream
artwork is included in this foundation.
