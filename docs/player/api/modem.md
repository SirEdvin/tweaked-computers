# Radar modems

A vanilla radar can be a `modem`. Connect its native circuit socket to a
computer's Network socket using red or green wire, directly or through supported
same-color network relays. No adapter item, extra
research, replacement body or hidden power helper is required. Native scanning,
circuit transmission, opening, settings, power use and mining remain vanilla.
Only the exact vanilla `radar` and the optional advanced radar are supported;
other mods' radar prototypes are not automatically enrolled.

A radar is enrolled only through a physical path rooted at a placed computer.
Placement, cloning, revival or a standalone peripheral component does not enroll
it. A stopped or faulted computer still supplies a physical root; custom computers need no electricity;
running a program is not required for discovery. The complete path must stay on
one wire color, force and surface. Hidden radio links and adjacent monitor tiles
do not extend that path.

Fresh discovery requests bounded computer-rooted adoption of an existing wired
radar. Maintenance retains only pending computer/color requests, including
stopped physical roots; idle computers do not acquire an adoption sweep.
While adoption is incomplete, discovery reports `E_NETWORK_PENDING`; exhausted
identity capacity reports `E_CAPACITY`. Integration failure never destroys or
refunds a native radar. Very crowded native hidden-link inventories can exceed
the physical edge limit and report `E_LIMIT`, even with few visible local cables.

## Local wire authority, radio channels

`peripheral.find("modem", "red")` selects a locally reachable modem. The explicit
wire is a physical discovery color, not a frequency. Native radar hidden links
are excluded from discovery and saved path witnesses. A radar relays local
same-color physical discovery wires, but never switches colors. Ordinary poles,
machines and factory-only ports remain unsupported discovery relays.

`peripheral.describe(name, wire)` includes `modem_tier` (`surface` or
`interplanetary`), actual 3×3 or 5×5 footprint, quality and current availability.
Both wire colors expose the same physical name and shared channel set.
Receiving a name in a message never grants access to the sender's peripherals.
There is no rednet, remote enumeration, remote method call, `os.pullEvent`, OS
socket or automatic repeater.

## Seven methods

All calls use dots and exact argument counts. The channel domain is integer
0–65535, including both endpoints. Wrong types or arity give `E_ARGUMENT`;
out-of-domain numbers give `E_RANGE`.

| Call | Result | Meaning |
| --- | --- | --- |
| `open(channel)` | no values | Open a shared channel; reopening is harmless. |
| `isOpen(channel)` | boolean | Test this radar's shared set. |
| `close(channel)` | no values | Close a shared channel; absent is harmless. |
| `closeAll()` | no values | Close every channel, including another computer's. |
| `transmit(channel, replyChannel, payload)` | no values | Submit an independent broadcast, with no ACK or delivery count. |
| `isWireless()` | true | Both tiers are wireless. |
| `getLimits()` | copied record | Effective finite transport and common Data bounds. |

128 distinct channels may be open per physical radar. At capacity reopening an
existing channel succeeds; opening a new channel gives `E_CAPACITY` without
changing the set. Both computers, both colors, saved programs and Console share
that set. Stop/fault does not close channels. Use separate radars for independent
channel ownership. Console can configure and transmit, but cannot register a
background receiver. Only a running saved program receives callbacks.

Discovery, metadata and `getLimits()` remain available without power. Every other
method requires a live native radar with `active=true` and positive electrical
energy; otherwise it gives `E_UNPOWERED`. Native freezing/script disablement is
also unavailable. Low supply can cause tick-by-tick availability changes. The
mod reads power; it never increases or normalizes the radar's buffer.

## Messages and named handlers

Use the complete [sender and receiver examples](../examples.md). They explicitly
register `computer.on("modem_message", "receive")` or `"reply"`, open the receiving
channel, and send replies themselves. Registration names are strings, not
function values. Neither the sending channel nor reply channel needs to be open
on the sender to transmit. `replyChannel` is a hint, not an automatic return route.

A `modem_message` handler retains background topology interest in both local
wire colors even without attach/detach handlers. Opening a channel alone does
not create receive interest. Removing the last relevant handler retires future
observation after pending host work settles, not already accepted queue snapshots.
Actual transmission and receiver eligibility always use fresh live proofs.

A modem event has ordinary `name`, dispatch `tick`, `sequence`, `computer_id` and
`run_id`, plus:

| Field | Value |
| --- | --- |
| `peripheral` | The locally receiving radar name, never sender authority. |
| `wire`, `wires` | Receive-time local paths, red before green; `wire` is first. |
| `channel`, `replyChannel` | Exact numeric values selected by the sender. |
| `message` | Independent Data snapshot, or absent for explicit nil. |
| `distance` | Euclidean radar-center distance in tiles on the same surface; absent across surfaces. |
| `sent_tick` | Accepted transmission simulation tick, even if dispatch is later. |

One radar reached on both colors produces one event per handler registration.
Two receiving radars produce separate events; duplicate registrations are
intentional duplicate callbacks. Publication order is computer name, receiving
radar name, subscription sequence. Callbacks use FIFO scheduling and never run
recursively inside `transmit()`; no minimum one-tick delay is promised.

Only exact same-force powered receivers with open channels participate. Allied
forces are not included. Either tier communicates at any distance on one surface;
there is no scanning-radius range gate. The sending physical radar is excluded,
even if another computer is attached to it. Another local radar remains eligible.

Payloads follow [Data rules](common.md), plus explicit top-level nil as the third
argument. Omitting that argument is an arity error. False, zero and empty strings
remain distinct. No cycles, facades, metatables, native objects, functions,
nonfinite numbers, sparse arrays or mixed-key maps are serialized. Every handler
owns its own copy; changing one copy cannot affect the sender or another handler.

## Bounds and datagram failure

The measured initial transport envelope is `message_bytes=4096`,
`message_nodes=256`, `message_depth=8`,
`routing_candidates=64`, `deliveries_per_transmit=8`,
`transmits_per_computer_tick=2`, `transmits_per_tick=16`. Encoded Data bytes include
string/table/key overhead; a string's length alone is not its Data byte size.
`getLimits()` also exposes `channel_min=0`, `channel_max=65535`, `open_channels=128`
and common string/table/node/depth ceilings. Quality does not change these bounds.
The full event envelope, not only payload bytes, must fit the recipient queue.
Routing starts with eligible receiving computers and their fresh local paths.
The candidate ceiling counts unique connected, available, open-channel receivers;
disconnected remembered radars are not scanned and do not consume candidate slots.

Proof, copies and complete fanout are admitted before publication. A relevant
incomplete graph, invalid payload, payload/fanout/rate bound or fatal host budget
refusal publishes no recipient prefix. Unrelated forces/surfaces are excluded
from relevant proof. Rate allowance is shared across programs, Console and both
colors; retry a rate refusal on a later tick, not in a tight loop. Existing global
callback/host/maintenance budgets remain unchanged and can refuse a smaller
workload under contention.

The packaged competition scene combines four 6×6 charts, one maximum-size
transmission to eight handler registrations every 15 ticks, and a live logic
controller polling every 15 ticks. This is not a promise that every independent
cap can be saturated simultaneously. In particular, the separate lossless
every-tick logic subscription can visibly refuse with `E_BUSY` under full-wall
maintenance pressure; owned outputs fail closed rather than losing observations.
Polling/reapplying an appropriate controller or reducing workload is explicit
player recovery, not an automatic change to a saved program. Headless publication
intervals and a 30 FPS recording are not measured client FPS.

After acceptance, a full recipient queue visibly faults that run, discards its
remaining deliveries and continues other recipients. The sender is not given a
retryable partial-send error. There is no ACK, retry, delivery guarantee or offline
mailbox. Closing/detaching a radar after queue admission does not recall accepted
data. Computer Stop/fault/removal can cancel transient queued messages; electrical cycling cannot.
Missed outage traffic is never replayed. Current peripheral calls always require
new local authority, even inside an accepted event handler.

## Space Age advanced tier

With Space Age 2.1.23 enabled, research **Interplanetary radar modems**. Research
requires exactly automation, logistic, chemical, production, utility and space
science: 500 units, one of each pack per unit, 30 seconds. No military or
planet-specific pack. Prerequisites are circuit computers and the production,
utility and space-science technologies. The recipe is initially disabled and
unlocks with research; reconciliation preserves an already researched force's
unlock without granting research to others.

Craft one radar, 20 steel plates, 20 processing units and 10 low-density structures
in 10 seconds. The advanced radar consumes 1 MW, uses a 5×5 footprint and about
1.5× native radar visual scale. These are initial balance choices, not measured
balance claims. Scanning radii remain native. Body, shadow, integration/reflection
and wire contact transformations reference installed native assets; no Factorio
assets are bundled. See [transformation provenance](../radar-native-assets.md).
The advanced entity retains the pinned native 300 kW heating requirement on
freezing surfaces, separately from its 1 MW electrical consumption.

Both endpoints must be advanced for cross-surface traffic, including genuine
travelling platforms. Mixed tiers communicate only on the same surface, in both
directions. Platforms need an adequate ordinary valid construction site and power;
there is no planet-only, orbital-location or stationary-platform routing gate.
Base-only games have no advanced entity, item, recipe or technology.

## Saves and moving devices

Ordinary save/load retains exact radar IDs, channels, accepted queues, subscriptions
and spent same-tick transport credits. Load executes no guest startup or transmit.
An ordinary same-scope power cycle retains channels. Force/surface changes revoke
old bindings and clear channels before participation in the new scope. Mining,
replacement, clone and blueprint placement receive a new empty identity only
after a valid computer connection; channel state is not copied into items or
pasted settings.

Disconnecting the last computer path preserves the same radar's name and channels
as dormant saved data, without recurring availability checks, generic tick visits
or dormant-pool polling. Same-entity, same-scope reconnection restores access;
an old wrapper grants no authority while detached. Dormant radars receive and
buffer no traffic, and reconnecting never replays missed messages. Already queued
snapshots are not recalled by radar removal.

Version 0.1.16 partitions previously registered radars out of generic ticking
before the first ordinary tick after upgrading 0.1.15. No mining, rewiring or
gameplay cleanup sweep is required. Ordinary cold reload preserves that separation.
Dormant records still use memory/save space and count toward identity capacity;
Factorio's own native radar simulation is unchanged.

Back up the save and complete mod set before upgrade. Roll back by restoring that
backup with its prior mods. Older code assumes a different registry layout, so do
not downgrade a newly saved 0.1.16 world in place. Downgrading a live save or removing Space Age is not
promised lossless: advanced entities/research can disappear. Unknown/corrupt modem
state is retained inert with `E_UNSUPPORTED`, not silently reset.
