---@meta

---Plain persistent data, copied across API boundaries. Numbers must be finite.
---A table is either a dense one-based array or a string-keyed map, never mixed.
---Cycles, metatables, functions, threads, userdata and native objects are refused.
---There are no nil elements; use deleteState to delete stored values. An empty
---table is a map unless a particular schema requires an array. Repeated subtrees
---are copied, not retained as cross-boundary aliases. Byte, node, depth, entry and
---key limits all apply; satisfying a LuaLS type does not bypass these checks.
---
---### Calling convention
---API version 1 is implicit. Namespaces and facades use dot calls, never colon
---calls or implicit self. Extra arguments and unknown option fields are errors
---unless the member explicitly supports them. Omission and nil are accepted only
---as documented; API arguments are not implicitly coerced from strings or truthy
---values. Calls are synchronous, non-yielding and non-reentrant. Each successful
---mutation is committed in dispatcher order; a callback is not a transaction.
---
---### Exceptions
---Modem transmit accepts a required top-level nil message, but not nested nil.
---Detached native Logic signal graphs bypass generic Data transport limits;
---this grants no exemption for explicit state, KV, Console retention, arbitrary
---table growth or guest execution. Circuit queues still account for envelope
---bytes and entries, excluding the native graphs; this is not a total heap bound.
---Console scratch uses its own validated graph and authentic symbolic bindings,
---not an expanded Data domain. Saved callbacks reconstruct fresh locals/functions.
---Console computer.log currently ignores trailing arguments after the text;
---saved-program computer.log retains exact one-argument validation.
---
---### Authority and copies
---Returned records are isolated snapshots, never native LuaObjects. Identifiers
---are opaque case-sensitive strings, stable across ordinary reload but not new
---placement or cloning. Prototype names are exact installed identifiers, not
---localized labels. No table address, wall clock or player-local state orders
---collections. Check each member's ordering and native-field exceptions.
---Custom devices need no electricity; native radar/speaker active calls still
---require their own operational availability. Discovery does not grant remote
---radio authority, host globals, files, HTTP, arbitrary Factorio API or CraftOS.
---@alias TC.Data boolean|number|string|TC.Data[]|table<string, TC.Data>

---An intentionally open transient guest value. Includes nil, ordinary guest
---tables/functions and authentic protected API handles where the called helper
---allows them. This notation does NOT authorize foreign objects, host reflection,
---persistence, arbitrary metatables or passing such values to Data-only services.
---@alias TC.GuestValue any

---An approved callable: guest function or exposed guarded API/helper function.
---Calling consumes the same work/depth/tuple budgets; not a persisted callback.
---@alias TC.Callable fun(...: TC.GuestValue): ...: TC.GuestValue

---Explicit physical circuit color. No default, both, mixed-color path or coercion.
---@alias TC.Wire
---| 'red' # Red path, independently proved.
---| 'green' # Green path, independently proved.

---Required Logic input selection, independent of the discovery wire.
---@alias TC.InputSelection TC.Wire

---Opaque identity of the current placed computer, not a message address.
---@alias TC.ComputerId string

---Opaque discoverable peripheral identity, not a label or native object ID.
---@alias TC.PeripheralName string

---Opaque Configurator target identity, scoped to its physical target network.
---@alias TC.DeviceId string

---Registration identity bound to one computer/run; never a saved function.
---@alias TC.SubscriptionId string

---Timer identity bound to one computer/run, including its queued delivery.
---@alias TC.TimerId string

---Simulation tick: integer 0..9007199254740991, not wall-clock time.
---@alias TC.Tick integer

---Exact signed integer -2147483648..2147483647. No float/string coercion.
---@alias TC.Int32 integer

---Declared exported handler name in the active saved document. Case-sensitive.
---Console cannot borrow these handlers. A local/private function is not an export.
---@alias TC.HandlerName string

---Installed signal kind. Recipe identities are independent of their products
---and research state; same-named item and recipe signals remain distinct.
---@alias TC.SignalType 'item'|'fluid'|'virtual'|'recipe'|'entity'|'space-location'|'asteroid-chunk'|'quality'

---Circuit signal identity. Logic compares (type or item, name, quality or normal).
---Native reads preserve omitted fields/order without normalization; caller writes
---validate installed prototypes and reject wildcard pseudo-signals. Configurator
---has separate schemas requiring explicit type and permitting role-specific
---wildcards. Normal is the only universally assumed quality name.
---@class TC.SignalId
---@field type? TC.SignalType Logic defaults item; native reads may omit it.
---@field name string Exact installed prototype name.
---@field quality? string Installed quality name; effective Logic default normal.

---Detached native signal entry. Order is native, not sorted or stable by contract.
---Zero-valued output entries are omitted; absence of a read signal means zero.
---@class TC.Signal
---@field signal TC.SignalId Complete effective identity including quality.
---@field count TC.Int32 Signed count; negative counts are legal.

---World coordinates in tiles, not rounded integer tile positions.
---@class TC.Position
---@field x number Finite horizontal coordinate.
---@field y number Finite vertical coordinate.

---Plain surface identity, never a LuaSurface or cross-surface authority.
---@class TC.Surface
---@field index integer Native surface index in this world.
---@field name string Exact current surface name.

---Axis-aligned footprint in world tiles; monitor terminal axes may differ.
---@class TC.Footprint
---@field width integer Positive world-X extent.
---@field height integer Positive world-Y extent.

---Public ordinary failure code; messages are explanatory, not stable API strings.
---@alias TC.ErrorCode
---| 'E_ARGUMENT' # Wrong type, arity, option or structure; no mutation.
---| 'E_RANGE' # Invalid numeric, enum, prototype or domain value; no mutation.
---| 'E_NOT_FOUND' # Addressed identity or section no longer exists.
---| 'E_UNREACHABLE' # No valid selected-wire path or wrong force/surface.
---| 'E_NETWORK_PENDING' # Complete topology proof unavailable; retry later.
---| 'E_UNPOWERED' # Native radar/speaker operational availability absent.
---| 'E_UNSUPPORTED' # Unsupported device, schema, mode or Console operation.
---| 'E_READ_ONLY' # Setting/section is immutable in its current native mode.
---| 'E_SHARED_SCOPE' # Shared-group mutation exceeds target authority.
---| 'E_WRONGTYPE' # Wrong live KV key type or a non-monitor in monitor synchronization selection.
---| 'E_CAPACITY' # Accepted content/storage capacity would be exceeded.
---| 'E_LIMIT' # Request exceeds a published size/complexity boundary.
---| 'E_BUSY' # Host work cannot be admitted now; do not busy-wait.
---| 'E_ENGINE' # Native adapter failure; recovery state retained on failed rollback.
---| 'E_PROGRAM' # Uncaught ordinary program failure; prior effects remain committed.
---| 'E_BUDGET' # Candidate refusal or fatal active execution budget exhaustion.

---A fresh defensive ordinary API error table. pcall returns false,error for
---ordinary failures; first check type(error)==table because guest assertions can
---throw strings. Expected absence is documented per method and is not an error.
---Failed admission never means a successful empty result or permission to delete
---accepted content. E_ENGINE rolls back the current operation where supported;
---failed rollback faults that adapter and retains an explicit recovery record.
---
---Fatal work/allocation/depth/tuple exhaustion and saved-program stop bypass guest
---pcall/xpcall; their private controls are not exposed as ApiError values. Faults
---retain source/state/logs and earlier successful effects, except still-owned
---Logic output is cleared by host cleanup. Candidate validation failure preserves
---the previous active run; a newly activated run's failure does not restore it.
---@class TC.ApiError
---@field code TC.ErrorCode Machine-readable failure category.
---@field message string Human-readable explanation; wording is not stable.
---@field field? string Relevant argument, field or option path when supplied.
---@field peripheral? TC.PeripheralName Relevant peripheral when supplied.
---@field device? TC.DeviceId Relevant target device when supplied.
