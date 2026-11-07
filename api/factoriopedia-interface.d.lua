---@meta

---This record gives common locale-independent native metadata, with references
---projected to names. It retains required false, zero and empty values.
---It exposes no icons, LocalisedStrings, tooltips, simulations, native objects or
---implicit player language.
---@class TC.PrototypeInfo
---@field type TC.ProductType Lookup namespace, not native item subtype.
---@field name string Exact requested installed prototype name.
---@field prototype_type string Native subtype. An item does not require subtype item.
---@field group string Native group name.
---@field subgroup string Native subgroup name.
---@field order string Native order string, possibly empty. This is not API list sorting order.
---@field hidden boolean Native hidden flag.
---@field hidden_in_factoriopedia boolean Native Factoriopedia visibility flag.
---@field parameter boolean Native blueprint-parameter flag.
---@field factoriopedia_alternative? string Optional same-namespace alternative name. The API never follows this alternative automatically.

---This record gives baseline item metadata, not an inventory stack or every quality-specific variant.
---Static native fields are direct. The spoil_ticks field explicitly uses normal
---quality, independent of the peripheral's own quality.
---The record adds no tags, current count, freshness, combat/module/equipment details
---or entity/location lookups.
---
---For positive weight, rocket_capacity=floor(default_rocket_lift_weight/weight).
---This count uses individual items, not stacks. It does not round to complete stack multiples.
---Use resolved native weight and installed utility reference lift weight.
---Never reimplement recipe weights. An overweight item has capacity zero.
---
---Zero weight has no finite capacity, so the record omits the field.
---Invalid weights/reference mass or inexact/nonfinite derived counts cause
---E_UNSUPPORTED, never clamped sentinels.
---The count does not inspect a particular rocket/silo, slots/cargo, launch state,
---destination, research or send_to_orbit_mode. It is not launchability permission.
---@class TC.ItemInfo: TC.PrototypeInfo
---@field type 'item' Exact item-namespace discriminator.
---@field stack_size integer Positive native maximum stack size.
---@field stackable boolean Whether native stacking is permitted.
---@field weight number Finite nonnegative resolved native Weight, unchanged engine units.
---@field default_rocket_lift_weight number Finite positive installed reference mass in the same units.
---@field rocket_capacity? integer Nonnegative exact mass-limited individual-item count. This field is absent only at zero weight.
---@field fuel_value number Finite nonnegative joules per item. Nonfuel items have zero fuel value.
---@field fuel_categories string[] Native ordered 2.1 fuel categories, empty when absent natively.
---@field burnt_result? string Optional native item left after burning.
---@field spoil_ticks integer Nonnegative normal-quality lifetime in simulation ticks. Zero means no spoilage.
---@field quality_affects_spoil_ticks boolean Whether native quality changes spoil lifetime.
---@field spoil_result? string Optional spoil-result item. Absence does not exclude trigger-based spoilage.
---@field place_result? string Optional placed entity name, not generalized tile/equipment/seed placement.
---@field default_import_location? string Optional native location reference. The API never invents a Nauvis default.

---This record gives fluid metadata, not a tank's temperature or achievable recipe/boiler states.
---It preserves finite negative/equal temperature bounds and large finite gas thresholds.
---The default_temperature field is also the native minimum, with no extra alias.
---No item weight, stack, rocket or spoilage fields appear on this record.
---@class TC.FluidInfo: TC.PrototypeInfo
---@field type 'fluid' Exact fluid-namespace discriminator.
---@field default_temperature number Finite default/minimum degrees Celsius.
---@field max_temperature number Finite maximum degrees Celsius.
---@field gas_temperature number Finite native gas-animation threshold in Celsius, not promised boiling point.
---@field heat_capacity number Finite nonnegative joules per native fluid unit per degree Celsius.
---@field fuel_value number Finite nonnegative joules per native fluid unit. Zero remains zero.
---@field emissions_multiplier number Finite nonnegative native fuel-emissions multiplier.

---This API provides a read-only catalog of installed items and fluids.
---The catalog includes hidden, Factoriopedia-hidden, parameter and modded prototypes.
---Native item subtypes share the item namespace.
---Items and fluids with the same name remain distinct.
---Research and current surface never filter metadata.
---The API reports alternatives, but does not follow them.
---
---There is no quality, filter, page, cursor, bulk-detail, recipe or entity argument.
---An explicit extra nil is still incorrect arity.
---
---The custom interface needs no electricity.
---Each call, including getLimits, checks the exact bound identity/generation,
---force/surface and selected physical color again.
---New placement never retargets an old facade.
---Console-restored bindings have the same live checks.
---Ordinary load runs no query, rebuild, guest startup or credit renewal.
---
---Methods have no world effects or per-device catalog state, cache or query session.
---Each result is detached finite Data.
---Mutation cannot change native state or a later return.
---Persisted copies still need their separate state allowance.
---
---### Completeness and failure
---Full sorted lists can fail existing table/node/depth/string/result-byte and
---shared host-work limits even when exact-name lookup fits.
---The API adds no catalog quota, pagination, successful prefix, truncation or asynchronous index.
---The native circuit transfer exception does not apply.
---Native materialization costs do not establish CPU or heap bounds.
---Do not busy-retry permanent size failures.
---
---Incorrect types, incorrect arity or an empty name cause E_ARGUMENT.
---An unknown name causes E_RANGE with field='name'.
---An exceeded envelope causes E_LIMIT.
---Unrepresentable or nonfinite metadata causes E_UNSUPPORTED.
---Native access failure causes E_ENGINE, never invented values.
---
---Physical failures retain E_UNREACHABLE/E_NETWORK_PENDING/E_LIMIT.
---A retired caller causes E_NOT_FOUND.
---Fatal E_BUDGET bypasses ordinary error handling.
---Input, authority and work admission can precede provider validation.
---No catalog method has an electrical E_UNPOWERED.
---@class TC.FactoriopediaInterface
local Interface = {}

---Read one exact installed item/subtype record. Unknown names cause errors, not nil.
---@param name string Required nonempty case-sensitive internal item ID within string_bytes.
---@return TC.ItemInfo item One detached baseline item record.
function Interface.getItem(name) end

---Read one exact installed fluid record. Unknown names cause errors, not nil.
---@param name string Required nonempty case-sensitive internal fluid ID within string_bytes.
---@return TC.FluidInfo fluid One detached baseline fluid record.
function Interface.getFluid(name) end

---List every installed item name once, sorted bytewise, including hidden items.
---The result has no details, localization ordering, aliasing, fuzzy lookup or silent truncation.
---@return string[] names One complete dense name array. An empty array is valid. The result is never nil.
function Interface.listItems() end

---List every installed fluid name once in ascending bytewise order.
---@return string[] names One complete dense name array, possibly empty.
function Interface.listFluids() end

---Read current common limits. The result adds no feature-specific count field.
---@return TC.Limits limits One independent effective common limit map.
function Interface.getLimits() end
