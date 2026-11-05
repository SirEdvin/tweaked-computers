---@meta

---This record summarizes native-target applicability. It is not a control-behavior handle.
---Discovery does not create a missing native control behavior only to inspect its capability.
---@class TC.ConfigurationSummary
---@field behavior? string Native behavior class, using the supported compatibility vocabulary.
---@field readable string[] Sorted readable root setting names, excluding currently unreadable fields.
---@field writable string[] Sorted currently writable root names, excluding native applicability refusals.
---@field sections boolean Whether the behavior supports constant-combinator sections.
---@field reason? string owned_mod_device_protected, no_supported_native_control_behavior, control_behavior_unset or no_writable_native_settings when applicable.

---This record gives a fresh complete target description.
---The ID is opaque, not coordinates. A replacement at the same location gets a new identity.
---Descriptions and settings can change while the identity stays the same.
---Nonconfigurable real targets remain in the inventory.
---@class TC.DeviceInfo
---@field id TC.DeviceId Current physical target identity.
---@field prototype string Exact entity prototype name.
---@field type string Native entity prototype type, not a peripheral family.
---@field position TC.Position Current native world position.
---@field surface TC.Surface Current native surface identity.
---@field direction string Native direction enum name. The value is not restricted to cardinal directions.
---@field quality string Current installed native entity quality name.
---@field target_wire TC.Wire Explicit selected TARGETS color, independent of the computer discovery wire.
---@field connected_connector_ids TC.WireConnectorId[] Sorted native connector enum names actually reached on that color.
---@field configurable boolean True when the current summary contains writable root settings.
---@field configuration TC.ConfigurationSummary Behavior/field applicability snapshot.

---This record defines one discriminator-dependent field set in a native-normalized schema.
---@class TC.ConfigurationVariant
---@field fields string[] Fields allowed for this operation in addition to its operation discriminator.
---@field required string[] Fields that must be supplied for this particular operation.

---This public normalized recursive field schema is not raw engine documentation JSON.
---Only keys applicable to kind are present. Enum values are symbolic strings,
---never host defines ordinals. The schema excludes internal native_enum/concept metadata.
---
---Required, readable, writable and clearable are independent properties.
---A recognized field can be unavailable in the current entity mode.
---That field includes its restriction reason.
---
---Known constraints include registered_signal, explicit_signal_type,
---condition_operand_exclusive, condition_signal_roles, operation_variant,
---logistic_mode_requester_or_buffer, fuel_inventory_required, rail_chain_signal_only,
---native_asteroid_no_logistic_connection, ammo_or_fluid_turret_required and
---set_requests_requires_space_travel. Section readback can also report
---nonmanual_section and shared_group_detach_first as unavailable_reason.
---@class TC.FieldSchema
---@field kind 'boolean'|'integer'|'number'|'string'|'enum'|'object'|'array'|'map'|'union' Normalized validation shape.
---@field readable boolean Whether this field can currently be read.
---@field writable boolean Whether this field can currently be set.
---@field clearable boolean Whether the field supports an explicit root patch clear, not implicit nil assignment.
---@field min? number Numeric lower bound where applicable.
---@field max? number Numeric upper bound where applicable.
---@field max_bytes? integer Maximum string bytes. Input identity strings must not contain NUL.
---@field max_items? integer Maximum dense-array entry count where applicable.
---@field values? string[] Accepted enum names where kind=enum.
---@field fields? table<string, TC.FieldSchema> Nested field schemas where kind=object.
---@field required? string[] Required object keys. The schema describes variant-required keys separately.
---@field additional_fields? false The schema refuses unknown object keys when this flag is present.
---@field items? TC.FieldSchema Array element schema.
---@field alternatives? TC.FieldSchema[] Union alternatives in normalization order.
---@field prototype_registry? string Installed prototype registry required for a normalized name string.
---@field constraints? string[] Additional machine-readable semantic/domain restrictions.
---@field variants? table<string, TC.ConfigurationVariant> Operation-discriminated field/required-key inventory.
---@field unavailable_reason? string Current native mode/entity/shared-scope restriction, when applicable.

---This record gives constant-combinator section allowances, not the complete Configurator limits.
---@class TC.SectionLimits
---@field sections integer Maximum supported native sections.
---@field section_filters integer Maximum supported native filter capacity/slot index.

---The schema always describes sections capability. The value supported=false does not authorize calls.
---@class TC.SectionCapabilities
---@field supported boolean True only for a supported constant-combinator behavior.
---@field fields table<string, TC.FieldSchema> Schemas for active, group, multiplier and filters.
---@field limits TC.SectionLimits Current section/count envelopes.

---This record describes live target capability, independent of a returned value snapshot.
---Native disabled and condition fulfilled values are observations only, never settings.
---Space-travel absence removes request-setting modes.
---Target subtype, fuel and mode restrictions remain visible.
---The record does not report these restrictions as an unimplemented adapter.
---@class TC.CapabilitySet
---@field api_version 1 Exact public schema version.
---@field behavior? string Supported native behavior class. This field is absent for unsupported or protected targets.
---@field settings table<string, TC.FieldSchema> All recognized root settings with live applicability metadata.
---@field observations table<string, TC.FieldSchema> Read-only disabled/condition-fulfilled observation schemas.
---@field sections TC.SectionCapabilities Current constant-section capability and envelopes.
---@field reason? string Current target/behavior applicability reason when supplied.

---This record gives a fresh normalized root snapshot.
---Values depend on the actual behavior, which TC.Config.Read.* describes.
---Unset roots are absent, not false. Getter normalization can fill native defaults
---and convert union inputs to objects. It does not apply the caller's
---256-byte/128-element input limits to native readback.
---
---Generic Data and configuration result limits still apply.
---Native objects and read-only condition members never appear inside writable values.
---@class TC.ConfigurationSnapshot
---@field values TC.Config.Read.Values Present normalized roots for the actual behavior, not all families at once.
---@field unset string[] Sorted readable root names whose normalized value is absent.
---@field observations table<string, boolean> Present native disabled and condition-name_fulfilled observations.

---This patch replaces whole roots. It does not recursively merge values.
---Omitted roots remain unchanged. An empty patch is a validated no-op/readback.
---Explicit nil table fields count as omitted fields, not clear requests.
---Use clear only when the current schema says clearable.
---@class TC.ConfigurationPatch
---@field set? TC.Config.Values Root replacements for the target's actual native behavior.
---@field clear? string[] Unique clearable root names. No name can overlap with set or identify a read-only or unknown field.

---A section patch uses the same explicit replacement convention.
---No section field supports clear. The clear field must be absent or empty.
---Otherwise, the patch causes E_READ_ONLY.
---@class TC.SectionPatch
---@field set? TC.Config.SectionValues Supported fields to replace. Omitted fields remain unchanged.
---@field clear? string[] Only an empty array is permitted. To clear filters, use set.filters={} instead.

---This record gives complete native section readback.
---The index is a position, not a stable identity.
---Removal of an earlier section shifts later indexes.
---The filter array contains occupied slots in native slot order.
---It includes sparse slot indexes explicitly.
---The native capacity filters_count is not the number of populated array entries.
---
---Nonmanual sections are readable but protected.
---Shared-group filters require explicit local detachment before writes.
---Multiplier readback preserves native float32 rounding.
---@class TC.SectionInfo
---@field index integer Native one-based current section index.
---@field type TC.LogisticSectionType Current native logistic-section enum name.
---@field is_manual boolean Whether native manual editing is permitted.
---@field active boolean Current section enabled state.
---@field group string Shared-group name. An empty name means local.
---@field multiplier number Finite native multiplier readback, not a decimal-rounding promise.
---@field filters TC.Config.Read.SectionFilter[] Complete populated normalized indexed filters.
---@field filters_count integer Native slot capacity, separately bounded by section_filters.
---@field capabilities table<string, TC.FieldSchema> Dynamic active/group/multiplier/filters capabilities and reasons.

---This API configures circuit control through the Configurator's separate TARGETS port.
---The discovery wire from computer to NETWORK and each target_wire argument
---are independent mandatory colors. Neither bridges circuits or discovery.
---The API follows only real physical connector paths with the same color, force and surface.
---Matching signal values, ghosts, isolated combinator ports, hidden radio transport
---and coordinates do not provide paths.
---
---The API supports ordinary same-color native relays.
---Owned helper entities stay hidden.
---Descriptions can identify public mod bodies as protected or nonconfigurable.
---
---### Schema and normalized values
---The generator uses the existing schema normalizer for TC.Config.*, not a second
---handwritten setting inventory. Inputs are finite plain objects, bounded arrays
---and exact registered prototype names. Inputs exclude native quality/location
---objects and the raw defines global. Signals require explicit type/name,
---except for documented SignalFilter string forms.
---The generated types describe quality/readback defaults and role-specific wildcards.
---
---Missing expansion prototypes fail validation instead of adding a hard dependency.
---The API exposes only circuit-control settings.
---It provides no arbitrary inventories, teleportation, creation, recipe execution,
---force edits or remote interface injection.
---Actual applicability governs generic/inherited and modded native behaviors,
---not a prototype-name whitelist.
---
---The API retains compatibility vocabulary on Factorio 2.1.
---The include_fuel name maps to read_fuel, and messages maps to records.
---Container/landing-pad mode can represent both read/request switches as send_contents_and_set_requests.
---Tank read_contents=true retains an existing segment-read mode.
---The value false disables reading.
---Documentation generation does not change these mappings or expand the available native setting set.
---
---### Atomic update and lifetime
---Before mutation, the API checks the whole patch, current identity/path,
---prototypes/schema, capacity and work. Setters run in deterministic native-safe order.
---The simulation does not advance between setters. Exact native readback follows.
---Invalid fields, invalid variants, read-only values or broken invariants cause
---failure before target changes.
---
---After unexpected native failure, the adapter attempts target-local restoration.
---Failed restoration retains recovery state
---and faults that target adapter with E_ENGINE. It never reports false success.
---Only an admitted nonempty update authorizes creation of a missing behavior.
---Recovery cannot necessarily delete a native-created default behavior.
---Recovery does not roll back external effects or earlier successful calls.
---
---This is last-successful-write, not a lock/CAS.
---Player edits remain authoritative until a later explicit write.
---Stop, disconnect, read, reconnect and cold load do not undo or re-enforce
---factory settings that were already applied.
---
---The custom Configurator needs no electricity. Every call retains exact identity,
---force/surface and discovery/target path authority.
---Captured facades never retarget a replacement.
---Unsupported retained recovery remains visible. A read does not reset it.
---@class TC.Configurator
local Configurator = {}

---Enumerate the complete target network once per exact identity, sorted by ID.
---The result includes unsupported and nonconfigurable real devices with reasons.
---Incomplete proof, size refusal or work refusal causes an error, never a successful partial list.
---@param target_wire TC.Wire Required TARGETS color, distinct from discovery wire.
---@return TC.DeviceInfo[] devices One complete detached sorted array, possibly empty.
function Configurator.getDevices(target_wire) end

---Look up one exact current target identity. Never use coordinates as identity.
---@param device_id TC.DeviceId Opaque previously discovered target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.DeviceInfo|nil device Exactly one description or one nil if missing/off this target network.
function Configurator.getDevice(device_id, target_wire) end

---Read live applicability and complete recursive schemas.
---This method does not create native behavior.
---A stale identity or path causes failure instead of fabricated capability.
---@param device_id TC.DeviceId Exact current target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.CapabilitySet capabilities One defensive current schema/applicability record.
function Configurator.getCapabilities(device_id, target_wire) end

---Read current normalized values, sorted unset roots and separate observations.
---False, missing and read-only are distinct. A read does not create behavior.
---@param device_id TC.DeviceId Exact current target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.ConfigurationSnapshot snapshot One complete defensive readback, not a lock.
function Configurator.getConfiguration(device_id, target_wire) end

---This method validates whole-root replacements before it applies them atomically
---with native readback. Unknown roots/nested fields, repeated clear/set overlap,
---unsupported domains and mode invariants cause refusal before mutation.
---Clear can normalize to native defaults, not nil.
---E_READ_ONLY protects observations, protected targets and nonclearable fields.
---E_UNSUPPORTED applies to native applicability.
---
---Generic admission and fatal budgets remain unchanged.
---See Configurator lifecycle notes for native recovery limits.
---@param device_id TC.DeviceId Exact current target ID.
---@param patch TC.ConfigurationPatch Entire candidate patch. An empty patch is a checked no-op/readback.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.ConfigurationSnapshot snapshot One actual normalized post-update readback.
function Configurator.setConfiguration(device_id, patch, target_wire) end

---Read complete native sections. This method does not create control behavior.
---Only compatible constant combinators support this method.
---Other types cause E_UNSUPPORTED. Owned targets cause E_READ_ONLY.
---A native count or filter capacity beyond supported envelopes causes E_LIMIT.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.SectionInfo[] sections Complete native-index-ordered array, possibly empty.
function Configurator.getSections(device_id, target_wire) end

---Create a manual section. The method returns the actual native index, not a guessed length.
---The defaults are active=true, group='', multiplier=1 and local filters={}.
---A nonempty group joins its shared data instead of creating empty filters.
---If you supply filters while joining a nonempty group, the method raises E_SHARED_SCOPE.
---The method never truncates existing sections.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param definition TC.Config.SectionValues Whole new section definition with documented defaults.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return integer section_index Actual positive native index after successful readback.
function Configurator.addSection(device_id, definition, target_wire) end

---Replace selected section fields with full preflight, rollback and readback.
---A missing section causes E_NOT_FOUND. A nonmanual section causes E_READ_ONLY.
---
---The method never writes shared contents. Filters require final group=''.
---For detachment, supply group='' explicitly.
---Detachment preserves the current effective filters before any explicit replacement.
---
---The method does not silently detach or overwrite a group outside its scope.
---An empty patch still checks manual authority.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param section_index integer Current native index in 1..4294967295. Enumerate the sections again after removals.
---@param patch TC.SectionPatch Explicit supported replacements. The clear array must not be nonempty.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.SectionInfo section One actual complete post-update native readback.
function Configurator.setSection(device_id, section_index, patch, target_wire) end

---Remove one present manual section with target-local recovery and readback.
---A present nonmanual section causes E_READ_ONLY, not false.
---Later native indexes shift. The API supplies no saved section handle or identity.
---Failed native restoration retains recovery state.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param section_index integer Native index in 1..4294967295. A missing valid index is ordinary absence.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return boolean removed True when removed; false if that valid index was already absent.
function Configurator.removeSection(device_id, section_index, target_wire) end

---Read effective common limits plus target traversal, configuration, patch and section envelopes.
---Actual native domains and current capabilities still constrain calls.
---@return TC.ConfiguratorLimits limits One defensive current limit map.
function Configurator.getLimits() end
