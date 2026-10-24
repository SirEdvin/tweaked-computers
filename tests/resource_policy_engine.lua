-- Real production services, electrical supply and cold processes; no GUI claims.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local shell=require('scripts.runtime.shell')
local editor=require('scripts.ui.editor')
local editor_model=require('scripts.ui.editor-model')
local editor_contract=require('tests.editor_contract')
local M={}; local loaded=false
local player,gui
local function with_player(fn)
  if not player then return fn() end
  local original=game
  game=setmetatable({get_player=function(index) if index==player.index then return player end; return original.get_player(index) end},
    {__index=function(_,key) return original[key] end})
  local ok,result=pcall(fn); game=original
  if not ok then error(result,0) end
  return result
end
local function tick(event) with_player(function() scheduler.tick(event.tick) end) end
local function open(rec,token)
  player=editor_contract.player(4001,rec.body)
  assert(editor.open(player,rec.id)); gui=player.gui.screen[editor.frame_name]
  if token then editor_model.session(player.index).token=token; gui.tags.token=token end
  with_player(function() gui.content.selected_tab_index=2; editor.on_tab{player_index=player.index,element=gui.content,tick=game.tick} end)
end
local function submit(source)
  with_player(function()
    editor.refresh(player)
    local input=gui.content.console.prompt.command; input.text=source
    editor.on_text{player_index=player.index,element=input,tick=game.tick}
    editor.on_confirmed{player_index=player.index,element=input,tick=game.tick}
    assert(input.text=='','Console ingress refused: '..tostring(gui.content.console.shell_status.caption))
  end)
end
local function copy(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {}; if seen[v] then return seen[v] end
  local out={}; seen[v]=out
  for k,x in pairs(v) do out[k]=copy(x,seen) end; return out
end
local function equal(a,b,seen)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  seen=seen or {}; if seen[a] then return seen[a]==b end; seen[a]=b
  for k,v in pairs(a) do if not equal(v,b[k],seen) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function data_only(v,seen)
  local t=type(v)
  assert(t=='nil' or t=='number' or t=='string' or t=='boolean' or t=='table','non-data checkpoint')
  if t~='table' or seen[v] then return end
  assert(getmetatable(v)==nil,'checkpoint metatable')
  seen[v]=true
  for k,x in pairs(v) do data_only(k,seen); data_only(x,seen) end
end
local function snapshot()
  local f=storage.tc_resource_engine; local root=registry.get(); local records={}
  local function add(id)
    local r=registry.computer(id)
    records[#records+1]={run=r.run_id,generation=r.run_generation,active=copy(r.active),saved=r.saved_source,
      invocation=copy(r.invocation),shell=copy(r.shell),queue=copy(r.queue),bytes=r.queue_bytes,state=copy(r.state),dispatch=r.last_dispatch_tick,next_class=r.next_work_class}
  end
  for _,id in ipairs(f.computers) do add(id) end
  for _,id in ipairs(f.runaways) do add(id) end
  local dbs={}; for _,id in ipairs(f.databases) do dbs[#dbs+1]=copy(registry.record(id).database) end
  return {computers=records,databases=dbs,ledger=copy(root.ledger),scheduler=copy(root.scheduler),sequence=root.next_sequence,
    cache_limit=limits.compiler_cache_bytes}
end
local function frozen()
  local f=storage.tc_resource_engine
  assert(equal(snapshot(),f.expected),'cold load changed graph, work, queue or effects')
  for i,id in ipairs(f.computers) do
    local checkpoint=registry.computer(id).invocation.checkpoint
    assert(checkpoint==f.checkpoints[i] and checkpoint.frame==f.frames[i],'checkpoint identity changed')
    data_only(checkpoint,{})
  end
  for _,link in ipairs(f.links) do
    assert(link.checkpoint.bindings[link.token]==link.descriptor and link.descriptor.facade==link.parent,'binding/facade alias changed')
  end
  local s=registry.computer(f.computers[1]).shell
  assert(s.id==f.shell_id and s.invocation.checkpoint==f.shell_checkpoint and s.values==nil,'staged shell identity/commit changed')
  assert(s.invocation.checkpoint.shell_root.x==10,'staged scratch value lost')
  data_only(s.invocation.checkpoint,{})
end
local function cache_setting(value)
  local ledger=registry.get().ledger
  local before=copy(ledger)
  settings.global['tc-compiler-cache-bytes']={value=value}
  local handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
  handler{setting='tc-compiler-cache-bytes',setting_type='runtime-global',tick=game.tick}
  assert(settings.global['tc-compiler-cache-bytes'].value==value and limits.compiler_cache_bytes==value)
  assert(registry.get().ledger==ledger and equal(ledger,before),'cache setting renewed spent credits')
end
local function document(body,descriptor)
  if descriptor then
    return "return {api_version=1,handlers={start=function(e) "..body.." end,later=function(e) computer.setState('last',e.tag) end}}"
  end
  return 'function start(e) '..body.." end\nfunction later(e) computer.setState('last',e.tag) end"
end
local function source(db,descriptor,target)
  return document("local db=peripheral.wrap('"..db.."','red'); local write=db.set; "..
    "write('prefix',tostring((tonumber(db.get('prefix')) or 0)+1)); "..
    "local n=0; while n<"..target.." do n=n+1; if n%50000==0 then "..
    "write('loop',tostring((tonumber(db.get('loop')) or 0)+1)); write('loop-at',tostring(n)) end end; "..
    "write('result',tostring(n)); computer.setState('finished',true)",descriptor)
end
function M.run()
  local s=game.surfaces[1]
  local function build(kind,x,y)
    local rec,e=lifecycle.build(assert(s.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'}))
    assert(rec,e and (e.code..': '..e.message)); return rec
  end
  local f={phase='power',origin=game.tick,computers={},databases={},runaways={},loop_targets={300000,600000},cache_limit=limits.compiler_cache_bytes}
  assert(f.cache_limit==8388608 and settings.global['tc-compiler-cache-bytes'].value==8388608)
  storage.tc_resource_engine=f
  for i=1,2 do
    local c=build('computer',0,(i-1)*6); local db=build('kv',3,(i-1)*6)
    assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(db,'network','red')))
    f.computers[i]=c.id; f.databases[i]=db.id
  end
  local peer=build('computer',0,12); f.peer=peer.id
  for i=1,2 do f.runaways[i]=build('computer',6,(i-1)*12).id end
  assert(s.create_entity{name='substation',position={6,6},force='player'})
  local supply=assert(s.create_entity{name='electric-energy-interface',position={9,6},force='player'})
  supply.power_production=100000000; supply.power_usage=0
end
function M.on_load()
  loaded=true
  if storage.tc_resource_engine.phase=='frozen' then frozen(); log('TC_COLD_ON_LOAD_UNCHANGED durable-scalar-bindings') end
end
function M.on_tick(event)
  local f=storage.tc_resource_engine
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    frozen(); loaded=false
    for _,id in ipairs(f.computers) do
      local ctx=runtime.context(registry.computer(id),f.freeze_tick)
      assert(not admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work+1),'cold credits renewed')
    end
    scheduler.tick(f.freeze_tick); frozen()
    open(registry.computer(f.computers[1]),f.token)
    f.phase='resume'
  elseif f.phase=='power' then
    loaded=false; scheduler.tick(event.tick)
    assert(event.tick-f.origin<120,'electrical bootstrap deadline')
    for _,id in ipairs(f.computers) do if not registry.computer(id).powered then return end end
    if not registry.computer(f.peer).powered then return end
    for _,id in ipairs(f.runaways) do if not registry.computer(id).powered then return end end
    for i,id in ipairs(f.computers) do
      local c=registry.computer(id)
      runtime.save(id,source(f.databases[i],i==1,f.loop_targets[i]),0); assert(runtime.activate(id,event.tick))
      f.computers[i]=c.id
    end
    local peer=registry.computer(f.peer)
    runtime.save(peer.id,"function start() computer.every(1,'sample') end\nfunction sample() computer.setState('beats',(computer.getState('beats') or 0)+1) end",0)
    assert(runtime.activate(peer.id,event.tick))
    for i,id in ipairs(f.runaways) do
      runtime.save(id,document("computer.log('runaway-prefix'); while true do end",i==1),0)
      assert(runtime.activate(id,event.tick))
    end
    f.execution_origin=event.tick
    f.phase='armed'; return
  end
  if f.phase=='submit' then submit(f.command); f.phase='shell-armed' end
  if f.phase=='control-submit' then submit('control_probe=37'); f.control_submitted=true; f.phase='resume' end
  tick(event)
  if f.phase=='armed' then
    local c=registry.computer(f.computers[1]); local db=f.databases[1]
    assert(c.invocation and c.status=='running',c.diagnostic and c.diagnostic.message)
    open(c)
    f.command="x=10; local db=peripheral.wrap('"..db.."','red'); db.set('shell-prefix',tostring((tonumber(db.get('shell-prefix')) or 0)+1)); print('shell-before'); local n=0; while n<600000 do n=n+1 end; x=n; db.set('shell-result',tostring(n))"
    f.phase='submit'; return
  elseif f.phase=='shell-armed' then
    assert(event.tick-f.execution_origin<200,'mid-loop snapshot deadline')
    for i,id in ipairs(f.databases) do
      local at=registry.record(id).database.entries['loop-at']
      if not at or tonumber(at.value)<f.loop_targets[i]/2 then return end
    end
    local s=registry.computer(f.computers[1]).shell
    assert(s.invocation and s.invocation.checkpoint.shell_root.x==10 and s.values==nil,s.diagnostic and s.diagnostic.message)
    f.shell_id=s.id; f.shell_checkpoint=s.invocation.checkpoint; f.token=editor_model.session(player.index).token
    f.checkpoints={}; f.frames={}; f.links={}
    for i,id in ipairs(f.computers) do
      local c=registry.computer(id); local db=registry.record(f.databases[i])
      assert(c.status=='running',c.diagnostic and c.diagnostic.message)
      assert(c.invocation and not c.state.finished and db.database.entries.prefix.value=='1','missing unfinished KV-writing invocation')
      assert(runtime.enqueue(c,'later',{name='fixture',tag='a'},event.tick))
      assert(runtime.enqueue(c,'later',{name='fixture',tag='b'},event.tick))
      runtime.save(c.id,'function start() error("saved-only source executed") end',c.saved_revision)
      local checkpoint=c.invocation.checkpoint
      f.checkpoints[i]=checkpoint; f.frames[i]=checkpoint.frame
      for token,descriptor in pairs(checkpoint.bindings) do
        f.links[#f.links+1]={checkpoint=checkpoint,token=token,descriptor=descriptor,parent=descriptor.facade}
      end
      data_only(checkpoint,{})
    end
    for token,descriptor in pairs(f.shell_checkpoint.bindings) do
      f.links[#f.links+1]={checkpoint=f.shell_checkpoint,token=token,descriptor=descriptor,parent=descriptor.facade}
    end
    assert(#f.links>=4,'real captured facade/method witnesses required')
    cache_setting(1)
    f.phase='frozen'; f.freeze_tick=event.tick; f.expected=snapshot()
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-f.freeze_tick<200,'finite continuation deadline')
  local done=true
  local owner=registry.computer(f.computers[1]); local shell_db=registry.record(f.databases[1]).database
  assert(shell_db.entries['shell-prefix'].value=='1','Console peripheral effect replayed')
  if shell.waiting(owner) then
    assert(owner.shell.values==nil,'unfinished Console command committed staging')
    done=false
  else
    assert(not owner.shell.diagnostic,owner.shell.diagnostic and owner.shell.diagnostic.message)
    assert(shell_db.entries['shell-result'].value=='600000','Console local lost')
  end
  for i,id in ipairs(f.computers) do
    local c=registry.computer(id); local db=registry.record(f.databases[i])
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.run_generation==1 and db.database.entries.prefix.value=='1','startup/effect replayed')
    if c.state.last=='a' then f.saw_a=true end
    if c.state.last~='b' then done=false end
    if c.state.finished then
      assert(db.database.entries.result.value==tostring(f.loop_targets[i]),'loop local lost')
      assert(tonumber(db.database.entries.loop.value)==f.loop_targets[i]/50000
        and db.database.entries['loop-at'].value==tostring(f.loop_targets[i]),'KV loop body replayed or skipped')
    end
  end
  if done then
    assert(f.saw_a and registry.computer(f.peer).state.beats>0,'FIFO/neighbor progress missing')
    local x
    for _,entry in ipairs(owner.shell.values.nodes[1].entries) do if entry.key=='x' then x=entry.value end end
    assert(x==600000,'Console staging was not committed on success')
    local prints=0; for _,entry in ipairs(owner.logs) do if entry.text:find('output: shell-before',1,true) then prints=prints+1 end end
    assert(prints==1,'Console print replayed or lost')
    local runaway=registry.computer(f.runaways[1])
    if not f.control_submitted then
      open(runaway); f.phase='control-submit'
      return
    end
    assert(runaway.status=='running' and runaway.invocation,'Console retired the runaway program')
    if shell.waiting(runaway) then return end
    assert(not runaway.shell.diagnostic and runaway.shell.values,'finite Console command starved or failed')
    local probe
    for _,entry in ipairs(runaway.shell.values.nodes[1].entries) do if entry.key=='control_probe' then probe=entry.value end end
    assert(probe==37,'Console did not commit beside infinite program')
    local invocation=runaway.invocation
    local ctx=runtime.context(runaway,event.tick)
    local work,allocations,total=ctx.machine.work,ctx.machine.allocations,ctx.ledger.total
    assert(shell.reset(runaway,'reset') and runaway.shell==nil and runaway.invocation==invocation)
    assert(runtime.context(runaway,event.tick).machine==ctx.machine and ctx.machine.work==work
      and ctx.machine.allocations==allocations and ctx.ledger.total>=total,'Console reset renewed guest credits')
    log('TC_CONTRACT finite-console-and-reset-beside-infinite-program-share-credits')
    for _,id in ipairs(f.runaways) do
      local rec=registry.computer(id); local ctx=runtime.context(rec,event.tick)
      assert(rec.status=='running' and rec.invocation and rec.last_dispatch_tick>f.freeze_tick)
      local work,allocations,total=ctx.machine.work,ctx.machine.allocations,ctx.ledger.total
      assert(runtime.stop(id) and rec.status=='stopped' and rec.invocation==nil)
      assert(runtime.context(rec,event.tick).machine==ctx.machine and ctx.machine.work==work
        and ctx.machine.allocations==allocations and ctx.ledger.total>=total,'host Stop renewed guest credits')
      local count=0; for _,entry in ipairs(rec.logs) do if entry.text=='runaway-prefix' then count=count+1 end end
      assert(count==1,'runaway prefix replayed across real ticks/cold load')
    end
    log('TC_CONTRACT both-source-runaways-stop-after-real-ticks-and-cold-without-credit-renewal')
    cache_setting(f.cache_limit)
    f.phase='done'; log('TC_COLD_OK durable-KV-loop both-source-forms locals aliases FIFO neighbor Console-staging once-only')
  end
end
return M
