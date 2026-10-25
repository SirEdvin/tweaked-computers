# Recipe Searcher

Available in 0.1.9 ALPHA. Research and craft the
[separate Recipe Searcher](../getting-started.md#research-and-craft), supply 30 kW
and connect its 1×1 body directly to the computer's red or green Network.
It is a read-only catalogue scanner: no item inventory, fluid input, crafting
execution or dedicated search GUI. Inspect it through the existing Peripherals tab.

## Discovery and calls

Peripheral type: `recipe_searcher`. Use dots, never colons:

```lua
return {
    api_version = 1,
    handlers = {
        start = function(event)
            local searcher = peripheral.find("recipe_searcher", "red")
            assert(searcher, "Connect a powered Recipe Searcher on red")
            local recipes = searcher.findRecipes("item", "iron-plate", "smelting")
            local limits = searcher.getLimits()
        end
    }
}
```

- `findRecipes(product_type, product_name [, category])` returns exactly one
  complete dense recipe array, possibly empty. Exactly two or three arguments;
  an explicit nil category means no filter.
- `getLimits()` takes no arguments and returns a defensive snapshot of current
  common limits plus the fixed `recipe_search_results=50`.

Type is exactly `"item"` or `"fluid"`; names are exact, case-sensitive installed
prototype IDs in that namespace. Category is an optional exact installed recipe
category, including modded categories. It matches primary or additional categories.
No localization, substring, quality, temperature or flag filters, category browser,
pagination or separate details API is provided.

The query matches direct products (including secondary/probabilistic products),
not ingredients or recursive chains. Locked, disabled, hidden, recycling, modded
and surface-restricted recipes all participate. A registered product with no
producers returns an empty array; an unknown product/category is an error.

## Complete results, not a prefix

Results are unique recipes in ascending bytewise name order. Category filtering
happens before counting. Fifty matching small records can succeed; 51 filtered
matches raise `E_LIMIT` with `field="results"`. The error suggests selecting a
crafting category. A single category can still exceed 50. No recipe, ingredient,
product or field is silently omitted to make a call fit.

The unchanged [Data/work limits](limits.md) also apply: 50 is not a guaranteed
payload size or CPU/UPS bound. Oversized metadata may refuse with fewer recipes;
work/allocation exhaustion remains fatal. Native catalogue filtering has an opaque
engine cost. Since 0.1.13, admission charges the native call, actual candidates,
category checks and projected metadata, not every installed recipe/category.
These charges do not bound native CPU time or initial table materialization.
There is no retained query cache/index or job.

## Recipe record

Every required field appears, including false and empty arrays. Optional fields
are absent when the engine does not provide them. All values are detached finite
plain Data; ingredient/product order is the engine's readback order, not necessarily
the author's prototype-source order.

| Required field | Type and meaning |
| --- | --- |
| `name` | Internal recipe name, sorting/deduplication key |
| `category` | First native 2.1 category, kept as the compatibility primary |
| `additional_categories` | Sorted unique remaining native category names, excluding the first |
| `energy` | Finite base crafting time in seconds at speed 1, not electrical energy |
| `enabled` | Current enabled flag in the requesting computer's force |
| `enabled_by_default` | Prototype's initial enabled flag |
| `hidden` | Hidden recipe flag |
| `hidden_from_player_crafting` | Hidden from player crafting selection |
| `hidden_from_flow_stats` | Hidden from production statistics |
| `hidden_in_factoriopedia` | Hidden from Factoriopedia |
| `ingredients` | Complete ordered Ingredient records |
| `products` | Complete ordered Product records, not just the searched output |
| `surface_conditions` | Complete ordered SurfaceCondition records, empty if unrestricted |

Ingredient records require `type` (item/fluid), `name` and finite `amount`.
Optional `ignored_by_stats` is finite. Fluid ingredients can additionally provide
finite `temperature`, `minimum_temperature`, `maximum_temperature`, and integer
`fluidbox_index` / `fluidbox_multiplier`. Exact versus interval temperature remains
distinct; no ingredient quality is invented.

In 2.1, item ingredients/products also copy `quality_min` / `quality_max` as
quality names and finite `quality_change` / `spoil_weight` when native metadata
provides them. Products additionally retain the optional boolean fields
`affected_by_quality`, `always_fresh` and `reset_freshness_on_craft`.

Product records require `type`, `name`, and finite `probability` in [0,1]. Quantity
is either finite `amount` or the finite pair `amount_min` / `amount_max`, as read
from the engine. Optional finite `ignored_by_stats` and `ignored_by_productivity`
apply to either type. Item products may provide finite `extra_count_fraction` and
`percent_spoiled`; fluids may provide finite `temperature` and integer
`fluidbox_index`. Zero values and repeated product entries remain intact.

Products also return 2.1's `independent_probability` and
`shared_probability={min,max}`. The compatibility `probability` is
`independent_probability * (shared_probability.max - shared_probability.min)`.
Shared intervals can correlate products; the marginal probability alone does not
describe that correlation. Amounts remain unmodified, not expected yields.
No expected yields, productivity or quality projection is calculated.

SurfaceCondition records require `property`; optional finite `min` / `max` are
copied exactly. Negative-infinite lower and positive-infinite upper bounds become
absent fields (unbounded, not zero). Other nonfinite metadata refuses explicitly.
A condition remains present even if both ends are unbounded. Conditions do not
filter recipes according to the computer's current surface.

## Freshness, authority and lifecycle

`enabled` is live force-specific state, including script changes and research;
it is not a generic researched/craftable flag. Each later call rereads it, without
reboot/research-cache invalidation. Earlier snapshots stay unchanged. Queries never
unlock recipes or mutate the world. Localized text, icons, native objects, machine
lists and technology objects are deliberately outside this schema.

Normal same-force/surface, explicit-color, live identity/generation and power checks
apply before provider arguments. Reachable unpowered searchers remain discoverable,
relay Network paths and allow `getLimits`, but searches fail `E_UNPOWERED`.
Restored power allows new calls. Captured methods cannot retarget a replacement.
There are no new events beyond ordinary peripheral attach/detach.

Programs should retain name/wire and wrap again next callback, not save facades as
Data. Console's existing symbolic bindings can be retained but still recheck live
authority. Query snapshots can be stored through computer state if independent
state limits permit. Ordinary cold load performs no query or source replay and
renews no spent tick credits; later queries read the currently installed catalogue.

The block follows ordinary rotation, mining, clone and wired-blueprint lifecycle,
with one logical drop and nonselectable private power helper. Back up saves and
matching mod ZIPs before upgrading: downgrading removes unknown new prototypes;
restore a pre-upgrade backup for lossless rollback. Existing Circuit Computers
research does not grant this separately researched recipe. Configuration repair
is additive and does not disable unrelated script-enabled recipes.

## Errors and example

Ordinary errors are catchable plain `{code,message,field?,peripheral?,device?}`;
do not parse messages. Fatal resource controls remain noncatchable.

| Condition | Code |
| --- | --- |
| Wrong arity/type, colon receiver or empty name | `E_ARGUMENT` |
| Unsupported product type, unknown product/category | `E_RANGE` |
| 51 filtered matches | `E_LIMIT`, `field="results"` |
| Input/result shape, strings or bytes exceed common bounds | `E_LIMIT`, never partial data |
| Metadata cannot be represented by the schema | `E_UNSUPPORTED` |
| Unpowered active search | `E_UNPOWERED` |
| Lost bound identity/path/force/surface | `E_UNREACHABLE` |
| Incomplete/oversized proof | Existing `E_NETWORK_PENDING` / `E_LIMIT` |
| Work/allocation exhausted | Fatal `E_BUDGET` |
| Native failure or missing force recipe | `E_ENGINE` |

Already consumed credits remain spent after refusal. Under pressure an earlier
budget error can precede a later semantic/count error.

Copy the complete [Recipe Searcher program](../examples.md#recipe-searcher-program),
then Validate → Save → Run. It searches iron plates, handles `E_LIMIT` with one
bounded smelting-category fallback and queries petroleum gas in chemistry. The
fallback is not a promise that every limit failure is count overflow, nor that a
modpack's smelting set fits. Let repeated refusal surface rather than retrying
without a bound.
