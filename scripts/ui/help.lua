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
Console holds bounded output; turn Follow off to pause its selectable snapshot.
Console also accepts one live Lua line with Enter or Execute; no command history.
Scratch globals/tables and peripheral bindings are shared per computer and saved.
print(p.getSize()) inspects a retained p=peripheral.wrap(name,"red") binding.
Calls affect the real factory. Failed commands keep previous scratch values but
do not undo earlier API effects. No retained user functions, timers or subscriptions.
Successful Run/Apply, explicit Stop or confirmed Reset Shell clear scratch values.
Close/reopen, save/load, program faults and power loss keep committed values.
Peripherals inspects the red or green channel, with explicit pending results.
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
Ordinary opening of a peripheral opens its read-only local inspector; no computer
or running program is required. Select name for copy selects only the API ID;
use native Copy, then paste into your draft. Escape retains computer drafts.
KV and Configurator use explicit Refresh snapshots, with bounded pages/chunks.
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
getNames(wire) -> complete sorted names
isPresent(name, wire) -> boolean; getType(name, wire) -> type/nil
getMethods(name, wire) -> method names/nil; describe(name, wire) -> metadata/nil
wrap(name, wire) -> dot-call facade/nil
call(name, wire, method, ...) -> results
find(type_name, wire) -> zero or more facades (multiple returns)
getName(facade) -> name; getWire(facade) -> wire
setMonitorSyncGroup({{name=...,wire=...},...}) -> no values; {} clears
getMonitorSyncGroup() -> copied members/status/presented_sequence/tick/diagnostic
One selected group per run; at most four screens and 10584 summed actual cells.
Every supplied path is checked; duplicate names prefer red. Writing stays shared.
wire is explicitly "red" or "green", never "both" for discovery.
Only same-color physical mod NETWORK ports and supported native radar/speaker sockets relay discovery; vanilla poles,
INPUT/OUTPUT/TARGETS ports and color changes are not discovery paths.
Types: monitor, kv_database, logic_handler, configurator, recipe_searcher, modem, speaker.
Each has getLimits().
Store name/wire in state, not ephemeral facades. Calls recheck live authority.
Use Peripherals / Refresh for current names/types/power on the selected color.
Incomplete discovery reports pending/limit, never a successful empty prefix.

SPEAKER
find("speaker", wire): existing vanilla programmable-speaker, native sockets and GUI.
No adapter, helpers or research; native circuits/settings/wires/mining and Configurator
remain intact. Connected old speakers enter bounded adoption; pending means retry later.
getInstruments() -> complete copied exact-name array, sorted bytewise.
getNotes(instrument) -> complete {pitch=integer,name=string} array in native note order.
playNote(instrument, volume?, pitch?) -> one boolean. Volume 0..1 defaults 1;
pitch defaults 0 and is a zero-based Factorio sample index, not MIDI/CC pitch.
The first pinned piano sample is F3 at pitch 0. Discover each instrument's range.
playSound(path, volume?) -> one boolean; exact native-valid SoundPath, <=256 bytes.
getSounds(prefix?, after?) -> {sounds={...},next?}, <=50 unique valid sorted paths.
Strings default empty; prefix is literal, after an exclusive lexical key. Only a
later match produces next, equal to the last returned path. One page per callback.
Discovery captures documented sound families at data-final-fixes; later additions
may remain directly playable without being indexed. Missing/oversized data errors.
getLimits() -> copied common/speaker limits, including without native electrical power.
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

RADAR MODEM
Native radar: unchanged scanning, circuits, power, GUI and mining; no adapter item.
find("modem", wire); numeric channels are not red/green discovery colors.
open(channel), close(channel), closeAll(), transmit(channel, replyChannel, payload)
return no values. isOpen(channel) and isWireless() return booleans; getLimits()
works without power. Other calls require an active, electrically supplied radar.
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

LOGIC HANDLER
find("logic_handler", wire) -> facade; NETWORK discovery is not INPUT selection.
readSignal(input, SignalId) -> signed32; readSignals(input) -> sorted copied signals
input explicitly selects red or green, never both; identities include type/name/quality (normal by default).
getInputStatus() -> red_connected/green_connected; getOutput() -> own contribution
setOutput(signals), clearOutput() -> no values; one bank mirrored to both OUTPUT wires.
subscribe({input=..., signals={SignalId,...}?, initial=boolean?}, handler_name) -> ID
unsubscribe(ID) -> boolean; removes queued samples from that binding.
getLimits() includes 64 slots/filter signals and one-tick sampling.
signal_changed includes sample_tick, previous/current, changes with disappeared
current=0, selected connectivity, initial/resync and discovery wire.
Admission advances the baseline. Outages discard queued transients and resync current
input. Stop/fault/cable loss clears only the still-owned run/channel bank.
Controller: INPUT red from stock chest, OUTPUT to inserter with signal A > 0;
red NETWORK chain to computer; paste examples/logic-controller.lua, Save, then Run.

KV DATABASE
get(key) -> string/nil; set(key,string) -> "OK"; del(key,...) -> count
exists(key,...) -> count; type(key) -> none/string/hash
hget(key,field) -> string/nil; hset(key,field,value,...) -> newly added fields
hdel(key,field,...) -> removed fields; hexists(key,field) -> 0/1
hgetall(key) -> copied map; hlen(key) -> integer
expire(key,integer_seconds) -> 0/1; ttl(key) -> -2 absent/-1 persistent/seconds
persist(key) -> 0/1; getLimits(). Values/fields/keys are byte strings.
SET replaces any type and clears TTL. Hash edits preserve TTL; final field deletion
removes the key. Expiry uses absolute simulation ticks, including while mined.
Each physical database is independent; authorized computers share committed data.

MONITOR
write(text), blit(text,fg_digits,bg_digits), clear(), clearLine(), scroll(integer)
getSize() -> width,height; getCursorPos() -> x,y; setCursorPos(x,y)
getCursorBlink() -> boolean; setCursorBlink(boolean)
get/setTextColor, get/setBackgroundColor; Color/Colour aliases are identical.
isColor()/isColour() -> true; getPaletteColor(color) -> r,g,b
setPaletteColor(color,rgb) or (color,r,g,b); PaletteColour aliases are identical.
getTextScale(); setTextScale(0.5..5 in half steps); getLimits()
One byte per cell; clip without wrapping; blit uses equal-length lowercase 0..f.
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

RECIPE SEARCHER
find("recipe_searcher", wire) -> facade. Separate Recipe Searcher research.
findRecipes("item"/"fluid", exact_product_name, exact_category?) -> one complete array.
Includes locked, hidden, recycling, modded and surface-restricted direct producers.
Primary and additional categories match. Filter before the fixed 50-result limit;
51 raises E_LIMIT, never truncation/pagination. Results sort by recipe name.
Records include ingredients/products, ranges/probabilities, energy in seconds,
categories, visibility, surface bounds and current force enabled state (not feasibility).
getLimits() includes recipe_search_results=50 plus unchanged common budgets.
No inventory, physical product input, crafting execution or recipe browser GUI.
Reachable unpowered devices allow limits/discovery/relay, not findRecipes.
Paste examples/recipe-searcher-program.lua's document, Validate, Save and Run.

CONFIGURATOR
getDevices(target_wire) -> complete device array; getDevice(ID,target_wire) -> data/nil
getCapabilities(ID,target_wire) -> typed settings/observations/sections
getConfiguration(ID,target_wire) -> values/unset/observations
setConfiguration(ID,{set={...},clear={...}},target_wire) -> exact native readback
getSections(ID,target_wire); addSection(ID,definition,target_wire) -> native index
setSection(ID,index,patch,target_wire); removeSection(ID,index,target_wire) -> boolean
getLimits(). NETWORK color and TARGETS color are separate arguments and graphs.
Full pinned applicable circuit controls are supported; no arbitrary host properties.
Unknown/read-only/invalid patches refuse before mutation. Native failures have
explicit local recovery, never promised global rollback. Shared filter edits refuse;
explicit local group="" detachment preserves effective filters. Re-enumerate indexes.

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
  COMPUTER={'State, events and timers','Computer'}, PERIPHERALS={'Discovery and identity','Peripherals'},
  ['LOGIC HANDLER']={'Logic handler','Peripherals'}, ['KV DATABASE']={'KV database','Peripherals'},
  MONITOR={'Monitor','Peripherals'}, CONFIGURATOR={'Configurator','Peripherals'},
  ['RECIPE SEARCHER']={'Recipe Searcher','Peripherals'},
  ['RADAR MODEM']={'Radar modem','Peripherals'},
  SPEAKER={'Programmable speaker','Peripherals'},
  ['COMBINED EXAMPLE']={'Factory examples','Examples'},
  ['FAILURES AND PERSISTENCE']={'Failures and persistence','Safety'}
}
M.topics={}; local topic={title='Lua API v1 overview',category='Authoring',text=''}
M.topics[1]=topic
for line in string.gmatch(M.text..'\n','([^\n]*)\n') do
  local section=sections[line]
  if section then topic={title=section[1],category=section[2],text=''}; M.topics[#M.topics+1]=topic end
  topic.text=topic.text..line..'\n'
end
M.topics[#M.topics+1]={title='Starter controller',category='Examples',text=M.template,example=true}
return M
