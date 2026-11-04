---@meta

---Common locale-independent native metadata, with references projected to names.
---Required false/zero/empty values are retained. No icons, LocalisedStrings,
---tooltips, simulations, native objects or implicit player language are exposed.
---@class TC.PrototypeInfo
---@field type TC.ProductType Lookup namespace, not native item subtype.
---@field name string Exact requested installed prototype name.
---@field prototype_type string Native subtype; an item need not have subtype item.
---@field group string Native group name.
---@field subgroup string Native subgroup name.
---@field order string Native order string, possibly empty; not API list sorting order.
---@field hidden boolean Native hidden flag.
---@field hidden_in_factoriopedia boolean Native Factoriopedia visibility flag.
---@field parameter boolean Native blueprint-parameter flag.
---@field factoriopedia_alternative? string Optional same-namespace alternative name; never followed automatically.

---Baseline item metadata, not an inventory stack or every quality-specific
---variant. Static native fields are direct; spoil_ticks explicitly uses normal
---quality, independent of the peripheral's own quality. No tags, current count,
---freshness, combat/module/equipment details or entity/location lookups are added.
---
---For positive weight, rocket_capacity=floor(default_rocket_lift_weight/weight),
---in individual items, not stacks and not rounded to complete stack multiples.
---Use resolved native weight and installed utility reference lift weight; never
---reimplement recipe weights. An overweight item has capacity zero; zero weight
---has no finite capacity and omits the field. Invalid weights/reference mass or
---inexact/nonfinite derived counts are E_UNSUPPORTED, never clamped sentinels.
---The count does not inspect a particular rocket/silo, slots/cargo, launch state,
---destination, research or send_to_orbit_mode; it is not launchability permission.
---@class TC.ItemInfo: TC.PrototypeInfo
---@field type 'item' Exact item-namespace discriminator.
---@field stack_size integer Positive native maximum stack size.
---@field stackable boolean Whether native stacking is permitted.
---@field weight number Finite nonnegative resolved native Weight, unchanged engine units.
---@field default_rocket_lift_weight number Finite positive installed reference mass in the same units.
---@field rocket_capacity? integer Nonnegative exact mass-limited individual-item count; absent only at zero weight.
---@field fuel_value number Finite nonnegative joules per item; zero for nonfuel.
---@field fuel_categories string[] Native ordered 2.1 fuel categories, empty when absent natively.
---@field burnt_result? string Optional native item left after burning.
---@field spoil_ticks integer Nonnegative normal-quality lifetime in simulation ticks; zero means no spoilage.
---@field quality_affects_spoil_ticks boolean Whether native quality changes spoil lifetime.
---@field spoil_result? string Optional spoil-result item; absence does not exclude trigger-based spoilage.
---@field place_result? string Optional placed entity name, not generalized tile/equipment/seed placement.
---@field default_import_location? string Optional native location reference; never an invented Nauvis default.

---Fluid metadata, not a tank's temperature or achievable recipe/boiler states.
---Finite negative/equal temperature bounds and large finite gas thresholds are
---preserved; default_temperature is also native minimum, with no extra alias.
---No item weight, stack, rocket or spoilage fields appear on this record.
---@class TC.FluidInfo: TC.PrototypeInfo
---@field type 'fluid' Exact fluid-namespace discriminator.
---@field default_temperature number Finite default/minimum degrees Celsius.
---@field max_temperature number Finite maximum degrees Celsius.
---@field gas_temperature number Finite native gas-animation threshold in Celsius, not promised boiling point.
---@field heat_capacity number Finite nonnegative joules per native fluid unit per degree Celsius.
---@field fuel_value number Finite nonnegative joules per native fluid unit; preserve zero.
---@field emissions_multiplier number Finite nonnegative native fuel-emissions multiplier.

---Read-only installed item/fluid catalogue, including hidden, Factoriopedia-hidden,
---parameter and modded prototypes. Native item subtypes share the item namespace;
---equal item/fluid names remain distinct. Research and current surface never filter
---metadata. Alternatives are reported, not followed. No quality/filter/page/cursor,
---bulk-detail/recipe/entity argument exists; explicit extra nil is still wrong arity.
---
---Custom interface needs no electricity. Each call, including getLimits, rechecks
---exact bound identity/generation, force/surface and selected physical color. New
---placement never retargets an old facade. Console-restored bindings have the same
---live checks; ordinary load runs no query/rebuild/guest startup or credit renewal.
---Methods have no world effects or per-device catalogue state/cache/query session.
---Each result is detached finite Data: mutation cannot change native state or a
---later return. Persisted copies still need their separate state allowance.
---
---### Completeness and failure
---Full sorted lists may fail existing table/node/depth/string/result-byte and work/
---allocation budgets even when exact-name lookup fits. No new catalogue quota,
---pagination, successful prefix, truncation or asynchronous index is introduced.
---The native circuit transfer exception does not apply. Native materialization
---costs are not bounded CPU/heap claims; do not busy-retry permanent size failures.
---Wrong types/arity/empty name: E_ARGUMENT. Unknown name: E_RANGE field='name'.
---Over-envelope: E_LIMIT. Unrepresentable/nonfinite metadata: E_UNSUPPORTED.
---Native access failure: E_ENGINE, never invented values. Physical failures retain
---E_UNREACHABLE/E_NETWORK_PENDING/E_LIMIT; retired caller E_NOT_FOUND. Fatal
---E_BUDGET bypasses ordinary error handling; input/authority/work admission may
---precede provider validation. No catalogue method has an electrical E_UNPOWERED.
---@class TC.FactoriopediaInterface
local Interface = {}

---Read one exact installed item/subtype record; unknown names are errors, not nil.
---@param name string Required nonempty case-sensitive internal item ID within string_bytes.
---@return TC.ItemInfo item One detached baseline item record.
function Interface.getItem(name) end

---Read one exact installed fluid record; unknown names are errors, not nil.
---@param name string Required nonempty case-sensitive internal fluid ID within string_bytes.
---@return TC.FluidInfo fluid One detached baseline fluid record.
function Interface.getFluid(name) end

---List every installed item name once, sorted bytewise, including hidden items.
---No details, localization ordering, aliasing, fuzzy lookup or silent truncation.
---@return string[] names One complete dense name array; empty is valid, never nil.
function Interface.listItems() end

---List every installed fluid name once in ascending bytewise order.
---@return string[] names One complete dense name array, possibly empty.
function Interface.listFluids() end

---Read current common limits; no feature-specific count field is added.
---@return TC.Limits limits One independent effective common limit map.
function Interface.getLimits() end
