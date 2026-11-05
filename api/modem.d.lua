---@meta

---A radio channel is a finite exact number in 0..65535, unrelated to the red or green circuit wire.
---Channels are shared routing identifiers, not security credentials.
---@alias TC.RadioChannel integer

---This modem sends checked native radar datagrams.
---Peripheral metadata identifies the surface or interplanetary tier.
---Only vanilla radar and Space Age tc-interplanetary-radar are supported, not arbitrary radar prototypes.
---
---Discovery and enrollment start at a computer through a complete physical path on the same color, force and surface.
---They never use native hidden radio links, standalone peripherals, ghosts or monitor adjacency.
---Supported native relays can enroll transitively.
---Stopped and faulted computers remain physical roots.
---Pending adoption survives load and proves scope and generation again without partial inventories.
---
---Channel state belongs to this physical radar.
---All local computers, wire colors, runs and Console sessions share that state in accepted-call order.
---Stop and fault do not close channels.
---Channel opening alone creates neither a program nor a receive subscription.
---Console can call every method but cannot register a background named receive handler.
---
---Real interactions and receive eligibility check native power and active availability, not generic background polling.
---Only getLimits and discovery remain available without power.
---Even isOpen and isWireless need availability.
---Custom computers need no power.
---
---### Reception and routing
---Saved programs use computer.on('modem_message', handler_name).
---Each registration gets a separate TC.ModemMessage.
---Registration maintains topology interest in both colors, but transmission uses fresh proofs.
---Each computer run/receiving radar/registration gets one event.
---Both colors deduplicate with red first.
---Two receiver radars give two deliveries.
---
---The exact transmitting radar cannot receive the datagram, even through another computer.
---Another radar connected to the sender's computer can receive it.
---Only active powered receivers with an open channel and the exact same force qualify.
---Allies do not qualify.
---
---Either tier operates at any distance on one surface.
---Cross-surface transmission requires both interplanetary and Space Age, also for traveling platforms.
---There is no invented planetary distance, delay, radio bridge or relay routing.
---Destinations require a running valid computer/handler and a fresh local path.
---If no receiver qualifies, transmission is a successful no-op.
---The channel need not be open at the sender.
---
---Candidate, delivery, copy and work planning completes before the first packet effect.
---A relevant proof, fan-out, capacity or rate refusal publishes no prefix.
---Dormant disconnected records are not radio candidates.
---After path deduplication, successful publication follows computer ID, receiver ID and subscription sequence order.
---
---Callbacks use scheduling, not reentrant calls.
---There is no guaranteed minimum one-tick delay.
---Identical transmissions remain independent.
---Queue overflow faults that recipient, skips its remaining deliveries and continues with other recipients.
---After partial publication, queue overflow is not a retryable sender error.
---There is no ACK, delivery count, retry or guaranteed receipt.
---
---### Lifetime
---Queued packets are accepted independent snapshots.
---Later channel closure, receiver detachment or receiver removal does not recall them.
---Computer or run retirement still cancels transient events.
---The modem does not replay missed traffic.
---Cold load retains channels, registrations, queues and spent transport credits without retransmission or source execution.
---
---Mining, blueprint, clone and settings paste do not carry channels.
---New enrollment has a new empty identity.
---Force or surface reassignment clears channels and revokes the old scope before reuse.
---A mismatched call refuses access until host reconciliation; it does not repair authority.
---
---Disconnection of the same entity in the same scope retains dormant channels and identity without polling, adoption or routing.
---Reconnection restores access without replay of missed messages.
---Dormant records still consume identity, memory and save capacity.
---Targeted destruction does not transfer state.
---A compatible legacy upgrade removes recurring dormant work before the next tick.
---Unsupported saved state remains retained with E_UNSUPPORTED.
---
---There is no remote peripheral enumeration or call, rednet, os.pullEvent, network socket, HTTP, file or new global modem namespace.
---@class TC.Modem
local Modem = {}

---Add a shared channel.
---The method returns zero values.
---Reopening succeeds even at capacity.
---A new 129th channel raises E_CAPACITY without a change to the set.
---@param channel TC.RadioChannel Required exact integer 0..65535. The wrong type causes E_ARGUMENT. An invalid numeric domain causes E_RANGE.
function Modem.open(channel) end

---Read the shared open state.
---The method still requires powered native availability.
---@param channel TC.RadioChannel Required exact integer 0..65535.
---@return boolean open True exactly when this physical radar's shared set contains the channel.
function Modem.isOpen(channel) end

---Remove a shared channel.
---An absent channel is a valid no-op.
---The method returns zero values.
---@param channel TC.RadioChannel Required exact integer 0..65535.
function Modem.close(channel) end

---Clear all channels, also those that another authorized caller opened.
---The method returns zero values.
function Modem.closeAll() end

---Broadcast one complete defensive datagram.
---Supply all three positions, with an explicit third nil for a nil message.
---False, zero and an empty string are distinct.
---Top-level nil is the only Data exception.
---Nested nil, cycles, mixed or sparse tables, nonfinite numbers, functions, facades and native objects remain invalid.
---
---Before any packet effect, validation checks all bytes, nodes, depth and per-handler event copies.
---Payload size alone is not event size.
---Every recipient gets an independent snapshot.
---
---Both per-computer and world tick limits include saved-program calls, Console calls and both wire colors.
---Rate, fan-out or payload refusal causes E_LIMIT, not a boolean or automatic retry.
---Fatal E_BUDGET remains noncatchable.
---Existing physical errors can occur before argument errors.
---The method returns zero values: neither boolean success, delivery count nor acknowledgement.
---@param channel TC.RadioChannel Destination numeric channel, independent of locally open channels.
---@param replyChannel TC.RadioChannel Sender hint only. There is no automatic reply, route or local channel opening.
---@param payload TC.Data|nil Required third position. Explicit nil makes event.message absent.
function Modem.transmit(channel, replyChannel, payload) end

---Both supported tiers are wireless.
---This method does not enumerate or authorize peers.
---@return true wireless Exactly one true result, after powered availability checks.
function Modem.isWireless() end

---Read the exact transport map with string_bytes, table_entries, data_nodes and data_depth.
---It is not the entire TC.Limits map.
---The method is available without power, but still requires physical reachability and generation/scope authority.
---No numeric infinity indicates unlimited range.
---Only channel_min is zero.
---Resource limits are not throughput guarantees.
---@return TC.ModemLimits limits Defensive finite transport/data envelope.
function Modem.getLimits() end
