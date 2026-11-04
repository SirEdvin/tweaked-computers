-- Authored workspace guidance and tutorials, composed with generated API data.
-- The public api/*.d.lua library owns all method/type contracts.
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
Search an exact TC.* type name for complete fields and behavior. API entries come from the shipped public declarations.

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
Reference filters complete help by category/search. Manually select/copy each
paragraph or entire literal code box with native controls; browsing never edits a draft.
Maintenance holds reviewed revision resolution, retained drafts and stopped-only reset.
Type/paste into the source box. Validate checks the draft without effects.
Save commits source, but does not change the active run. Run/Apply validates and
activates the displayed saved revision only. Save first if the draft is dirty.
Invalid candidates preserve the old run. Successful Run/Apply retains state.
Computer items are plain hardware: ordinary pickup/replacement loses their source/state.
Clipboard/blueprint/clone copies include saved source/label only and start stopped.
Native undo restores pre-removal source/label/state into a new stopped identity, not a run.
Formerly active source is reviewed recovery text; private drafts keep their old identity.
Old computer-item payloads are ignored with no item-data recovery. Placed records/drafts,
KV contents/deadlines and monitor data retain their existing save/item policies.
Undo history/its original ghost is not permanent backup; keep complete save/mod backups.
Stop cancels callbacks/timers and clears only this run's still-owned logic output.
Reset State requires Stop and a separate confirmation; it never clears a KV.
Close/Escape retains the draft. Reopen the same body to recover it.
Conflict: Review opens Maintenance; read current source, then Rebase (retain draft) or
Reload (discard your draft). The revision is checked again on either action.
Eight bounded recovery drafts per player; no automatic dirty-draft eviction.
Ctrl+left-click (rebindable), empty cursor/no GUI, opens an actual computer.
Review retained drafts through Maintenance; empty-ground clicks do nothing.
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
Ctrl-click monitor touches remain distinct. Custom devices need no electricity;
identity, geometry, permissions and live wiring still govern availability.
All essential actions are buttons, including while the text box has focus.

LANGUAGE
function start(event) ... end; function sample(event) ... end
Plain declarations export named handlers; API version 1 is implicit. start is optional.
sample() calls directly in this program with ordinary arguments/results and the
same callback budget. computer.every(60, "sample") schedules a later TimerEvent.
Names alone do not subscribe. Registration uses strings, never function values.
Declare private local function helpers before use; they are not exported.
Exports are read-only and forward-visible; parameters/locals shadow them normally.
Only declarations, comments and semicolons belong at top level; at least one
export is required. No top-level values, returns, calls or effects.
Locals, helpers, if, loops and tables have guarded work/depth/allocation limits.
Functions/locals are fresh per callback; keep durable values in computer state.
Console cannot call saved-program functions. The starter samples once immediately,
logs the returned count, then samples every 60 simulation ticks; no device required.
No require/load, game/storage/remote, _ENV/_G, metatables, coroutine, patterns,
random, string-method syntax or colon calls. API calls use dots.

New global names are reserved for public/private top-level declarations, not
body locals/parameters. Old colliding active
source faults on synchronized reconstruction, retaining source/state; rename and
explicitly Save/Run. A colliding Console root reports E_UNSUPPORTED before effects;
its graph is retained until confirmed Reset Shell discards it. Nested keys are fine.

COMBINED EXAMPLE
Choose Examples for complete, small tutorials with setup, runnable code, execution
steps, expected results and failure notes. No external file or guest import is needed.
Small factory dashboard combines configuration, logic, a database and a monitor.
Two-computer shared data uses two real computers and two physical databases.
The starter needs no peripherals. One speaker note, Stock-controlled inserter and
Find iron plate recipes teach one service each. Larger shipped programs and docs
are supplementary; they are not required to complete these in-game tutorials.

FAILURES AND PERSISTENCE
Saved and active sources may differ. Functions are reconstructed only on dispatch.
No player code runs on load and startup is not replayed. Earlier successful effects
remain after later faults. Keep full save/mod backups before changing runtimes.
Search TC.ApiError, TC.Data and TC.Limits for the complete shared contract.
Quotas are development ceilings, not a guaranteed real-time latency bound.
]]
}
-- Categorized views of the same complete shipped reference, not a second API list.
M.categories={'All topics','Authoring','Language','Computer','Peripherals','Examples','Safety','Types'}
local sections={
  WORKFLOW={'Workspace and revisions','Authoring'}, LANGUAGE={'Supported Lua','Language'},
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
local tutorials=require('scripts.ui.tutorials')
tutorials.starter={title='Starter controller',purpose='Sample immediately, then retain a counter once per 60 simulation ticks. No peripheral is needed.',
  setup='Research Native circuit computers (tc-circuit-computers) and craft one computer. No electricity, wire, second computer or external file is needed.',
  steps='Clear the cursor and Ctrl+left-click the computer. Select and copy this entire code box with native controls, paste into an empty Editor draft, then Validate, Save and Run. The Editor starter control is an optional way to insert the same source; Reference has no action buttons.',
  expected='Console prints Initial sample count: 1 on a fresh computer. The retained samples state is 1 immediately and increases to 2 at the first 60-tick timer. Reapplying retains the previous count; cold load does not replay start.',
  failures='Save alone does not activate a revision. Saved program functions cannot be called from Console. Stop cancels the timer without clearing the count. Maintenance Reset State requires Stop and separate confirmation.',
  source='function-program',code=M.template}
M.tutorials=tutorials
local function block(topic,kind,text)
  if kind=='prose' and text:find('\n',1,true) then
    for line in text:gmatch('[^\n]+') do block(topic,kind,line) end
    return
  end
  topic.blocks[#topic.blocks+1]={kind=kind,text=text}
end
local subheadings={
  ['Console holds']='Live Console', ['Peripherals inspects']='Discovery and navigation',
  ['Maintenance holds']='Editing and execution', ['Stop cancels']='Stopping and recovery',
  ['Ctrl+left-click']='World interaction', ['Open inspectors']='Local inspectors',
  ['Monitor dimensions']='Monitor interaction', ['All essential']='Native controls',
  ['function start']='Named handlers',
  ['Locals, helpers']='Callback lifetime', ['No require']='Sandbox boundaries',
  ['print(...)']='Printing', ['rawget(t,key)']='Raw table helpers',
  ['xpcall(fn,handler,...)']='Errors and protected calls', ['New global names']='Reserved names and upgrades',
  ['General events:']='Events', ['Timer event:']='Timer delivery', ['Data:']='Persistent Data',
  ['Ordinary errors']='Errors and partial effects', ['Custom computers']='Electricity and cold load',
  ['Quotas are']='Resource limits'
}
-- Signatures stay isolated rather than relying on representation-specific blank
-- lines. Paragraph wrapping is visual only: the actual copied bytes are plain.
local function structure(topic)
  topic.blocks={}; block(topic,'heading',topic.title)
  local paragraph={}; local length=0; local first=true
  local function flush()
    if #paragraph>0 then block(topic,'prose',table.concat(paragraph,' ')); paragraph={}; length=0 end
  end
  for line in (topic.text..'\n'):gmatch('([^\n]*)\n') do
    if first then first=false
    elseif line=='' then flush()
    else
      local heading
      for prefix,title in pairs(subheadings) do if line:sub(1,#prefix)==prefix then heading=title; break end end
      if heading then flush(); block(topic,'heading',heading) end
      if length+#line>420 then flush() end
      paragraph[#paragraph+1]=line; length=length+#line+1
    end
  end
  flush()
  local parts={}; for _,part in ipairs(topic.blocks) do parts[#parts+1]=part.text end
  topic.text=table.concat(parts,'\n\n')
end
for _,entry in ipairs(M.topics) do structure(entry) end
local api=require('scripts.ui.api-reference')
for _,entry in ipairs(api.topics) do M.topics[#M.topics+1]=entry end
M.type_topics=api.locations
local complete={}; for _,entry in ipairs(M.topics) do complete[#complete+1]=entry.text end
M.text=table.concat(complete,'\n\n')
for _,id in ipairs({'starter','speaker','logic','recipe','factory','shared','statistics','dashboard','dashboard_charts'}) do
  local tutorial=tutorials[id]
  local entry={id='tutorial.'..id,title=tutorial.title,category='Examples',blocks={},text=''}
  block(entry,'heading',tutorial.title)
  for _,part in ipairs{{'Purpose','purpose'},{'Build and wire','setup'},{'Enter and run','steps'}} do
    block(entry,'heading',part[1]); block(entry,'prose',tutorial[part[2]])
  end
  if tutorial.prelude then
    block(entry,'heading','Computer 1 — writer'); block(entry,'code',tutorial.prelude)
    block(entry,'heading','Computer 2 — observer')
  else block(entry,'heading','Complete program') end
  block(entry,'code',tutorial.code)
  for _,part in ipairs{{'Expected result','expected'},{'Failures and safety','failures'}} do
    block(entry,'heading',part[1]); block(entry,'prose',tutorial[part[2]])
  end
  local text={}; for _,part in ipairs(entry.blocks) do text[#text+1]=part.text end
  entry.text=table.concat(text,'\n\n')
  M.topics[#M.topics+1]=entry
end
-- Exact API types, never localized titles, substring matching or topic positions.
local peripheral_topics={monitor='peripheral.monitor',kv_database='peripheral.kv_database',
  logic_handler='peripheral.logic_handler',configurator='peripheral.configurator',
  recipe_searcher='peripheral.recipe_searcher',factoriopedia_interface='peripheral.factoriopedia_interface',production_statistics='peripheral.production_statistics',dashboard='peripheral.dashboard',modem='peripheral.modem',speaker='peripheral.speaker'}
function M.peripheral_topic(kind)
  local id=peripheral_topics[kind]
  if id then for i,entry in ipairs(M.topics) do if entry.id==id then return i end end end
end
return M
