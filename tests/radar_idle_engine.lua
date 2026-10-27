-- Test-only paired idle benchmark. No production budgets or native power writes.
local scheduler=require('scripts.scheduler')
local registry=require('scripts.registry')
local config=require('tests.radar_idle_config')
local M={}; local lifecycle,network,runtime,defs
local active=false; local profiles={}; local visits=0
local targets={0,100,500,1000}
local function f() return storage.tc_idle_probe end
function M.install()
  if config.profile then
    local register=scheduler.register_phase
    scheduler.register_phase=function(phase,name,fn)
      register(phase,name,function(...)
        if not active then return fn(...) end
        local p=helpers.create_profiler(); local result=table.pack(pcall(fn,...)); p.stop()
        profiles[#profiles+1]={phase..'/'..name,p}
        if not result[1] then error(result[2],0) end
        return table.unpack(result,2,result.n)
      end)
    end
    local record=registry.record
    registry.record=function(id)
      if active and f().dormant[id] then visits=visits+1 end
      return record(id)
    end
  end
  lifecycle=require('scripts.lifecycle'); network=require('scripts.network')
  runtime=require('scripts.runtime.computer'); defs=require('scripts.device-definitions')
end
local function build(kind,x,y)
  return assert(lifecycle.build(assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
end
local function land(pos)
  local tiles={}
  for y=-2,2 do for x=-2,2 do tiles[#tiles+1]={name='landfill',position={pos.x+x,pos.y+y}} end end
  game.surfaces[1].set_tiles(tiles)
end
local function connect(c,b)
  local a=lifecycle.connector(c,'network','red'); local target=b.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  assert(a.connect_to(target,false)); return a,target
end
local function enroll(c,b)
  local a,target=connect(c,b)
  if network.adopt then network.adopt(c,'red',function() end) end
  local rec=assert(registry.by_entity(b)); rec.modem.channels[42]=true; rec.modem.count=1
  assert(a.disconnect_from(target)); return rec
end
function M.run()
  storage.tc_idle_probe={stage=1,age=0,count=0,done=false,dormant={},bodies={}}
  local surface=game.surfaces[1]
  for _,pos in ipairs({{x=-12,y=-12},{x=-6,y=-12},{x=0,y=-12},{x=-6,y=-18}}) do land(pos) end
  if config.workload=='network' then
    local c=build('computer',-12,-12); local db=build('kv',-6,-12)
    assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(db,'network','red')))
    local r=assert(surface.create_entity{name='radar',position={0,-12},force='player',raise_built=true})
    connect(c,r); if network.adopt then network.adopt(c,'red',function() end) end
    f().computer=c.id
    runtime.save(c.id,[[function start(e) computer.every(10,'work') end
function work(e) local db=peripheral.find('kv_database','red'); db.set('beats',tostring(e.tick)); computer.setState('beats',(computer.getState('beats') or 0)+1) end]],0)
    assert(runtime.activate(c.id,game.tick))
  end
  -- Fixed power-grid geometry in every count window; dormant power is the only toggle.
  local positions={{x=-6,y=-18}}
  if config.powered then for y=3,201,18 do for x=3,201,18 do positions[#positions+1]={x=x,y=y} end end end
  for _,pos in ipairs(positions) do land(pos); assert(surface.create_entity{name='substation',position=pos,force='player'}) end
  for i,pos in ipairs(positions) do
    local p={x=pos.x+3,y=pos.y}; land(p)
    local power=assert(surface.create_entity{name='electric-energy-interface',position=p,force='player'})
    power.power_production=100000000; power.power_usage=0
  end
  game.speed=100
end
local function populate(target)
  local x=f(); local surface=game.surfaces[1]
  local c=config.history=='detached' and build('computer',-12,-6)
  for i=x.count+1,target do
    local pos={x=((i-1)%33)*6,y=math.floor((i-1)/33)*6}; land(pos)
    local b=assert(surface.create_entity{name='radar',position=pos,force='player',raise_built=true})
    local rec=c and enroll(c,b) or registry.by_entity(b)
    if rec then x.dormant[rec.id]=true end
    if config.candidate then assert((rec~=nil)==(config.history=='detached')) else assert(rec) end
    x.bodies[#x.bodies+1]=b
    for _,color in ipairs({'red','green'}) do
      local connector=b.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
      if connector then for _,edge in ipairs(connector.real_connections) do assert(edge.origin==defines.wire_origin.radars) end end
    end
  end
  if c then lifecycle.on_removed{entity=c.body}; c.body.destroy() end
  x.count=target
end
function M.on_tick(event)
  local x=f(); if x.done then return end
  x.age=x.age+1
  if x.age==1 and x.count~=targets[x.stage] then populate(targets[x.stage]) end
  profiles={}; visits=0; active=config.profile
  local measuring=x.age>60
  local p=config.profile and helpers.create_profiler()
  scheduler.tick(event.tick)
  if p then p.stop() end
  active=false
  if config.candidate then assert(visits==0,'recurring dormant identity visit') end
  if x.age==60 then
    local powered=0; for _,b in ipairs(x.bodies) do if b.energy>0 then powered=powered+1 end end
    assert(powered==(config.powered and x.count or 0),'power control mismatch '..powered..'/'..x.count)
  end
  if measuring then
    local prefix='TC_IDLE count='..x.count..' sample='..(x.age-60)..' tick='..event.tick
    log(prefix..' visits='..visits)
    if p then log({'',prefix..' phase=scheduler ',p}) end
    for _,entry in ipairs(profiles) do log({'',prefix..' phase='..entry[1]..' ',entry[2]}) end
  end
  if x.age==360 then
    if x.computer then local c=registry.record(x.computer); assert(c.status=='running' and c.state.beats>(x.last_beats or 0)); x.last_beats=c.state.beats end
    log('TC_IDLE_CASE_DONE count='..x.count)
    x.age=0
    if x.stage<#targets then x.stage=x.stage+1
    else x.done=true; log('TC_IDLE_DONE') end
  end
end
return M
