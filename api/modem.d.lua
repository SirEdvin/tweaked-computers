---@meta

---Finite exact numeric radio channel 0..65535, unrelated to red/green circuit wire.
---Channels are shared routing identifiers, not security credentials.
---@alias TC.RadioChannel integer

---Checked native radar datagrams, with surface/interplanetary tiers in peripheral
---metadata. Only vanilla radar and Space Age tc-interplanetary-radar are supported,
---not arbitrary radar prototypes. Discovery/enrollment is computer-rooted through
---a complete same-color/force/surface physical path, never native hidden radio links,
---standalone peripherals, ghosts or monitor adjacency. Supported native relays may
---enroll transitively; stopped/faulted computers remain physical roots. Pending
---adoption survives load and re-proves scope/generation without partial inventories.
---
---Channel state belongs to this physical radar, shared by all local computers,
---wire colors/runs/Console sessions in accepted-call order. Stop/fault does not close
---channels. Opening alone creates neither program nor receive subscription. Console
---can call every method but cannot register a background named receive handler.
---Native power/active availability is checked at real interactions/receive eligibility,
---not generic background polling; only getLimits/discovery remain available without
---power. Even isOpen/isWireless need availability. Custom computers need no power.
---
---### Reception and routing
---Saved programs use computer.on('modem_message', handler_name); each registration
---gets a separate TC.ModemMessage. It maintains both-color topology interest, but
---transmission uses fresh proofs. One event per computer run/receiving radar/
---registration; both colors deduplicate with red first. Two receiver radars are two
---deliveries. The exact transmitting radar is excluded even via another computer;
---another radar wired to the sender's computer may receive.
---Only active powered receivers with an open channel and exact same force qualify;
---allies are excluded. Either tier works at any distance on one surface. Cross-
---surface requires both interplanetary and Space Age, including travelling platforms.
---No invented planetary distance, delay, radio bridge or relay routing exists.
---Destinations require a running valid computer/handler and fresh local path.
---No receiver is a successful no-op. Channel is not required open at the sender.
---
---Candidate/delivery/copy/work planning completes before the first packet effect.
---Relevant proof/fan-out/capacity/rate refusal publishes no prefix. Dormant disconnected
---records are not radio candidates. Successful publication is ordered by computer
---ID, receiver ID, subscription sequence after path deduplication. Callbacks are
---scheduled, not reentrant; there is no promised minimum one-tick delay. Identical
---transmissions remain independent. Queue overflow faults that recipient, skips its
---remaining deliveries and continues other recipients; it is not a retryable sender
---error after partial publication. No ACK, delivery count, retry or guaranteed receipt.
---
---### Lifetime
---Queued packets are accepted independent snapshots; later close/detach/removal of
---the receiver does not recall them. Computer/run retirement still cancels transient
---events. No missed traffic is replayed. Cold load retains channels, registrations,
---queues and spent transport credits without retransmission/source execution. Mining,
---blueprint/clone/settings paste do not carry channels; new enrollment has new empty
---identity. Force/surface reassignment clears channels and revokes old scope before
---reuse; a mismatched call refuses pending host reconciliation, not repairs authority.
---Same-entity same-scope disconnection retains dormant channels/identity without
---polling/adoption/routing; reconnection restores access without missed-message replay.
---Dormant records still consume identity/memory/save capacity. Targeted destruction
---does not transfer state. Compatible legacy upgrade removes recurring dormant work
---before the next tick; unsupported saved state is retained with E_UNSUPPORTED.
---No remote peripheral enumeration/calls, rednet, os.pullEvent, network sockets,
---HTTP, files or new global modem namespace are supplied.
---@class TC.Modem
local Modem = {}

---Add a shared channel, returning zero values. Reopening succeeds even at capacity;
---a new 129th channel raises E_CAPACITY without changing the set.
---@param channel TC.RadioChannel Required exact integer 0..65535; wrong type E_ARGUMENT, numeric domain E_RANGE.
function Modem.open(channel) end

---Read shared open state; still requires powered native availability.
---@param channel TC.RadioChannel Required exact integer 0..65535.
---@return boolean open True exactly when this physical radar's shared set contains the channel.
function Modem.isOpen(channel) end

---Remove a shared channel; absent is a valid no-op. Returns zero values.
---@param channel TC.RadioChannel Required exact integer 0..65535.
function Modem.close(channel) end

---Clear all channels, including ones opened by another authorized caller. Zero results.
function Modem.closeAll() end

---Broadcast one complete defensive datagram. Require all three positions, including
---an explicit third nil for a nil message. False/zero/empty string are distinct.
---Top-level nil is the sole Data exception; nested nil, cycles/mixed/sparse tables,
---nonfinite numbers/functions/facades/native objects remain invalid. Validate all
---bytes/nodes/depth and per-handler event copies before any packet effect; payload
---size alone is not event size. Every recipient gets an independent snapshot.
---Both per-computer and world tick limits include saved/Console calls and both wire
---colors. Rate/fan-out/payload refusal is E_LIMIT, not a boolean or automatic retry;
---fatal E_BUDGET stays noncatchable. Existing physical errors can precede arguments.
---Returns zero values: neither boolean success, delivery count nor acknowledgement.
---@param channel TC.RadioChannel Destination numeric channel, independent of local opens.
---@param replyChannel TC.RadioChannel Sender hint only; no automatic reply, route or local channel opening.
---@param payload TC.Data|nil Required third position; explicit nil gives an absent event.message.
function Modem.transmit(channel, replyChannel, payload) end

---Both supported tiers are wireless; this does not enumerate or authorize peers.
---@return true wireless Exactly one true result, after powered availability checks.
function Modem.isWireless() end

---Read the exact transport map plus string_bytes/table_entries/data_nodes/data_depth.
---It is NOT the entire TC.Limits map. Accessible while unpowered, but still requires
---physical reachability and generation/scope authority. No numeric infinity denotes
---unlimited range; only channel_min is zero. Resource limits are not throughput claims.
---@return TC.ModemLimits limits Defensive finite transport/data envelope.
function Modem.getLimits() end
