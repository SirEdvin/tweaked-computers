# Recipe Searcher Lua API v1

This is the normative companion to [the capability specification](spec.md), under the [shared API rules](../../api/common.md). Verification receipts distinguish actual guest execution, native appearance and connected peers from illustrative source alone.

## Discovery and calling convention

Peripheral type: `recipe_searcher`.

Use existing `peripheral.find("recipe_searcher", "red")`, `wrap(name, wire)` or `call(name, wire, method, ...)`. Wire is explicitly `"red"` or `"green"`. Methods use dots, not colons. There is no global recipe library, remote API, physical product input or search GUI.

The exact public method set is `findRecipes`, `getLimits`. Both are synchronous, non-yielding calls. No new event is added; ordinary `peripheral_attach` and `peripheral_detach` notifications retain their existing payload and timing, with `peripheral_type="recipe_searcher"`.

| Signature | Exact returns |
| --- | --- |
| `searcher.findRecipes(product_type, product_name [, category])` | Exactly one dense `RecipeInfo[]`, possibly empty |
| `searcher.getLimits()` | Exactly one defensive map of current common limits plus `recipe_search_results=50` |

`findRecipes` accepts exactly two or three arguments; an explicitly nil third argument is equivalent to omission. `getLimits` accepts zero arguments. Extra arguments, a colon-supplied receiver or a table in place of the product type are invalid. There are no option tables, flag filters, cursors, pagination tokens or separate detail calls.

## Query inputs

- `product_type`: exactly `"item"` or `"fluid"`.
- `product_name`: exact, case-sensitive internal prototype name in that namespace. Display names, icons, signal IDs and inferred types are not accepted.
- `category`: optional exact, case-sensitive registered recipe-category name. It matches the recipe's primary category or any additional category. Modded categories are supported through the installed registry. No prefix, wildcard or case normalization is performed.
- Names are nonempty strings bounded by the common `string_bytes` ceiling; their lookup/validation is admitted work. The peripheral's own opaque address still follows the existing peripheral-name rules.

Searches match declared recipe products, not ingredients, recipe names or localized text. Every recipe with at least one matching product entry is a candidate, including secondary/probabilistic outputs; duplicate entries do not duplicate a recipe. All matching recipes participate regardless of hidden/enabled/recycling status, origin mod, current surface or available machines. No quality or temperature filter is accepted: these are recipe-definition results, not a particular machine's projected production.

The category filter is applied before the count ceiling. A known category with no matches returns an empty array. A missing prototype or unknown category is an error, not an empty search. Primary and additional categories are returned, allowing programs to distinguish them. Recycling is represented by actual category membership; the API does not invent a universal `is_recycling` classification for arbitrary mods.

## Completeness and limits

- A successful result includes every filtered match exactly once, in ascending bytewise recipe-name order.
- Zero matches returns exactly one empty table interpreted by this schema as an array, never zero returns or nil.
- Fifty matches are permitted if all other limits admit the complete metadata. Fifty-one or more matches raise `E_LIMIT`, with `field="results"`; the diagnostic explains the 50-recipe ceiling and suggests a crafting-category filter. Message wording is not stable API.
- No successful prefix, approximate count, total-count field or continuation cursor is returned. Programs can issue separate exact-category searches and deduplicate by recipe name if they choose; a single category can still exceed 50 and must then fail explicitly.
- Existing Data node/depth/string/table/snapshot-byte and callback/shared work/allocation limits remain effective. A query below the count ceiling is not guaranteed to fit all other budgets. Ingredient/product arrays and metadata are never shortened to make a result fit.
- Read `getLimits()` for the effective common values. The result count is fixed at 50 and is not a new runtime setting. No existing production limit is increased by this feature.

## RecipeInfo

Every record is a fresh plain string-keyed map. All required fields appear even when false or empty. Optional fields are absent, not represented by placeholder nil array slots.

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Internal recipe prototype name; stable deduplication/sort key |
| `category` | string | First native Factorio 2.1 crafting category, retained as the compatibility primary |
| `additional_categories` | string[] | Sorted unique remaining native category names, excluding the first category |
| `energy` | finite number | Base recipe crafting time in seconds at crafting speed 1; not electrical energy |
| `enabled` | boolean | Current enabled state in the requesting computer's force |
| `enabled_by_default` | boolean | Recipe prototype's initial enabled flag |
| `hidden` | boolean | Hidden recipe flag |
| `hidden_from_player_crafting` | boolean | Hidden from player crafting selection |
| `hidden_from_flow_stats` | boolean | Hidden from flow statistics |
| `hidden_in_factoriopedia` | boolean | Hidden from Factoriopedia |
| `ingredients` | IngredientInfo[] | Complete ordered ingredient list |
| `products` | ProductInfo[] | Complete ordered product list, not only the queried product |
| `surface_conditions` | SurfaceConditionInfo[] | Complete declared surface conditions; empty when unrestricted |

Ingredient/product order follows the engine-provided recipe array. They are not aggregated, reordered or deduplicated; repeated product records can carry different probabilities or temperatures. Numeric quantities are copied, not converted to expected yield. The schema is intentionally a plain-data recipe description, not exposure of every native prototype property: localized strings, icons, native objects, machine lists, technology objects and module-effect projections are not included.

### IngredientInfo

Required fields: `type` (`"item"` or `"fluid"`), `name` (string), `amount` (finite number).

Optional fields, copied only when present:

- Both types: `ignored_by_stats` (finite number).
- Items: `quality_min`, `quality_max` (registered quality names), `quality_change`, `spoil_weight` (finite numbers), when present in native 2.1 metadata.
- Fluids: `temperature`, `minimum_temperature`, `maximum_temperature` (finite numbers), `fluidbox_index`, `fluidbox_multiplier` (integers).

Preserve the engine's distinction between exact temperature and a temperature interval; do not fabricate all three fields. No quality is invented for an ingredient.

### ProductInfo

Required fields: `type` (`"item"` or `"fluid"`), `name` (string), `probability` (finite number in `[0,1]`).

Factorio 2.1 also supplies `independent_probability` (number in `[0,1]`) and
`shared_probability={min=number,max=number}` (ordered bounds in `[0,1]`). Both
are returned. The compatibility `probability` is their marginal probability:
`independent_probability * (shared_probability.max - shared_probability.min)`.
Shared intervals can correlate multiple products; the marginal alone does not describe that correlation.

Quantity uses either `amount` or the pair `amount_min`, `amount_max`, according to engine readback. Preserve fixed versus ranged quantities and all other optional fields:

- Both types: `ignored_by_stats`, `ignored_by_productivity` (finite numbers).
- Items: `extra_count_fraction`, `percent_spoiled` (finite numbers).
- Items, when native metadata provides them: `affected_by_quality`, `always_fresh`, `reset_freshness_on_craft` (booleans), `quality_min`, `quality_max` (quality names), `quality_change`, `spoil_weight` (finite numbers).
- Fluids: `temperature` (finite number), `fluidbox_index` (integer).

Probability and extra-count fractions remain explicit. Do not multiply amounts by probability, add productivity, project quality chances, synthesize extra recipes or discard zero-valued modifiers.

### SurfaceConditionInfo

Required: `property` (string). Optional: `min`, `max` (finite numbers).

Finite bounds are copied exactly. An engine lower bound of negative infinity is represented by absent `min`, and an upper bound of positive infinity by absent `max`; absence means unbounded, not zero. No other nonfinite numeric value is permitted in a successful snapshot. Each condition remains present even if both bounds are unbounded. Conditions preserve engine array order. This is metadata only: a recipe is not excluded because the current surface fails a condition.

## Availability and freshness

Each call reads current force recipe state. `enabled` is not an alias for `enabled_by_default` or a computed `researched` flag: scripts can change recipe availability, and more than one technology can unlock a recipe. No research event or reboot is needed for a later call to reflect a new value. No machine, material, surface or hand-crafting feasibility flag is promised.

Searches are read-only: they never unlock recipes, change a machine, consume/produce a resource, reserve an output, or cache an authoritative research snapshot. Later program calls observe live game state; the returned prior snapshot itself does not change.

## Errors

Ordinary errors use the existing plain `{code, message, field?, peripheral?, device?}` form and can be caught with `pcall`. Do not parse `message`. Existing fatal budget controls remain noncatchable.

| Condition | Error |
| --- | --- |
| Wrong arity, colon call, wrong argument type or empty name | `E_ARGUMENT` |
| Input string or argument snapshot exceeds the common service envelope | Existing `E_LIMIT` before provider validation |
| Product type other than item/fluid; unknown product or category | `E_RANGE` |
| More than 50 matches after category filtering | `E_LIMIT`, `field="results"` |
| Result violates a documented structure/string/snapshot-byte bound | `E_LIMIT`; no partial result |
| Unexpected native metadata cannot be represented by this contract, including nonfinite values other than open surface bounds | `E_UNSUPPORTED`; no omitted recipe or field to conceal the issue |
| Searcher physically unavailable | `E_UNREACHABLE`; no electrical requirement |
| Bound identity/path/force/surface was lost | Existing `E_UNREACHABLE` behavior |
| Incomplete or oversized network proof | Existing `E_NETWORK_PENDING` / `E_LIMIT` behavior |
| Callback/shared work or allocation is exhausted | Existing fatal `E_BUDGET` control; no budget reset or retry loop |
| Unexpected native access failure or missing force recipe for an existing candidate | `E_ENGINE`; no fabricated enabled value |

Live physical authority checks retain existing peripheral precedence before service argument handling. An operation can exhaust its existing work budget before detecting a later semantic/count error; no stronger error precedence under exhausted credits is promised. Invalid or oversized results never mutate recipes or world state, but legitimately consumed accounting credits remain consumed.

## Identity, persistence and lifecycle

A wrapper is protected, callback-local and bound to the selected wire, current run and exact device identity/generation. It cannot be saved as Data. Store its name/color and wrap again in another callback. Every captured method rechecks authority; neither replacement at the same coordinates nor a shared label retargets it.

The [Console](../console-shell/lua-api.md) may retain authentic symbolic peripheral bindings in its separate scratch graph. This does not permit functions/facades in ordinary Data or change saved-handler lifetime, and every restored call retains the same live authority checks.

The searcher needs no electricity or electrical helper. Discovery, getLimits and active search retain their non-power physical identity/scope/path requirements. Removing or changing force/surface revokes the old path. The new service owns no mutable database, job queue, query session, output or persistent catalogue cache.

Ordinary cold reload preserves existing physical identity and computer state without executing source or mutating storage on load. Query tables contain only serializable plain Data and can be saved through existing computer-state APIs if their independent state limits permit; obtaining a snapshot does not guarantee it fits one state entry. A new call after configuration changes reads the currently installed catalogue rather than an old retained result.

## Example: search, refine and read metadata

Illustrative source for the named-handler runtime; acceptance must execute this exact maintained example through the packaged compiler and services on a real physically valid Network connection.

```lua
function start(event)
    local searcher = peripheral.find("recipe_searcher", "red")
    assert(searcher, "Connect a Recipe Searcher with a red Network wire")

    local limits = searcher.getLimits()
    assert(limits.recipe_search_results == 50)

    local ok, recipes = pcall(searcher.findRecipes, "item", "iron-plate")
    if not ok then
        if type(recipes) ~= "table" or recipes.code ~= "E_LIMIT" then
            error(recipes)
        end
        recipes = searcher.findRecipes("item", "iron-plate", "smelting")
    end
    for _, recipe in ipairs(recipes) do
        computer.log(recipe.name .. " / " .. recipe.category
            .. " / seconds=" .. tostring(recipe.energy)
            .. " / enabled=" .. tostring(recipe.enabled))
    end

    local fluids = searcher.findRecipes("fluid", "petroleum-gas", "chemistry")
    computer.setState("recipe_count", #recipes)
    computer.setState("fluid_recipe_count", #fluids)
end
```

The bounded fallback is illustrative, not a promise that every `E_LIMIT` is count overflow or that every modpack has a small smelting set. Applications should select a relevant known category and allow repeated refusal to surface. There is no same-callback unbounded retry loop. Boundary fixtures must separately prove exactly-50 success, 51-match refusal, and category refinement of an oversized set.
