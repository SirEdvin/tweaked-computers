# Tweaked Computers — ALPHA

Native circuit computers for Factorio 2.0.77, with base alone or optional Space Age.
The integrated alpha implements native guarded callbacks, a five-tab single-document editor,
same-color peripheral discovery, merging world monitors, string/hash KV storage,
logic I/O, typed factory configuration and data-bearing device lifecycle.
Version 0.1.8 adds a [live single-line Console](docs/player/console.md) with
save-backed scratch bindings, independent of the saved program. No interpreter,
OS, gameplay filesystem or dynamic guest loader is shipped; there is no command history.

- [Player guide and complete Lua reference](https://siredvin.github.io/tweaked-computers/).
- [Guide source](docs/player/index.md) and [factory tutorial](docs/player/factory.md).
- [Public source](https://github.com/SirEdvin/tweaked-computers) and [issues](https://github.com/SirEdvin/tweaked-computers/issues).
- [Documentation build and deployment](docs/documentation-maintenance.md).

This is a user-test alpha, not stable or universally client-verified. Back up saves.
Foundry artwork and live monitor charts have isolated base/Space Age graphical
checks with software rendering. Console input/workflows have native-client checks
in both modes and actual base two-client late-join/cold-server acceptance.
Space Age connected joining, native wire selection/touch and audible playback
remain unverified. Full-world
performance limits are provisional; software rendering is not a GPU benchmark.
Install from the [Factorio Mod Portal](https://mods.factorio.com/mod/tweaked-computers)
and follow the guide above. Report problems with engine/mod versions, wiring,
source and diagnostics; remove private literals before sharing.

The source includes a separate [developer OpenWiki](openwiki/quickstart.md).
See the [0.1.5 monitor buffering evidence](docs/monitor-buffer-verification.md),
[0.1.4 interaction hotfix notes](docs/interaction-release.md),
[integrated verification](docs/rd5-candidate.md) and
[native-client playtest](docs/player/editor.md#integrated-redesign-playtest).
Version 0.1.6 adds [live Map budgets](docs/player/api/limits.md#live-mod-settings),
fivefold default allowances and [dirty-cell animation](docs/player/monitor-animation.md).
Version 0.1.7 adopts the selected Foundry artwork, connected-subpixel chart and
independent background/glyph reuse without raising budgets or changing the API.
The [monitor performance investigation](docs/monitor-performance.md) records the
earlier workload separately; current matched results accompany the release.
Version 0.1.8 retains those monitor/live-budget features and adds bounded Console
commands with live effects, shared save-backed values and confirmed reset, but no
retained user functions or command history. See the [release notes](docs/console-shell-release.md).
The release source is [alpha-0.1.8](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.8);
[0.1.1 release notes](docs/alpha-release.md) remain historical.

## Development

Build an installable archive outside the checkout:

    python3 tools/build.py --output /absolute/path/to/artifacts

Use a fresh output directory for the packaged official-engine integration smoke:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.8.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.integration_engine --production-context --cold

The harness exercises base and Space Age; cold phases use isolated localhost-only
servers and acknowledged console shutdown. It never launches a graphical client.
The source/API contracts remain in openspec/changes/add-native-circuit-computers;
that change is deliberately unarchived pending review and user client testing.
The shipped `buffer-monitor-presentation` API extension documents automatic
snapshots, every 1..6-by-1..6 rectangle and optional selected-group publication.
Broader graphical validation remains part of the user's alpha review;
Console native/multiplayer evidence does not certify every device interaction.

Project source is [MIT licensed](LICENSE). Pinned Phobos parser source retains
[its license](vendor/phobos/LICENSE.txt), [notice](vendor/phobos/NOTICE.md) and
manifest. Selected Greg Flavored MIT artwork retains its notices; the glyph atlas
is independently authored, not an imported CC:Tweaked font. See assets/README.md
and assets/manifest.json for provenance and reproducible transforms.
