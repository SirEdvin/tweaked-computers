# Configurator Lua API v1

Normative companion to [spec.md](spec.md). The complete pinned engine inventory is [configuration-catalog.md](configuration-catalog.md), with nested types/enums in [configuration-catalog.json](configuration-catalog.json). Shared values/errors: [common.md](../../api/common.md).

Obtain `cfg` with `peripheral.find("configurator", computer_network_wire)`. Every target API below separately requires `target_wire`: the color on the configurator's other physical port. These arguments are not interchangeable and neither creates an internal circuit/discovery bridge.

## Device discovery and inspection

| Signature | Returns | Contract |
| --- | --- | --- |
| `cfg.getDevices(target_wire)` | `DeviceInfo[]` | Complete sorted unique target-network inventory; no silent partial result |
| `cfg.getDevice(device_id, target_wire)` | DeviceInfo or nil | Nil if that identity no longer exists or is no longer on this selected target network |
| `cfg.getCapabilities(device_id, target_wire)` | CapabilitySet | Current typed configuration schema and applicability |
| `cfg.getConfiguration(device_id, target_wire)` | ConfigurationSnapshot | Current normalized values, unset fields and read-only observations |
| `cfg.setConfiguration(device_id, patch, target_wire)` | ConfigurationSnapshot | Validate the whole patch before mutation; read back the exact device afterward |
| `cfg.getLimits()` | table | `target_nodes`, `target_edges`, `configuration_bytes`, `configuration_nodes`, `patch_fields`, `sections`, `section_filters`, plus common caps |

A complete network includes same-force real devices reached through ordinary same-color wire relays. Do not change color, cross surfaces, infer reachability from matching signal values, follow ghosts, jump between a combinator's isolated connectors or traverse radio-like signal transport as if it were a physical wire. Actual native-connected wire connectors of a device are followed; an entity's mere presence does not authorize every isolated connector it owns. Internal helper entities belonging to this mod are hidden from the device inventory; a public mod body can be described as protected/nonconfigurable instead of exposing its children.

```text
DeviceInfo = {
  id: DeviceId,
  prototype: string,               -- exact entity prototype name
  type: string,                    -- Factorio entity prototype type
  position: { x: number, y: number },
  surface: { index: integer, name: string },
  direction: string,               -- native direction enum name, not assumed cardinal
  quality: string,
  target_wire: Wire,
  connected_connector_ids: string[], -- native connector enum names, sorted
  configurable: boolean,
  configuration: {
    behavior: string | nil,
    readable: string[], writable: string[],
    sections: boolean,
    reason: string | nil
  }
}
```

IDs are opaque identities, never coordinates. Descriptions and current availability can change without replacing an ID; replacement at identical coordinates produces a different ID. Devices without a circuit-control behavior remain in getDevices with configurable=false and a reason. Reading inventory or capabilities must not create control behavior on an otherwise untouched device just for discovery.

## Capability schemas

```text
CapabilitySet = {
  api_version: 1,
  behavior: string | nil,          -- native behavior enum name, normalized
  settings: { [setting_name]: FieldSchema },
  observations: { [name]: FieldSchema },
  sections: { supported: boolean, fields: {...}, limits: {...} },
  reason: string | nil
}

FieldSchema = {
  kind: "boolean" | "integer" | "number" | "string" |
        "enum" | "object" | "array" | "map" | "union",
  readable: boolean, writable: boolean, clearable: boolean,
  min?: number, max?: number, max_bytes?: integer, max_items?: integer,
  values?: string[],               -- enum names, not host integer constants
  fields?: { [field_name]: FieldSchema },
  required?: string[], additional_fields?: false,
  items?: FieldSchema, alternatives?: FieldSchema[],
  prototype_registry?: string,
  constraints?: string[],          -- documented machine-readable constraint identifiers
  unavailable_reason?: string
}
```

The public schema is this normalized data structure, not raw engine JSON. Type conversion rules:

- Finite booleans/numbers/strings and bounded dense arrays/maps only. Native numeric ranges remain enforced, with guest integers restricted to exact safe integer values.
- Engine `defines.*` enum inputs/outputs use names from the pinned catalogue, not numeric ordinals or a raw `defines` global.
- `QualityID` and `SpaceLocationID` object/string unions accept existing prototype-name strings only. `LuaQualityPrototype` and `LuaSpaceLocationPrototype` are never exposed. Base-only absence of a referenced expansion prototype is a validation error, not a hard mod dependency.
- Signal inputs require explicit type/name; quality defaults to normal and is always returned explicitly. Conditional/wildcard signals are allowed only where the relevant pinned concept permits them.
- Comparators use the engine-supported symbols/aliases declared by the pinned `ComparatorString` concept; no guessed conversion or misspelling repair. UI help presents accepted values from the schema.
- `fulfilled` and behavior `disabled` are observations, not writable control settings. Getter snapshots keep observations separate so a normal values table does not smuggle read-only condition results into a patch.
- Applicability restrictions (native mode, nonmanual sections, unsupported entity, shared scope) appear as field metadata/reasons. “Adapter not implemented” is not an acceptable release-time reason for a pinned applicable setting.

Support the entire catalogue, including inherited generic on/off/logistic conditions, arithmetic/decider/selector parameter objects, inserter filtering/hand/stack controls, machine recipe/content status, train-stop settings, lamp colors, display messages, circuit-capable expansion devices and constant-combinator sections. This is circuit-control configuration only: no arbitrary inventory mutation, teleportation, entity creation, recipe execution, force settings or third-party remote API injection.

## Configuration reads and updates

```text
ConfigurationSnapshot = {
  values: { [setting_name]: plain normalized value },
  unset: string[],
  observations: { [name]: plain normalized value }
}
ConfigurationPatch = {
  set?: { [setting_name]: plain normalized value },
  clear?: string[]
}
```

An empty patch is a validated no-op/readback. Each root field is a complete value replacement; nested objects are not recursively merged. Omitted root fields are unchanged. Explicit clear is accepted only for fields whose schema says clearable, such as applicable circuit/logistic conditions. A field cannot occur in both set and clear; clear entries cannot repeat. Unknown root/nested fields, read-only fields, unsupported values or broken inter-field invariants fail before any target change.

Preflight the full patch, current identity/path, schema/prototype references, final capacity and operation budget. Apply setters in a deterministic adapter-defined order that respects native mode constraints, without allowing native simulation advancement between them. Read back the target to verify accepted normalization. Unexpected engine failure restores the operation's prior target snapshot; failed restoration faults the adapter with explicit recovery diagnostics rather than returning fake success. Earlier completed API calls are not rolled back.

Last-successful-write semantics apply; snapshots are not locks and there is no implicit compare-and-set. Program stop or cable removal never undoes already applied factory settings. Subsequent player edits are authoritative until an explicit future program write. Read/reconnect does not continuously enforce an old desired configuration.

## Constant-combinator sections

```text
cfg.getSections(device_id, target_wire) -> SectionInfo[]
cfg.addSection(device_id, definition, target_wire) -> integer section_index
cfg.setSection(device_id, section_index, patch, target_wire) -> SectionInfo
cfg.removeSection(device_id, section_index, target_wire) -> boolean
```

Only compatible constant-combinator targets support these methods; others throw E_UNSUPPORTED. `definition` accepts `active`, `group`, `multiplier`, `filters`, with explicit defaults active=true, group="", multiplier=1, filters={}. `patch` uses the same set/clear structure as configuration; only supported section fields can be set, none are implicitly cleared. Filters are complete normalized arrays matching the pinned LogisticFilter concept, including native indexes and quality-aware signal values. The full catalogue supplies nested types and restrictions; it is not legal to treat filters as the simpler logic-handler Signal array.

SectionInfo includes native `index`, `type`, `is_manual`, `active`, `group`, `multiplier`, `filters`, `filters_count` and dynamic field capabilities. Section indexes are native 1-based indexes and can shift after removal: callers must re-enumerate rather than assume identity. No LuaLogisticSection object is exposed.

Nonmanual sections are protected. Group assignment changes only the selected section's reference. Mutating shared group contents is refused with E_SHARED_SCOPE unless the adapter can prove the entire affected membership remains within current target authority; the default safe operation is explicit `group=""` detachment followed by local filter editing. Detachment preserves the currently effective filter snapshot before local changes. Never silently detach or overwrite another device's group to make a setter succeed.

Section edits obey the same validation/rollback/readback boundaries. Removing a missing index returns false; trying to remove a present nonmanual section throws E_READ_ONLY. A successful new section index is obtained from actual engine readback, not guessed from array length.

## Example: inspect devices, then configure only applicable inserters

```lua
function start(event)
  local cfg = peripheral.find("configurator", "red")
  if not cfg then return end
  for _, device in ipairs(cfg.getDevices("green")) do
    computer.log(device.prototype .. " at " ..
      tostring(device.position.x) .. "," .. tostring(device.position.y))
    if device.type == "inserter" then
      local caps = cfg.getCapabilities(device.id, "green")
      local enable = caps.settings.circuit_enable_disable
      local condition = caps.settings.circuit_condition
      if enable and enable.writable and condition and condition.writable then
        cfg.setConfiguration(device.id, {
          set = {
            circuit_enable_disable = true,
            circuit_condition = {
              comparator = ">",
              first_signal = { type = "virtual", name = "signal-A", quality = "normal" },
              constant = 0
            }
          }
        }, "green")
      end
    end
  end
end
```

Here red reaches the configurator from the computer; green enumerates its separate target port. The program does not bridge discovery colors or emit a circuit signal. The condition is a flat normalized condition object, not the legacy Factorio 0.16 `condition={...}` wrapper.

## Required cases

Catalogue completeness against pinned source; coordinates/types and unsupported devices; pole relays, connector isolation and no cross-color/surface traversal; stale IDs/paths/forces; false/unset/read-only distinctions; every writable field with actual applicable engine fixtures; enum/prototype/quality validation; invalid multi-field patch preserves prior settings; native GUI readback; constant sections and protected/shared groups; player changes after program stop; base-only plus expansion coverage and no arbitrary object escape.
