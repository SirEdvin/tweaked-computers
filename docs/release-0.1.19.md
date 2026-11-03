# Tweaked Computers 0.1.19 ALPHA

## What changes

- **One saved-program grammar:** a document contains named function declarations,
  with optional semicolons. `start(e)` is the startup handler; other named
  handlers run only when registered. No top-level executable setup, returned
  program table, automatic legacy conversion, interpreter or dynamic loader is
  provided. Put setup inside `start` and durable values in the state API.
  Console commands remain a separate expression/statement language and do not
  become saved handlers. See the [language guide](player/api/language.md).
- **Electricity-free custom devices:** Computer, KV Database, Monitor, Logic
  Handler, Configurator, Recipe Searcher, Factoriopedia Interface, Production
  Statistics and Dashboard require no electrical coverage or power helper.
  Factory outages do not pause their callbacks, discard accepted events, erase
  valid outputs or blank displays. Native radars (both tiers) and programmable
  speakers retain their normal electricity requirements and live operation-time
  availability/authority checks. This does not power the factory machines a
  Configurator controls.
- **Demand-driven scheduling:** ready program/Console queues, timer deadlines,
  subscribed signal inputs, output owners, pending topology/presentation,
  expiry deadlines and open UI sessions own the recurring work they need.
  Tick-level signal observation, deterministic fair dispatch, admission limits,
  last-writer cleanup and whole-frame presentation remain enforced. No new
  scheduler API, setting or relaxed resource budget is introduced.
- **Native adoption repair:** a pending discovery retains the last complete
  observation rather than fabricating an empty detach and clearing a still-valid
  output. Actual authority loss still revokes effects safely.
- **Compatibility retained:** the manifest accepts Factorio 2.1 patches via
  `base >= 2.1.0` and optional `space-age >= 2.1.0`, as in 0.1.18. Optional
  `factorio-charts >= 1.2.0` is unchanged. Verification uses **2.1.23 build 87750**,
  base and Space Age, not every patch or arbitrary modpack. Stay on 0.1.14 for
  Factorio 2.0.77.

## Breaking source and save guidance

**Back up the complete save and matching mod set before upgrading.** Load a copy
first. Legacy table-form saved source is not converted: manually rewrite it as
named functions before running. Unsupported active source fails closed with its
source and accepted data recoverable; validation failure does not replace a prior
valid run. This release does not promise that legacy source can keep executing.

A supported legacy electrically paused run resumes without replaying startup;
aligned timers coalesce overdue intervals. Migration removes only owned power
helpers, preserves real role wires/identities and accepted source/state, queues,
KV data, dashboard/display models and spent credits. Ordinary cold load does not
execute guest source or renew credits. Existing stop/fault/authority cleanup and
unknown-version fail-closed protections remain.

**Computer items are still plain hardware (0.1.17 breaking change).** Ordinary
pickup/replacement loses computer contents; old programmed item payloads are not
imported. Placed records and private drafts are not a portable item backup.
Existing approved database/item and blueprint/Undo behavior is not a general
computer-content export. Restore the old save **and** old mod set for rollback;
do not downgrade an upgraded save in place.

## Installation

Use the existing [Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers)
or download **`tweaked-computers_0.1.19.zip`** from the
[GitHub prerelease](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.19).
Do not download GitHub's automatic **Source code (zip)** as an installable mod.
Keep the mod ZIP unextracted in the Factorio user-data `mods` directory and move
conflicting older archives/extracted copies aside after backup. Select 0.1.19
explicitly: synchronizing an older save's mod versions can select the old release
again. Follow the [installation guide](player/getting-started.md).

## Verification and limitations

The reviewed function-only, scheduling and adoption-repair source is retained by
history-preserving merges. Release acceptance uses exact-package checks,
separate-process populated 0.1.18 upgrades and cold reloads in both content modes,
and full-client smoke; expensive prior native/connected-peer correctness evidence
is carried only after complete production/fixture payload equivalence, with
metadata/documentation/generated-manifest differences recorded separately.
Local acceptance is not a hosted-test CI pass. Neither finite peer cases nor
software-rendered appearance establishes universal multiplayer/modpack support,
representative GPU FPS or physical-speaker certification.

**Benchmarks are incomplete; performance and scaling are unverified.** On
2026-11-04 the user explicitly authorized this alpha without completed benchmark
results. The original scheduling checklist row **5.4 stays unchecked**; its release
eligibility was waived, not its measurement recorded as passed. Historical partial
reports, failed/timeout attempts, native controls and the standalone portable Linux
runner are preserved separately. No new benchmark campaign was run for release,
and no partial timings or structural counters establish a speedup.

The retained local LLM-Wiki note
`concepts/tweaked-computers-demand-driven-scheduling-benchmarks.md` is an incomplete
historical report, not a public completed performance certificate. The
[benchmark procedure](scheduling-benchmarks.md) remains available for future
measurement. The active OpenSpec changes are not archived by this release.
