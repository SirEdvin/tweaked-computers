# Tweaked Computers 0.1.11 — ALPHA

Target: exactly Factorio **2.0.77**, base alone or optional Space Age. Back up the
save and its complete mod configuration before installation or upgrade. This is
an alpha, not stable software or exhaustive compatibility/performance certification.
Historical releases and their checksums remain immutable.

## Five finalized features

- **Peripheral inspectors:** open KV, monitor, logic handler, Configurator or
  Recipe Searcher bodies for read-only identity/status and bounded local views.
  Copy names without executing guest code. Recipe Searcher has no query controls.
  Monitor views report the merged logical display; logic inputs remain separate
  red/green values rather than a fabricated combined value. Dirty computer drafts
  survive window transitions. Inspectors never become a remote-write API.
  See [inspectors](player/inspectors.md).
- **Radar modems:** the exact vanilla radar joins same-color physical discovery
  without replacing its body, native GUI, settings, scanning, circuits or mining
  result. Seven methods provide bounded shared channel sets and same-force
  datagrams. Hidden native radar radio links never grant peripheral discovery or
  remote-call authority. Vanilla tiers communicate within one surface; a separately
  researched Space Age advanced tier supports explicitly permitted interplanetary
  messaging. No rednet, automatic repeater, ACK or delivery guarantee is added.
  See [modems and the paired programs](player/api/modem.md).
- **Guarded Lua globals:** saved programs and Console share print,
  rawget/rawset/rawlen/rawequal, xpcall, unpack (identical to table.unpack) and
  `_VERSION == "Lua 5.2"`. Raw access is restricted to guest-owned tables;
  snapshots are usable copies, never service internals. Fatal budget/stop control
  escapes protected calls. No helper grants host globals, metatables, loaders,
  files, OS access or unlimited native execution. See [language](player/api/language.md).
- **Vanilla programmable speaker:** six methods expose exact instruments and
  zero-based sample pitches, paginated installed sound paths, limits and bounded
  synchronous positional note/effect submission. Native GUI/circuit configuration,
  power, wires, blueprints and mining remain vanilla. True means engine submission,
  not an audible acknowledgement. Nearby listeners can be on other forces, but
  hearing grants no control. Mixer, camera, charting and attenuation still apply.
  No streaming, audio queue, completion event or cancellation of submitted samples.
  See [speaker API and ownership/audio restrictions](player/api/speaker.md).
- **Contextual Reference:** common APIs and peripheral discovery are separate from
  seven complete peripheral-kind references. Contextual links select the right
  section and return its viewport to the top without running guest methods,
  resetting state or losing a dirty draft. Player/API pages and complete runnable
  examples cover the same contracts. See [editor](player/editor.md).

The complete canonical contracts and Lua API companions are on main. All five
planning changes are finalized under their 2026-10-21 archive directories; no
active-change path is required by the installable package.

## Upgrade and deliberate recovery

Install `tweaked-computers_0.1.11.zip` from the existing
[Factorio Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers) or
[alpha-0.1.11](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.11).
Use the installable ZIP, not GitHub's generated source archive or a test companion.
Compare it with `SHA256SUMS` and `SHA1SUMS`. Load a copied save first. Keep the
pre-upgrade save, mod set and matching 0.1.10 ZIP; rollback restores all of them,
not an in-place downgrade of an upgraded campaign.

API 1, compiler 2 and storage 1 remain unchanged. Noncolliding supported programs
retain exact source and state, without startup replay or guest execution on load.
Newly wired/pre-existing native carriers are adopted through bounded maintenance,
not a full world scan. Retry `E_NETWORK_PENDING` on a later tick; do not replace
native devices to force adoption. Shared work/Data/transport/audio limits still
apply, and no production safety ceiling is raised.

New built-ins reserve public/private **top-level function declaration names**,
not ordinary locals/parameters, legacy descriptor handler keys or nested scratch
fields. An older colliding active declaration faults only during synchronized
reconstruction, retaining exact source/state: rename the declaration, then
explicitly Save/Run. An old Console root with a newly reserved name reports named
`E_UNSUPPORTED` before effects and retains its graph. Confirm **Reset Shell only
when ready to discard all scratch values**, not just the colliding binding.
It does not erase saved source, application state, the running program or old logs.
Inspect/copy needed data from a pre-upgrade backup first. Maintenance Reset State
is a different destructive action and is not the reserved-name recovery shortcut.

## Verification boundary

Release acceptance requires two deterministic builds, complete relative-payload
comparison against the archival candidate, strict canonical/archived OpenSpec and
package/docs/example checks, full exact-head required CI, packaged base/Space Age
and separate-process cold checks, populated published-0.1.10 upgrades and final
native-client smoke of this versioned ZIP. The actual merged-main rebuild must be
byte-identical before tagging. Public Portal/GitHub artifact and deployed-document
readbacks are separate publication gates.

Earlier integration, native UI, independently recorded speaker PCM and actual
two-client fresh/cold evidence is carried only across byte-identical production
and relevant fixtures, with explicit metadata/docs/manifest exceptions in the
external release receipt. Original archive/source hashes stay separate; changed
production or fixtures require affected reruns. Historical failed attempts remain
failed. Server-authored peer JSON equality is not independent client-storage
computation. Tested connected cases cover base and Space Age within their recorded
scope, not every topology/platform/mod combination. Native speaker submission is
not proof every player heard it; independently captured PCM has its own finite
listener/mixer scope. Xvfb/llvmpipe establishes appearance, not GPU FPS; work-unit
and two-tick cadence checks do not guarantee real-time latency or maximum-world UPS.

See the [installation/recovery guide](player/getting-started.md),
[complete player API](player/index.md) and source tests for supported behavior.
