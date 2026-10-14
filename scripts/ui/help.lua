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

FAILURES AND PERSISTENCE
Ordinary errors are plain {code,message,field?,peripheral?,device?} and catchable.
Earlier successful effects remain after a later fault; no callback transaction.
Unpowered computers pause; state/source survive. Cold load does not replay start.
Saved and active sources may differ. Functions are reconstructed only on dispatch.
Quotas are initial development ceilings, not a guaranteed real-time latency bound.
Full capability method guides ship in docs/ with the installed mod.
]]
}
