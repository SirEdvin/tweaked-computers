# Tweaked Computers 0.1.12 — ALPHA

A focused inspector refresh and UI cleanup release for exactly Factorio **2.0.77**,
with base alone or optional Space Age. Back up the save and its complete mod set.
API 1, compiler 2, storage 1 and production safety ceilings are unchanged.

## Refresh without blank panels

- Every peripheral inspector constructs meaningful pending content immediately.
  KV keys, Configurator columns, monitor dimensions and logic signal trays no
  longer wait for a successful data query before appearing. Recipe Searcher
  retains its identity/status-only interface.
- Logic Handler uses native decider-style signal trays and engine-backed input
  reads. Red input, green input and the handler's own output update independently.
  One refused wire cannot hide another region. Disconnected inputs do not request
  a native signal inventory. Missing, disconnected, empty and refused samples
  remain distinct; older samples keep their original ticks.
- Failed refreshes retain any previous complete view as explicitly stale rather
  than clearing it. Unresolved monitor identities cannot be copied as current.
  Configurator unique totals still require both complete target traversals; no
  partial count is passed off as a full inventory.
- Inspection remains read-only. It does not run programs, create subscriptions,
  claim output ownership or change existing output fail-safe behavior.
- Switching from an inspector to the computer workspace no longer crashes when
  the previous window closes before the new workspace finishes construction.

## Less instruction text, more useful data

Long copy, wiring, byte-escape, sampling and monitor explanations move to tooltips
and the existing Reference/player guide. The editor loses repeated introductory
text, the reference Copy reminder and the synthetic Console header. Real errors,
conflicts, no-power states, paused output, actual output truncation and destructive
Reset/Forget confirmations remain visible when relevant. Console retention limits
and live-command safety guidance remain available in tooltips. No controls,
reference topics, recovery actions or bounded-data checks are removed.

## Upgrade

Install `tweaked-computers_0.1.12.zip` from the existing
[Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers) or
[GitHub alpha release](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.12).
Use the installable ZIP, not GitHub's generated source archive. Check `SHA256SUMS`
and `SHA1SUMS`, then load a copy of the save first.

Old open editor/inspector windows may close once during synchronized gameplay;
reopen them. Computer drafts, source, state, logs and peripheral data are retained.
No query or program executes during load. For rollback, restore the pre-upgrade
save and matching 0.1.11 mod set rather than downgrading an upgraded campaign in place.

## Verification scope

Release gates include deterministic packaging, canonical specification and strict
player-document checks, packaged base/Space Age inspector/editor/logic/shell tests,
separate-process cold reload, a populated published-0.1.11 save upgrade, native-client
checks of all five inspectors and the computer workspace, and hosted required CI.
Public GitHub assets and Mod Portal checksums are read back after publication.

Native captures use an isolated software renderer and establish appearance, not
representative GPU FPS. The focused 0.1.12 checks do not certify every third-party
mod, busy factory, platform or connected multiplayer topology. Earlier alpha
receipts keep their original source and scope; they are not silently relabelled
as new 0.1.12 multiplayer acceptance.
