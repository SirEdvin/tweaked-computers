---@meta

---Physical connector status for both Logic input colors, independent of signal counts.
---@class TC.InputStatus
---@field red_connected boolean Whether the actual red INPUT connector has a connection.
---@field green_connected boolean Whether the actual green INPUT connector has a connection.

---Options for named input-change subscriptions.
---Unknown fields cause failure before registration.
---@class TC.SignalSubscriptionOptions
---@field input TC.InputSelection Required explicit red or green. There is no default or both selector.
---@field signals? TC.SignalId[] Omission or nil selects all signals. Otherwise, supply a nonempty dense array of unique effective identities.
---@field initial? boolean Default false. A true value requests an initial event at the next sample, with empty previous.

---This circuit I/O facade has independent INPUT, NETWORK and OUTPUT ports.
---The discovery wire and input selector are different.
---A red NETWORK path can read green INPUT.
---There is no internal feedthrough, but external input/output wiring can deliberately cause feedback.
---Both connectors mirror one output bank.
---The output is not independent color banks or total external network counts.
---
---### Signals and native inventory
---The effective identity is (type or item, name, quality or normal).
---Native reads preserve order and omitted fields without validation, sorting or normalization.
---They do not guarantee stable order.
---Caller filters and output require installed signal types and prototypes, exact signed-32 counts, and unique effective identities.
---Validation refuses wildcard pseudo-signals.
---
---Recipe names include installed mod recipes, independent of research or products.
---Signals with the same name but different types or qualities never merge.
---The mod sets no count cap for signals, filters or output.
---Native index and count domains still apply; output section indexes are uint16.
---Metering still applies to fixed service and dispatch work.
---
---Native graph transfer bypasses generic Data ceilings.
---This exception does not apply to guest execution, arbitrary growth or explicit state/KV/Console retention.
---It is not a calibrated universal guarantee for memory or ticks.
---Every direct read and baseline is fresh.
---
---### Subscriptions
---Register a declared saved handler by name.
---Never persist a closure.
---Registration belongs to this run and the exact discovery-color binding.
---Another color does not silently take ownership of the registration.
---Registration checks the counts.
---
---Filters have no cardinality cap.
---Non-growing edits to native arrays can build large requests.
---Each simulation tick uses one fresh native read per watched physical input/color for independent filters and events.
---Without a subscription, there is no discovery visit.
---
---Notifications compare effective counts, identities and connectivity, not order or explicit-default spelling.
---See TC.SignalChanged for baseline and admission semantics.
---Cancellation, retirement and removal release watches and cancelled queued deliveries.
---Native updates do not guarantee within-tick transients or immediate output feedback.
---
---### Shared output ownership and lifetime
---Every successful setOutput or clearOutput transfers the entire bank to this computer/run/discovery binding.
---Failure does not transfer ownership.
---Host cleanup clears still-owned output after Stop, fault, physical invalidity or removal, force/surface change, or selected-path loss.
---When a previous writer stops, it must not clear a newer writer's bank.
---Cleanup occurs before later unauthorized calls and retains the published physical observation envelope.
---This is not a general factory rollback: state/KV/monitor contents and Configurator-applied settings remain committed.
---
---Ordinary load retains valid ownership without republication or a new owner.
---Clones and new placement start empty.
---Electrical cycling has no effect.
---
---Console writes instead belong to the shell-session identity.
---A saved-program fault does not clear shell-owned output.
---Explicit Stop, successful Run/Apply or Reset Shell retires the bank that the shell still owns.
---Window closure and cold load retain that bank.
---Neither execution owner may clear a newer writer's output.
---
---Legacy subscriptions with both, missing or invalid input fault before queued replay.
---They clear still-owned output and require source correction and restart.
---Valid single-color load retains exact identities.
---Legacy resync is a current observation, not replay.
---@class TC.LogicHandler
local Logic = {}

---Read one signal from a fresh native query of the selected input.
---An absent signal is zero, also when the input is disconnected.
---If necessary, inspect connectivity separately.
---@param input TC.InputSelection Mandatory red or green INPUT color, not the discovery wire.
---@param signal TC.SignalId Installed non-wildcard identity; defaults apply as documented.
---@return TC.Int32 count Native signed count; absent means zero, not nil.
function Logic.readSignal(input, signal) end

---Read the complete selected native input as a fresh detached array.
---The array preserves native order and optional fields.
---The result is not a cached observation or a sorted prefix.
---@param input TC.InputSelection Mandatory red or green INPUT color.
---@return TC.Signal[] signals Complete fresh input, possibly empty.
function Logic.readSignals(input) end

---Inspect the actual input connector connectivity, not whether any count is nonzero.
---@return TC.InputStatus status Both physical input colors' connection status.
function Logic.getInputStatus() end

---Read only the configured native output contribution of this handler.
---The result excludes totals from other devices on either connected network.
---The native section is the source of truth.
---@return TC.Signal[] signals Detached configured contribution, empty for no output.
function Logic.getOutput() end

---Atomically replace the entire output bank and transfer last-writer ownership.
---The input must contain dense unique effective identities and exact Int32 counts.
---The method omits zero entries.
---Duplicate default aliases and wildcard, prototype, count or index errors cause failure before mutation.
---Both OUTPUT colors receive the one bank.
---The method returns zero values.
---@param signals TC.Signal[] Complete desired contribution. An empty array clears the bank.
function Logic.setOutput(signals) end

---This method is equivalent to setOutput({}), with the same last-writer ownership.
---It returns zero values.
function Logic.clearOutput() end

---Register a named saved callback with a fresh baseline.
---Invalid or missing input, both input, an invalid or missing handler, or a malformed filter causes E_ARGUMENT.
---Unknown or wildcard signal prototypes or qualities cause E_RANGE.
---Excess registrations cause E_CAPACITY.
---Console causes E_UNSUPPORTED, also through captured methods and peripheral.call.
---@param options TC.SignalSubscriptionOptions Exact validated selection, filter and initial options.
---@param handler_name TC.HandlerName Declared export that receives TC.SignalChanged.
---@return TC.SubscriptionId id New run-bound exact peripheral/wire registration.
function Logic.subscribe(options, handler_name) end

---Remove the registration for this run/binding and its queued samples that await dispatch.
---A different computer, run or binding is invalid.
---Console causes E_UNSUPPORTED.
---@param subscription_id TC.SubscriptionId Registration for this Logic binding.
---@return boolean removed True if present; false if already absent.
function Logic.unsubscribe(subscription_id) end

---Read the effective common registration/work policy and sampling/notification envelopes.
---The removed signal_slots, filter_signals, active_logic_handlers and aggregate_owned_outputs fields are absent.
---They are not replacement configuration controls.
---@return TC.LogicLimits limits Defensive limit map; not a native signal cardinality cap.
function Logic.getLimits() end
