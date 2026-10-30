# Tweaked Computers — ALPHA

Native circuit computers for Factorio 2.1.23, with base alone or optional Space Age.
The integrated alpha implements native guarded callbacks, a five-tab single-document editor,
same-color peripheral discovery, merging world monitors, string/hash KV storage,
logic I/O, typed factory configuration and data-bearing device lifecycle.
Version 0.1.8 adds a [live single-line Console](docs/player/console.md) with
save-backed scratch bindings, independent of the saved program. No interpreter,
OS, gameplay filesystem or dynamic guest loader is shipped; there is no command history.

Version **0.1.17 ALPHA** adds Dashboards (optional `factorio-charts`), native-only
Factoriopedia/Production Statistics, elapsed Console time and demand-driven monitor
maintenance. **Breaking:** computer items are plain hardware; ordinary pickup and
replacement loses their contents, and legacy item payloads are not imported.
Placed records/active programs/private drafts are not reset. Back up the complete
save and matching mod set first; restore both for rollback, never downgrade in place.
See [0.1.17 release notes](docs/release-0.1.17.md) for all six changes and exact
verification scope. Controlled 2.1.23 base/Space Age client and connected-peer
acceptance is available; software rendering is not a representative GPU benchmark.
Keep 0.1.14 if you remain on Factorio 2.0.77.

Version 0.1.14 exposes complete fresh native circuit signals and native
own-output configuration, without mod-defined signal/filter/output-slot ceilings.
Reads preserve native order and optional identity fields. Ctrl-click opens only
an actual computer body, not draft recovery on empty ground. Authority, fail-safe
ownership and ordinary guest/persistence budgets remain. See
[0.1.14 release notes](docs/release-0.1.14.md) for compatibility and upgrade guidance.

Version 0.1.12 added nonblank pending inspector panels, independent decider-style
logic signal trays and concise UI text. See [historical 0.1.12 notes](docs/release-0.1.12.md).

Version 0.1.11 added [peripheral inspectors](docs/player/inspectors.md),
[radar modems](docs/player/api/modem.md), bounded [vanilla speaker audio](docs/player/api/speaker.md),
[guarded Lua globals](docs/player/api/language.md#printing-raw-helpers-and-error-transformation)
and a reorganized contextual in-game Reference. See [0.1.11 release notes](docs/release-0.1.11.md),
including the narrow reserved-name recovery and destructive Reset Shell warning.
All five feature specifications are finalized and archived on main.

Version 0.1.10 added [plain function programs](docs/player/api/language.md),
the [live maintenance setting](docs/player/api/limits.md#maintenance-and-shared-headroom),
independent fault diagnostics and the selected [Service Rack six-device artwork](docs/player/artwork.md),
including both research icons. The maintenance default stays **200000**;
the benchmark's provisional 300000 recommendation is not adopted.
See [historical 0.1.10 release notes](docs/release-0.1.10.md).

Version 0.1.9 added the separately researched
[Recipe Searcher](docs/player/api/recipe-searcher.md): a powered 1×1 read-only
item/fluid recipe catalogue peripheral, with complete sorted metadata and an
explicit 50-result ceiling after category filtering. It also adds recipe circuit
signals, monitor stacks of 50, readable Console tabs and native Ctrl-click
preservation. Logic calls now require explicit red or green, not the old both
selector. See [0.1.9 release notes](docs/release-0.1.9.md) and the original
[feature verification](docs/recipe-searcher-validation.md).

- [Player guide and complete Lua reference](https://siredvin.github.io/tweaked-computers/).
- [Guide source](docs/player/index.md) and [factory tutorial](docs/player/factory.md).
- [Public source](https://github.com/SirEdvin/tweaked-computers) and [issues](https://github.com/SirEdvin/tweaked-computers/issues).
- [Documentation build and deployment](docs/documentation-maintenance.md).

This is a user-test alpha, not stable or universally client-verified. Back up saves.
Service Rack artwork and live monitor charts have isolated base/Space Age graphical
checks with software rendering. Console input/workflows have native-client checks
in both modes and actual base two-client late-join/cold-server acceptance.
Recipe Searcher appearance and Ctrl-click transfers/modifier reuse/monitor touch
have native checks in both modes; recipe queries also have actual base two-client
late-join/cold-server checks. The five-feature campaign adds native inspector/Reference,
radar and independently recorded speaker audio checks, plus actual two-client fresh/cold
cases in base and Space Age. These finite receipts do not certify every platform,
wire topology, third-party mod or simultaneous maximum-world workload. Full-world
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
The release source is [alpha-0.1.17](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.17);
[0.1.1 release notes](docs/alpha-release.md) remain historical.

## Development

Validation runs locally, not in GitHub CI. Follow the [local checks](docs/documentation-maintenance.md#required-local-validation);
documentation publishing and optional OpenWiki updates remain automated.

Use the [granular scheduling benchmarks](docs/scheduling-benchmarks.md) before
changing device scheduling: isolated idle/active cases, separate timing/profile/
structural lanes, and a portable Markdown report with exact-archive evidence.

The finalized radar integration provides [locally wired native radar modems](docs/player/api/modem.md)
and an optional Space Age interplanetary tier. Native hidden radio links do not
grant discovery authority; the seven-method API has bounded channel datagrams.
This ships in 0.1.11, without changing immutable 0.1.10.
The finalized speaker integration exposes the unmodified vanilla
programmable speaker as a [physically wired speaker peripheral](docs/player/api/speaker.md).
Its six methods provide installed catalogues and bounded, synchronous positional
notes/effects. It adds no replacement entity, playback queue or completion event;
native circuits, settings, mining results and GUI remain vanilla.

Build an installable archive outside the checkout:

    python3 tools/build.py --output /absolute/path/to/artifacts

Use a fresh output directory for the packaged official-engine integration smoke:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.15.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.integration_engine --production-context --cold

The harness exercises base and Space Age; cold phases use isolated localhost-only
servers and acknowledged console shutdown. It never launches a graphical client.
Current source/API contracts live in `openspec/specs/` and `openspec/api/`.
All eleven completed changes retain their planning history under
`openspec/changes/archive/2026-10-{19,20,21}-*/`. All five new feature contracts and
their complete API companions are canonical and packaged without active-change dependencies.
The monitor buffering companion documents automatic snapshots, every
1..6-by-1..6 rectangle and optional selected-group publication.
[Consolidated acceptance](docs/sc4-final-acceptance.md) binds automated native,
connected-peer and packaged-engine receipts to verified production bytes.
This remains alpha: finite llvmpipe observations are not hardware FPS, universal
real-time guarantees or user manual/aesthetic approval.

Project source is [MIT licensed](LICENSE). Pinned Phobos parser source retains
[its license](vendor/phobos/LICENSE.txt), [notice](vendor/phobos/NOTICE.md) and
manifest. Selected Greg Flavored MIT artwork retains its notices; the glyph atlas
is independently authored, not an imported CC:Tweaked font. See assets/README.md
and assets/manifest.json for provenance and reproducible transforms.
