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
Each computer has one source document with native named callbacks.
There is no OS, VM, or filesystem.
Search for an exact TC.* type name to find its fields and behavior.
The public declaration files supply the API entries.

WORKFLOW
Editor is the workspace for source text. Focus hides tabs but keeps your source.
Console holds live output within its limits. Follow off stops automatic scrolling, but updates continue.
An update can clear the text selection. You can select and copy text between updates.
Console also accepts one live Lua line through Enter or Execute. It has no command history.
Each computer shares and saves its Console globals, tables, and peripheral bindings.
print(p.getSize()) inspects a retained p=peripheral.wrap(name,"red") binding.
Calls operate on the real factory. A failed command keeps previous Console values.
It does not reverse earlier API effects. Console cannot keep user functions, timers, or subscriptions.
Successful Run/Apply, explicit Stop, or confirmed Reset Shell clears Console values.
Close/reopen, save/load, program faults, and power loss keep committed values.
Peripherals inspects the red or green channel. It identifies pending results explicitly.
Click a row to select its details. Click the selected row again to open its Reference topic.
There is no double-click timer. A wire change or unavailable inventory clears the selection.
Reference filters the complete help by category or search text.
Use native controls to select and copy a paragraph or a complete code box.
Reference does not change your draft.
Maintenance holds revision review, retained drafts, and reset controls. A reset requires a stopped program.
Type or paste source into the source box. Validate checks the draft without effects.
Save stores source but does not change the active run.
Run/Apply validates and activates only the saved revision on the screen.
Save an unsaved draft before Run/Apply. An invalid candidate keeps the previous run.
Successful Run/Apply keeps state.
Computer items contain only hardware. Ordinary pickup and replacement loses the computer's source and state.
Clipboard, blueprint, and clone copies contain only saved source and label. They start stopped.
Native undo restores the source, label, and state from before removal into a new stopped identity.
It does not restore a run. Previously active source becomes recovery text for review.
Private drafts keep their previous identity. Old computer-item payloads are ignored; item data cannot be recovered.
Placed records, drafts, KV contents and deadlines, and monitor data keep their existing save and item policies.
Undo history and its original ghost are not permanent backups. Keep complete save and mod backups.
Stop cancels callbacks and timers. It clears only the logic output that this run still owns.
Reset State requires Stop and a separate confirmation. It never clears a KV database.
Close and Escape keep the draft. Reopen the same computer body to recover it.
For a conflict, select Review to open Maintenance. Read the current source.
Select Rebase to keep your draft, or Reload to discard it. Both controls check the revision again.
Each player can keep eight recovery drafts within their limits. Unsaved drafts are not automatically removed.
Ctrl+left-click opens an actual computer when your cursor is empty and no GUI is open.
You can change this key binding. Review retained drafts in Maintenance.
Clicks on empty ground do nothing.
An ordinary open action on a composite peripheral opens its local read-only inspector.
Radars and programmable speakers keep their native configuration windows.
Inspectors do not need a computer or an active program.
Select name for copy selects only the API ID. Use native Copy.
Paste the ID into your draft. Escape keeps computer drafts.
Open inspectors and Peripherals update automatically in limited pages or chunks.
KV byte strings show empty values in quotes. They escape quotes and backslashes.
They use hexadecimal byte escapes for control bytes, high bytes, and brackets.
You can still read the complete values.
Configurator lists prototypes on its target side. Unique counts each prototype once across Red and Green.
Logic shows separate colored inputs and its own output bank. It does not show other emitters in that bank.
Logic and monitor updates are sampled every 15 ticks when resource checks permit them.
Monitor dimensions use connected tiles on local axes and terminal columns and rows. They are not pixel dimensions.
Ctrl-click monitor touches remain a separate interaction. Custom devices do not need electricity.
Identity, geometry, permissions, and current wiring still determine availability.
All essential controls are buttons. They remain available when the text box has focus.

LANGUAGE
function start(event) ... end; function sample(event) ... end
Plain declarations export named handlers. API version 1 is implicit. start is optional.
sample() calls directly into this program with ordinary arguments and results. It uses the same callback budget.
computer.every(60, "sample") schedules a later TimerEvent.
A name alone does not register a subscription. Registration uses strings, never function values.
Declare a private local function before use. Private helpers are not exported.
Exports are read-only and visible before their declarations. Parameters and locals can shadow them normally.
Only declarations, comments, and semicolons are permitted at top level. At least one export is required.
Top-level values, returns, calls, and effects are not permitted.
Locals, helpers, if, loops, and tables have guarded work, depth, and allocation limits.
Each callback has new functions and locals. Keep durable values in computer state.
Console cannot call saved-program functions. The starter samples once immediately and logs the returned count.
It then samples every 60 simulation ticks. It does not need a peripheral.
No require, load, game, storage, remote, _ENV, _G, metatables, coroutine, patterns,
random, string-method syntax, or colon calls are available. API calls use dots.

New global names are reserved in public and private top-level declarations. Body locals and parameters are not subject to this restriction.
Old active source with a conflicting declaration faults during synchronized reconstruction. Source and state remain available.
Rename the declaration. Explicitly Save and Run the corrected source.
A conflicting Console root reports E_UNSUPPORTED before effects. Its graph remains until confirmed Reset Shell discards it.
Nested keys are permitted.

COMBINED EXAMPLE
Choose Examples for small, complete tutorials. They contain setup instructions, executable code, procedures, expected results, and failure notes.
They do not need external files or guest imports.
Small factory dashboard combines configuration, logic, a database, and a monitor.
Two-computer shared data uses two actual computers and two physical databases.
The starter does not need peripherals.
One speaker note, Stock-controlled inserter, and Find iron plate recipes each teach one service.
Larger supplied programs and documents give more information. The in-game tutorials do not require them.

FAILURES AND PERSISTENCE
Saved and active source can differ. Functions are reconstructed only on dispatch.
No player code runs on load. Startup is not replayed.
Earlier successful effects remain after later faults. Keep complete save and mod backups before you change runtimes.
Search TC.ApiError, TC.Data, and TC.Limits for the complete shared contract.
Quotas are development limits. They do not guarantee a real-time response interval.
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
tutorials.starter={title='Starter controller',purpose='Sample immediately. Then update a saved counter every 60 simulation ticks. A peripheral is not necessary.',
  setup='Research Native circuit computers (tc-circuit-computers). Craft one computer. Electricity, wires, a second computer, and external files are not necessary.',
  steps='Clear the cursor. Ctrl+left-click the computer. Use native controls to select the complete code box. Copy the selection. Paste it into an empty Editor draft. Select Validate. Select Save. Select Run. The Editor starter control can insert the same source. Reference has no action buttons.',
  expected='Console prints Initial sample count: 1 on a new computer. The saved samples state is immediately 1. It increases to 2 at the first 60-tick timer. Apply keeps the previous count. A cold load does not replay start.',
  failures='Save alone does not activate a revision. Console cannot call saved-program functions. Stop cancels the timer but keeps the count. Maintenance Reset State requires Stop and a separate confirmation.',
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
