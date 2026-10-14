# Tweaked Computers — ALPHA, in development

Native circuit computers for Factorio 2.0.77, with base alone or optional Space Age.
This public bootstrap contains the native compiler/sandbox foundation, not playable
computer entities or the complete mod. Planned features include an in-game editor,
same-color discovery, logic handlers, KV databases, monitors and typed configurators.
No interpreter, OS or gameplay filesystem is shipped.

- [Player documentation](https://siredvin.github.io/tweaked-computers/) — currently an honest scaffold, not a complete guide.
- [Source](https://github.com/SirEdvin/tweaked-computers) and [issues](https://github.com/SirEdvin/tweaked-computers/issues).
- [Compiler/service foundation](docs/runtime-foundation.md).
- [Capability and API contracts](openspec/changes/add-native-circuit-computers/README.md).
- [Documentation maintenance and deployment](docs/documentation-maintenance.md).

No Factorio Mod Portal release is published at this checkpoint. Client editing,
focus, touch, rendering, rotation and multiplayer joining have not been verified
by agents; user client testing follows full implementation. Back up saves before
trying future alpha releases. Do not mistake planned contracts for shipped behavior.

## Development

Build (output must be outside this checkout):

    python3 tools/build.py --output /absolute/path/to/artifacts

Packaged official-engine smoke, with fresh output directories:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.0.zip \
      --output /absolute/path/to/new-smoke-directory

The smoke creates maps with base and Space Age and runs focused native adversarial
contracts from the ZIP. It does not launch a graphical client or bind a server.

New project source is [MIT licensed](LICENSE). Pinned Phobos parser/dependency
source is also MIT; see [its license](vendor/phobos/LICENSE.txt),
[notice](vendor/phobos/NOTICE.md) and [manifest](vendor/phobos/manifest.json).
No upstream artwork is included in this bootstrap; later artwork integration must
retain its own notices and independent glyph provenance.
