# RD3 implementation handoff

Implemented on the isolated RD3 branch after fast-forwarding approved plan merge
`705e562df16cbfd6ff4d2c9b960ca33a24facc38`. Both that commit and baseline
`cb300e62ebad6a4a9a38a0679f21e251009f1d16` pass `git merge-base --is-ancestor`.
No prerequisite feature cards. RD5 owns integration; RD6 alone owns 0.1.2 publication.
No release, default-branch merge, protection change or OpenSpec archival here.

## Delivered

- Native Editor / Console / Peripherals / Reference / Maintenance, compact draggable
  title and close, screen-clamped scale math, reversible focus, one activation button.
- Source widget identity/bytes retained across tab/focus/status/geometry changes;
  Save separate from activation, disabled-action reasons and reviewed conflicts.
- Bounded selectable Console snapshot/follow, explicit source-line navigation with
  matching-source checks, real red/green inspector, timestamped rows/icons/power,
  honest disconnected versus pending state, searchable complete shipped reference.
- Every recovery/reset action retained. New `review-recovery` previews source before
  copy/forget; reviewed bytes and identity are rechecked before destructive changes.
  Standalone recovery still works without a body and never executes code.
- Exact opened-frame/token/ID/generation/active-subtree/widget checks on new routes.
  Old saved GUI schema retires only at synchronized work, retaining accepted drafts.
- Declared native monospace font, localized controls, updated help/player editor and
  developer UI docs. No backend API, budget or physical-device behavior changes.

## Evidence and boundaries

`tests.editor_workspace` has 18 focused groups run from the packaged ZIP in official
Factorio 2.0.77 base and Space Age. It uses real bodies/wires/traversal/runtime effects,
but GUI/player construction and event delivery are explicitly table-backed mocks.
It covers source write counts/identity, toolbar separation, four scale layouts,
paused Console updates, reference completeness, real color isolation/disconnection,
shared-work inspection refusal, every Maintenance/recovery action, stale/foreign/
hidden events, live fault markers and matching-source diagnostic navigation.

`tests.editor_cold` runs the original 12 contracts and a real powered body, with
separate cold engine processes. Before resumed work it verifies exact dirty/saved/
active sources, tab/focus/prior tab/follow/reference/review state, spent counters,
plain persistence, no load mutation, no startup replay and once-only timer delivery.
The harness requires a readable snapshot and acknowledged `/quit`, with no SIGINT or
forced kill. Final machine-readable results/logs are in the attached evidence bundle.

Strict MkDocs and generated player-reference/built-link checks run against the source.
The original integration and logic fixtures use the new nested widget paths; RD5
owns their integrated rerun after merging all physical/art/monitor feature heads.

Modeled layouts (GUI units; not client screenshots):

| Resolution | Scale | Window | Source | Focus source |
| --- | --- | --- | --- | --- |
| 1280×720 | 100% | 1040×688 | 488 | 580 |
| 1280×720 | 150% | 821×448 | 248 | 340 |
| 1920×1080 | 100% | 1040×940 | 740 | 832 |
| 1920×1080 | 150% | 1040×688 | 488 | 580 |

Minimum effective display is 760×480. Smaller layouts are not claimed usable;
reduce GUI scale. Native appearance/tab visibility, physical typing/paste/selection,
caret/focus, native scroll/hover and multiplayer client delivery are **not performed**.
The short user checklist is `docs/player/editor.md`; headless success does not pass it.
Checklist 3.1 stays unchecked for that explicitly deferred native-client portion;
its implementation, model construction/event routing and scale math are complete.

## Retained investigation failures

Early workspace fixture attempts are retained outside Git. They exposed fixture-only
assumptions: physical dispatch needed its paid power-check tick, a destroyed mock
frame no longer retained its child lookup, registry removal changes record status,
and post-dispatch validation must not use a backwards tick. These were corrected in
the fixture without relaxing production budgets or assertions. Source review also
caught pinned native GUI differences before final verification: size aliases are
write-only and ButtonStyle has no rich-text-setting property. The GUI mock now
checks those constraints. Diagnostic navigation was hardened against a successful
unrelated draft validation incorrectly selecting an active-source location.

## RD5 merge seams

Merge this card's verified head, not just its dependency edge. Preserve the three
added native GUI event registrations in `control.lua`. `tests.integration_engine`
and `tests.logic_engine` only change GUI paths to `content.editor` / `title.close`
and the contextual `activate` button. Preserve RD1's physical fixture changes too.
Developer `openwiki/` is deliberately untouched: RD5 owns its integrated refresh.
General lifecycle documentation still has an old “Recover Active Source” phrase;
reconcile that with Maintenance / Review active snapshot during RD5's cross-stream
documentation pass. Public Lua v1 and original vendor/art bytes remain unchanged.
The verification ZIP still uses baseline version 0.1.1; it is **not a publication**
or a replacement public release. RD5/RD6 prepare the integrated 0.1.2 artifact.
