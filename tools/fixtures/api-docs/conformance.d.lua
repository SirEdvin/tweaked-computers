---@meta

---Finite scalar or acyclic string-keyed map; shared subtrees are copied.
---@alias TC.Data boolean|number|string|table<string, TC.Data>

---Discovery wire. Omission means red; explicit nil is refused where stated.
---@alias TC.Wire
---| 'red' # Red network.
---| 'green' # Green network.

---A detached event envelope; never a native engine object.
---@class TC.Event
---@field tick integer Simulation tick, not wall time.
---@field name string Stable public event identity.

---A detached payload delivered to the named handler.
---@class TC.Message: TC.Event
---@field channel integer Channel in 0..65535.
---@field data TC.Data Copied message, without cycles or executable values.
---@field reply? integer Omitted when no reply channel was supplied.

---Callback shape for documentation; saved registrations use a handler name.
---@alias TC.Handler fun(event: TC.Message)

---Synthetic facade for documentation-tool conformance, not a shipped guest API.
---@class TC.Probe
probe = {}

---Read a snapshot using a dot call, with no implicit self.
---
---### Errors
---E_ARGUMENT refuses an invalid wire. No state changes on refusal.
---
---### Effects
---Returns a defensive copy. An empty string differs from a missing record.
---
---### Example
---```lua
---function start()
---  local record, found = probe.read('red', nil)
---  probe.log('[color=red]literal[/color] ]=] "quoted"', found)
---end
---```
---@param wire TC.Wire Discovery wire; required even when the record is missing.
---@param fallback string|nil Required second position; explicit nil means no fallback.
---@param limit? integer Optional result limit; omission means 10, explicit nil is refused.
---@return TC.Message|nil record Detached record, or exactly nil when absent.
---@return boolean found True for an existing record, including empty payloads.
---@overload fun(wire: 'red'): TC.Message|nil, boolean # wire selects the red network; record/found keep their documented meanings.
---@overload fun(channel: integer): absent: nil # channel is a numeric channel in 0..65535; absent is exactly one nil result.
function probe.read(wire, fallback, limit) end

---Exact alias of read, including overloads, errors and result arity.
probe.fetch = probe.read

---Accept zero or more values; returns no values, not one nil.
---@param ... TC.Data Values to record in order.
function probe.log(...) end

---Returns exactly one nil value.
---@return nil absent One result slot containing nil.
function probe.absent() end

---Returns zero or more values in order, preserving explicit nil slots.
---@param ... string|nil Values whose arity is preserved, including trailing nil.
---@return string|nil ... The same ordered result sequence, possibly empty.
function probe.echo(...) end

---Does not return normally; raises E_STOP. This is not a nil-valued result.
---@param reason string Diagnostic message, preserved literally.
function probe.fail(reason) end

---The enum's numeric values are public constants, not native defines ordinals.
---@enum TC.Color
probe.colors = {
    ---The red palette entry, not a color mask combination.
    red = 1,
    ---The green palette entry, preserving its literal value.
    green = 2,
}

---The same immutable synthetic facade, not a second mutable table.
probeAlias = probe

---A fixed public family string; not a claim of unrestricted compatibility.
probeVersion = 'Lua 5.2'

---A transient tuple whose n field preserves nil-bearing arity.
---@class TC.Tuple
---@field n integer Exact positional width including nil holes.
---@field [integer] TC.Data Nonnil value at that one-based position, when present.
