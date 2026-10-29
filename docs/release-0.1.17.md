# 0.1.17 ALPHA — factory dashboards and native catalogues

**Factorio 2.1.23**, base alone or optional Space Age. Install
`tweaked-computers_0.1.17.zip` from **alpha-0.1.17**, not GitHub's automatic source
archive; leave the mod ZIP unextracted. This remains a user-test prerelease.

## Six changes

- **Console elapsed time:** retained entries show `[HH:MM:SS]` elapsed simulation
  time, including hours above 99. This is not wall-clock time; selection, copying,
  Follow-off reading and reopening retain their existing behavior.
- **Demand-driven monitor maintenance:** unchanged screens no longer pay repeated
  full-screen maintenance. Dirty work stays bounded; continuously updating screens,
  cold state and fair multi-screen presentation retain their existing contracts.
  This is not a GPU-FPS or full-modpack performance guarantee.
- **Factoriopedia Interface:** a powered, physically wired, read-only peripheral
  queries installed native item, fluid, recipe and entity metadata. Results contain
  native facts only, not projected crafting chains, estimated factory rates or
  hand-maintained game catalogues. See the complete API and runnable examples.
- **Entity-owned computer storage:** computer items are now plain hardware. The
  compatibility break and required backup procedure are below.
- **Production Statistics:** a powered, wired, read-only peripheral exposes native
  production/consumption statistics and complete 300-sample histories in engine
  order. Native GUI smoothing is a presentation detail, not an API transformation;
  no runtime smoothing or inferred data is added.
- **Dashboard:** a separate powered, wired device retains labels, buttons, tabs,
  bounded chart histories and duration-bar datasets. Optional **factorio-charts
  1.2.0 or later** supplies its unchanged upstream line charts and duration bars,
  not a generic numeric bar renderer. Without that mod, labels/buttons still work,
  chart regions report unavailable and accepted data is retained. Removing and
  reinstalling the dependency does not replay producer startup.

Player instructions and complete examples are in the
[installation guide](player/getting-started.md),
[Dashboard guide](player/dashboard.md),
[Factoriopedia API](player/api/factoriopedia-interface.md) and
[Statistics API](player/api/production-statistics.md).

## Breaking computer-item change — back up first

**Before upgrading, back up the complete save, mod configuration and matching old
mod ZIPs.** Test a copy. To roll back, restore that complete backup with its matching
engine/mod set; do not load a newly saved 0.1.17 world in an older mod version.
Synchronizing an old save's mod versions can reselect 0.1.16 instead of 0.1.17.

Ordinary mining/pickup and replacement loses the removed computer's source, label
and application state: placement creates a **new blank, stopped identity**. Old
programmed computer items are deliberately ignored, whether their payload was
valid, malformed or unsupported. There is **no legacy item import or hidden
item-data recovery**. Preserve reusable source with source-only blueprints or
clipboard copies before removal.

Upgrading does **not** blanket-delete placed computer records, active programs,
private player drafts or KV/monitor data. Qualifying native Undo restores the
pre-removal source/label/state into a new **stopped** computer; it does not restore
old subscriptions, timers, Console sessions, output ownership or replay effects.
History and restoration ghosts are not permanent backups. KV, monitor and Dashboard
items retain their own documented policies. Read the full
[moving and recovery guide](player/lifecycle.md) before moving devices.

## Verification scope

The six reviewed feature histories and their completed specifications are integrated
and archived together. The release uses the pinned **2.1.23 base/Space Age** matrix,
packaged native contracts, cold save/reload and populated 0.1.16 upgrade checks.
Earlier accepted native-client and connected-peer receipts are carried forward only
where complete relative package payload comparison proves production and relevant
fixtures unchanged; release-only metadata/documentation is recorded separately.
Final-version packaged, upgrade and native smoke checks are additional gates, not a
claim that every historical native scenario was rerun on new version metadata.

Native GUI/connected-peer cases cover finite controlled scenes, not arbitrary mod
packs or every platform. Software-rendered Xvfb/llvmpipe validates appearance, not
representative GPU FPS; publication cadence and 30-FPS recordings are not measured
client FPS. Shared-host timing has contention and adverse tails. No production
budget or safety boundary is raised, and API 1/compiler 2/storage 1 remain unchanged.
