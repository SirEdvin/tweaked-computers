---@meta

---The current computer's dot-call API. A saved document contains exported function
---declarations and optional private local functions; start is optional. Save only
---commits source; Run/Apply validates then activates a new generation. Failed
---candidate validation preserves the old run. Successful replacement retires old
---timers/subscriptions/queued work and still-owned outputs, then queues start.
---Explicit application state survives unless the user deliberately resets it.
---Each callback has fresh locals/functions; only explicit supported storage lasts.
---
---### Scheduling
---Synchronized processing first reconciles lifecycle/physical changes and revokes
---stale authority, then samples watched Logic inputs, advances timers and host
---notifications, dispatches callbacks/Console, and performs bounded presentation
---and housekeeping. Native circuit propagation is not zero-latency feedback.
---Simulation events and Console commands share a persisted ready rotation. At
---most one item per computer runs in an actual tick, with FIFO queues and fair
---program/Console alternation. New work awakened during a dispatch joins a later
---round. A callback completes or faults, never suspends its Lua stack. Future
---timers are indexed by earliest deadline, not visited every tick while waiting.
---Ordinary cold load retains pending order, registrations and same-tick credits;
---it does not rerun startup or already completed effects. Custom computers need
---no electricity; electrical cycling does not pause or discard accepted work.
---
---### Context
---Console shares real application state and per-computer admission but has its
---own scratch graph, output attribution and transient ownership. on, off, after,
---every, cancelTimer and stop are saved-program-only (E_UNSUPPORTED in Console).
---No filesystem, wall clock, direct signal API, direct computer messages, on_tick,
---guest stop/fault cleanup callback or implicit transaction is provided.
---@class TC.Computer
computer = {}

---Return the current placed identity; labels and native object IDs are not addresses.
---@return TC.ComputerId id Stable identity through ordinary save/load.
function computer.getID() end

---Read the descriptive user label. An empty string is distinct from no label.
---@return string|nil label Exactly one string or one nil when unset.
function computer.getLabel() end

---Set or clear the label atomically. Duplicate labels are allowed. Returns no
---values. E_ARGUMENT rejects a non-string or a label beyond identifier_bytes.
---@param label? string Omission/nil clears; otherwise a bounded byte string.
function computer.setLabel(label) end

---Read synchronized simulation time, not real elapsed time or a process clock.
---@return TC.Tick tick Current tick for this dispatched execution.
function computer.getTick() end

---Read a defensive complete map of effective limits and representation versions.
---Defaults are not live values; changing settings does not replenish spent credit.
---@return TC.Limits limits Current common limits, not a native settings object.
function computer.getLimits() end

---Read a defensive snapshot of explicit application state. Missing is one nil;
---false and an empty string/table remain valid present values. Copy admission may
---fail with E_LIMIT/E_BUDGET; failure is never reported as absence.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@return TC.Data|nil value Independent copy, or exactly one nil when absent.
function computer.getState(key) end

---Validate/copy the complete value before atomically replacing one state key.
---Returns no values. E_ARGUMENT/E_LIMIT reject invalid Data; E_CAPACITY refuses
---the final retained size without changing the old value. Earlier writes survive
---a later callback error. Nil is not deletion; use deleteState explicitly.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@param value TC.Data Required nonnil plain Data; no handles, cycles or functions.
function computer.setState(key, value) end

---Remove one state key. Returns one boolean; repeated removal is harmless.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@return boolean removed True only when a present value was removed.
function computer.deleteState(key) end

---Append one bounded diagnostic entry; returns no values. Requires a string,
---unlike print. Formatting/retention admission precedes publication; old entries
---may be evicted by existing Console retention. Console calls are shell-attributed.
---The shell attribution prefix counts toward console_bytes; oversized output is
---E_LIMIT, never a partial successful append. Saved programs require exactly one
---argument. The current Console override ignores additional guarded arguments;
---this is a context-specific compatibility exception, not general permissive arity.
---@param text string Exact bytes; text plus any shell prefix must fit console_bytes.
function computer.log(text) end

---Does not return normally. End the active saved run through host-controlled
---cleanup, cancelling its work and clearing only its still-owned Logic output.
---pcall/xpcall cannot defeat stop. Source/state/logs and other writers' effects
---remain. In Console this throws ordinary E_UNSUPPORTED instead of stopping.
function computer.stop() end

---Register a named general-event handler in this run. Each call deliberately
---creates an independent registration, not a replacement. Handler name must be an
---export in the active source. Registrations survive reload without startup replay.
---power_restored is accepted only for compatibility and produces no new events.
---No initial inventory is delivered; discover explicitly after registration.
---E_ARGUMENT rejects names; E_CAPACITY refuses excess registrations. Console is
---E_UNSUPPORTED. General subscriptions are not bound to one incidental device.
---@param event_name TC.GeneralEventName Supported general event discriminator.
---@param handler_name TC.HandlerName Declared exported callback name, not a function.
---@return TC.SubscriptionId id New identity bound to this computer/run.
function computer.on(event_name, handler_name) end

---Cancel this run's registration. E_ARGUMENT rejects another computer/run's ID.
---Provider-specific lifecycle cleanup also applies to Logic/Dashboard registrations.
---Console is E_UNSUPPORTED; this cannot edit a saved run from its shell.
---@param subscription_id TC.SubscriptionId Identity from this run.
---@return boolean removed True if the registration existed; false if already absent.
function computer.off(subscription_id) end

---Schedule one named saved handler. The absolute deadline is current tick plus
---delay; that addition must stay within the safe integer domain (E_RANGE).
---Copy the optional payload at registration. One-shot ownership is consumed once
---when its event is admitted, but cancelTimer can still remove a queued delivery.
---E_CAPACITY refuses a full timer inventory; Console is E_UNSUPPORTED.
---@param delay_ticks integer Positive integer simulation ticks, not seconds.
---@param handler_name TC.HandlerName Export in the active saved document.
---@param payload? TC.Data Omission/nil means no payload field; nonnil Data is copied.
---@return TC.TimerId id New one-shot identity owned by this run.
function computer.after(delay_ticks, handler_name, payload) end

---Schedule recurring named callbacks at aligned absolute deadlines. Overdue
---intervals coalesce into one TC.TimerEvent with missed count, never a burst.
---Stop/fault/activation cancels them. Admission and Console restrictions match
---after; pause, speed and wall-clock downtime do not change simulation deadlines.
---@param interval_ticks integer Positive integer simulation ticks within safe addition.
---@param handler_name TC.HandlerName Export in the active saved document.
---@param payload? TC.Data Omission/nil means no payload; otherwise a registration copy.
---@return TC.TimerId id New recurring identity owned by this run.
function computer.every(interval_ticks, handler_name, payload) end

---Cancel both a future deadline and any matching queued undispatched event.
---E_ARGUMENT rejects another computer/run's identity; Console is E_UNSUPPORTED.
---@param timer_id TC.TimerId Timer from this run, including an admitted one-shot.
---@return boolean removed True if pending deadline or queued delivery existed.
function computer.cancelTimer(timer_id) end
