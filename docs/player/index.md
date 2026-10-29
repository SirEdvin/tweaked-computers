# Tweaked Computers

Build a programmable factory controller: read circuit signals, control an
inserter, keep shared telemetry and draw a touchable status screen.

Tweaked Computers runs bounded native Lua callbacks, not a computer OS. Each
computer has one source document and explicit persistent state. The separate
[live Console](console.md) evaluates bounded Lua lines with shared saved scratch
bindings. There are no OS commands, files, imports, background threads or direct
Factorio objects, and no command history.

## Start here

**0.1.18 ALPHA** accepts all **Factorio 2.1** patches, base alone or optional Space
Age. It only relaxes version dependencies; runtime code and save behavior are
unchanged from 0.1.17. Verification remains on 2.1.23, not every 2.1 patch.

0.1.17 added [Dashboards](dashboard.md) with optional `factorio-charts`, native-only
[Factoriopedia catalogues](api/factoriopedia-interface.md) and
[Production Statistics](api/production-statistics.md), elapsed [Console](console.md)
time and demand-driven [monitor maintenance](monitor-animation.md).
**Breaking:** computer items are plain hardware; ordinary pickup/replacement loses
their contents, with no legacy item import. Placed computers and private drafts are
not reset. [Back up the complete save and matching mods before upgrading](lifecycle.md#compatibility-break-and-rollback);
restore both for rollback. Keep 0.1.14 if you remain on Factorio 2.0.77.

Controlled 2.1.23 base/Space Age native-client and connected-peer cases cover the
new features, cold resume and retained data. They do not certify arbitrary mod
packs or GPU performance. Historical results below retain their original scope.

Version 0.1.14 exposes complete fresh [native circuit signals](api/logic.md)
without mod-defined signal/filter/output-slot ceilings. Reads retain native order
and optional identity fields. Ctrl-click opens only a selected computer body;
empty ground is inert and draft recovery remains in Maintenance. Independent
[signal trays](inspectors.md), validation, authority, fail-safe ownership and
ordinary guest/persistence budgets remain.

Version 0.1.11 added [peripheral inspectors](inspectors.md),
[radar modems](api/modem.md), [vanilla speaker audio](api/speaker.md),
[guarded Lua globals](api/language.md#printing-raw-helpers-and-error-transformation)
and a complete contextual in-game Reference. Plain function programs, legacy
descriptors, the live maintenance setting and Service Rack artwork remain.
The maintenance default stays 200000; no production safety ceiling is raised.

1. [Install the alpha and craft the devices](getting-started.md).
2. [Control your first inserter](first-controller.md) with a computer and logic handler.
3. [Use the editor safely](editor.md): Save is not Run, and Stop is not Reset State.
   [Inspect peripherals directly](inspectors.md) to copy names and read local state.
4. [Build the combined factory controller](factory.md), adding configuration,
   expiring database telemetry and a merged touchable monitor.
5. Look up [Lua types, errors and limits](api/common.md), then choose a complete
   reference: [computer](api/computer.md), [peripheral discovery](api/peripheral.md),
   [monitor](api/monitor.md), [database](api/kv.md), [logic](api/logic.md),
   [configurator](api/configurator.md), [Recipe Searcher](api/recipe-searcher.md),
   [radar modem](api/modem.md), [programmable speaker](api/speaker.md)
   and [supported settings](api/settings.md).

[Runnable programs](examples.md) are ready to copy as whole documents. The
[moving and recovery guide](lifecycle.md) explains what mining, destruction,
blueprints and cloning preserve.

This release adds locally wired native radar modems and,
with Space Age, a separately named interplanetary tier. The [modem guide](api/modem.md)
includes complete paired sender/receiver programs and exact bounds. Historical
0.1.10 remains immutable and does not contain these new features.
The release also adds [vanilla speaker attachment](api/speaker.md)
for bounded positional notes, sound effects and paginated sound discovery, with
native GUI/circuit configuration preserved. See its maintained alarm/melody/catalogue programs.

## Alpha warning

Back up your save before installation, upgrades or manual recovery. The supported
verification target is Factorio 2.1.23, base alone or with optional Space Age.
Expansion-only prototypes/settings are available only when the engine provides
them. Newer engine versions and third-party prototype combinations are not claimed
verified by this guide.

The implementation has packaged headless native-runtime, factory-effect and
cold-save checks. The following client results are historical **2.0.77** evidence:
Service Rack artwork and live charts have isolated software-rendered
base/Space Age captures. The Console has native input/size/workflow acceptance in
both modes and actual base two-client late joining plus cold server resume.
Recipe Searcher appearance and Ctrl-click transfers/held-modifier reuse/monitor
touch have native checks in both modes; recipe queries also have base two-client
late-join/cold-server checks. The new campaign also has real inspector/Reference
workflows, independently captured speaker PCM and actual two-client fresh/cold
radar/speaker/inspector cases in base and Space Age. Representative cases do not
cover every wire topology, platform, mixer configuration or IME.
The declaration starter also has real native editor input checks in both modes.
Historical connected-peer receipts retain their original source/scope; this
release does not claim exhaustive multiplayer compatibility or independent
client-storage equality from server-authored peer receipts.
These captures are not GPU benchmarks.
Resource ceilings are provisional safety limits, not a promise of real-time latency
or simultaneous maximum-world performance. Report failures with the mod/engine
versions, wiring, source and error code; remove private literals before sharing.

## Source and developer documentation

The [0.1.12 ALPHA source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.12) includes
source, notices and examples; report problems in its
[issue tracker](https://github.com/SirEdvin/tweaked-computers/issues).
The separately generated
[developer OpenWiki](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.12/openwiki)
explains implementation internals; this site, not that wiki, is the player and
public Lua API reference. This link identifies the source-grounded developer
wiki snapshot independently of the repository's default branch. Generated wiki
pages can lag source changes; source/tests and this guide remain authoritative.

Project source, the original industrial device family and the independently
authored character atlas are MIT licensed. Approved historical Greg Flavored
inputs and their complete MIT notices remain in the source/package; the new
family does not sample them. No original CC:Tweaked font or complete
CraftOS/Computer Core/Redis compatibility is implied.

Version 0.1.10 adopts the selected Service Rack six-device family, with matching
item and research icons. See the [artwork guide](artwork.md) and
[identification guide](getting-started.md#research-and-craft). Published 0.1.9
remains immutable; the new artwork does not change device geometry or certify
hardware performance.
