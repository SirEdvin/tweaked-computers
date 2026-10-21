-- Plain native help text; no rich text or file imports.
local M={
  template=[[local function increment(value)
  return value + 1
end

function start(event)
  local total = sample()
  print("Initial sample count:", total)
  computer.every(60, "sample")
end

function sample(event)
  local total = increment(computer.getState("samples") or 0)
  computer.setState("samples", total)
  return total
end
]],
  text=[[TWEAKED COMPUTERS — Lua API v1
One document. Native named callbacks; no OS, VM or filesystem.

WORKFLOW
Editor is the writing workspace. Focus hides tabs without replacing your source.
Console holds bounded live output; Follow off stops automatic scrolling, not updates.
Incoming changed text may clear selection; native selection/copy works between updates.
Console also accepts one live Lua line with Enter or Execute; no command history.
Scratch globals/tables and peripheral bindings are shared per computer and saved.
print(p.getSize()) inspects a retained p=peripheral.wrap(name,"red") binding.
Calls affect the real factory. Failed commands keep previous scratch values but
do not undo earlier API effects. No retained user functions, timers or subscriptions.
Successful Run/Apply, explicit Stop or confirmed Reset Shell clear scratch values.
Close/reopen, save/load, program faults and power loss keep committed values.
Peripherals inspects the red or green channel, with explicit pending results.
Click a row to select details; click the selected row again for its Reference topic.
There is no double-click timer. Changing wire or unavailable inventory resets selection.
Reference filters this complete help by category/search; Select text uses native Copy.
Insert starter only changes an empty draft. It never saves or runs it.
Maintenance holds reviewed revision resolution, retained drafts and stopped-only reset.
Type/paste into the source box. Validate checks the draft without effects.
Save commits source, but does not change the active run. Run/Apply validates and
activates the displayed saved revision only. Save first if the draft is dirty.
Invalid replacements preserve the old run. State survives replacement.
Stop cancels callbacks/timers and clears only this run's still-owned logic output.
Reset State requires Stop and a separate confirmation; it never clears a KV.
Close/Escape retains the draft. Reopen the same body to recover it.
Conflict: Review opens Maintenance; read current source, then Rebase (retain draft) or
Reload (discard your draft). The revision is checked again on either action.
Eight bounded recovery drafts per player; no automatic dirty-draft eviction.
Ctrl+left-click (rebindable), empty cursor/no GUI, opens a computer or recovery.
Ordinary opening of a composite peripheral opens its read-only local inspector;
radars and programmable speakers keep their native configuration windows.
No computer or running program is required. Select name for copy selects only the API ID;
use native Copy, then paste into your draft. Escape retains computer drafts.
Open inspectors and Peripherals update automatically, with bounded pages/chunks.
KV byte strings quote empty values, escape quotes/backslashes and use hexadecimal
byte escapes for control/high bytes and brackets. Full values remain reachable.
Configurator lists target-side prototypes: Unique deduplicates overlapping Red
and Green counts. Logic shows separate colored inputs and its own output bank,
not other emitters. Logic/monitor updates are sampled every 15 ticks when admitted.
Monitor dimensions are local connected tiles and terminal columns/rows, not pixels.
Ctrl-click monitor touches remain distinct. Unpowered peripherals retain identity,
but only committed monitor geometry is readable without active service power.
All essential actions are buttons, including while the text box has focus.

LANGUAGE
function start(event) ... end; function sample(event) ... end
Plain declarations export named handlers; API version 1 is implicit. start is optional.
sample() calls directly in this program with ordinary arguments/results and the
same callback budget. computer.every(60, "sample") schedules a later TimerEvent.
Names alone do not subscribe. Registration uses strings, never function values.
Declare private local function helpers before use; they are not exported.
Exports are read-only and forward-visible; parameters/locals shadow them normally.
Legacy return {api_version=1, handlers={start=function(event) ... end, ...}}
still works. Use one form per document. No top-level values, calls or effects.
Locals, helpers, if, loops and tables have guarded work/depth/allocation limits.
Functions/locals are fresh per callback; keep durable values in computer state.
Console cannot call saved-program functions. The starter samples once immediately,
logs the returned count, then samples every 60 simulation ticks; no device required.
No require/load, game/storage/remote, _ENV/_G, metatables, coroutine, patterns,
random, string-method syntax or colon calls. API calls use dots.
Approved globals: assert, error, ipairs, pairs, next, pcall, xpcall, select,
tonumber, tostring, type, print, rawget, rawset, rawlen, rawequal, unpack,
_VERSION, math, string, table, colors/colours, computer, peripheral.
print(...) writes one tab-separated Console entry, including false/nil; no results.
print() writes an empty entry. No chat output. computer.log(text) is unchanged.
rawget(t,key), rawset(t,key,value) require guest-owned plain tables, not API handles.
rawset returns t; nil deletes. rawget with explicit nil/NaN returns nil.
rawlen measures string bytes or native table borders, not map cardinality.
rawequal(a,b) compares approved identities/values without inspecting API handles.
unpack == table.unpack; same index/tuple limits (i=1..1025, j=0..1024).
_VERSION is "Lua 5.2", not unrestricted Lua support. Data/retention is unchanged.
xpcall(fn,handler,...) returns true,results or false,first handler result (nil included).
Guest errors preserve identity; host error records are copied. Handler failures
use bounded native error-handler re-entry. Earlier successful effects stay committed.
Fatal work/allocation/depth/tuple exhaustion and stop bypass pcall AND xpcall;
private control values never reach a guest handler. Console cannot stop a program.
New global names are reserved for public/private top-level declarations, not
body locals/parameters or legacy descriptor handler keys. Old colliding active
source faults on synchronized reconstruction, retaining source/state; rename and
explicitly Save/Run. A colliding Console root reports E_UNSUPPORTED before effects;
its graph is retained until confirmed Reset Shell discards it. Nested keys are fine.

COMPUTER
getID() -> string; getLabel() -> string/nil; setLabel(label/nil)
getTick() -> simulation tick; getLimits() -> defensive limit snapshot
getState(key) -> copied Data/nil; setState(key, value); deleteState(key) -> boolean
log(text) -> bounded plain output
stop() -> does not return; ends this callback/run and cannot be caught by pcall
on(event_name, handler_name) -> subscription ID; off(ID) -> boolean
General events: peripheral_attach, peripheral_detach, monitor_resize,
monitor_touch, power_restored, modem_message. Events include name/tick/sequence/computer_id/run_id.
after(delay_ticks, handler_name, payload?) -> timer ID
every(interval_ticks, handler_name, payload?) -> timer ID
cancelTimer(ID) -> boolean, including already queued timer notifications.
Timer event: timer_id, scheduled_tick, interval_ticks?, missed, payload?.
Recurring overdue intervals coalesce. Callbacks finish or fault; they never yield.
Data: finite numbers, booleans, strings, dense arrays or string-keyed maps;
no mixed keys, nil entries, cycles, functions, metatables or native objects.

PERIPHERALS
Shared discovery guidance:
wire is explicitly "red" or "green", never "both" for discovery.
Only same-color physical mod NETWORK ports and supported native radar/speaker sockets relay discovery; vanilla poles,
INPUT/OUTPUT/TARGETS ports and color changes are not discovery paths.
Types: monitor, kv_database, logic_handler, configurator, recipe_searcher, modem, speaker.
Each has getLimits().
Store name/wire in state, not ephemeral facades. Calls recheck live authority.
Use Peripherals for automatically updated names/types/power on the selected color.
Incomplete discovery reports pending/limit, never a successful empty prefix.

getNames(wire) -> complete sorted name array. Includes reachable unpowered devices;
pending/limit errors are not an empty inventory.


isPresent(name, wire) -> boolean. Tests exact identity on the selected discovery path,
not service power or a display label.


getType(name, wire) -> exact type string or one nil when absent on that path.


getMethods(name, wire) -> complete sorted method-name array, or one nil if absent.
Includes aliases and getLimits; it does not invoke the methods.


describe(name, wire) -> copied metadata or one nil if absent. Includes identity,
type, power, position/surface, quality, direction, footprint and selected wire.


wrap(name, wire) -> dot-call facade or one nil if absent. Every later call rechecks
live identity/path and service availability; a facade is not persistent Data.


call(name, wire, method, ...) -> that method's exact results. Dynamic dot-call
dispatch uses the same live checks, argument validation and budgets as a facade.


find(type_name, wire) -> zero or more facades in name order, as multiple returns,
not an array. Excess matches raise E_LIMIT; use getNames and wrap instead.


getName(facade) -> exact opaque name. Requires a genuine facade from this callback;
retain the string and wire rather than storing a saved-program facade.


getWire(facade) -> "red" or "green" for that genuine callback facade's binding.
It never silently changes colors after a cable disappears.


setMonitorSyncGroup(members) -> no values. members={{name=...,wire=...},...}; {} clears.
One selected group per run, at most four screens/10584 summed actual cells. Every
path is checked; duplicate names prefer red. Writing stays shared, not locked.


getMonitorSyncGroup() -> copied members/status/presented_sequence/tick/diagnostic.
Reports synchronized presentation progress, not application drawing completion.

SPEAKER
find("speaker", wire): existing vanilla programmable-speaker, native sockets and GUI.
No adapter, helpers or research; native circuits/settings/wires/mining and Configurator
remain intact. Connected old speakers enter bounded adoption; pending means retry later.
Other methods need energy and no script-disable/freeze/deconstruction. A false circuit
trigger alone does not prevent API playback. Every call proves live wire authority.
True means engine submission, not audible acknowledgement; false means shared quota.
Per tick: 8 notes + 1 effect per speaker, 16 combined per computer, 64 worldwide.
Colors/programs/Console share credits, including volume 0. Apply/reconnect/same-tick
reload never renew credits. Invalid arguments spend no audio quota; native failures do.
Audio is positional on the current surface, eligible for nearby charted listeners
on any force under native attenuation/mixer rules, regardless of native global mode.
No playAudio, stop, streams, queue or completion event. Submitted samples cannot be
cancelled. See docs/player/api/speaker.md and the speaker-alarm/melody/catalogue programs.

getInstruments() -> complete copied exact-name array, sorted bytewise. Oversized
metadata refuses instead of truncating the result.


getNotes(instrument) -> complete copied {pitch=integer,name=string} array in native
note order. Unknown instruments refuse; discover each instrument's own range.


playNote(instrument, volume?, pitch?) -> one boolean. Volume 0..1 defaults 1;
pitch defaults 0, a zero-based Factorio sample index, not MIDI/CC pitch. The first
pinned piano sample is F3 at pitch 0. True is submission, false shared quota refusal.


playSound(path, volume?) -> one boolean. Exact native-valid SoundPath, <=256 bytes;
volume 0..1 defaults 1. True is submission, false shared quota refusal, not an ACK.


getSounds(prefix?, after?) -> {sounds={...},next?}, <=50 unique valid sorted paths.
Strings default empty; prefix is literal, after an exclusive lexical key. Only a
later match produces next, equal to the last returned path. One page per callback.
Discovery captures documented sound families at data-final-fixes; later additions
may remain directly playable without being indexed. Missing/oversized data errors.


getLimits() -> copied common/speaker limits, including without native electrical power.
Playback and catalogue caps are independent of ordinary callback/result budgets.

RADAR MODEM
Native radar: unchanged scanning, circuits, power, GUI and mining; no adapter item.
find("modem", wire); numeric channels are not red/green discovery colors.
Shared radio guidance: all methods except getLimits require an active, electrically
supplied radar. Discovery wire and numeric radio channel are independent.
Channels 0..65535; 128 shared open channels per physical radar, across all callers.
closeAll affects other computers too. Stop does not close the shared channels.
computer.on("modem_message", "received") registers a saved named handler.
Event: peripheral (receiver), wire/wires, channel, replyChannel, message, distance?,
sent_tick; nil payload is an absent message, false is preserved. Same-radar echo
is excluded. Both-color paths deduplicate; two receiving radars remain distinct.
Whole-send proof/copies/fanout are admitted before publication; overflow faults
the recipient, not a retryable partial sender error. No ACK/retry/offline mailbox.
Payloads: bounded Data plus explicit third-argument nil. Check getLimits for
finite payload/candidate/delivery/rate caps; Console and programs share credits.
Same-force/same-surface unlimited-distance radio. Space Age advanced endpoints
at BOTH ends allow cross-surface traffic, including travelling platforms.
Advanced: 5x5, 1.5x native art, 1MW; six-pack research excludes military/planet packs.
Hidden native radar links and received names never grant remote device authority.
No rednet, callRemote, remote inventory or pullEvent. Channels/queues survive cold
load without replay; replacement/clone and force/surface changes clear channels.

open(channel) -> no values. Integer channel 0..65535; idempotent. At most 128
shared open channels per physical radar across colors, computers and Console.


isOpen(channel) -> boolean. Validates the channel and reads the physical radar's
shared set, not a private subscription owned by this caller.


close(channel) -> no values. Idempotently closes that shared channel for all callers;
already admitted messages are not recalled.


closeAll() -> no values. Clears the physical radar's shared channels for every
caller. Does not recall messages; stopping a program alone does not close channels.


transmit(channel, replyChannel, payload) -> no values. Both channels are integers
0..65535; the explicit third argument accepts bounded Data or nil. Sending need
not open either channel. Whole-send admission precedes publication; no ACK/retry.


isWireless() -> true. This is radio transport, never remote discovery authority.


getLimits() -> copied common/modem payload, candidate, delivery and rate caps.
Available on a reachable unpowered radar; it does not open channels or send traffic.

LOGIC HANDLER
find("logic_handler", wire) -> facade; NETWORK discovery is not INPUT selection.
Shared signal guidance:
input explicitly selects red or green, never both; identities include type/name/quality (normal by default).
signal_changed includes sample_tick, previous/current, changes with disappeared
current=0, selected connectivity, initial/resync and discovery wire.
Admission advances the baseline. Outages discard queued transients and resync current
input. Stop/fault/cable loss clears only the still-owned run/channel bank.
Controller: INPUT red from stock chest, OUTPUT to inserter with signal A > 0;
red NETWORK chain to computer; paste examples/logic-controller.lua, Save, then Run.

readSignal(input, signal) -> signed32 count; absent gives 0. signal is an exact
SignalId {type,name,quality?}; type includes item/fluid/virtual/recipe.


readSignals(input) -> complete sorted copied nonzero Signal array. Each entry is
{signal={type,name,quality},count=Int32}; only the selected INPUT color is read.


getInputStatus() -> {red_connected=boolean,green_connected=boolean}. Distinguishes
disconnected wires from connected empty inputs using actual INPUT edges.


getOutput() -> copied Signal array of this handler's own configured contribution,
not summed network values or other emitters.


setOutput(signals) -> no values. Replaces the complete bank mirrored to both OUTPUT
wires and transfers writer ownership. Duplicate identities refuse, including zeros;
zero counts are omitted. Failed admission preserves the prior bank and owner.


clearOutput() -> no values. Equivalent to setOutput({}), including writer transfer;
it does not clear other native emitters on the output network.


subscribe(options, handler_name) -> run-scoped subscription ID. options={input=...,
signals={SignalId,...}?,initial=boolean?}; input required, filters nonempty/unique if
supplied, initial defaults false. Named saved handlers only; Console refuses.


unsubscribe(subscription_id) -> boolean. Removes this run/binding's registration
and its queued samples; false when absent, not authority to remove another binding.


getLimits() -> copied common/logic ceilings, including while reachable unpowered.
Includes 64 slots/filter signals and one-tick sampling; shared admission still applies.

KV DATABASE
Shared storage guidance: values/fields/keys are byte strings, including empty/NUL.
Hash commands reject live strings with E_WRONGTYPE. Each command validates complete
arguments/capacity before mutation; earlier successful commands are not rolled back.
Expiry uses absolute simulation ticks, including while mined; reload does not renew it.
Each physical database is independent; authorized computers share committed data.

get(key) -> string or one nil for missing/expired keys. A live hash raises E_WRONGTYPE.


set(key, value) -> "OK". Replaces either type with the byte string and clears its TTL.


del(key, ...) -> integer removed count. At least one key; repeated keys count once.


exists(key, ...) -> integer live count. At least one key; repeated live arguments
count repeatedly, unlike del. Expired keys count as absent.


type(key) -> "none", "string" or "hash". Missing/expired keys return "none".


hget(key, field) -> string or one nil for a missing key/field; never false/empty as
an absence marker. Hash reads reject a live string.


hset(key, field, value, ...) -> integer newly added distinct fields. At least one
complete pair; last repeated field wins. Preserves an existing hash TTL.


hdel(key, field, ...) -> integer removed fields, counting each once. At least one
field; preserves TTL unless deleting the last field, which removes the key.


hexists(key, field) -> integer 0 or 1, not boolean. Missing/expired gives 0.


hgetall(key) -> copied string-keyed map. Missing gives independent {}; not an ordered
array or a successful truncated prefix.


hlen(key) -> integer field count. Missing/expired gives 0.


expire(key, seconds) -> integer 0 or 1. Integer simulation seconds; nonpositive
deletes a live key. Validates duration even if absent; 1 means live expiry/deletion.


ttl(key) -> integer: -2 absent, -1 persistent, otherwise nearest remaining simulation
second (half up). Zero can still be live; deadline expiry is logically immediate.


persist(key) -> integer 0 or 1. Returns 1 only when removing a live existing deadline.


getLimits() -> copied common/KV capacities, including while reachable unpowered.
Byte, field, key, argument and snapshot limits all apply; no external Redis connection.

MONITOR
Shared display guidance: one byte per cell, no terminal escape/Unicode processing.
Adjacent same-force/orientation powered tiles share a rectangular screen.
Every complete shape up to 6x6 is supported, including 1x6 and 3x6.
Methods update the model immediately. Fixed snapshots prepare invisibly after
callbacks; the previous complete image remains until the replacement publishes.
Selected groups wait for every member's successful mutation (including no-ops).
They publish together, without flush or a timeout that splits a frame. Buffering
does not infer completion of an application drawing over multiple callbacks.
Resize clears changed dimensions. Stop leaves the image; outage hides, not erases.
Ctrl+left-click (rebindable), empty cursor/no GUI: monitor_touch carries logical
peripheral, x/y, player_index, sample_tick, wire and deduplicated sorted wires.
monitor_resize includes old_width/height, width/height and tiles/scale reason.

write(text) -> no values. One byte per cell; clips without wrapping/newline handling;
cursor X advances by full byte length, including clipped bytes.


blit(text, foreground, background) -> no values. Equal byte lengths; foreground and
background are lowercase 0..f palette digits. Validates all before changing cells.


clear() -> no values. Fills all cells with spaces/current colors; cursor unchanged.


clearLine() -> no values. Clears the current visible row with spaces/current colors;
offscreen row does nothing and cursor stays unchanged.


scroll(lines) -> no values. Safe integer; positive up, negative down. Exposed rows
use current colors; cursor unchanged. Large amounts clear without offset-sized work.


getSize() -> width, height as integer terminal columns/rows, not tiles or pixels.


getCursorPos() -> x, y as safe integers, initially 1,1; offscreen positions are valid.


setCursorPos(x, y) -> no values. Safe integers; offscreen allowed and writes clip.
The final X after a write must remain a safe integer.


getCursorBlink() -> boolean, initially false. Offscreen cursor state is retained.


setCursorBlink(enabled) -> no values. Requires a boolean; only presentation changes.


getTextColor() -> foreground color mask, initially white; shared by all writers.


getTextColour() -> foreground mask. Exact alias of getTextColor().


setTextColor(color) -> no values. One valid color mask, never a combined mask.


setTextColour(color) -> no values. Exact alias of setTextColor(color).


getBackgroundColor() -> background color mask, initially black; shared by all writers.


getBackgroundColour() -> background mask. Exact alias of getBackgroundColor().


setBackgroundColor(color) -> no values. One valid color mask, never a combined mask.


setBackgroundColour(color) -> no values. Exact alias of setBackgroundColor(color).


isColor() -> true. All monitors support the shared 16-color palette.


isColour() -> true. Exact alias of isColor().


setPaletteColor(color, rgb) or setPaletteColor(color, r, g, b) -> no values.
Packed integer RGB 0..16777215 or exactly three finite channels 0..1; recolors
existing cells because they retain palette indexes, not copied RGB triples.


setPaletteColour(color, rgb) or setPaletteColour(color, r, g, b) -> no values.
Exact alias of both setPaletteColor overloads, with identical validation/results.


getPaletteColor(color) -> r, g, b in 0..1. Requires one valid color mask.


getPaletteColour(color) -> r, g, b. Exact alias of getPaletteColor(color).


getTextScale() -> number, initially 1. Scale is shared across the logical screen.


setTextScale(scale) -> no values. Half-steps 0.5..5; recalculates terminal geometry.
Changed dimensions clear the image and report resize; it is not a pixel font size.


getLimits() -> copied common/monitor capacities, including while reachable unpowered.
Query actual cell, write, tile and rendering bounds; maxima need not combine.

RECIPE SEARCHER
find("recipe_searcher", wire) -> facade. Separate Recipe Searcher research.
Shared query guidance: no inventory, physical product input, crafting execution or
recipe browser GUI. Reachable unpowered devices allow limits/discovery/relay only.
Paste examples/recipe-searcher-program.lua's document, Validate, Save and Run.

findRecipes("item"/"fluid", exact_product_name, exact_category?) -> one complete array.
Includes locked, hidden, recycling, modded and surface-restricted direct producers.
Primary and additional categories match. Filter before the fixed 50-result limit;
51 raises E_LIMIT, never truncation/pagination. Results sort by recipe name.
Records include ingredients/products, ranges/probabilities, energy in seconds,
categories, visibility, surface bounds and current force enabled state (not feasibility).


getLimits() -> copied common/recipe-searcher limits, including while unpowered.
recipe_search_results=50; common work/result/allocation limits still apply.

CONFIGURATOR
Shared configuration guidance: NETWORK and TARGETS colors are separate arguments
and graphs. Target IDs are opaque; each addressed call proves live identity/path.
Full pinned applicable circuit controls are supported; no arbitrary host properties.
Unknown/read-only/invalid patches refuse before mutation. Native failures have
explicit local recovery, never promised global rollback. Shared filter edits refuse;
explicit local group="" detachment preserves effective filters. Re-enumerate indexes.

getDevices(target_wire) -> complete ID-sorted unique DeviceInfo array. Explicit red
or green TARGETS; pending/limit errors never mean a partial or empty success.


getDevice(id, target_wire) -> copied DeviceInfo or one nil for absent/disconnected/
replaced identity. Same coordinates do not authorize a replacement body.


getCapabilities(id, target_wire) -> copied typed CapabilitySet of current settings,
observations and sections. Inspect writable/clearable flags and unavailable reasons.


getConfiguration(id, target_wire) -> copied {values={...},unset={...},observations={...}}.
False is a value; nil/unset is different. Observations are not writable settings.


setConfiguration(id, patch, target_wire) -> normalized native ConfigurationSnapshot
after verified update. patch={set={...}?,clear={...}?}; each set root replaces its
whole value, not recursive merge. Unknown/read-only/overlapping fields refuse.


getSections(id, target_wire) -> native-index-ordered copied SectionInfo array.
Only compatible targets; nonmanual sections are read-only. Re-enumerate after removal.


addSection(id, definition, target_wire) -> actual new native integer index.
Defaults active=true, group="", multiplier=1, filters={}; joining a shared group
reads effective filters rather than replacing them with empty defaults.


setSection(id, index, patch, target_wire) -> updated SectionInfo. Same set/clear
patch form; active/group/multiplier/filters are not clearable (use filters={}).
Shared filter edits refuse; explicitly detach group="" to preserve/localize filters.


removeSection(id, index, target_wire) -> boolean, false if absent, true after verified
removal. Nonmanual sections refuse. Native 1-based indexes can shift afterward.


getLimits() -> copied common/configurator capacities, including reachable unpowered.
Target graph, patch, section, filter and result budgets apply independently.

COMBINED EXAMPLE
Paste docs/factory-example.md's examples/factory-controller.lua document, Save/Run.
It configures TARGETS green inserters, samples INPUT red, stores expiring shared KV
telemetry and redraws/toggles a merged monitor. examples/shared-telemetry.lua runs
on a second computer: shared red database, separate physical green database.
Complete signature/type/error/event references are in docs/ and packaged source API
contracts under openspec/api and openspec/specs.

FAILURES AND PERSISTENCE
Ordinary errors are plain {code,message,field?,peripheral?,device?} and catchable.
Earlier successful effects remain after a later fault; no callback transaction.
Unpowered computers pause; state/source survive. Cold load does not replay start.
Saved and active sources may differ. Functions are reconstructed only on dispatch.
Quotas are initial development ceilings, not a guaranteed real-time latency bound.
Full capability method guides ship in docs/ with the installed mod.
]]
}
-- Categorized views of the same complete shipped reference, not a second API list.
M.categories={'All topics','Authoring','Language','Computer','Peripherals','Examples','Safety'}
local sections={
  WORKFLOW={'Workspace and revisions','Authoring'}, LANGUAGE={'Supported Lua','Language'},
  COMPUTER={'State, events and timers','Computer'}, PERIPHERALS={'Discovery and identity','Peripherals','peripheral.discovery'},
  ['LOGIC HANDLER']={'Logic handler','Peripherals','peripheral.logic_handler'}, ['KV DATABASE']={'KV database','Peripherals','peripheral.kv_database'},
  MONITOR={'Monitor','Peripherals','peripheral.monitor'}, CONFIGURATOR={'Configurator','Peripherals','peripheral.configurator'},
  ['RECIPE SEARCHER']={'Recipe Searcher','Peripherals','peripheral.recipe_searcher'},
  ['RADAR MODEM']={'Radar modem','Peripherals','peripheral.modem'},
  SPEAKER={'Programmable speaker','Peripherals','peripheral.speaker'},
  ['COMBINED EXAMPLE']={'Factory examples','Examples'},
  ['FAILURES AND PERSISTENCE']={'Failures and persistence','Safety'}
}
M.topics={}; local topic={title='Lua API v1 overview',category='Authoring',text=''}
M.topics[1]=topic
for line in string.gmatch(M.text..'\n','([^\n]*)\n') do
  local section=sections[line]
  if section then topic={title=section[1],category=section[2],id=section[3],text=''}; M.topics[#M.topics+1]=topic end
  topic.text=topic.text..line..'\n'
end
M.topics[#M.topics+1]={title='Starter controller',category='Examples',text=M.template,example=true}
-- Exact API types, never localized titles, substring matching or topic positions.
local peripheral_topics={monitor='peripheral.monitor',kv_database='peripheral.kv_database',
  logic_handler='peripheral.logic_handler',configurator='peripheral.configurator',
  recipe_searcher='peripheral.recipe_searcher',modem='peripheral.modem',speaker='peripheral.speaker'}
function M.peripheral_topic(kind)
  local id=peripheral_topics[kind]
  if id then for i,entry in ipairs(M.topics) do if entry.id==id then return i end end end
end
return M
