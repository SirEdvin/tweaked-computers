# Tweaked Computers — ALPHA

Native circuit computers for Factorio 2.0.77, with base alone or optional Space Age.
The integrated alpha implements native guarded callbacks, a single-document editor,
same-color peripheral discovery, merging world monitors, string/hash KV storage,
logic I/O, typed factory configuration and data-bearing device lifecycle.
No interpreter, OS, shell, gameplay filesystem or dynamic guest loader is shipped.

- [Player guide and complete Lua reference](https://siredvin.github.io/tweaked-computers/).
- [Guide source](docs/player/index.md) and [factory tutorial](docs/player/factory.md).
- [Public source](https://github.com/SirEdvin/tweaked-computers) and [issues](https://github.com/SirEdvin/tweaked-computers/issues).
- [Documentation build and deployment](docs/documentation-maintenance.md).

This is a user-test alpha, not stable or client-verified. Back up saves. Graphical
editing/focus, wire selection, rendering/touch, audible playback and multiplayer
joining remain user-owned checks. Full-world performance limits are provisional.
The documentation branch does not itself publish a Mod Portal release or deploy
the completed site; the final consolidated delivery performs those steps.

## Development

Build an installable archive outside the checkout:

    python3 tools/build.py --output /absolute/path/to/artifacts

Use a fresh output directory for the packaged official-engine integration smoke:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.integration_engine --production-context --cold

The harness exercises base and Space Age; cold phases use isolated localhost-only
servers and acknowledged console shutdown. It never launches a graphical client.
The source/API contracts remain in openspec/changes/add-native-circuit-computers;
that change is deliberately unarchived pending review and user client testing.

Project source is [MIT licensed](LICENSE). Pinned Phobos parser source retains
[its license](vendor/phobos/LICENSE.txt), [notice](vendor/phobos/NOTICE.md) and
manifest. Selected Greg Flavored MIT artwork retains its notices; the glyph atlas
is independently authored, not an imported CC:Tweaked font. See assets/README.md
and assets/manifest.json for provenance and reproducible transforms.
