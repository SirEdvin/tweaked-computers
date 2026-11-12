# Tweaked Computers — ALPHA

This mod supplies native circuit computers for Factorio 2.1, with base alone or optional Space Age.
The current source has trusted native callbacks, a five-tab single-document editor,
same-color peripheral discovery and merging world monitors.
It also has string/hash KV storage, logic I/O, typed factory configuration and a data-bearing device lifecycle.
Version 0.1.8 adds a [live single-line Console](docs/player/console.md) with
save-backed scratch bindings, independent of the saved program. The mod has no interpreter,
OS, gameplay filesystem or dynamic guest loader. There is no command history.

Version **0.1.24 ALPHA** gives the devices new art. Each device copies the look of a CC:Tweaked or
addon peripheral, with worn and lightly rusted paint. Wires attach to antenna rings. No API, limit
or save format changes. See [0.1.24 release notes](docs/release-0.1.24.md) and the
[artwork guide](docs/player/artwork.md).

Version **0.1.23 ALPHA** decreases host work for callbacks. A run validates its source one time,
also when more than eight different programs run. A `computer` call no longer makes the next
peripheral call search the wire network again. No API, limit or save format changes.
See [0.1.23 release notes](docs/release-0.1.23.md).

Version **0.1.22 ALPHA** adds a monitor [graphics mode](docs/player/api/monitor.md) with retained
lines, shapes, text, game icons and lights in monitor pixels. Terminal rows now draw as text in a
mod-supplied font, which needs far fewer native objects. Monitor and guarded-call host work is lower.
Saves from 0.1.21 upgrade automatically. See [0.1.22 release notes](docs/release-0.1.22.md).

Version **0.1.21 ALPHA** runs saved programs and Console as trusted native Lua.
It removes mod execution and temporary-memory quotas, and it reduces idle and per-callback host overhead.
Run only trusted code. An infinite loop can stop the game. Temporary values can use all available memory.
Stop cannot interrupt code that does not return control to the host.
Source validation, current API authority, host-work admission, and retained-data limits remain.
See [runtime upgrade and rollback](docs/player/lifecycle.md#upgrading-to-trusted-native-lua) and [0.1.21 release notes](docs/release-0.1.21.md).

Version **0.1.20 ALPHA** includes a separate [public Lua declaration library](api/README.md)
as the authoritative API reference. The website and searchable in-game Reference
are generated from the same complete types, overloads, errors and examples.
That documentation release did not change guest behavior, save formats, or budgets from 0.1.19. Verification used
Factorio **2.1.23**, base and Space Age. The mod accepts other 2.1 patches, but verification does not cover each patch. See [0.1.20 release notes](docs/release-0.1.20.md).

Version **0.1.19 ALPHA** introduced function-declaration-only saved programs and
demand-driven scheduling. All nine custom device families now work without
electricity. Native radars and speakers still need their normal supply.
**Breaking:** Rewrite legacy table-form saved source manually. There is no
automatic conversion. Source and accepted data remain recoverable.
Benchmarks are incomplete. Performance and scaling are unverified. The user waived
benchmark completion for 0.1.19, not correctness or safety checks. That performance
limitation remains in 0.1.20.
It keeps 0.1.18's acceptance of all Factorio 2.1 patches. Verification remains
on 2.1.23, not every patch. See [0.1.19 release notes](docs/release-0.1.19.md).

Version **0.1.17 ALPHA** adds Dashboards (optional `factorio-charts`), native-only
Factoriopedia/Production Statistics, elapsed Console time and demand-driven monitor
maintenance. **Breaking:** Computer items are plain hardware. Ordinary pickup and
replacement loses their contents. The mod does not import legacy item payloads.
Placed records, active programs and private drafts are not reset. Back up the complete
save and matching mod set first. For rollback, restore both. Never downgrade in place.
See [0.1.17 release notes](docs/release-0.1.17.md) for all six changes and exact
verification scope. Controlled 2.1.23 base/Space Age client and connected-peer
acceptance is available. Software rendering is not a representative GPU benchmark.
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
and independent fault diagnostics. It also added the selected [Service Rack six-device artwork](docs/player/artwork.md),
including both research icons. The maintenance default stays **200000**.
The mod does not adopt the benchmark's provisional 300000 recommendation.
See [historical 0.1.10 release notes](docs/release-0.1.10.md).

Version 0.1.9 added the separately researched
[Recipe Searcher](docs/player/api/recipe-searcher.md). This 1×1 read-only peripheral supplies an
item/fluid recipe catalogue. It now operates without electricity. It has complete sorted metadata and an
explicit 50-result ceiling after category filtering. Version 0.1.9 also adds recipe circuit
signals, monitor stacks of 50, readable Console tabs and native Ctrl-click
preservation. Logic calls now require explicit red or green, not the old both
selector. See [0.1.9 release notes](docs/release-0.1.9.md) and the original
[feature verification](docs/recipe-searcher-validation.md).

- [Player guide and complete Lua reference](https://siredvin.github.io/tweaked-computers/).
- [Guide source](docs/player/index.md) and [factory tutorial](docs/player/factory.md).
- [Public source](https://github.com/SirEdvin/tweaked-computers) and [issues](https://github.com/SirEdvin/tweaked-computers/issues).
- [Documentation build and deployment](docs/documentation-maintenance.md).

This alpha is for user tests. It is not stable, and client verification does not cover every environment. Back up saves.
Service Rack artwork and live monitor charts have isolated base/Space Age graphical
checks with software rendering. Console input/workflows have native-client checks
in both modes and actual base two-client late-join/cold-server acceptance.
Recipe Searcher appearance and Ctrl-click transfers/modifier reuse/monitor touch
have native checks in both modes. Recipe queries also have actual base two-client
late-join/cold-server checks. The five-feature campaign adds native inspector/Reference,
radar and independently recorded speaker audio checks, plus actual two-client fresh/cold
cases in base and Space Age. These finite receipts do not certify every platform,
wire topology, third-party mod or simultaneous maximum-world workload. Full-world
performance limits are provisional. Software rendering is not a GPU benchmark.
Install from the [Factorio Mod Portal](https://mods.factorio.com/mod/tweaked-computers)
and follow the guide above. Report problems with engine/mod versions, wiring,
source and diagnostics. Remove private literals before you share a report.

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
earlier workload separately. The matched benchmark campaign for 0.1.19 is incomplete.
Version 0.1.8 keeps those monitor/live-budget features. It adds bounded Console
commands with live effects, shared save-backed values and confirmed reset. There are no
retained user functions or command history. See the [release notes](docs/console-shell-release.md).
The release source is [alpha-0.1.20](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.20).
[0.1.1 release notes](docs/alpha-release.md) remain historical.

## Development

Validation runs locally, not in GitHub CI. Follow the [local checks](docs/documentation-maintenance.md#required-local-validation).
Documentation publishing and optional OpenWiki updates remain automated.

Before you change device scheduling, use the [granular scheduling benchmarks](docs/scheduling-benchmarks.md).
These include isolated idle and active cases, separate timing, profile and structural lanes, and a portable Markdown report with exact-archive evidence.

The finalized radar integration provides [locally wired native radar modems](docs/player/api/modem.md)
and an optional Space Age interplanetary tier. Native hidden radio links do not
grant discovery authority. The seven-method API has bounded channel datagrams.
Version 0.1.11 includes this integration. The immutable 0.1.10 release stays unchanged.
The finalized speaker integration exposes the unmodified vanilla
programmable speaker as a [physically wired speaker peripheral](docs/player/api/speaker.md).
Its six methods provide installed catalogues and bounded, synchronous positional
notes/effects. It adds no replacement entity, playback queue or completion event.
Native circuits, settings, mining results and GUI remain vanilla.

Build an installable archive outside the checkout:

    python3 tools/build.py --output /absolute/path/to/artifacts

Use a fresh output directory for the packaged official-engine integration smoke:

    python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
      --archive /absolute/path/to/artifacts/tweaked-computers_0.1.19.zip \
      --output /absolute/path/to/new-smoke-directory \
      --fixture tests.integration_engine --production-context --cold

The harness exercises base and Space Age. Cold phases use isolated localhost-only
servers and acknowledged console shutdown. It never starts a graphical client.
Behavioral requirements are in `openspec/specs/`. The authoritative public API
is the separate [Lua declaration library](api/README.md). Both the website and
offline in-game Reference are generated from that library.
All eleven completed changes retain their planning history under
`openspec/changes/archive/2026-10-{19,20,21}-*/`. All five new feature contracts and
their complete typed API definitions are canonical. The package does not depend on active changes.
The [monitor declaration](api/monitor.d.lua) documents automatic snapshots, every
1..6-by-1..6 rectangle and optional selected-group publication.
[Consolidated acceptance](docs/sc4-final-acceptance.md) binds automated native,
connected-peer and packaged-engine receipts to verified production bytes.
This remains alpha. Finite llvmpipe observations do not establish hardware FPS, universal
real-time guarantees or user approval of the manual or appearance.

Project source is [MIT licensed](LICENSE). Pinned Phobos parser source retains
[its license](vendor/phobos/LICENSE.txt), [notice](vendor/phobos/NOTICE.md) and
manifest. Selected Greg Flavored MIT artwork keeps its notices. The glyph atlas
is independently authored, not an imported CC:Tweaked font. See assets/README.md
and assets/manifest.json for provenance and reproducible transforms.
