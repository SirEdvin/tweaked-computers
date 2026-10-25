# 0.1.15 ALPHA — Factorio 2.1

Target: **Factorio 2.1.23**, base alone or optional Space Age. The dependency is
pinned to that tested engine. Stay on **0.1.14** for Factorio **2.0.77**.
Back up the save, engine and matching mod ZIP before conversion. Do not downgrade
an upgraded save in place. API **1**, compiler **2** and storage **1** remain unchanged.

## Compatibility investigation

The immutable 0.1.14 release was tested first. Its 2.0.77 dependency declarations
prevent loading in 2.1.23. Changing only metadata permitted startup, but real
factory integration failed on removed writable entity APIs. A metadata-only
release would therefore not have been sufficient.

## Changes

- Use `minable_flag` for protected helper entities and data-bearing device mining
  guards. Preserve the guard during entity replacement and blueprint cloning.
- Read native recipe `categories`; retain `category` as the first native entry
  and sorted `additional_categories` as the rest. Category filtering still covers
  every native category.
- Preserve the Recipe Searcher `probability` field as the marginal probability,
  and also return `independent_probability` and `shared_probability={min,max}`.
  Copy native quality/freshness metadata when provided; do not project yields.
- Adapt the existing configurator guest fields to native `read_fuel`, `records`
  and independent read/request switches. The existing mode field additionally
  accepts `send_contents_and_set_requests`, so readback/rollback do not lose a
  simultaneous native mode. Storage-tank `read_contents=true` preserves an existing
  segment-read mode, while false disables reading; failed writes restore the exact
  previous native mode.
- Update isolated test harnesses for the 2.1 profiler, entity activity and quickbar
  APIs. Explicitly select the new bundled recycler mod with Space Age and disable
  it for base-only tests. Released-save checks create saves in 2.0.77 before loading
  the unchanged candidate archive in 2.1.23.

No production safety budget is raised, no save data is intentionally discarded,
and no new runtime abstraction or gameplay dependency is introduced.

## Verification scope and limitations

This release is **headless-only on 2.1.23**, by explicit release decision. Packaged
native-runtime contracts, cold save/reload, monitor publication and old-engine
save conversion are the automated acceptance gates. Their exact commands,
archive hashes, logs and outcomes are retained in the external release evidence:
`/home/siredvin/artifacts/tweaked-computers/release-0.1.15-2026-10-25/`.

Earlier **2.0.77** graphical, audio and connected-multiplayer results are historical;
they do **not** verify the 2.1 client. No 2.1 UI/rendering/audio/connected-peer
acceptance, third-party mod-pack certification or representative GPU benchmark
is claimed. Headless chart cadence is not client FPS.

The previously documented 0.1.1 physical-conversion fixture failure remains a
historical coverage gap, not evidence of universal old-save migration. Keep
backups and matching old packages rather than relying on an in-place downgrade.
