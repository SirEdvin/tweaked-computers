# Factoriopedia Interface Lua API

This is the companion contract for [the capability](spec.md). It describes the proposed guest API, not an implemented or engine-verified feature.

## Discovery and method inventory

Peripheral type: `factoriopedia_interface`. Research Recipe Searcher, craft a `tc-factoriopedia-interface`, supply 30 kW and connect its Network body directly to a computer's red or green Network path.

Use dot calls. The closed method inventory is:

| Method | Arguments | Successful return |
| --- | --- | --- |
| `getItem(name)` | Exactly one string | One Item record |
| `getFluid(name)` | Exactly one string | One Fluid record |
| `listItems()` | None | One dense array of item-name strings |
| `listFluids()` | None | One dense array of fluid-name strings |
| `getLimits()` | None | One detached map of current common limits |

The four agreed feature methods are accompanied by the existing common `getLimits()` convention. No optional quality, filter, page, cursor, bulk-detail, recipe or entity argument is accepted. Passing an explicit extra nil still changes arity. The underlying same-force/surface, explicit-color, identity and power checks remain mandatory.

## Names and catalogue scope

- A name is an exact, case-sensitive, nonempty installed prototype ID. No trimming, case folding, aliases, localized lookup or fuzzy search occurs.
- `getItem` and `listItems` use the item namespace, including native item subtypes such as ammo or tools. `getFluid` and `listFluids` use only the fluid namespace. Equal names in different namespaces remain independent.
- All installed entries participate, including hidden, Factoriopedia-hidden, blueprint-parameter and modded entries. This is structured source metadata, not a promise to mirror Factoriopedia's visible page list.
- A Factoriopedia alternative is reported by name when present; it is never followed to replace the requested record.
- Research, recipe enabled state and the computer's planet/surface do not filter results. Availability to query the peripheral is still subject to ordinary network and power authority.
- Name lists are unique, complete, bytewise name-sorted arrays, possibly empty. They contain no detail records. Returned order is not localized alphabetical order or prototype `order`.

## Common record fields

All fields in this table are required unless marked optional. `false`, zero and empty strings/arrays are preserved where meaningful. Native references are projected to names; no native object escapes.

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | Literal `"item"` or `"fluid"`, the lookup namespace |
| `name` | string | The exact requested installed prototype name |
| `prototype_type` | string | Native prototype subtype; an item need not have subtype `"item"` |
| `group` | string | Native group name |
| `subgroup` | string | Native subgroup name |
| `order` | string | Native ordering string, possibly empty; not a list sorting rule |
| `hidden` | boolean | Native hidden flag |
| `hidden_in_factoriopedia` | boolean | Native Factoriopedia visibility flag |
| `parameter` | boolean | Native blueprint-parameter flag |
| `factoriopedia_alternative` | string, optional | Alternative display prototype name in the same namespace; absent when none exists |

Localized strings, rendered icons, custom tooltip fields, Factoriopedia simulations and arbitrary prototype properties are not returned. A locale-independent computer API does not select an implicit viewing player's language.

## Item record

Item records add the following fields to the common record.

| Field | Type | Meaning |
| --- | --- | --- |
| `stack_size` | positive integer | Native maximum item stack size |
| `stackable` | boolean | Whether the native item is allowed to stack |
| `weight` | finite nonnegative number | Resolved native `Weight`, in unchanged engine units; not a guessed recipe-based weight or a formatted kilogram string |
| `default_rocket_lift_weight` | finite positive number | Installed reference lift weight, in the same native units as `weight` |
| `rocket_capacity` | nonnegative integer, optional | Reference mass-limited count of individual items; absent only when `weight == 0` |
| `fuel_value` | finite nonnegative number | Native fuel energy in joules per item; preserve zero for nonfuel items |
| `fuel_categories` | dense string array | Native 2.1 fuel categories, copied in native order; empty when the optional native array is absent |
| `burnt_result` | string, optional | Native item name left after burning; absent when none exists |
| `spoil_ticks` | nonnegative integer | Native spoil lifetime in simulation ticks at normal quality; zero means no spoilage |
| `quality_affects_spoil_ticks` | boolean | Whether quality affects the native spoil lifetime |
| `spoil_result` | string, optional | Native item spoil-result name; absence alone does not mean the item cannot spoil, because trigger-based outcomes can exist |
| `place_result` | string, optional | Native entity name placed by this item; not a generalized equipment/tile/seed placement description |
| `default_import_location` | string, optional | Native location name when a location reference is available; never an invented Nauvis fallback |

No actual stack count, tags, remaining freshness, physical inventory state, quality-specific variant or subtype-specific combat/equipment/module configuration is returned. Placement/import names are references only; they do not introduce entity or location lookup methods.

### Rocket-count semantics

For `weight > 0`:

    rocket_capacity = floor(default_rocket_lift_weight / weight)

This is the whole-item mass capacity of the installed reference rocket, assuming its mass budget contains only this item. It is not a stack count, and it is not rounded down to complete stack multiples. `stack_size` remains an independent field.

- Use the resolved native item weight, including engine calculation and mod changes. Do not reimplement the recipe-to-weight algorithm.
- Use the installed native utility constant, not a hardcoded default mass or a particular entity's lift weight.
- A positive-weight item heavier than the reference rocket has count zero.
- A zero-weight item has no finite mass-limited count; omit `rocket_capacity` while retaining `weight=0`. Do not use zero, infinity, NaN or an enormous sentinel as a substitute.
- Negative/nonfinite weight, nonpositive/nonfinite reference lift weight, or a derived count that cannot be represented as an exact finite Lua integer raises `E_UNSUPPORTED`; these are representability rules, not a new configurable quota.
- Do not clamp to a silo inventory's slots, its existing cargo, launch conditions, platform destination or force research. A reference count does not guarantee launchability.
- The native `send_to_orbit_mode` controls a different launch-to-orbit behavior and must not be used as a platform-cargo eligibility filter or a reason to zero this reference count.

The intended ordinary-item behavior matches the pinned client's reference Rocket capacity presentation. Native comparison of representative and fractional-weight cases is mandatory before release. If the engine disagrees with the specified count semantics, retain the failing evidence and review the contract rather than hiding the mismatch behind rounding epsilons or changing values silently.

### Quality semantics

The one-name API deliberately has no quality selector. Static prototype fields are read directly; `spoil_ticks` is obtained explicitly for `"normal"`. The peripheral's own quality never chooses the metadata quality. This is a baseline prototype catalogue, not every quality-specific Factoriopedia variant.

## Fluid record

Fluid records add these required fields to the common record.

| Field | Type | Meaning |
| --- | --- | --- |
| `default_temperature` | finite number | Native default and minimum temperature in degrees Celsius |
| `max_temperature` | finite number | Native maximum temperature in degrees Celsius |
| `gas_temperature` | finite number | Native visual gas-animation threshold in degrees Celsius; not a promised boiling point or production temperature |
| `heat_capacity` | finite nonnegative number | Joules to heat one native fluid unit by one degree Celsius |
| `fuel_value` | finite nonnegative number | Joules per native fluid unit when used as fuel; preserve zero |
| `emissions_multiplier` | finite nonnegative number | Native fuel emissions multiplier |

`default_temperature` is also the native minimum, so there is no redundant `min_temperature` alias. Preserve negative finite bounds, equal default/maximum values and the engine's finite default gas threshold. Do not replace large finite thresholds with infinity or nil.

These describe the fluid itself, not the current temperature in a tank, the temperatures available from recipes/boilers, recipe ingredient bounds, a thermodynamic simulation or an enumeration of achievable temperatures. Fluids do not receive item stack, spoilage or rocket fields. Recipe output/ingredient temperatures remain the responsibility of Recipe Searcher.

## Completeness, ownership and limits

Every successful return is finite, detached plain Data. A caller can edit it without modifying native state or a later return. No native prototype object, `LuaCustomTable`, iterator, function, metatable, translation request or saved query handle is exposed.

`getLimits()` reports the current common limits without a feature-specific count field. The existing `table_entries`, `data_nodes`, `data_depth`, `string_bytes`, `peripheral_call_bytes`, allocation and work rules continue to apply. The inspected baseline has `table_entries=1024`; this is an existing generic Data boundary, not a newly proposed catalogue quota or a guaranteed list size. Bytes/work can refuse a smaller list. A sufficiently large modpack can therefore make a complete name-list call fail even while individual exact-name lookups remain usable.

There is no pagination, truncation, cache, persisted index or asynchronous job. Failure returns no successful prefix or partial count. Programs should request lists only when needed; they must not retry the same permanent size failure in a tight loop. Native catalogue access/materialization has engine-owned costs: metered Lua work is not a proven native CPU-time or memory upper bound.

Work, allocation, error handling, shared scheduling and already-spent tick credits retain their existing behavior. In particular, `E_BUDGET` is fatal and not made catchable by this provider. The circuit-only large-native-array exception is not generalized to catalogue lists by this change.

## Authority, power and persistence

All methods, including `getLimits`, recheck current same-force/surface, explicit-color path and bound generation. `getLimits` is the only power-exempt method. Reachable unpowered interfaces remain discoverable and passive network relays; the four catalogue methods raise `E_UNPOWERED`.

Queries have no world effects and require no persistent per-device catalogue state. New calls read the installed prototypes; already returned snapshots do not update themselves. Storing a snapshot through computer state remains subject to that independent storage allowance. Store name/wire for later rediscovery rather than treating an ephemeral facade as plain Data; retained Console symbolic bindings still revalidate live authority.

Ordinary load does not query, rebuild a catalogue, run guest start handlers or renew work credits. New entities receive new identities; a stale captured method never addresses a replacement at the same coordinates.

## Errors

Ordinary errors use the existing plain `{code, message, field?, peripheral?, device?}` shape. Programs should branch on `code`, not message text.

| Condition | Error |
| --- | --- |
| Wrong arity, colon receiver, wrong argument type, empty name | `E_ARGUMENT` |
| Unknown exact item/fluid name | `E_RANGE`, `field="name"` |
| Arguments or complete result exceed an existing Data/string allowance | `E_LIMIT`; never a successful prefix |
| Nonfinite/unrepresentable metadata or unsupported required native representation | `E_UNSUPPORTED` |
| Active catalogue call without power | `E_UNPOWERED` |
| Bound peripheral removed, replaced or no longer reachable in its scope | `E_UNREACHABLE` |
| Network proof pending or over its existing allowance | Existing `E_NETWORK_PENDING` / `E_LIMIT` |
| Retired or otherwise unauthorized calling computer run | Existing `E_NOT_FOUND` |
| Native metadata access raises an engine error | `E_ENGINE` |
| Work or allocation credits exhausted | Fatal `E_BUDGET` |

Input Data admission occurs before provider validation; current authority and power checks precede provider semantic checks. Thus an earlier Data, authority, power or budget failure can take precedence over an invalid name. Fatal budget poison must not be caught and translated to `E_ENGINE` by a native-access wrapper.

## Guest example

This document is proposed example source to be exercised through the real compiler and packaged provider during implementation; it is not an execution receipt. On a fresh base or Space Age game, research Recipe Searcher, connect a powered interface on red, and run:

```lua
return {
    api_version = 1,
    handlers = {
        start = function(event)
            local encyclopedia = peripheral.find("factoriopedia_interface", "red")
            assert(encyclopedia, "Connect a powered Factoriopedia Interface on red")

            local item = encyclopedia.getItem("iron-plate")
            computer.log(item.name .. " stack size=" .. tostring(item.stack_size))
            if item.rocket_capacity ~= nil then
                computer.log("Reference items per rocket=" .. tostring(item.rocket_capacity))
            else
                computer.log("No finite mass-limited rocket count")
            end

            local fluid = encyclopedia.getFluid("water")
            computer.log(fluid.name .. " temperature="
                .. tostring(fluid.default_temperature) .. ".."
                .. tostring(fluid.max_temperature) .. " C")

            local function reportNames(method, label)
                local ok, result = pcall(method)
                if ok then
                    computer.log(label .. ": " .. tostring(#result))
                elseif type(result) == "table" and result.code == "E_LIMIT" then
                    computer.log(label .. ": complete list exceeds shared Data limits")
                else
                    error(result)
                end
            end
            reportNames(encyclopedia.listItems, "Installed item names")
            reportNames(encyclopedia.listFluids, "Installed fluid names")
        end
    }
}
```

Tests must separately exercise the absent-count branch with a genuine zero-weight fixture item, both namespace lists, invalid arguments and refusal. The ordinary iron-plate example alone does not cover those boundaries.
