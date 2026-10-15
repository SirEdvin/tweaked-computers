# Tweaked Computers

Build a programmable factory controller: read circuit signals, control an
inserter, keep shared telemetry and draw a touchable status screen.

Tweaked Computers runs bounded native Lua callbacks, not a computer OS. Each
computer has one source document and explicit persistent state. There are no
shell commands, files, imports, background threads or direct Factorio objects.

## Start here

1. [Install the alpha and craft the devices](getting-started.md).
2. [Control your first inserter](first-controller.md) with a computer and logic handler.
3. [Use the editor safely](editor.md): Save is not Run, and Stop is not Reset State.
4. [Build the combined factory controller](factory.md), adding configuration,
   expiring database telemetry and a merged touchable monitor.
5. Look up [Lua types, errors and limits](api/common.md), then choose a complete
   reference: [computer](api/computer.md), [peripheral discovery](api/peripheral.md),
   [monitor](api/monitor.md), [database](api/kv.md), [logic](api/logic.md),
   [configurator](api/configurator.md) and [supported settings](api/settings.md).

[Runnable programs](examples.md) are ready to copy as whole documents. The
[moving and recovery guide](lifecycle.md) explains what mining, destruction,
blueprints and cloning preserve.

## Alpha warning

Back up your save before installation, upgrades or manual recovery. The supported
verification target is Factorio 2.0.77, base alone or with optional Space Age.
Expansion-only prototypes/settings are available only when the engine provides
them. Newer engine versions and third-party prototype combinations are not claimed
verified by this guide.

The implementation has packaged headless native-runtime, factory-effect and
cold-save checks. Graphical typing/paste/focus, wire selection and artwork
alignment, zoom/monitor readability and touch delivery, audible speaker playback
and multiplayer client joining remain user testing, not agent-verified features.
Resource ceilings are provisional safety limits, not a promise of real-time latency
or simultaneous maximum-world performance. Report failures with the mod/engine
versions, wiring, source and error code; remove private literals before sharing.

## Source and developer documentation

The [0.1.2 ALPHA source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2) includes
source, notices and examples; report problems in its
[issue tracker](https://github.com/SirEdvin/tweaked-computers/issues).
The separately generated
[developer OpenWiki](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2/openwiki)
explains implementation internals; this site, not that wiki, is the player and
public Lua API reference. This link identifies the source-grounded developer
wiki snapshot independently of the repository's default branch.

Project source, the original industrial device family and the independently
authored character atlas are MIT licensed. Approved historical Greg Flavored
inputs and their complete MIT notices remain in the source/package; the new
family does not sample them. No original CC:Tweaked font or complete
CraftOS/Computer Core/Redis compatibility is implied.
