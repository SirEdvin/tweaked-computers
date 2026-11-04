---@meta

---Native-target applicability summary, not a control-behavior handle. Discovery
---does not create a missing native control behavior just to inspect its capability.
---@class TC.ConfigurationSummary
---@field behavior? string Native behavior class, using the supported compatibility vocabulary.
---@field readable string[] Sorted readable root setting names, excluding currently unreadable fields.
---@field writable string[] Sorted currently writable root names, excluding native applicability refusals.
---@field sections boolean Whether the behavior supports constant-combinator sections.
---@field reason? string owned_mod_device_protected, no_supported_native_control_behavior, control_behavior_unset or no_writable_native_settings when applicable.

---Fresh complete target description. ID is opaque, not coordinates: replacement
---at the same location gets a new identity. Descriptions/settings can change while
---the identity stays the same. Nonconfigurable real targets remain in inventory.
---@class TC.DeviceInfo
---@field id TC.DeviceId Current physical target identity.
---@field prototype string Exact entity prototype name.
---@field type string Native entity prototype type, not a peripheral family.
---@field position TC.Position Current native world position.
---@field surface TC.Surface Current native surface identity.
---@field direction string Native direction enum name; not restricted to cardinal directions.
---@field quality string Current installed native entity quality name.
---@field target_wire TC.Wire Explicit selected TARGETS color, independent of the computer discovery wire.
---@field connected_connector_ids TC.WireConnectorId[] Sorted native connector enum names actually reached on that color.
---@field configurable boolean True when the current summary contains writable root settings.
---@field configuration TC.ConfigurationSummary Behavior/field applicability snapshot.

---One discriminator-dependent field set in a native-normalized schema.
---@class TC.ConfigurationVariant
---@field fields string[] Fields allowed for this operation in addition to its operation discriminator.
---@field required string[] Fields that must be supplied for this particular operation.

---Public normalized recursive field schema, not raw engine documentation JSON.
---Only keys appropriate to kind are present. Enum values are symbolic strings,
---never host defines ordinals. Internal native_enum/concept metadata is excluded.
---Required/readable/writable/clearable are independent; a recognized field may be
---unavailable in the current entity mode and carries its restriction reason.
---Known constraints include registered_signal, explicit_signal_type,
---condition_operand_exclusive, condition_signal_roles, operation_variant,
---logistic_mode_requester_or_buffer, fuel_inventory_required, rail_chain_signal_only,
---native_asteroid_no_logistic_connection, ammo_or_fluid_turret_required and
---set_requests_requires_space_travel. Section readback can additionally report
---nonmanual_section and shared_group_detach_first as unavailable_reason.
---@class TC.FieldSchema
---@field kind 'boolean'|'integer'|'number'|'string'|'enum'|'object'|'array'|'map'|'union' Normalized validation shape.
---@field readable boolean Whether this field can currently be read.
---@field writable boolean Whether this field can currently be set.
---@field clearable boolean Whether an explicit root patch clear is supported; not implicit nil assignment.
---@field min? number Numeric lower bound where applicable.
---@field max? number Numeric upper bound where applicable.
---@field max_bytes? integer Maximum string bytes; input identity strings also reject NUL.
---@field max_items? integer Maximum dense-array entry count where applicable.
---@field values? string[] Accepted enum names where kind=enum.
---@field fields? table<string, TC.FieldSchema> Nested field schemas where kind=object.
---@field required? string[] Required object keys; variant-required keys are separately described.
---@field additional_fields? false Unknown object keys are refused when this flag is present.
---@field items? TC.FieldSchema Array element schema.
---@field alternatives? TC.FieldSchema[] Union alternatives in normalization order.
---@field prototype_registry? string Installed prototype registry required for a normalized name string.
---@field constraints? string[] Additional machine-readable semantic/domain restrictions.
---@field variants? table<string, TC.ConfigurationVariant> Operation-discriminated field/required-key inventory.
---@field unavailable_reason? string Current native mode/entity/shared-scope restriction, when applicable.

---Constant-combinator section allowances, not the complete Configurator limits.
---@class TC.SectionLimits
---@field sections integer Maximum supported native sections.
---@field section_filters integer Maximum supported native filter capacity/slot index.

---Sections capability is always described; supported=false does not grant calls.
---@class TC.SectionCapabilities
---@field supported boolean True only for a supported constant-combinator behavior.
---@field fields table<string, TC.FieldSchema> Schemas for active, group, multiplier and filters.
---@field limits TC.SectionLimits Current section/count envelopes.

---Live target capability, independent of a returned value snapshot. Native
---disabled and condition fulfilled values are observations only, never settings.
---Space-travel absence removes request-setting modes; target subtype/fuel/mode
---restrictions remain visible instead of claiming an unimplemented adapter.
---@class TC.CapabilitySet
---@field api_version 1 Exact public schema version.
---@field behavior? string Supported native behavior class; absent for unsupported/protected targets.
---@field settings table<string, TC.FieldSchema> All recognized root settings with live applicability metadata.
---@field observations table<string, TC.FieldSchema> Read-only disabled/condition-fulfilled observation schemas.
---@field sections TC.SectionCapabilities Current constant-section capability and envelopes.
---@field reason? string Current target/behavior applicability reason when supplied.

---Fresh normalized root snapshot. Values depend on the actual behavior, described
---by TC.Config.Read.*. Unset roots are absent, not false. Getter normalization can
---fill native defaults and convert union inputs to objects; it does not apply the
---caller's 256-byte/128-element input limits to native readback. Generic Data and
---configuration result limits still apply. Native objects and read-only condition
---members never appear inside writable values.
---@class TC.ConfigurationSnapshot
---@field values TC.Config.Read.Values Present normalized roots for the actual behavior, not all families at once.
---@field unset string[] Sorted readable root names whose normalized value is absent.
---@field observations table<string, boolean> Present native disabled and condition-name_fulfilled observations.

---Whole-root replacements, not recursive merge. Omitted roots remain unchanged.
---Empty patch is a validated no-op/readback. Explicit nil table fields are omitted,
---not clear requests; use clear only when the current schema says clearable.
---@class TC.ConfigurationPatch
---@field set? TC.Config.Values Root replacements for the target's actual native behavior.
---@field clear? string[] Unique clearable root names; no overlap with set, no read-only/unknown fields.

---Section patch with the same explicit replacement convention. No section field
---supports clear: clear must be omitted or empty, otherwise E_READ_ONLY.
---@class TC.SectionPatch
---@field set? TC.Config.SectionValues Supported fields to replace; omitted fields unchanged.
---@field clear? string[] Only an empty array is accepted; clear filters with set.filters={} instead.

---Complete native section readback. Index is a position, not stable identity;
---removing an earlier section shifts later indexes. Filter array contains occupied
---slots in native slot order; sparse slot indexes are carried explicitly. Native
---capacity filters_count is not the number of populated array entries. Nonmanual
---sections are readable but protected. Shared-group filters require explicit local
---detachment before writes; multiplier readback preserves native float32 rounding.
---@class TC.SectionInfo
---@field index integer Native one-based current section index.
---@field type TC.LogisticSectionType Current native logistic-section enum name.
---@field is_manual boolean Whether native manual editing is permitted.
---@field active boolean Current section enabled state.
---@field group string Shared-group name; empty means local.
---@field multiplier number Finite native multiplier readback, not a decimal-rounding promise.
---@field filters TC.Config.Read.SectionFilter[] Complete populated normalized indexed filters.
---@field filters_count integer Native slot capacity, separately bounded by section_filters.
---@field capabilities table<string, TC.FieldSchema> Dynamic active/group/multiplier/filters capabilities and reasons.

---Circuit-control configuration on the Configurator's distinct TARGETS port.
---The discovery wire from computer to NETWORK and each target_wire argument are
---independent mandatory colors; neither bridges circuits/discovery. Follow only
---real same-color/force/surface physical connector paths, not matching signal
---values, ghosts, isolated combinator ports, hidden radio transport or coordinates.
---Ordinary same-color native relays are supported. Owned helper entities stay
---hidden; public mod bodies can be described as protected/nonconfigurable.
---
---### Schema and normalized values
---TC.Config.* is generated from the existing schema normalizer, not a second
---handwritten setting inventory. Inputs are finite plain objects, bounded arrays
---and exact registered prototype names; no native quality/location objects or raw
---defines global. Signals require explicit type/name except documented SignalFilter
---string forms; quality/readback defaults and role-specific wildcards are described
---on their generated types. Missing expansion prototypes fail validation instead
---of adding a hard dependency. Only circuit-control settings are exposed: no
---arbitrary inventories, teleportation, creation, recipe execution, force edits or
---remote interface injection. Generic/inherited and modded native behaviors remain
---subject to actual applicability, not a prototype-name whitelist.
---
---Compatibility vocabulary is retained on Factorio 2.1: include_fuel maps to
---read_fuel, messages to records, and container/landing-pad mode can represent both
---read/request switches as send_contents_and_set_requests. Tank read_contents=true
---retains an existing segment-read mode; false disables reading. No documentation
---generation changes these mappings or expands the available native setting set.
---
---### Atomic update and lifetime
---Preflight whole patch, current identity/path, prototypes/schema, capacity and work
---before mutation. Setters run in deterministic native-safe order without simulation
---advancing between them, followed by exact native readback. Invalid fields/variants/
---read-only values or broken invariants fail before target changes. Unexpected native
---failure attempts target-local restoration; failed restoration retains recovery and
---faults that target adapter with E_ENGINE, never fake success. Creating a missing
---behavior is authorized only by an admitted nonempty update; native-created default
---behavior cannot necessarily be deleted during recovery. External effects and earlier
---successful calls are not rolled back. This is last-successful-write, not a lock/CAS.
---Player edits remain authoritative until a later explicit write. Stop, disconnect,
---read/reconnect and cold load do not undo/re-enforce already applied factory settings.
---The custom Configurator needs no electricity, but every call retains exact identity,
---force/surface and discovery/target path authority. Captured facades never retarget
---a replacement. Unsupported retained recovery remains visible, not reset by a read.
---@class TC.Configurator
local Configurator = {}

---Enumerate the complete target network once per exact identity, sorted by ID.
---Include unsupported/nonconfigurable real devices with reasons. Incomplete proof,
---size or work refusal is an error, never a successful partial list.
---@param target_wire TC.Wire Required TARGETS color, distinct from discovery wire.
---@return TC.DeviceInfo[] devices One complete detached sorted array, possibly empty.
function Configurator.getDevices(target_wire) end

---Look up one exact current target identity; never use coordinates as identity.
---@param device_id TC.DeviceId Opaque previously discovered target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.DeviceInfo|nil device Exactly one description or one nil if missing/off this target network.
function Configurator.getDevice(device_id, target_wire) end

---Read live applicability and complete recursive schemas without creating native
---behavior. A stale identity/path fails rather than returning fabricated capability.
---@param device_id TC.DeviceId Exact current target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.CapabilitySet capabilities One defensive current schema/applicability record.
function Configurator.getCapabilities(device_id, target_wire) end

---Read current normalized values, sorted unset roots and separate observations;
---false, missing and read-only are distinct. No behavior is created by reading.
---@param device_id TC.DeviceId Exact current target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.ConfigurationSnapshot snapshot One complete defensive readback, not a lock.
function Configurator.getConfiguration(device_id, target_wire) end

---Validate and apply whole-root replacements atomically with native readback.
---Unknown roots/nested fields, repeated clear/set overlap, unsupported domains and
---mode invariants refuse before mutation. Clear can normalize to native defaults,
---not nil. E_READ_ONLY protects observations/protected targets/nonclearable fields;
---E_UNSUPPORTED covers native applicability. Generic admission and fatal budgets
---remain unchanged. See Configurator lifecycle notes for native recovery limits.
---@param device_id TC.DeviceId Exact current target ID.
---@param patch TC.ConfigurationPatch Entire candidate patch; empty is a checked no-op/readback.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.ConfigurationSnapshot snapshot One actual normalized post-update readback.
function Configurator.setConfiguration(device_id, patch, target_wire) end

---Read complete native sections without creating control behavior. Only compatible
---constant combinators support this; other types E_UNSUPPORTED, owned targets
---E_READ_ONLY. Native count/filter capacity beyond supported envelopes is E_LIMIT.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.SectionInfo[] sections Complete native-index-ordered array, possibly empty.
function Configurator.getSections(device_id, target_wire) end

---Create a manual section and return its actual native index, not guessed length.
---Defaults active=true, group='', multiplier=1 and local filters={}. A nonempty
---group joins its shared data instead of inventing empty filters. Supplying filters
---while joining a nonempty group is E_SHARED_SCOPE. Existing sections never truncate.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param definition TC.Config.SectionValues Whole new section definition with documented defaults.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return integer section_index Actual positive native index after successful readback.
function Configurator.addSection(device_id, definition, target_wire) end

---Replace selected section fields with full preflight/rollback/readback. Missing
---section E_NOT_FOUND; nonmanual E_READ_ONLY. Shared contents are never written:
---filters require final group='', explicitly supplied if detaching. Detachment
---preserves the current effective filters before any explicit replacement. No silent
---detach or out-of-scope group overwrite; empty patch still checks manual authority.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param section_index integer Current native index in 1..4294967295; re-enumerate after removals.
---@param patch TC.SectionPatch Explicit supported replacements; no nonempty clear array.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return TC.SectionInfo section One actual complete post-update native readback.
function Configurator.setSection(device_id, section_index, patch, target_wire) end

---Remove one present manual section with target-local recovery/readback. A present
---nonmanual section is E_READ_ONLY, not false. Later native indexes shift; no saved
---section handle/identity is supplied. Native failed restoration retains recovery.
---@param device_id TC.DeviceId Exact constant-combinator target ID.
---@param section_index integer Native index in 1..4294967295; missing valid index is ordinary absence.
---@param target_wire TC.Wire Required selected TARGETS color.
---@return boolean removed True when removed; false if that valid index was already absent.
function Configurator.removeSection(device_id, section_index, target_wire) end

---Read effective common limits plus target traversal/configuration/patch/section
---envelopes. Actual native domains and current capabilities still constrain calls.
---@return TC.ConfiguratorLimits limits One defensive current limit map.
function Configurator.getLimits() end
