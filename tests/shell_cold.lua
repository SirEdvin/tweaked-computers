-- Production-context, separate-process persistence contract. Native entities,
-- services and real scheduler ticks; authoring players/GUI are explicitly mocked.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local shell=require('scripts.runtime.shell')
local scheduler=require('scripts.scheduler')
local contracts=require('tests.editor_contract')
local editor=require('scripts.ui.editor')
local model=require('scripts.ui.editor-model')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local kv=require('scripts.services.kv')
local defs=require('scripts.device-definitions')
local M={}
local loaded=false
local player,gui
local function clone(v,seen)
  if type(v)~='table' then return v end
  seen=seen or {}
  if seen[v] then return seen[v] end
  local result={}; seen[v]=result
  for k,x in pairs(v) do result[k]=clone(x,seen) end
  return result
end
local function equal(a,b,forward,reverse)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  forward=forward or {}; reverse=reverse or {}
  if forward[a] then return forward[a]==b end
  if reverse[b] then return false end
  forward[a]=b; reverse[b]=a
  for k,v in pairs(a) do if not equal(v,b[k],forward,reverse) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function snapshot()
  local f=storage.tc_shell_fixture; local rec=registry.record(f.id); local r=registry.get()
  return {shell=clone(rec.shell),state=clone(rec.state),run=rec.run_id,queue=clone(rec.queue),
    unknown_shell=clone(registry.record(f.unknown).shell),
    collision=f.collision and clone(registry.record(f.collision).shell),
    ledger=clone(r.ledger),last_dispatch=rec.last_dispatch_tick,next_sequence=r.next_sequence,
    log_bytes=rec.log_bytes,logs=clone(rec.logs),scheduler=clone(r.scheduler)}
end
local function unchanged()
  assert(equal(snapshot(),storage.tc_shell_fixture.expected),'cold shell/queue/credits changed before synchronized work')
end
local function with_player(fn)
  local original=game
  game=setmetatable({get_player=function(i) if player and i==player.index then return player end; return original.get_player(i) end},
    {__index=function(_,k) return original[k] end})
  local ok,result=pcall(fn); game=original
  if not ok then error(result,0) end
  return result
end
local function open(rec,retained_token)
  player=contracts.player(4001,rec.body)
  assert(editor.open(player,rec.id)); gui=player.gui.screen[editor.frame_name]
  if retained_token then model.session(player.index).token=retained_token; gui.tags.token=retained_token end
  with_player(function()
    gui.content.selected_tab_index=2
    editor.on_tab{player_index=player.index,element=gui.content,tick=game.tick}
  end)
end
local function submit(text)
  with_player(function()
    editor.refresh(player)
    local input=gui.content.console.prompt.command; input.text=text
    editor.on_text{player_index=player.index,element=input,tick=game.tick}
    editor.on_confirmed{player_index=player.index,element=input,tick=game.tick}
    assert(input.text=='','cold ingress refused: '..tostring(gui.content.console.shell_status.caption))
  end)
end
local function tick(event) with_player(function() scheduler.tick(event.tick) end) end
function M.run()
  -- Runtime owners point back through their account; preserve cycles and aliases
  -- rather than recursively expanding them or dropping ownership from the check.
  local shared={value=false}; local graph={shared,shared}; graph.self=graph
  local copied=clone(graph)
  assert(copied~=graph and copied.self==copied and copied[1]==copied[2] and equal(graph,copied))
  copied[2]={value=false}; assert(not equal(graph,copied) and not equal(copied,graph))
  copied=clone(graph); copied[1].value=true; assert(not equal(graph,copied))
  log('TC_CONTRACT cold-snapshot-preserves-cycles-and-rejects-value-or-alias-changes')
  local surface=game.surfaces[1]
  local function build(kind,x,y)
    return assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
  end
  local rec=build('computer',0,0); local db=build('kv',3,0)
  local peer=build('computer',0,7)
  local unknown=build('computer',0,10)
  unknown.shell={version=99,payload='preserve future shell data'}
  assert(lifecycle.connector(rec,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  assert(surface.create_entity{name='substation',position={3,4},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={6,4},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  local source='return {api_version=1,handlers={start=function(e) computer.every(1,"sample") end,sample=function(e) computer.setState("samples",(computer.getState("samples") or 0)+1) end}}'
  runtime.save(rec.id,source,0); assert(runtime.activate(rec.id,game.tick))
  runtime.save(peer.id,source,0); assert(runtime.activate(peer.id,game.tick))
  runtime.save(unknown.id,source,0); assert(runtime.activate(unknown.id,game.tick))
  storage.tc_shell_fixture={phase='power',id=rec.id,db=db.id,peer=peer.id,unknown=unknown.id,start=game.tick}
  local collision=build('computer',0,13)
  runtime.save(collision.id,source,0); assert(runtime.activate(collision.id,game.tick))
  collision.shell={version=1,id=collision.id..'/old-shell',pending={},pending_bytes=0,
    values={version=1,root=1,nodes={{kind='table',entries={{key='rawset',value=false}}}}}}
  storage.tc_shell_fixture.collision=collision.id
end
function M.on_load()
  loaded=true
  if storage.tc_shell_fixture.phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED shell-values-pending-program-ledger') end
end
function M.on_tick(event)
  local f=storage.tc_shell_fixture; local rec=registry.record(f.id)
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false
    assert(rec.shell.values==f.values and rec.shell.pending==f.pending,'cold alias loss')
    local ctx=runtime.context(rec,f.tick)
    assert(ctx.machine.work==f.work and not admission.reserve(ctx,'work',1),'cold budget renewed')
    open(rec,f.token)
    f.phase='resume'; f.resume_tick=event.tick
  elseif f.phase=='power' then
    loaded=false; tick(event)
    assert(event.tick<f.start+120,'powered bootstrap deadline')
    if not rec.powered or not rec.state.samples then return end
    assert(not rec.shell,'old-save shell initialized before action')
    open(rec)
    submit('a={}; b=a; rawset(a,"self",a); rawset(a,"value",false); print(_VERSION,false,nil,3); p=peripheral.wrap("'..f.db..'","red"); get=p.get; p.set("once","one"); computer.setState("effects",(computer.getState("effects") or 0)+1)')
    f.phase='assigned'
    return
  elseif f.phase=='assigned' then
    tick(event)
    assert(event.tick<f.start+140,'shell assignment deadline')
    if shell.waiting(rec) then return end
    assert(not rec.shell.diagnostic,rec.shell.diagnostic and rec.shell.diagnostic.message)
    assert(rec.state.effects==1 and rec.status=='running')
    submit('assert(rawequal(a,b) and rawequal(rawget(a,"self"),a) and rawget(a,"value")==false and get==p.get and get("once")=="one"); rawset(b,"value",9); computer.setState("pending",(computer.getState("pending") or 0)+1)')
    submit('assert(a.value==9); print(false,nil,3)')
    local ctx=runtime.context(rec,event.tick)
    assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
    f.tick=event.tick; f.work=ctx.machine.work; f.token=model.session(player.index).token
    f.values=rec.shell.values; f.pending=rec.shell.pending; f.phase='frozen'
    f.expected=snapshot()
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if f.phase=='resume' then
    tick(event)
    assert(event.tick<f.resume_tick+60,'cold pending command deadline')
    if shell.waiting(rec) then return end
    assert(rec.state.effects==1 and rec.state.pending==1 and rec.status=='running')
    assert(not rec.shell.diagnostic,rec.shell.diagnostic and rec.shell.diagnostic.message)
    local db=registry.record(f.db)
    assert(kv.methods.get(rec,db,'red',event.tick,function() end,'once')=='one')
    assert(registry.record(f.peer).state.samples>0)
    assert(registry.record(f.unknown).shell.version==99 and registry.record(f.unknown).shell.payload=='preserve future shell data')
    assert(registry.record(f.unknown).status=='running' and registry.record(f.unknown).state.samples>0)
    submit('assert(a.value==9 and b==a and a.self==a and peripheral.getName(p)=="'..f.db..'"); print(get("once"))')
    f.phase='final'
  elseif f.phase=='final' then
    tick(event)
    if shell.waiting(rec) then return end
    assert(not rec.shell.diagnostic and rec.state.effects==1 and rec.state.pending==1)
    local printed=0
    for _,entry in ipairs(rec.logs) do if entry.text:find('output: Lua 5.2\tfalse\tnil\t3',1,true) then printed=printed+1 end end
    assert(printed==1,'completed shell print replayed or lost')
    local collision=registry.record(f.collision); local old=collision.shell.values
    local ok,d=shell.evaluate(collision,'computer.setState("unsafe",true)',event.tick,0)
    assert(not ok and d.code=='E_UNSUPPORTED' and d.message:find('rawset',1,true))
    assert(collision.shell.values==old and old.nodes[1].entries[1].value==false and collision.status=='running' and not collision.state.unsafe)
    for _,name in ipairs({'rawset','xpcall','unpack'}) do
      local graph=rec.shell.values
      ok,d=shell.evaluate(rec,'saved='..name,event.tick,0)
      assert(not ok and d.code=='E_UNSUPPORTED' and rec.shell.values==graph)
    end
    f.phase='done'; log('TC_COLD_OK shell-aliases-bindings-captured-methods-pending-once-only-real-ticks')
  end
end
return M
