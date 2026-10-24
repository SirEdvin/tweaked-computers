# Device configurator API v1

Connect NETWORK to computers and TARGETS to factory devices. The two roles never bridge circuits. `peripheral.find("configurator", "red")` selects computer discovery red; `cfg.getDevices("green")` independently selects target green. Ordinary poles relay target wires, but isolated combinator input/output connectors never relay to each other. Ghosts, foreign forces/surfaces and wireless transport are not authority.

All methods use dot calls with exact arity. Every addressed operation rechecks the current target path. Opaque IDs survive ordinary reload, not replacement; coordinates are descriptive only. Readback is copied plain data, never a native object. Unknown fields, cycles, metatables, functions, invalid prototypes/qualities/enums and read-only observations are refused.

## Methods

- `getDevices(target_wire)` returns a complete ID-sorted unique inventory, or an explicit error, never an unmarked prefix. Metadata includes prototype/type, actual position, surface index/name, direction, quality, wire, connector names and configuration availability. Owned implementation helpers are hidden; public mod bodies are protected.
- `getDevice(id, target_wire)` returns the current descriptor or one nil for an absent/disconnected/replaced identity.
- `getCapabilities(id, target_wire)` returns normalized typed settings, observations and section schemas. Inspect `readable`, `writable`, `clearable`, bounds, enum values, nested required fields, selector variants, constraints and unavailable reasons before writing. Inspection never creates a native behavior.
- `getConfiguration(id, target_wire)` returns `{values={}, unset={}, observations={}}`. False is a value. `disabled` and evaluated condition fulfillment are read-only observations.
- `setConfiguration(id, {set={...}, clear={...}}, target_wire)` replaces complete root values, leaves omitted roots unchanged, and returns native normalized readback. An empty patch is a read. Clears are explicit, unique, schema-gated and cannot overlap set fields.
- `getSections(id, target_wire)` returns native-index-ordered constant-combinator sections. Each has `index`, enum-name `type`, `is_manual`, `active`, `group`, `multiplier`, indexed `filters`, `filters_count` and dynamic `capabilities`.
- `addSection(id, definition, target_wire)` returns the actual native new index. Definition fields are `active`, `group`, `multiplier`, `filters`; defaults are true, empty group, 1 and empty local filters. Joining an existing group reads that group's effective filters instead of overwriting them with defaults.
- `setSection(id, index, {set={...}, clear={...}}, target_wire)` returns the selected section. Only the four definition fields can be set; none can be cleared. Use `filters={}` to empty local contents.
- `removeSection(id, index, target_wire)` returns false if missing, true after verified removal. Indexes shift after removal: always re-enumerate.
- `getLimits()` returns common effective resource policy; there are no independent configurator cardinality/string limits.

## Complete native field coverage

`configuration-coverage.json` is the mechanically generated field-to-adapter/prototype/mode/evidence ledger for all 36 pinned Factorio 2.0.77 behavior classes, 164 inherited field entries, 29 concepts and 10 enum groups. There are no unfinished adapters: 163 entries have applicable native writes; one inherited asteroid-collector logistic-connection switch is natively ineffective and explicitly unavailable. The ledger records that distinction rather than claiming a successful setter from metadata.

Supported families include all basic container/proxy-container, belt, inserter, loader, splitter, pump, mining, accumulator, tank, wall and generic controls; arithmetic, decider, selector and constant combinators; assembler/furnace recipe/content/status controls; train stops and rail signals; lamp colors, panel messages and speaker circuit parameters; roboports, turrets/artillery, reactors and rocket silos; logistic containers, landing pads, agricultural towers, asteroid collectors and platform hubs. The native class, not a prototype-name allowlist, selects the adapter, including modded entities using those classes. Expansion prototypes are available only when installed.

Actual native restrictions are exposed before mutation:

- `include_fuel` requires a fuel inventory. Electric machines cannot enable it; burner machines can. The native test includes a labelled test-only burner assembler because base has no such assembler.
- Rail `blue_signal` requires a chain signal.
- Logistic-container exclusive mode requires requester/buffer mode; other containers remain readable.
- Landing-pad `set_requests` requires the engine's space-travel feature. Base-only exposes none/send_contents.
- Electric turrets have no ammunition to read. Asteroid collectors cannot enable their inherited logistic-network connection switch.
- Speaker instrument/note IDs are checked against the selected target's actual instrument catalogue. Sound playback itself is not claimed by headless checks.

## Conditions and parameter objects

Signals use explicit registered `type`/`name`; quality defaults to normal and is explicit on readback. Prototype-object unions become names. Existing installed item/fluid/virtual/entity/recipe/location/asteroid/quality identities are checked; no native object crosses the boundary.

Conditions are flat `{first_signal=..., comparator=..., constant=...}` or use `second_signal` instead of constant. Accepted comparators are =, >, <, ≥, >=, ≤, <=, ≠, !=; readback canonicalizes aliases. Omitted comparator/constant normalize to < and 0. `fulfilled` is never writable. Clearing conditions yields native defaults, not an invented nil.

Arithmetic parameters contain first/second signals or constants, optional red/green network selections, operation and output signal. Arithmetic each input/output is supported; each output requires each input. Deciders accept dense `conditions` and `outputs` arrays, compare_type and/or, per-operand/output networks, output constants and copy_count_from_input. Their legal wildcard roles include each/anything/everything. Ordinary condition first operands allow anything/everything; second operands and ordinary signal roots reject wildcards.

Selectors use discriminated operation objects, not a bag of interchangeable fields:

- select: index_signal or index_constant, select_max;
- count: count_signal;
- random: random_update_interval;
- stack-size / rocket-capacity: no extra fields;
- quality-filter: a registered quality name or quality/comparator object;
- quality-transfer: required quality_destination_signal, select_quality_from_signal and applicable quality_source_signal or quality_source_static `{name=...}`.

Fields from another selector operation are rejected. Native network/default/quality forms are normalized on both expected and actual readback; absent static normal quality is not confused with an unset selection.

## Sections, groups and indexed filters

Example for a target constant combinator:

```lua
local index = cfg.addSection(id, {active=false, filters={
  {index=4, value={type="item",name="iron-plate",quality="normal",comparator="="}, min=7}
}}, "green")
cfg.setSection(id, index, {set={active=true,multiplier=2}}, "green")
```

Filters are LogisticFilter records, not logic-handler Signal records. They support explicit slot index (native uint16, 1–65535), value signal/quality/comparator, signed min, optional unsigned max and minimum_delivery_count, and import_from location name. Indexed sparse slots remain sparse; native array assignment would silently discard the index, so the adapter uses native set_slot. Duplicate indexes and duplicate native filter identities are refused. Nonzero min requires an exact quality filter. Readback uses each item's native default import location, including expansion locations, rather than assuming Nauvis. Multiplier readback preserves native float32 precision and its finite native domain.

Nonmanual sections are read-only, including removal. Shared filter writes are always refused with E_SHARED_SCOPE; the implementation deliberately does not enumerate unbounded global membership. Group assignment changes only the selected reference. Explicit `group=""` detaches and preserves effective filters before any optional local replacement. Never silently detach. Shared active/multiplier/reference operations remain target-local; unconnected member filters are checked unchanged in native fixtures. A plain group assignment cannot be combined with filters while the final group is nonempty.

## Admission, failures and persistence

Preflight copies and validates complete requests. Private plain-data validation cursors retain paid progress; preparation and commit are separate stages, not public futures. Immediately before mutation the service rechecks the target path and identity, native configuration, protected/nonmanual state and shared-group contents. A competing edit refuses with E_BUSY and leaves the other writer's changes intact. No stale prepared snapshot is restored over a newer writer.

Setters run deterministically: signals/modes, conditions, activation switches; alphabetical within ranks. Native commit, readback and possible restoration remain indivisible. Shared admission must reserve work, complete result storage and retained recovery before effects. An operation too large for an indivisible slice requires a recoverable setting diagnostic, not partial field application. The isolated branch's shared-runtime integration and remaining gates are documented in [configurator resource integration](configurator-resource-integration.md); a host-double continuation test is not proof of production resource admission.

Unexpected setter/readback failure never reports success. Supported prior target settings are restored and verified. A failed restoration retains `configuration_recovery[id]` with plain prior state, request, tick and diagnostic; subsequent writes through that configurator are faulted until host repair. Section removal reconstructs only a manual suffix when needed; a nonmanual suffix that cannot be restored is explicitly retained as a recovery fault, never overwritten. Native behavior creation can be restored to native defaults, not deleted. Native group creation/third-party notifications are not globally rolled back.

Successful factory settings survive program stop, disconnection and configurator removal. Player edits remain authoritative until another explicit write; there is no periodic settings enforcement. Cold tests verify native settings, section indexes/filters, entity aliases, outside shared membership and retained recovery aliases in a separate engine process. Invalid patches/admission refusals preserve prior settings.

Schemas no longer invent generic string, array, patch-field, section or filter counts. Native integer/float domains, dense arrays, registered identities and field/inter-field rules remain enforced. Complete reads and native mutations still require configured shared work and retained-memory admission. Recovery records are never evicted to make room. No shared production budgets were raised for the scoped checks.

`examples/configurator-program.lua` configures connected inserters. `examples/configurator-sections.lua` exercises actual registered section methods through the native compiler and separate target wiring. These are native source/service/setter checks, not evidence of client typing, native target GUI rendering, focus, audible playback, graphical latency or multiplayer joining. Those checks remain deferred to the user for the alpha.
