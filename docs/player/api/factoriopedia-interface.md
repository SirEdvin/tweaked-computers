# Factoriopedia Interface

This page documents the feature implementation, not a release announcement. Use
a build containing the interface; the older installation examples do not add it
to already published archives.

A read-only catalogue of installed item and fluid prototypes, including modded,
hidden and blueprint-parameter entries. It does not open or replace native
Factoriopedia, search recipes, craft anything or inspect a live inventory.

## Setup

Research **Recipe Searcher** (`tc-recipe-searcher`). This unlocks both devices;
Circuit Computers alone does not unlock the interface. Craft one interface from
10 steel plates, 5 advanced circuits and 2 processing units (2 seconds).
Place its 1×1 body, supply 30 kW, and connect its Network contacts directly to a
computer's Network on red or green. Ordinary opening shows copyable identity and
power status only; there is no catalogue-browser panel. No item/fluid input is needed.

## Methods

Use dot calls, exact case-sensitive nonempty prototype IDs, and an explicit wire.
Each method returns exactly one value. Extra arguments, including nil, are refused.

| Method | Result |
| --- | --- |
| `getItem(name)` | Item record in the item namespace, including subtypes |
| `getFluid(name)` | Fluid record in the fluid namespace |
| `listItems()` | Complete dense item-name array, ascending bytewise order |
| `listFluids()` | Complete dense fluid-name array, ascending bytewise order |
| `getLimits()` | Current common resource allowances; available without peripheral power |

Equal item/fluid names remain independent. Alternative Factoriopedia entries are
reported, never followed. Research and surface do not filter the catalogue.

## Records

Every record has `type` (`item` or `fluid`), `name`, `prototype_type`, `group`,
`subgroup`, `order` (strings); `hidden`, `hidden_in_factoriopedia`, `parameter`
(booleans); and optional `factoriopedia_alternative` (prototype name).
The subtype can be `ammo`, `tool`, etc., not merely `item`.

Item records also have:

| Field | Meaning |
| --- | --- |
| `stack_size` | Positive integer native stack size |
| `stackable` | Native boolean |
| `weight` | Finite nonnegative resolved native weight, unchanged engine units |
| `default_rocket_lift_weight` | Positive installed reference lift weight, same units |
| `rocket_capacity` | Whole individual items: floor(reference lift / weight); absent only at zero weight |
| `fuel_value` | Joules per item; zero for nonfuel |
| `fuel_categories` | Native-order dense name array; empty when absent natively |
| `burnt_result` | Optional burnt-result item name |
| `spoil_ticks` | Normal-quality lifetime in simulation ticks; zero means no spoilage |
| `quality_affects_spoil_ticks` | Native boolean; interface quality never selects query quality |
| `spoil_result` | Optional item name; trigger spoilage may have no item result |
| `place_result` | Optional placed entity name, not generalized tile/equipment placement |
| `default_import_location` | Optional native location name; no invented Nauvis fallback |

Rocket capacity is a reference mass count, not a stack count, stack-rounded load,
particular silo's capacity, free space or a guarantee of launch feasibility.
Overweight positive-weight items have count zero; zero-weight items omit the count
rather than returning infinity or a sentinel. `send_to_orbit_mode` does not filter
platform cargo metadata. Fields are baseline prototype metadata, not stack tags,
remaining freshness, current count or a quality variant.

Fluid records instead add:

| Field | Meaning |
| --- | --- |
| `default_temperature` | Native default **and minimum**, degrees Celsius |
| `max_temperature` | Native maximum, degrees Celsius |
| `gas_temperature` | Native visual gas threshold, degrees Celsius; not a production temperature |
| `heat_capacity` | Joules per fluid unit per degree Celsius |
| `fuel_value` | Joules per fluid unit; zero preserved |
| `emissions_multiplier` | Finite nonnegative native multiplier |

Negative/equal finite temperatures are preserved. There is no redundant
`min_temperature`, live tank temperature or obtainable-temperature catalogue.
All references are names; no native objects, localized strings or functions escape.
Editing any returned map/array cannot change later results or the factory.

## Failures and limits

Calls recheck bound identity, same force/surface, explicit-color Network path and
power. Unpowered devices remain discoverable/passive relays; only `getLimits()`
is power-exempt. Captured methods never retarget a replacement.

`E_ARGUMENT` means invalid arity/type/empty name; `E_RANGE` with `field="name"`
means an unknown exact name; `E_UNSUPPORTED` means required metadata cannot be
represented as finite Data; `E_ENGINE` means native metadata access failed.
Existing `E_UNPOWERED`, `E_UNREACHABLE`, network and retired-run errors apply.
Authority, input admission and power may fail before semantic name validation.

Results use existing common Data/work/allocation limits, not a new catalogue quota.
The baseline `table_entries=1024`, `data_nodes`, `data_depth`, `string_bytes` and
`peripheral_call_bytes` still apply. A large modpack's whole list can raise
`E_LIMIT` even when affordable individual lookups succeed. No prefix, pagination,
cache or background index is returned. Work/allocation exhaustion is fatal
`E_BUDGET`, not made catchable here; never retry a permanent refusal in a tight loop.
Work units do not establish native CPU/memory upper bounds.

## Example

Paste the complete [Factoriopedia program](../examples.md#factoriopedia-program).
It logs iron-plate stack/reference count, water temperature bounds and both name
lists (or their complete-list Data refusal). A zero-weight item's count is absent;
programs must test `rocket_capacity ~= nil` rather than assume it exists.
Retaining snapshots with computer state uses that separate storage allowance.
Cold load preserves snapshots and identities without replaying query/start handlers.
