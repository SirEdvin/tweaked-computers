# 0.1.13 ALPHA — actual-input query accounting

Target: Factorio **2.0.77**, base alone or optional Space Age. Back up saves and
matching ZIPs before upgrading. API **1**, compiler **2**, storage **1**, entity
prototypes, physical wiring, program source and persistent peripheral data are
unchanged. This is not a stable release or a universal mod-compatibility claim.

## Fix

A connected Logic Handler previously reserved work for every installed item,
fluid, virtual signal and recipe, multiplied by every installed quality, before
asking Factorio for the selected wire's signals. This could permanently reject
a steel chest containing only a few items with `E_BUSY` when unrelated mods added
many recipes. The refusal was visible in 0.1.12, but the small query still failed.

0.1.13 removes that global-prototype precharge from the shared input-read path,
covering inspectors, `readSignals` and subscription sampling. It admits the native
call, accounts the actual native tuple count and then meters identity validation,
canonicalization, copying and sorting. Disconnected inputs still skip enumeration;
single-signal reads retain direct native lookup. Red, green and own output remain
independent observations.

The peripheral audit also found global recipe-count and category-count estimates
in Recipe Searcher. These are removed. Product searches charge native-call
admission, actual candidates, requested category checks and projected metadata,
not unrelated registered recipes or categories.

## Checks retained

- At most 64 actual signal identities per selected input/output; no silent prefix.
- At most 50 complete Recipe Searcher results after category filtering; no silent
  truncation of records, ingredients, products or metadata.
- Prototype/quality validation, explicit wire selection, signed counts, finite
  plain Data, work/allocation limits and fatal sandbox budget enforcement.
- Current power, identity, force/surface, cable-path and writer authority, plus
  fail-safe output cleanup and complete Configurator deduplication.
- Shared scheduler ceilings, inspector refresh throttling and save-backed ledgers.
  No production allowance is increased and no read renews spent credits.

KV, monitor, Configurator, radar/modem and speaker paths have no corresponding
all-installed-prototype query precharge to remove. Their relevant bounds remain:
actual stored data, model geometry, traversed graph edges, deliveries and the
specific generated sound-catalogue blocks/pages being materialized. These are
not interchangeable with an unrelated global prototype inventory.

Native filtering/enumeration still has opaque engine cost and materializes native
result tables before Lua can inspect their sizes. A fixed call charge and actual
Lua-side accounting are **not** a hard bound on native C++ CPU time or allocation.

## Verification scope

The release campaign retains the failing published 0.1.12 reproduction separately
from the candidate: computer red Network to Logic Handler red Network, and a
steel chest with 42 iron plates and 7 steel plates connected to red INPUT, with
2,048 unrelated producer recipes from the existing companion data fixture.

Focused packaged checks cover both engine modes, cold reload, real mixed/quality
signals, sampling failures and fail-safe ownership, Recipe Searcher full metadata,
50/51 boundaries and fatal resource exhaustion. Synthetic host-boundary tests vary
unrelated registry lengths while preserving real lookups, and require identical
query work. CI runs all-family inspector checks with the large recipe fixture.
Native clients inspect the actual chest panel in both modes; populated saves
from published 0.1.12 are upgraded separately.

Evidence is retained outside git under
`/home/siredvin/artifacts/tweaked-computers/release-0.1.13-2026-10-21/`.
Archive hashes and terminal results belong to that external receipt, avoiding a
self-referential package hash. Hosted checks and publication readbacks must match
the exact frozen release archive. The user's complete third-party mod pack and
versions, connected multiplayer and representative GPU performance are not
claimed tested by these focused cases.
