# Proposal

## Why

Computer programs cannot currently discover which recipes produce a named item or fluid without hard-coding recipe knowledge. A dedicated Recipe Searcher peripheral will expose the installed game's recipe catalogue through the existing wired, powered, sandboxed device model, including recipes contributed by other mods.

## What Changes

- Add a distinct 1×1, 30 kW Recipe Searcher block with one Network endpoint supporting red and green wires and original archive/scanner-style Foundry artwork. It has no inventory, fluid boxes, crafting execution or dedicated search GUI.
- Craft one device in 2 seconds from 10 steel plates, 5 advanced circuits and 2 processing units.
- Add a separate `tc-recipe-searcher` technology with exactly two direct prerequisites: `tc-circuit-computers` and `utility-science-pack`. Research costs 200 units, each using one automation, one logistic and one utility science pack, at 60 seconds per unit.
- Add peripheral type `recipe_searcher`, exposing a synchronous item/fluid product search with an optional exact crafting-category filter. Categories include installed modded categories, not a hard-coded vanilla list.
- Include all matching recipe prototypes by default, including locked, hidden, recycling and other modded recipes. Return complete defensive recipe records: names, categories, ingredients, products, amounts/probabilities, base crafting time, visibility and force-enabled flags, and relevant fluid/surface constraints.
- Return one complete, deterministically ordered array. Apply category filtering before the fixed 50-recipe safety limit; 51 or more matches raise an explicit `E_LIMIT`. No pagination, truncation or arbitrary selection of the first 50. Existing byte, structure and callback budgets still apply.
- Separate device unlock ownership in prototype construction and existing-save reconciliation so researching Circuit Computers alone never unlocks the new device. Preserve all existing device unlocks and balances.

## Capabilities

### New Capabilities

- `recipe-searcher`: The physical Recipe Searcher, its independent research gate, read-only product/category lookup, full recipe snapshots, limits, network authority and lifecycle compatibility.

### Modified Capabilities

None. `openspec list --specs` reports no canonical specifications. Existing in-flight device/network contracts remain context; this additive capability does not rewrite those changes.

## Impact

- Device definitions, shared prototype generation, research reconciliation, closed peripheral-family registration and control-stage service imports.
- A new focused recipe service using Factorio 2.0.77's installed recipe prototypes and the requesting computer's force recipes; no new third-party dependency or execution backend.
- Additive Foundry artwork, socket metadata, localization, player/API/help documentation and an executable guest example.
- Data-stage, real-engine network/query/research, separate-process upgrade/reload, resource-bound and native-client visual checks in both base and Space Age configurations; packaging includes the new capability and Lua API contract.
- No changes to existing devices' recipes, power, footprints or public methods. No recipe execution, machine/inventory feasibility solver, recursive production planner, quality-yield calculator, localization search, category-discovery API or player-facing recipe browser.
