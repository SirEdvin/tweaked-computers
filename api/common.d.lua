---@meta

---The API copies plain persistent data across API boundaries. Numbers must be finite.
---A table is either a dense one-based array or a string-keyed map, never mixed.
---The API refuses cycles, metatables, functions, threads, userdata and native objects.
---
---There are no nil elements. Use deleteState to delete stored values.
---An empty table is a map unless a particular schema requires an array.
---
---The API copies repeated subtrees instead of retaining cross-boundary aliases.
---Byte, node, depth, entry and key limits all apply.
---A value that satisfies a LuaLS type must still pass these checks.
---
---### Calling convention
---API version 1 is implicit. Namespaces and facades use dot calls, never colon
---calls or implicit self. Extra arguments and unknown option fields are errors
---unless the member explicitly supports them. The API accepts omission and nil
---only as documented. The API does not implicitly coerce arguments from strings
---or truthy values. Calls are synchronous, non-yielding and non-reentrant.
---
---The dispatcher commits each successful mutation in dispatcher order.
---A callback is not a transaction.
---
---### Exceptions
---Modem transmit accepts a required top-level nil message, but not nested nil.
---Detached native Logic signal graphs bypass generic Data transport limits.
---This exception does not apply to explicit state, KV, Console retention,
---arbitrary table growth or guest execution. Circuit queues still account for
---envelope bytes and entries, but exclude the native graphs.
---This accounting is not a total heap bound.
---
---Console scratch uses its own validated graph and authentic symbolic bindings,
---not an expanded Data domain. Saved callbacks reconstruct fresh locals and functions.
---Console computer.log currently ignores trailing arguments after the text.
---Saved-program computer.log retains exact one-argument validation.
---
---### Authority and copies
---Returned records are isolated snapshots, never native LuaObjects.
---Identifiers are opaque case-sensitive strings. They stay the same across
---ordinary reload, but not new placement or cloning. Prototype names are exact
---installed identifiers, not localized labels. No table address, wall clock or
---player-local state determines collection order.
---Check each member's ordering and native-field exceptions.
---
---Custom devices need no electricity. Active calls to native radar and speaker
---devices still require their own operational availability. Discovery does not
---grant remote radio authority, host globals, files, HTTP, arbitrary Factorio API or CraftOS.
---@alias TC.Data boolean|number|string|TC.Data[]|table<string, TC.Data>

---This transient guest value has an intentionally open type.
---It includes nil, ordinary guest tables and functions, and authentic protected
---API handles where the called helper permits them.
---This notation does not authorize foreign objects, host reflection, persistence
---or arbitrary metatables. It does not authorize passing such values to Data-only services.
---@alias TC.GuestValue any

---An approved callable is a guest function or an exposed guarded API or helper function.
---A call consumes the same work, depth and tuple budgets.
---This callable is not a persisted callback.
---@alias TC.Callable fun(...: TC.GuestValue): ...: TC.GuestValue

---This value specifies the physical circuit color explicitly.
---There is no default, both selection, mixed-color path or coercion.
---@alias TC.Wire
---| 'red' # Red path, independently proved.
---| 'green' # Green path, independently proved.

---The Logic input selection is required and independent of the discovery wire.
---@alias TC.InputSelection TC.Wire

---This opaque identity identifies the current placed computer, not a message address.
---@alias TC.ComputerId string

---This opaque identity identifies a discoverable peripheral, not a label or native object ID.
---@alias TC.PeripheralName string

---This opaque identity identifies a Configurator target within its physical target network.
---@alias TC.DeviceId string

---This registration identity belongs to one computer and run. It is never a saved function.
---@alias TC.SubscriptionId string

---This timer identity belongs to one computer and run. It includes the timer's queued delivery.
---@alias TC.TimerId string

---A simulation tick is an integer in 0..9007199254740991, not wall-clock time.
---@alias TC.Tick integer

---This value is an exact signed integer in -2147483648..2147483647.
---The API does not coerce floats or strings to this type.
---@alias TC.Int32 integer

---This case-sensitive name identifies a declared exported handler in the active saved document.
---Console cannot borrow these handlers. A local/private function is not an export.
---@alias TC.HandlerName string

---This value identifies an installed signal kind.
---Recipe identities are independent of their products and research state.
---Item and recipe signals with the same name remain distinct.
---@alias TC.SignalType 'item'|'fluid'|'virtual'|'recipe'|'entity'|'space-location'|'asteroid-chunk'|'quality'

---This record identifies a circuit signal.
---Logic compares (type or item, name, quality or normal).
---Native reads preserve omitted fields and native order without normalization.
---Caller writes validate installed prototypes and reject wildcard pseudo-signals.
---Configurator has separate schemas that require an explicit type and permit
---role-specific wildcards. Normal is the only universally assumed quality name.
---@class TC.SignalId
---@field type? TC.SignalType Logic uses item by default. Native reads can omit this field.
---@field name string Exact installed prototype name.
---@field quality? string Installed quality name. Logic uses normal as the effective default.

---This detached entry describes a native signal.
---The contract specifies native order, not sorted or stable order.
---Output omits zero-valued entries. An absent read signal means zero.
---@class TC.Signal
---@field signal TC.SignalId Complete effective identity including quality.
---@field count TC.Int32 Signed count. Negative counts are permitted.

---These world coordinates use tiles, not rounded integer tile positions.
---@class TC.Position
---@field x number Finite horizontal coordinate.
---@field y number Finite vertical coordinate.

---This record gives a plain surface identity, never a LuaSurface or cross-surface authority.
---@class TC.Surface
---@field index integer Native surface index in this world.
---@field name string Exact current surface name.

---This axis-aligned footprint uses world tiles. Monitor terminal axes can differ.
---@class TC.Footprint
---@field width integer Positive world-X extent.
---@field height integer Positive world-Y extent.

---This public code identifies an ordinary failure.
---Messages explain the failure, but their wording is not a stable API contract.
---@alias TC.ErrorCode
---| 'E_ARGUMENT' # The type, arity, option or structure is incorrect. No mutation occurs.
---| 'E_RANGE' # The numeric, enum, prototype or domain value is invalid. No mutation occurs.
---| 'E_NOT_FOUND' # Addressed identity or section no longer exists.
---| 'E_UNREACHABLE' # No valid selected-wire path or wrong force/surface.
---| 'E_NETWORK_PENDING' # Complete topology proof is unavailable. Try again later.
---| 'E_UNPOWERED' # Native radar/speaker operational availability absent.
---| 'E_UNSUPPORTED' # Unsupported device, schema, mode or Console operation.
---| 'E_READ_ONLY' # Setting/section is immutable in its current native mode.
---| 'E_SHARED_SCOPE' # Shared-group mutation exceeds target authority.
---| 'E_WRONGTYPE' # Wrong live KV key type or a non-monitor in monitor synchronization selection.
---| 'E_CAPACITY' # The request would exceed the accepted content or storage capacity.
---| 'E_LIMIT' # Request exceeds a published size/complexity boundary.
---| 'E_BUSY' # The host cannot admit this work now. Do not busy-wait.
---| 'E_ENGINE' # The native adapter failed. A failed rollback retains recovery state.
---| 'E_PROGRAM' # An ordinary program failure escaped error handling. Earlier effects remain committed.
---| 'E_BUDGET' # Candidate refusal or fatal active execution budget exhaustion.

---This table is a fresh defensive copy of an ordinary API error.
---For ordinary failures, pcall returns false,error. First check type(error)==table
---because guest assertions can throw strings. Each method documents expected
---absence, which is not an error. Failed admission never means a successful empty
---result or permission to delete accepted content.
---
---For E_ENGINE, the adapter rolls back the current operation where supported.
---A failed rollback faults that adapter and retains an explicit recovery record.
---
---Fatal work, allocation, depth or tuple exhaustion and saved-program stop bypass
---guest pcall/xpcall. The API does not expose their private controls as ApiError values.
---Faults retain source, state, logs and earlier successful effects, except
---still-owned Logic output. Host cleanup clears that output.
---Candidate validation failure preserves the previous active run.
---A failure in a newly activated run does not restore the previous run.
---@class TC.ApiError
---@field code TC.ErrorCode Machine-readable failure category.
---@field message string Human-readable explanation. The wording is not stable.
---@field field? string Relevant argument, field or option path when supplied.
---@field peripheral? TC.PeripheralName Relevant peripheral when supplied.
---@field device? TC.DeviceId Relevant target device when supplied.
