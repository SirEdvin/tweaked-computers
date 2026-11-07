-- Production-context idle structure: real ticks, no hook or allocation while nothing is due.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')

local M={}
local resume=false
local window=1200
-- Every production hook; readiness is read before the measured scheduler call.
local hooks={
  {'lifecycle','00-physical-observation'},{'lifecycle','01-clone-components'},
  {'lifecycle','01-network-output-authority'},{'lifecycle','02-computer-undo'},
  {'lifecycle','02-monitor-groups'},{'lifecycle','02-native-radar-adoption'},
  {'sample','logic-input'},{'notifications','monitor-events'},{'notifications','peripheral-topology'},
  {'render','device-status-art'},{'render','kv-reclamation'},{'render','monitor-world'},
  {'render','program-editor'},{'render','ui-dashboard'},{'render','ui-peripheral-inspectors'},
}
local source=[[
function start() computer.every(300,'beat') end
function beat() computer.setState('beats',(computer.getState('beats') or 0)+1) end
]]
local function quiet(root,tick)
  for i=1,#hooks do if scheduler.hook_ready(hooks[i][1],hooks[i][2],root,tick) then return false end end
  local timer=root.scheduler.deadlines[1]
  return root.scheduler.ready_head==nil and (timer==nil or timer.tick>tick)
end
-- Each hook's own work makes only that hook ready; restoring the work makes it idle again.
local function readiness_matrix(root,tick)
  assert(tick%15==0 and quiet(root,tick))
  local owner={generation=1}
  local function clock(kind) return {function() registry.maintenance_set(kind,'probe',owner,tick) end,
    function() registry.maintenance_remove(kind,'probe') end} end
  local function push(get) return {function() local t=get(); t[#t+1]={} end, function() local t=get(); t[#t]=nil end} end
  local function field(get,key,value)
    local old
    return {function() old=get()[key]; get()[key]=value end, function() get()[key]=old end}
  end
  local function r() return root end
  local function s() return root.scheduler end
  local function order(key) return function() return root[key].order end end
  local cases={
    ['lifecycle/00-physical-observation']={clock('physical')},
    ['lifecycle/01-clone-components']={field(r,'pending_clone_ports',{{}})},
    ['lifecycle/01-network-output-authority']={push(order('output_owners'))},
    ['lifecycle/02-computer-undo']={field(s,'undo_pending',true)},
    ['lifecycle/02-monitor-groups']={field(r,'monitor_topology_dirty',true)},
    ['lifecycle/02-native-radar-adoption']={push(order('native_adoption'))},
    ['sample/logic-input']={push(order('logic_observers'))},
    ['notifications/monitor-events']={push(function() return root.monitors.touches end)},
    ['notifications/peripheral-topology']={push(order('topology_interests'))},
    ['render/device-status-art']={clock('art')},
    ['render/kv-reclamation']={clock('kv')},
    ['render/monitor-world']={field(function() return root.monitors.presentation.work end,'probe',{}),
      field(s,'render_demand_work',5)},
    ['render/program-editor']={clock('editor')},
    ['render/ui-dashboard']={field(r,'dashboard_sessions',{[1]={}})},
    ['render/ui-peripheral-inspectors']={clock('inspector')},
  }
  for _,hook in ipairs(hooks) do
    local key=hook[1]..'/'..hook[2]
    for _,trigger in ipairs(assert(cases[key],'readiness case missing '..key)) do
      trigger[1]()
      for _,other in ipairs(hooks) do
        local ready=scheduler.hook_ready(other[1],other[2],root,tick)
        assert(ready==(other==hook),key..' work changed readiness of '..other[1]..'/'..other[2])
      end
      trigger[2]()
    end
    assert(quiet(root,tick),key..' readiness did not return to idle')
  end
  -- Viewer lanes keep their 15-tick cadence; unknown state runs its hook.
  local editor=clock('editor'); editor[1]()
  assert(not scheduler.hook_ready('render','program-editor',root,tick+1)); editor[2]()
  local observers=root.logic_observers; root.logic_observers=nil
  assert(scheduler.hook_ready('sample','logic-input',root,tick),'unknown membership skipped its hook')
  root.logic_observers=observers
  assert(quiet(root,tick))
end
function M.run()
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={0,0},force='player'})
  local c=assert(lifecycle.build(body))
  runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  storage.tc_idle={phase='settle',id=c.id,start=game.tick,measured=0,quiet=0,busy=0,beats=0}
end
function M.on_load()
  resume=storage.tc_idle.phase=='frozen'
end
function M.on_configuration_changed() error('idle fixture is not an upgrade fixture') end
-- Lua frees spare call frames during GC; extend them first so only scheduler allocations count.
local function warm(depth) if depth>0 then return warm(depth-1)+0 end; return 0 end
local function measure(x,root,tick)
  local idle=quiet(root,tick)
  warm(48)
  local before=collectgarbage('count')
  scheduler.tick(tick)
  local after=collectgarbage('count')
  if idle then
    assert(after==before,'idle scheduler tick allocated '..((after-before)*1024)..' bytes at '..tick)
    assert(root.scheduler.maintenance_tick~=tick,'idle scheduler tick opened maintenance at '..tick)
    x.quiet=x.quiet+1
  else x.busy=x.busy+1 end
  x.measured=x.measured+1
end
function M.on_tick(event)
  local x=storage.tc_idle; local root=registry.get(); local c=registry.computer(x.id)
  if x.phase=='frozen' then
    if not resume then return end
    resume=false; x.phase='resumed'; x.measured=0; x.quiet=0; x.busy=0; x.beats=c.state.beats or 0
    -- The first tick after load performs the one-time retained-state migration check.
    scheduler.tick(event.tick); x.beats=c.state.beats or 0
    return
  end
  if x.phase=='settle' then
    scheduler.tick(event.tick)
    if event.tick>=x.start+120 then x.phase='measure'; x.beats=c.state.beats or 0 end
    return
  end
  if x.phase=='done' then return end
  if x.phase=='measure' and not x.matrix and event.tick%15==0 and quiet(root,event.tick) then
    readiness_matrix(root,event.tick); x.matrix=true
    log('TC_CONTRACT every-hook-readiness-follows-its-own-work')
  end
  measure(x,root,event.tick)
  assert(c.status=='running' and not root.scheduling_diagnostic,'idle computer stopped or diagnostic raised')
  if x.measured==window then
    local beats=(c.state.beats or 0)-x.beats
    -- One computer observes its body every 60 ticks; a 300-tick timer adds four more due ticks.
    assert(beats==window/300,'timer callbacks missing or replayed: '..beats)
    assert(x.busy<=window/60+window/300+2,'idle ticks were not quiet: busy='..x.busy)
    log('TC_IDLE_SCHEDULER '..helpers.table_to_json{phase=x.phase,quiet=x.quiet,busy=x.busy,beats=beats})
    if x.phase=='measure' then
      assert(x.matrix,'no quiet 15-tick boundary for the readiness matrix')
      log('TC_CONTRACT idle-ticks-call-no-hook-and-allocate-nothing')
      x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    else
      x.phase='done'; log('TC_COLD_OK')
    end
  end
end
return M
