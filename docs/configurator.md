# Device configurator API v1

Connect NETWORK to computers. Connect TARGETS to factory devices. The two roles never bridge circuits. `peripheral.find("configurator", "red")` selects computer discovery red. `cfg.getDevices("green")` independently selects target green. Ordinary poles relay target wires, but isolated combinator input/output connectors never relay to each other. Ghosts, foreign forces/surfaces and wireless transport do not give authority.

All methods use dot calls with exact arity. Every addressed operation rechecks the current target path. Opaque IDs persist across ordinary reload, not replacement. Coordinates are descriptive only. Readback is copied plain data, never a native object. The API refuses unknown fields, cycles, metatables, functions, invalid prototypes/qualities/enums and read-only observations.

## Methods

- `getDevices(target_wire)` returns a complete ID-sorted unique inventory, or an explicit error, never an unmarked prefix. Metadata includes prototype/type, actual position, surface index/name, direction, quality, wire, connector names and configuration availability. Owned implementation helpers are hidden. Public mod bodies are protected.
- `getDevice(id, target_wire)` returns the current descriptor or one nil for an absent/disconnected/replaced identity.
- `getCapabilities(id, target_wire)` returns normalized typed settings, observations and section schemas. Inspect `readable`, `writable`, `clearable`, bounds, enum values, nested required fields, selector variants, constraints and unavailable reasons before writing. Inspection never creates a native behavior.
- `getConfiguration(id, target_wire)` returns `{values={}, unset={}, observations={}}`. False is a value. `disabled` and evaluated condition fulfillment are read-only observations.
- `setConfiguration(id, {set={...}, clear={...}}, target_wire)` replaces complete root values and leaves omitted roots unchanged. It returns native normalized readback. An empty patch is a read. Clears are explicit, unique, schema-gated and cannot overlap set fields.
- `getSections(id, target_wire)` returns native-index-ordered constant-combinator sections. Each has `index`, enum-name `type`, `is_manual`, `active`, `group`, `multiplier`, indexed `filters`, `filters_count` and dynamic `capabilities`.
- `addSection(id, definition, target_wire)` returns the actual native new index. Definition fields are `active`, `group`, `multiplier`, `filters`. The defaults are true, empty group, 1 and empty local filters, respectively. Joining an existing group reads that group's effective filters instead of overwriting them with defaults.
- `setSection(id, index, {set={...}, clear={...}}, target_wire)` returns the selected section. Only the four definition fields can be set. None can be cleared. Use `filters={}` to empty local contents.
- `removeSection(id, index, target_wire)` returns false if missing, true after verified removal. Indexes shift after removal. Always enumerate them again.
- `getLimits()` returns common and configurator-specific ceilings.

## Complete native field coverage

`configuration-coverage.json` is the mechanically generated field-to-adapter/prototype/mode/evidence ledger for pinned Factorio 2.0.77. It covers all 36 behavior classes, 164 inherited field entries, 29 concepts and 10 enum groups. There are no unfinished adapters. Of the entries, 163 have applicable native writes. One inherited asteroid-collector logistic-connection switch is natively ineffective and explicitly unavailable. The ledger records that distinction. Metadata alone does not establish a successful setter.

Supported families include:

- All basic container/proxy-container, belt, inserter, loader, splitter, pump, mining, accumulator, tank, wall and generic controls
- Arithmetic, decider, selector and constant combinators
- Assembler/furnace recipe/content/status controls
- Train stops and rail signals
- Lamp colors, panel messages and speaker circuit parameters
- Roboports, turrets/artillery, reactors and rocket silos
- Logistic containers, landing pads, agricultural towers, asteroid collectors and platform hubs.

The native class, not a prototype-name allowlist, selects the adapter. This includes modded entities that use those classes. Expansion prototypes are available only when installed.

Actual native restrictions are exposed before mutation:

- `include_fuel` requires a fuel inventory. Electric machines cannot enable it. Burner machines can. The native test includes a labelled test-only burner assembler because base has no such assembler.
- Rail `blue_signal` requires a chain signal.
- Logistic-container exclusive mode requires requester/buffer mode. Other containers remain readable.
- Landing-pad `set_requests` requires the engine's space-travel feature. Base-only exposes none/send_contents.
- Electric turrets have no ammunition to read. Asteroid collectors cannot enable their inherited logistic-network connection switch.
- Speaker instrument/note IDs are checked against the selected target's actual instrument catalogue. Sound playback itself is not claimed by headless checks.

## Conditions and parameter objects

Signals use explicit registered `type`/`name`. Quality defaults to normal and is explicit on readback. Prototype-object unions become names. The API checks existing installed item/fluid/virtual/entity/recipe/location/asteroid/quality identities. No native object crosses the boundary.

Conditions are flat `{first_signal=..., comparator=..., constant=...}` or use `second_signal` instead of constant. Accepted comparators are =, >, <, ≥, >=, ≤, <=, ≠, !=. Readback canonicalizes aliases. Omitted comparator/constant normalize to < and 0. `fulfilled` is never writable. Clearing conditions gives native defaults, not an invented nil.

Arithmetic parameters contain first/second signals or constants, optional red/green network selections, operation and output signal. Arithmetic each input/output is supported. Each output requires each input. Deciders accept dense `conditions` and `outputs` arrays, compare_type and/or, per-operand/output networks, output constants and copy_count_from_input. Their permitted wildcard roles include each/anything/everything. Ordinary condition first operands allow anything/everything. Second operands and ordinary signal roots reject wildcards.

Selectors use discriminated operation objects, not interchangeable fields:

- select: index_signal or index_constant, select_max
- count: count_signal
- random: random_update_interval
- stack-size / rocket-capacity: no extra fields
- quality-filter: a registered quality name or quality/comparator object
- quality-transfer: required quality_destination_signal, select_quality_from_signal and applicable quality_source_signal or quality_source_static `{name=...}`.

Fields from another selector operation are rejected. Native network/default/quality forms are normalized on both expected and actual readback. Absent static normal quality is different from an unset selection.

## Sections, groups and indexed filters

Example for a target constant combinator:

```lua
local index = cfg.addSection(id, {active=false, filters={
  {index=4, value={type="item",name="iron-plate",quality="normal",comparator="="}, min=7}
}}, "green")
cfg.setSection(id, index, {set={active=true,multiplier=2}}, "green")
```

Filters are LogisticFilter records, not logic-handler Signal records. They support explicit slot index, value signal/quality/comparator, signed min, optional unsigned max and minimum_delivery_count, and import_from location name. Indexed sparse slots remain sparse. Native array assignment would silently discard the index. Thus, the adapter uses native set_slot. Duplicate indexes and duplicate native filter identities are refused. Nonzero min requires an exact quality filter. Readback normalizes the native item import default to the registered nauvis name. Multiplier readback preserves native float32 precision.

Nonmanual sections are read-only, including removal. Shared filter writes are always refused with E_SHARED_SCOPE. The implementation deliberately does not enumerate unbounded global membership. Group assignment changes only the selected reference. Explicit `group=""` detaches and preserves effective filters before any optional local replacement. Never silently detach. Shared active/multiplier/reference operations remain target-local. Native fixtures check that unconnected member filters stay unchanged. A plain group assignment cannot be combined with filters while the final group is nonempty.

## Admission, failures and persistence

Preflight copies and validates complete requests. It reserves weighted native setter/readback/restoration work on the existing shared ledger. Setters run in a deterministic order: signals/modes, conditions, then activation switches. Each rank uses alphabetical order. No simulation advancement occurs during an operation. Large responses are also bounded. Native group contents are opaque until joining. Native readback above its envelope is refused inside guarded target-local restoration. It does not expose an unbounded membership list.

Unexpected setter/readback failure never reports success. Supported prior target settings are restored and verified. A failed restoration keeps `configuration_recovery[id]` with plain prior state, request, tick and diagnostic. Subsequent writes through that configurator are faulted until host repair. Section removal reconstructs only a manual suffix when needed. A nonmanual suffix that cannot be restored is explicitly retained as a recovery fault, never overwritten. Native behavior creation can be restored to native defaults, not deleted. Native group creation/third-party notifications are not globally rolled back.

Successful factory settings persist across program stop, disconnection and configurator removal. Player edits remain authoritative until another explicit write. There is no periodic settings enforcement. Cold tests verify native settings, section indexes/filters, entity aliases, outside shared membership and retained recovery aliases in a separate engine process. Invalid patches/admission refusals preserve prior settings.

Development ceilings are:

- 256 reached connector vertices
- 512 examined edges
- 16,384 configuration bytes
- 4,096 Data nodes
- 32 root patch fields
- 32 sections
- 128 slots per section.

Common callback/allocation/return caps also apply. These ceilings apply together. They do not guarantee that every maximum can be combined in one callback. No shared production limits were increased.

`examples/configurator-program.lua` configures connected inserters. `examples/configurator-sections.lua` exercises actual registered section methods through the native compiler and separate target wiring. These are native source/service/setter checks. They do not establish client typing, native target GUI rendering, focus, audible playback, graphical latency or multiplayer joining. Those checks remain deferred to the user for the alpha.
