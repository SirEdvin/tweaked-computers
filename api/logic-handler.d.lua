---@meta

---Physical connector status for both Logic input colors, independent of counts.
---@class TC.InputStatus
---@field red_connected boolean Whether the actual red INPUT connector has a connection.
---@field green_connected boolean Whether the actual green INPUT connector has a connection.

---Named input-change subscription options. Unknown fields fail before registration.
---@class TC.SignalSubscriptionOptions
---@field input TC.InputSelection Required explicit red or green; no default/both selector.
---@field signals? TC.SignalId[] Omitted/nil means all; otherwise nonempty dense unique effective identities.
---@field initial? boolean Default false; true requests a next-sample initial event with empty previous.

---Circuit I/O facade with independent INPUT, NETWORK and OUTPUT ports. The
---discovery wire and input selector are different: a red NETWORK path may read
---green INPUT. No internal feedthrough exists; external input/output wiring may
---deliberately create feedback. Output is one bank mirrored to both connectors,
---not independent color banks or total external network counts.
---
---### Signals and native inventory
---Effective identity is (type or item, name, quality or normal). Native reads
---preserve order and omitted fields without validation/sorting/normalization or
---stable-order promises. Caller filters/output validate installed signal types and
---prototypes, exact signed-32 counts, and unique effective identities; wildcard
---pseudo-signals are refused. Recipe names include installed mod recipes regardless
---of research/products. Same-name different types/qualities never merge.
---There is no mod-defined signal/filter/output count cap. Native index/count
---domains remain (output section indexes are uint16), and fixed service/dispatch
---work is metered. Native graph transfer bypasses generic Data ceilings, NOT guest
---execution, arbitrary growth or explicit state/KV/Console retention. It is not a
---calibrated universal memory/tick promise. Every direct read/baseline is fresh.
---
---### Subscriptions
---Register a declared saved handler by name, never persist a closure. Registration
---belongs to this run and exact discovery-color binding; another color does not
---silently take it over. Counts are checked on registration. Filters are uncapped
---by cardinality; non-growing edits to native arrays can build large requests.
---One fresh native read per watched physical input/color each simulation tick
---serves independent filters/events. No subscription means no discovery visit.
---Notifications compare effective counts/identities and connectivity, not order or
---explicit-default spelling. See TC.SignalChanged for baseline/admission semantics.
---Cancel/retire/removal releases watches and cancelled queued deliveries. Native
---updates do not promise within-tick transients or immediate output feedback.
---
---### Shared output ownership and lifetime
---Every successful setOutput/clearOutput transfers the entire bank to this
---computer/run/discovery binding; failure does not. Stop, fault, physical
---invalidity/removal, force/surface change or selected-path loss clears its
---still-owned output through host cleanup. A stopping prior writer must not clear
---a newer writer's bank. Cleanup precedes later unauthorized calls and retains the
---published physical observation envelope. It is not a general factory rollback:
---state/KV/monitor contents and Configurator-applied settings remain committed.
---Ordinary load retains valid ownership without republishing or creating a new
---owner. Clones/new placement start empty. Electrical cycling has no effect.
---Console writes instead belong to the shell-session identity. A saved-program
---fault does not clear shell-owned output; explicit Stop, successful Run/Apply or
---Reset Shell retires that shell's still-owned bank. Closing the window or cold
---load retains it. Neither execution owner may clear a newer writer's output.
---Legacy subscriptions with both/missing/invalid input fault before queued replay,
---clear still-owned output and require source correction/restart. Valid single-color
---load retains exact identities; legacy resync is current observation, not replay.
---@class TC.LogicHandler
local Logic = {}

---Read one signal from a freshly queried selected native input. Absent signal is
---zero, including disconnected input; inspect connectivity separately if needed.
---@param input TC.InputSelection Mandatory red/green INPUT color, not discovery wire.
---@param signal TC.SignalId Installed non-wildcard identity; defaults apply as documented.
---@return TC.Int32 count Native signed count; absent means zero, not nil.
function Logic.readSignal(input, signal) end

---Read the complete selected native input as a fresh detached array. Preserve
---native ordering/optional fields; no cached observation or sorted-prefix result.
---@param input TC.InputSelection Mandatory red/green INPUT color.
---@return TC.Signal[] signals Complete fresh input, possibly empty.
function Logic.readSignals(input) end

---Inspect actual input connector connectivity, not whether any count is nonzero.
---@return TC.InputStatus status Both physical input colors' connection status.
function Logic.getInputStatus() end

---Read this handler's configured native output contribution only, not totals from
---other devices on either connected network. Native section is the source of truth.
---@return TC.Signal[] signals Detached configured contribution, empty for no output.
function Logic.getOutput() end

---Atomically replace the entire output bank and transfer last-writer ownership.
---Require dense unique effective identities and exact Int32 counts; zero entries
---are omitted. Duplicate default aliases, wildcard/prototype/count/index errors
---fail before mutation. Both OUTPUT colors receive the one bank. Zero results.
---@param signals TC.Signal[] Complete desired contribution; empty array clears.
function Logic.setOutput(signals) end

---Equivalent to setOutput({}), including last-writer ownership. Zero results.
function Logic.clearOutput() end

---Register a named saved callback using a fresh baseline. E_ARGUMENT rejects
---invalid/missing/both input, handler or malformed filter; unknown/wildcard signal
---prototypes or qualities are E_RANGE. E_CAPACITY refuses excess registrations.
---Console is E_UNSUPPORTED, including captured-method and peripheral.call routes.
---@param options TC.SignalSubscriptionOptions Exact validated selection/filter/initial options.
---@param handler_name TC.HandlerName Declared export receiving TC.SignalChanged.
---@return TC.SubscriptionId id New run-bound exact peripheral/wire registration.
function Logic.subscribe(options, handler_name) end

---Remove this run/binding's registration and its queued undispatched samples.
---Another computer/run/binding is invalid; Console is E_UNSUPPORTED.
---@param subscription_id TC.SubscriptionId Registration for this Logic binding.
---@return boolean removed True if present; false if already absent.
function Logic.unsubscribe(subscription_id) end

---Read effective common registration/work policy plus sampling/notification
---envelopes. Removed signal_slots, filter_signals, active_logic_handlers and
---aggregate_owned_outputs fields are absent, not replacement configuration knobs.
---@return TC.LogicLimits limits Defensive limit map; not a native signal cardinality cap.
function Logic.getLimits() end
