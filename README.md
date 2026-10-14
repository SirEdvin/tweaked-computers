# Tweaked Computers — native foundation

Development mod for exactly Factorio 2.0.77, with base alone or optional Space Age.
This checkpoint establishes the native compiler and sandbox, not playable computer
entities or the completed computer API. No interpreter, bytecode compiler,
continuation backend, OS, filesystem or dynamic guest loader is shipped.

Programs return a literal versioned named-handler descriptor. Each callback
receives a fresh closed environment and finishes or faults; explicit durable
computer state and scheduling are implemented in the next milestone.

See docs/runtime-foundation.md for compiler/service entry points, resource
ownership, limits, source diagnostics and reproducible checks. The authoritative
capability/API contracts remain in openspec/changes/add-native-circuit-computers.

Build (output must be outside this checkout):

    python3 tools/build.py --output /absolute/path/to/artifacts

Packaged official-engine smoke, with fresh output directories:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/path/to/new-smoke-directory

The smoke creates maps with base and Space Age and executes the same focused
native adversarial contracts from the ZIP. It does not launch a graphical client
or bind a server. Client rendering, focus, touch and multiplayer joining are
explicitly deferred to the user after implementation of every specification.

New project source is MIT licensed. Pinned Phobos parser/dependency source is
also MIT; see vendor/phobos/LICENSE.txt, NOTICE.md and manifest.json. No upstream
artwork is included in this foundation.
