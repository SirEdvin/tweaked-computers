-- Plain native text: no rich text, guest evaluator, shell or file imports.
return {
  template=[[return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.log("Controller started")
      computer.on("peripheral_attach", "attached")
    end,
    attached = function(event)
      computer.log(event.peripheral .. " attached on " .. event.wire)
    end
  }
}]],
  text=[[TWEAKED COMPUTERS — Lua API v1
One document. Native named callbacks; no OS, shell, VM or filesystem.

WORKFLOW
Type/paste into the source box. Validate checks the draft without effects.
Save commits source, but does not change the active run. Run/Apply validates and
activates the displayed saved revision only. Save first if the draft is dirty.
Invalid replacements preserve the old run. State survives replacement.
Stop cancels callbacks/timers and clears only this run's still-owned logic output.
Reset State requires Stop and a separate confirmation; it never clears a KV.
Close/Escape retains the draft. Reopen the same body to recover it.
Conflict: Review Current, read its source, then Rebase (retain your draft) or
Reload (discard your draft). The revision is checked again on either action.
Eight bounded recovery drafts per player; no automatic dirty-draft eviction.
Ctrl+Shift+E (rebindable) opens the selected computer, or recovery drafts.
All essential actions are buttons, including while the text box has focus.

LANGUAGE
return {api_version=1, handlers={start=function(event) ... end, ...}}
Handlers are named literal functions. Locals, helpers, if, loops and tables
are supported within guarded work/depth/allocation limits. No top-level effects.
No require/load, game/storage/remote, _ENV/_G, metatables, coroutine, patterns,
random, string-method syntax or colon calls. API calls use dots.
Approved globals: assert, error, ipairs, pairs, next, pcall, select, tonumber,
tostring, type, math, string, table, colors/colours, computer, peripheral.
Use computer.log, not print. Fatal budget exhaustion cannot be caught by pcall.

COMPUTER
getID() -> string; getLabel() -> string/nil; setLabel(label/nil)
getTick() -> simulation tick; getLimits() -> defensive limit snapshot
getState(key) -> copied Data/nil; setState(key, value); deleteState(key) -> boolean
log(text) -> bounded plain output
on(event_name, handler_name) -> subscription ID; off(ID) -> boolean
General events: peripheral_attach, peripheral_detach, monitor_resize,
monitor_touch, power_restored. Events include name/tick/sequence/computer_id/run_id.
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
wire is explicitly "red" or "green", never "both" for discovery.
Only same-color physical mod NETWORK ports relay discovery; vanilla poles,
INPUT/OUTPUT/TARGETS ports and color changes are not discovery paths.
Types: monitor, kv_database, logic_handler, configurator. Each has getLimits().
Store name/wire in state, not ephemeral facades. Calls recheck live authority.
Use Refresh Peripherals below for current names/types/power per color.
Incomplete discovery reports pending/limit, never a successful empty prefix.

LOGIC HANDLER
find("logic_handler", wire) -> facade; NETWORK discovery is not INPUT selection.
readSignal(input, SignalId) -> signed32; readSignals(input) -> sorted copied signals
input is red/green/both; identities include type/name/quality (normal by default).
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
Resize clears changed dimensions. Stop leaves the image; outage hides, not erases.
Ctrl+left-click (rebindable), empty cursor/no GUI: monitor_touch carries logical
peripheral, x/y, player_index, sample_tick, wire and deduplicated sorted wires.
monitor_resize includes old_width/height, width/height and tiles/scale reason.

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
contracts under openspec/changes/add-native-circuit-computers/api and specs.

FAILURES AND PERSISTENCE
Ordinary errors are plain {code,message,field?,peripheral?,device?} and catchable.
Earlier successful effects remain after a later fault; no callback transaction.
Unpowered computers pause; state/source survive. Cold load does not replay start.
Saved and active sources may differ. Functions are reconstructed only on dispatch.
Quotas are initial development ceilings, not a guaranteed real-time latency bound.
Full capability method guides ship in docs/ with the installed mod.
]]
}
