---@meta

---This API provides dot calls for the current computer.
---A saved document contains exported function declarations and optional private
---local functions. The start handler is optional. Save only commits source.
---Run/Apply validates a new generation before activation.
---
---Failed candidate validation preserves the old run.
---Successful replacement retires old timers, subscriptions, queued work and
---still-owned outputs. It then queues start.
---Explicit application state survives unless the user deliberately resets it.
---Each callback has fresh locals and functions. Only explicit supported storage lasts.
---
---### Scheduling
---Synchronized processing first reconciles lifecycle and physical changes and
---revokes stale authority. It then samples watched Logic inputs, advances timers
---and host notifications, and dispatches callbacks and Console commands.
---Finally, it performs bounded presentation and housekeeping.
---Native circuit propagation is not zero-latency feedback.
---
---Simulation events and Console commands share a persisted ready rotation.
---At most one item per computer runs in an actual tick.
---The scheduler uses FIFO queues and fair program/Console alternation.
---New work that becomes ready during a dispatch joins a later round.
---A returning callback completes or faults. It never suspends its Lua stack.
---Trusted Lua can stall the game or exhaust memory before it returns.
---Stop and scheduling do not interrupt runaway code.
---
---The scheduler indexes future timers by earliest deadline instead of visiting
---them every tick while they wait. Ordinary cold load retains pending order,
---registrations and same-tick credits. It does not repeat startup or completed effects.
---Custom computers need no electricity. Electrical cycling does not pause or
---discard accepted work.
---
---### Context
---Console shares real application state and source/host-work admission.
---It has its own scratch graph, output attribution and transient ownership.
---Only saved programs can call on, off, after, every, cancelTimer and stop.
---These methods raise E_UNSUPPORTED in Console.
---The API provides no filesystem, wall clock, direct signal API or direct computer messages.
---It provides no on_tick, guest stop/fault cleanup callback or implicit transaction.
---@class TC.Computer
computer = {}

---Return the current placed identity. Labels and native object IDs are not addresses.
---@return TC.ComputerId id Stable identity through ordinary save/load.
function computer.getID() end

---Read the descriptive user label. An empty string is distinct from no label.
---@return string|nil label Exactly one string or one nil when unset.
function computer.getLabel() end

---Set or clear the label atomically. Duplicate labels are permitted.
---This method returns no values. A non-string or a label beyond identifier_bytes
---causes E_ARGUMENT.
---@param label? string Omission or nil clears the label. Otherwise, supply a bounded byte string.
function computer.setLabel(label) end

---Read synchronized simulation time, not real elapsed time or a process clock.
---@return TC.Tick tick Current tick for this dispatched execution.
function computer.getTick() end

---Read a defensive complete map of effective limits and representation versions.
---Defaults are not live values. A settings change does not replenish spent host credit.
---Retired execution, allocation, depth, tuple, and generated-source fields are absent.
---string_bytes and table_entries constrain boundary data, not temporary Lua values.
---@return TC.Limits limits Current common limits, not a native settings object.
function computer.getLimits() end

---Read a defensive snapshot of explicit application state.
---For an absent value, this method returns one nil.
---False, an empty string and an empty table remain valid present values.
---Copy admission can fail with E_LIMIT/E_BUDGET.
---The method never reports failure as absence.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@return TC.Data|nil value Independent copy, or exactly one nil when absent.
function computer.getState(key) end

---This method validates and copies the complete value before it atomically replaces one state key.
---It returns no values. Invalid Data causes E_ARGUMENT/E_LIMIT.
---If the final retained size exceeds capacity, the method raises E_CAPACITY and
---leaves the old value unchanged.
---
---Earlier writes survive a later callback error. Nil does not delete a value.
---Use deleteState explicitly.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@param value TC.Data Required nonnil plain Data; no handles, cycles or functions.
function computer.setState(key, value) end

---Remove one state key. This method returns one boolean.
---Repeated removal causes no harm.
---@param key string Nonempty state key of at most identifier_bytes, not string_bytes.
---@return boolean removed True only when a present value was removed.
function computer.deleteState(key) end

---Append one bounded diagnostic entry. This method returns no values.
---Unlike print, this method requires a string. Formatting and retention admission
---precede publication. Existing Console retention can evict old entries.
---Logging uses the admitted execution owner. It does not repeat physical owner discovery for each entry.
---Canceled executions cannot append guest output.
---Both byte and entry bounds apply, including for empty entries.
---A refused append does not evict retained entries or change their truncation flag.
---Separate host diagnostics retain their existing output policy.
---
---Console attributes its calls to the shell. The shell attribution prefix counts
---toward console_bytes. Oversized output causes E_LIMIT, never a partial successful append.
---Saved programs require exactly one argument.
---The current Console override ignores additional arguments.
---This compatibility exception applies only to Console, not to arity in general.
---@param text string Exact bytes; text plus any shell prefix must fit console_bytes.
function computer.log(text) end

---This method does not return normally. It ends the active saved run through
---host-controlled cleanup. Cleanup cancels the run's work and clears only its
---still-owned Logic output. Guest pcall/xpcall cannot prevent stop.
---Source, state, logs and other writers' effects remain.
---In Console, this method throws ordinary E_UNSUPPORTED instead of stopping the run.
function computer.stop() end

---Register a named general-event handler in this run.
---Each call creates an independent registration, not a replacement.
---The handler name must be an export in the active source.
---Registrations survive reload without startup replay.
---The method accepts power_restored only for compatibility.
---The power_restored registration produces no new events.
---
---The method delivers no initial inventory. Discover explicitly after registration.
---Invalid names cause E_ARGUMENT. Excess registrations cause E_CAPACITY.
---Console calls cause E_UNSUPPORTED.
---General subscriptions are not bound to one incidental device.
---@param event_name TC.GeneralEventName Supported general event discriminator.
---@param handler_name TC.HandlerName Declared exported callback name, not a function.
---@return TC.SubscriptionId id New identity bound to this computer/run.
function computer.on(event_name, handler_name) end

---Cancel this run's registration.
---An ID from another computer or run causes E_ARGUMENT.
---Provider-specific lifecycle cleanup also applies to Logic and Dashboard registrations.
---Console calls cause E_UNSUPPORTED. The shell cannot use this method to change a saved run.
---@param subscription_id TC.SubscriptionId Identity from this run.
---@return boolean removed True if the registration existed; false if already absent.
function computer.off(subscription_id) end

---Schedule one named saved handler. The absolute deadline is the current tick
---plus the delay. This addition must stay within the safe integer domain, or the
---method raises E_RANGE. The method copies the optional payload at registration.
---Event admission consumes one-shot ownership once, but cancelTimer can still
---remove a queued delivery. A full timer inventory causes E_CAPACITY.
---
---Console calls cause E_UNSUPPORTED.
---@param delay_ticks integer Positive integer simulation ticks, not seconds.
---@param handler_name TC.HandlerName Export in the active saved document.
---@param payload? TC.Data Omission or nil means no payload field. The method copies nonnil Data.
---@return TC.TimerId id New one-shot identity owned by this run.
function computer.after(delay_ticks, handler_name, payload) end

---Schedule recurring named callbacks at aligned absolute deadlines.
---Overdue intervals coalesce into one TC.TimerEvent with a missed count, never a burst.
---Stop, fault or activation cancels these callbacks.
---Admission and Console restrictions are the same as for after.
---Pause, speed and wall-clock downtime do not change simulation deadlines.
---@param interval_ticks integer Positive integer simulation ticks within safe addition.
---@param handler_name TC.HandlerName Export in the active saved document.
---@param payload? TC.Data Omission or nil means no payload. Otherwise, the method copies the payload at registration.
---@return TC.TimerId id New recurring identity owned by this run.
function computer.every(interval_ticks, handler_name, payload) end

---Cancel both a future deadline and any matching queued undispatched event.
---An identity from another computer or run causes E_ARGUMENT.
---Console calls cause E_UNSUPPORTED.
---@param timer_id TC.TimerId Timer from this run, including an admitted one-shot.
---@return boolean removed True if pending deadline or queued delivery existed.
function computer.cancelTimer(timer_id) end
