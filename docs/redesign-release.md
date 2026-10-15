# Tweaked Computers 0.1.2 — ALPHA

The complete device-experience redesign for **Factorio 2.0.77**, base alone or
optional Space Age. Back up the save and old mod ZIP before upgrading from 0.1.1.
This remains a user-test alpha, not stable or native-client verified.

## Changes from 0.1.1

- Wire computers, databases and monitors directly on their visible device bodies.
  Logic keeps separate Input / Network / Output roles; configurators keep Network
  and Factory targets isolated. Private power carriers are not extra wire targets.
- Five original industrial silhouettes, with all cardinal sprites, shadows,
  inventory icons, status frames and socket-aligned artwork: operator console,
  storage cabinet, flat monitor, three-bay logic instrument and two-bay configurator.
- A code-first workspace with Editor, Console, Peripherals, Reference and
  Maintenance tabs, reversible focus mode, compact actions and recovery controls.
  Draft, saved and active revisions remain distinct; Save does not Run or Apply.
- Monitor content uses explicit sprite layers below native world feedback.
  Mark/cancel preserves content, cursor, palette and grouping; ongoing updates and
  actual robot removal retain the existing lifecycle policies.
- Staged upgrade from 0.1.1 preserves device data and native role wires, including
  older blueprint ghosts/items. Unsafe conversion retains recoverable state rather
  than silently dropping data. Existing same-color authority checks remain intact.
- The integrated source also retains the reviewed runtime table.sort capacity fix.

Public Lua API v1, guarded named callbacks, state/events/timers, monitor services,
KV storage, logic and typed configurator support remain unchanged. No interpreter,
OS, shell, filesystem, dynamic guest loader or direct Factorio-object access is added.

## Install and learn

Install **0.1.2** from the existing
[Factorio Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers), or use
`tweaked-computers_0.1.2.zip` from the matching
[GitHub alpha prerelease](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.2).
Do not use GitHub's automatic source archive as a mod ZIP. Load a backed-up test
world first and retain its previous mod configuration.

The [player guide](https://siredvin.github.io/tweaked-computers/),
[installation/wiring instructions](https://siredvin.github.io/tweaked-computers/getting-started/)
and [complete Lua reference](https://siredvin.github.io/tweaked-computers/api/common/)
cover the actual devices and controls. Immutable
[release source](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2) and
[source-grounded developer OpenWiki](https://github.com/SirEdvin/tweaked-computers/tree/alpha-0.1.2/openwiki)
are separate from the player site. The default branch and implementation PR are
not merged by this release; OpenSpec remains unarchived.

## Focused verification and honest limits

The [integrated verification record](rd5-candidate.md) defines the focused base /
Space Age packaged checks: physical wiring/role authority, factory author-save-run,
tabbed GUI model, draft/cold persistence, monitor render-state/removal, art and
sandbox contracts. The release repeats these against the final versioned ZIP and
runs the populated pinned-0.1.1 cold-upgrade fixture. Only the baseline's opt-in
fixture is instrumented; final candidate bytes are not rewritten. Checksums and
per-case logs belong in external release evidence, avoiding recursive self-hashes.

The old published 0.1.1 archive and its checksums remain immutable. Release assets
include the tested 0.1.2 archive and its SHA-1/SHA-256 checksums. The portal's
version, filename, compatibility and SHA-1 must match those exact bytes, and the
GitHub asset is downloaded again for SHA-256 comparison.

Native graphical GUI construction/layout, typing/paste/caret/clipboard/focus/scroll,
world hover/wire/art readability, genuine red-X visibility, touch delivery, audible
playback and multiplayer joining remain unperformed/user-owned. GUI/model fixtures
and headless sprite properties are not native-client acceptance. Use the short
[integrated playtest checklist](player/editor.md#integrated-redesign-playtest).
No broad client, stress or multiplayer matrix was added as a publication gate.
Resource ceilings remain provisional, not real-time or maximum-world guarantees;
newer engines and arbitrary third-party prototype combinations are unverified.

Report problems in the [issue tracker](https://github.com/SirEdvin/tweaked-computers/issues)
with exact engine/mod versions, wiring, source and diagnostics; remove private
literals/save data. Preserve backups if recovery seems unsafe.

Project source and the original industrial family retain MIT notices. Historical
Greg Flavored inputs and the pinned Phobos parser retain their respective MIT
licenses/notices; the independent glyph atlas includes no original CC:Tweaked font.
