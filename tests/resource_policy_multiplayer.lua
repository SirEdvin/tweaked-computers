-- Two real clients; hold the scheduler at an observed durable boundary until
-- the second synchronized join event. Never resume from a process-local flag.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local editor=require('scripts.ui.editor')
local shell=require('scripts.runtime.shell')
local scene=require('tests.resource_policy_multiplayer_scene')
local M={}
local function f() return storage.tc_policy_multiplayer end
local function computer() return registry.computer(storage.tc_shell_client.computer) end
local function snapshot()
  local c=computer()
  return {computer=c,db=registry.record(storage.tc_shell_client.db).database}
end
local function graph(root)
  local seen,records={},{}
  local function visit(t)
    if type(t)~='table' or rawget(t,'__self') or seen[t] then return end
    seen[t]=true; local r={target=t,entries={}}; records[#records+1]=r
    for k,v in pairs(t) do r.entries[#r.entries+1]={k,v}; visit(k); visit(v) end
  end
  visit(root); return records
end
local function unchanged()
  for _,r in ipairs(f().graph) do
    local n=0; for _ in pairs(r.target) do n=n+1 end
    assert(n==#r.entries,'late join changed retained keys')
    for _,e in ipairs(r.entries) do assert(r.target[e[1]]==e[2],'late join changed retained value/alias') end
  end
end
local function publish()
  local c=computer(); local x=f(); local peers={}
  for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end
  local state={phase=x.phase,peers=peers,freeze_tick=x.freeze_tick,join_tick=x.join_tick,
    run=c.run_id,generation=c.run_generation,state=c.state,source=c.active.source,saved=c.saved_source,
    queue=c.queue,timers=c.timers,logs=c.logs,shell_values=c.shell and c.shell.values,
    db=registry.record(storage.tc_shell_client.db).database}
  local text=helpers.table_to_json(state)
  helpers.write_file('resource-policy-peer.json',text,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('resource-policy-peer.json',text,false,p.index) end
end
function M.run()
  scene.run()
  runtime.stop(storage.tc_shell_client.computer)
  storage.tc_policy_multiplayer={phase='waiting-first'}
end
function M.on_load()
  if f().phase=='frozen' then unchanged(); log('TC_MP_LOAD_UNCHANGED nested-console') end
end
function M.on_player_joined(e)
  if e.name~=defines.events.on_player_joined_game then return end
  local x=f(); local p=game.get_player(e.player_index)
  p.teleport({0,-2},game.surfaces[1]); p.zoom=1
  if #game.connected_players==1 and x.phase=='waiting-first' then
    x.player=p.index; x.phase='power'; log('TC_MP_FIRST_JOINED')
  elseif #game.connected_players==2 and x.phase=='frozen' then
    unchanged(); x.join_tick=game.tick; x.phase='resuming'; x.graph=nil
    log('TC_MP_SECOND_JOINED_AT_BOUNDARY nested-console')
  end
end
function M.on_configuration_changed() error('not an upgrade fixture') end
function M.on_tick(e)
  local x=f(); local c=computer()
  if x.phase=='done' then if e.tick%60==0 then publish() end; return end
  if x.phase=='waiting-first' then return end
  if x.phase=='frozen' then unchanged(); if e.tick%60==0 then publish() end; return end
  if x.phase=='power' then
    scheduler.tick(e.tick)
    if not c.powered then return end
    local source=[[function start()
      computer.setState('boots',(computer.getState('boots') or 0)+1)
      computer.every(100000,'timer')
      local function outer(target)
        local function inner(n)
          computer.setState('prefix',(computer.getState('prefix') or 0)+1)
          local i=0; while i<n do i=i+1 end
          return i
        end
        return inner(target)+7
      end
      computer.setState('result',outer(600000))
    end
    function later(e) computer.setState('order',(computer.getState('order') or '')..e.tag) end
    function timer() error('unexpected timer') end]]
    assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,e.tick))
    x.run=c.run_id; x.phase='arm'; return
  end
  if x.phase~='submit' then scheduler.tick(e.tick) end
  assert(c.status=='running',c.diagnostic and c.diagnostic.message)
  if x.phase=='arm' and c.state.prefix==1 then x.phase='submit'; return end
  if x.phase=='submit' then
    assert(c.invocation,'nested handler finished before boundary')
    local p=game.get_player(x.player); assert(editor.open(p,c.id))
    local gui=p.gui.screen[editor.frame_name]
    gui.content.selected_tab_index=2; editor.on_tab{player_index=p.index,element=gui.content,tick=e.tick}
    local input=gui.content.console.prompt.command
    input.text="staged=10; computer.setState('shell_prefix',(computer.getState('shell_prefix') or 0)+1); print('once-before'); local n=0; while n<600000 do n=n+1 end; staged=n; computer.setState('shell_done',n)"
    editor.on_text{player_index=p.index,element=input,tick=e.tick}
    editor.on_confirmed{player_index=p.index,element=input,tick=e.tick}
    assert(input.text=='','native Console submission refused: '..serpent.line(gui.content.console.shell_status.caption)); x.phase='shell'
  elseif x.phase=='shell' and c.state.shell_prefix==1 then
    assert(c.invocation and c.shell.invocation and c.shell.invocation.checkpoint.shell_root.staged==10)
    local frame=c.invocation.checkpoint.frame
    assert(frame.parent and frame.parent.parent,'must join while both nested caller frames are live')
    assert(c.shell.values==nil and not c.state.result and not c.state.shell_done)
    assert(runtime.enqueue(c,'later',{name='fixture',tag='a'},e.tick)); assert(runtime.enqueue(c,'later',{name='fixture',tag='b'},e.tick))
    assert(runtime.save(c.id,'function start() error("saved-only replay") end',c.saved_revision))
    x.freeze_tick=e.tick; x.graph=graph(snapshot()); x.phase='frozen'
    publish(); game.server_save('resource-policy-boundary'); log('TC_MP_BOUNDARY_READY nested-console')
  elseif x.phase=='resuming' then
    assert(e.tick-x.join_tick<200,'postjoin completion deadline')
    assert(c.run_id==x.run and c.state.boots==1 and c.state.prefix==1 and c.state.shell_prefix==1,'effect replay')
    if c.state.order=='ab' and not shell.waiting(c) then
      assert(c.state.result==600007 and c.state.shell_done==600000,'nested local/result lost')
      assert(not c.shell.diagnostic,c.shell.diagnostic and c.shell.diagnostic.message)
      local prints=0; for _,entry in ipairs(c.logs) do if entry.text:find('output: once-before',1,true) then prints=prints+1 end end
      assert(prints==1,'Console output replay/loss')
      local staged; for _,entry in ipairs(c.shell.values.nodes[1].entries) do if entry.key=='staged' then staged=entry.value end end
      assert(staged==600000,'staged Console commit lost')
      x.phase='done'; publish(); log('TC_MP_OK nested-console')
    end
  end
end
return M
