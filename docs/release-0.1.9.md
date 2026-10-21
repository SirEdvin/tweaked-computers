# Tweaked Computers 0.1.9 — ALPHA

Factorio 2.0.77, base alone or optional Space Age. Back up the save and keep its
matching mod ZIP before upgrading. Restore that backup rather than downgrade a
save containing the new device. This is a user-test alpha, not stable.

## Changes since 0.1.8

- Separately researched 1×1 Recipe Searcher, 30 kW: read-only exact item/fluid
  product queries with optional exact primary/additional crafting-category filter.
  Complete sorted records include ingredients/products, quantities/probabilities,
  visibility, surface conditions and the requesting force's live enabled flag.
  Category filtering precedes the fixed 50-result ceiling; 51 raises E_LIMIT,
  never truncation. Existing Data/work limits can refuse smaller oversized results.
  There is no recipe execution, planner, query cache or dedicated search GUI.
- Monitor stacks are 50, retaining item-with-tags and native tag/label/quality
  compatibility. Unlike state does not silently merge; computer/KV stacks stay one.
  Mining/replacement retains settings/palette, not a portable old screen buffer.
- Console tabs display as spaces, preserving raw saved log bytes and print
  semantics. Save-backed scratch graphs/bindings remain; no command history or
  retained user functions is introduced.
- Recipe circuit signals join item/fluid/virtual signals. Input and discovery
  selectors must be explicit red or green. The old both selector is unsupported:
  update existing programs. Invalid retained subscriptions fault before queued
  callbacks, release owned output and never replay or silently translate wires.
  Output is still one shared bank mirrored onto both colors. Separate subscriptions
  share unchanged budgets; simultaneous maximum subscriptions are not guaranteed.
- Ctrl-click preserves native transfers and subsequent held-Ctrl shortcuts while
  retaining guarded computer opening, monitor touch and (at that release) empty-ground recovery.
  Current versions leave empty ground inert; recover drafts through another
  computer's Maintenance or the capacity viewer when opening a ninth computer.

## Install and learn

Use `tweaked-computers_0.1.9.zip` from the existing
[Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers) or matching
[GitHub prerelease](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.9).
The [player installation guide](player/getting-started.md),
[Recipe Searcher API](player/api/recipe-searcher.md), [logic API](player/api/logic.md),
[monitor API](player/api/monitor.md) and [Console guide](player/console.md) describe
exact research, wiring, signatures, errors, examples and retention rules.

## Evidence boundaries

Exact-archive base/Space Age regressions cover contracts, research installation,
native circuit/lifecycle behavior, save–reload and populated published-0.1.8 upgrade.
Native appearance/input checks use software rendering, not representative GPU FPS
or real-time/busy-factory guarantees. Actual two-client Recipe Searcher late joining
and cold-server continuation cover base. Earlier Console client/multiplayer evidence
is retained separately with relevant payload comparisons. Space Age connected
multiplayer, arbitrary modpacks/WAN/platforms/IMEs, exhaustive native wiring and
audible playback are not claimed. Production work/rendering ceilings are unchanged.

The prerelease carries final archive/source hashes, counted verification receipts
and selected evidence. Scoped native/Console/Recipe Searcher OpenSpec changes pass
strict checks. Broad `--all --strict` also reports two unchanged historical delta
warnings reproduced on pre-release main; those failures are retained, not passed
or silently rewritten. Historical implementation reports remain unchanged.
