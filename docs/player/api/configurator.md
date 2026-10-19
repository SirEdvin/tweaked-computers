# Configurator: factory circuit settings

Connect computer NETWORK to configurator NETWORK; connect factory devices to its
separate TARGETS port. `peripheral.find("configurator", "red")` selects discovery
red; `cfg.getDevices("green")` independently selects TARGETS green. These roles
never bridge. Vanilla poles relay same-color TARGETS wires, but isolated native
combinator input/output connectors do not bridge. Ghosts, foreign force/surface
and wireless transport do not grant authority.

## Complete methods

All use dots, strict arity, opaque string IDs and explicit target Wire. Every
addressed operation rechecks live identity/path. Replacement at identical coordinates
gets a different ID. Readback is copied Data, not Factorio objects.

| Signature | Exact returns |
| --- | --- |
| `cfg.getDevices(target_wire)` | Complete ID-sorted unique DeviceInfo array, never a partial prefix |
| `cfg.getDevice(id, target_wire)` | DeviceInfo or one nil for absent/disconnected/replaced identity |
| `cfg.getCapabilities(id, target_wire)` | CapabilitySet of current typed settings/observations/sections |
| `cfg.getConfiguration(id, target_wire)` | ConfigurationSnapshot |
| `cfg.setConfiguration(id, patch, target_wire)` | Normalized native ConfigurationSnapshot after verified update |
| `cfg.getSections(id, target_wire)` | Native-index-ordered SectionInfo array |
| `cfg.addSection(id, definition, target_wire)` | Actual new native integer index |
| `cfg.setSection(id, index, patch, target_wire)` | Selected SectionInfo after update |
| `cfg.removeSection(id, index, target_wire)` | Boolean; false if absent, true after verified removal |
| `cfg.getLimits()` | Defensive common + configurator capacities |

## Device and schema records

DeviceInfo: `id`, `prototype`, `type`, `position={x,y}` actual world coordinates,
`surface={index,name}`, `direction` native enum name (not necessarily cardinal),
`quality`, `target_wire`, sorted `connected_connector_ids` native enum-name array,
`configurable:boolean`, `configuration={behavior?, readable:string[],
writable:string[], sections:boolean, reason?}`. Helpers are hidden; public mod
bodies are protected/nonconfigurable. Devices without supported behavior remain
in inventory with a reason. Inspection never creates native control behavior.

CapabilitySet: `api_version=1`, `behavior?`, `settings` field-name map,
`observations` field-name map, `sections={supported, fields, limits}`, `reason?`.
Each FieldSchema describes `kind`, `readable`, `writable`, `clearable`, optional
`min/max/max_bytes/max_items`, enum `values`, nested `fields/required`,
`additional_fields=false`, array `items`, union `alternatives`,
`prototype_registry`, `constraints`, `unavailable_reason`. Selector objects also
expose operation `variants={operation={fields,required}}`. Respect current flags
and reasons rather than inferring writability from a name.

The complete readable [settings catalogue](settings.md) and [nested schemas](schemas.md)
list every pinned root field, enum and parameter type. No need to open development
JSON to find supported settings. Native mode restrictions remain dynamic:

- include_fuel needs a fuel inventory; electric machines cannot enable it.
- blue_signal needs a chain signal; normal rail signal marks it unreadable/unwritable.
- logistic-container exclusive mode needs requester/buffer mode.
- landing-pad set_requests requires the engine's space-travel feature; base exposes
  none/send_contents only.
- electric turrets cannot read ammunition; asteroid collectors' inherited
  connect_to_logistic_network setting is natively ineffective and unavailable.
- speaker zero-based instrument/note IDs must exist on the actual target.
  Headless verification does not establish audible playback.

Behavior class selects the adapter, not a prototype-name allowlist; expansion
prototypes must actually be installed. This is circuit configuration only, not
arbitrary entity properties, inventory mutation, creation, teleport or remote calls.

## Read and patch

ConfigurationSnapshot is `{values={...}, unset={string,...}, observations={...}}`.
False is a real value; nil/unset is different. `disabled` and evaluated
`circuit_condition_fulfilled`/`logistic_condition_fulfilled` are observations, not
writable settings or nested `fulfilled` inputs.

Patch: `{set={field=value,...}?, clear={field_name,...}?}`. An empty patch is a
validated read/no-op. Each set root replaces a **complete** value; nested maps are
not recursively merged. Omitted roots remain. Explicit clear requires clearable
metadata, cannot repeat or overlap set. Unknown/read-only fields, malformed Data,
invalid prototype/quality/enum or broken variants fail before mutation.

Signal type/name are explicit; quality defaults normal and readback includes it.
Configurator SignalID additionally supports installed entity, space-location,
asteroid-chunk and quality signal types where the native schema permits them;
logic-handler ordinary SignalId supports item/fluid/virtual/recipe.
Quality/location object unions become registered name strings, never native
objects. Conditions are flat `{first_signal=..., comparator=..., constant=...}`
or second_signal instead of constant; no legacy `condition={...}` wrapper.
Comparators =, >, <, ≥/>=, ≤/<=, ≠/!= normalize aliases. Default comparator <,
constant 0. Clearing conditions can return native defaults, not nil. Ordinary
first condition operands permit anything/everything; second operands do not.
Arithmetic each output requires each input; decider each output requires an each
condition. See [nested schemas](schemas.md) for full combinator/selector forms.

Setters apply deterministically (signals/modes, conditions, activation switches;
alphabetical inside ranks) with no simulation advance during the operation.
Preflight reserves setter/readback/restoration work. Unexpected engine failure
restores prior supported target settings and verifies them. Failed restoration
retains explicit recovery and faults further writes through that configurator.
A newly created behavior can be reset to defaults, not deleted; shared-group
creation and third-party notifications are not global rollback.

Last successful write wins, not a lock or compare-and-set. Stop, cable loss or
configurator removal does not undo applied native settings. Player edits remain
until a new explicit write. Reading/reconnecting does not periodically enforce an
old desired configuration.

## Constant-combinator sections

Only compatible targets support section methods; others raise E_UNSUPPORTED.
SectionInfo has `index`, enum-name `type`, `is_manual`, `active`, `group`,
`multiplier`, indexed `filters`, `filters_count`, dynamic `capabilities`.
Indexes are native 1-based and shift after removal: always re-enumerate.

Definition fields/defaults: active=true, group="", multiplier=1, filters={}.
SetSection uses the same patch form for these four fields, none clearable; use
filters={} to empty. Joining an existing nonempty group reads its effective filters
instead of replacing them with defaults. Nonmanual sections are read-only,
including removal. Removing missing index returns false, not an invented section.

Filters are LogisticFilter records, **not** logic Signal arrays: explicit `index`
1–128, optional `value` signal/quality/comparator, signed min, optional unsigned
max/minimum_delivery_count and registered import_from location. Sparse slots are
represented by a dense list of explicit indexes. Duplicate indexes/identities
refuse. Nonzero min needs an exact quality filter. Readback normalizes item import
default to registered nauvis; multiplier preserves native float32 precision.

Shared filter writes always raise E_SHARED_SCOPE. Explicit `group=""` detaches
only the selected section, preserves effective filters, then permits optional local
replacement. Never silently detach. Nonempty final group cannot combine group
assignment with filters. Active/multiplier/reference changes stay target-local.
Section failure recovery does not overwrite a protected nonmanual suffix.

## Bounds, programs and troubleshooting

Initial limits: target_nodes=256 connector vertices, target_edges=512,
configuration_bytes=16384, configuration_nodes=4096, patch_fields=32,
sections=32, section_filters=128. Common return/callback/allocation bounds also
apply; maxima cannot necessarily be combined in one callback. Pending/limit
errors are not an empty target inventory. Active service needs configurator power;
getLimits still works if reachable and unpowered.

Run [configurator-program](../examples.md#configurator-program) with one inserter
on green TARGETS to set its condition, or
[configurator-sections](../examples.md#configurator-sections) with a constant
combinator on green. The [factory tutorial](../factory.md) supplies actual output.
No inserter movement from configuration alone is expected: it still needs power,
items and a circuit signal. If a setting refuses, inspect current writable/reason
metadata, exact enum/prototypes and selected connector. For shared filters explicitly
detach or edit the native group manually; never retry unsafe writes in a loop.
