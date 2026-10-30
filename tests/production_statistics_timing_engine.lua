-- Matched physical scenes, real ticks/guest dispatch; profiler output is observational.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local M={}; local resumed=false
local busy=[[function start() computer.every(1,'pulse') end

function pulse() computer.setState('pulses',(computer.getState('pulses') or 0)+1) end]]
local polling=[[function start() computer.every(1,'pulse') end

function pulse()
  local s=peripheral.find('production_statistics','red'); assert(s)
  local a=s.getTotals('item'); local b=s.getRates('fluid','one_minute'); local h=s.getHistory('item','iron-plate','one_minute')
  assert(#h.input==300 and #h.output==300 and a.input.normal['iron-plate']==123 and b.input.water~=nil)
  computer.setState('reads',(computer.getState('reads') or 0)+1)
end]]
local function f() return storage.tc_stat_timing end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=b}; return assert(registry.by_entity(b))
end
local function population(kind)
  local x=f(); x.idle={}
  for i=1,32 do x.idle[i]=build(kind,12+(i-1)%8*2,12+math.floor((i-1)/8)*2).id end
end
function M.run()
  storage.tc_stat_timing={phase='boot',origin=game.tick,phase_start=game.tick,samples={control=0,idle=0,polling=0}}
  local x=f(); local surface=game.surfaces[1]
  surface.request_to_generate_chunks({12,12},2); surface.force_generate_chunk_requests()
  local tiles={}; for y=-8,22 do for xx=-8,30 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end; surface.set_tiles(tiles)
  for _,e in ipairs(surface.find_entities_filtered{area={{-8,-8},{30,22}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local c=build('computer',0,0); local s=build('production_statistics',3,0); x.c=c.id; x.s=s.id
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(s,'network','red')))
  x.neighbors={}
  for i=1,2 do local n=build('computer',0,i*3); x.neighbors[i]=n.id; runtime.save(n.id,busy,0); assert(runtime.activate(n.id,game.tick)) end
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={8,4},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  assert(surface.create_entity{name='substation',position={4,4},force='player'})
  runtime.save(c.id,busy,0); assert(runtime.activate(c.id,game.tick))
  game.forces.player.get_item_production_statistics(surface).on_flow('iron-plate',123)
  game.forces.player.get_fluid_production_statistics(surface).on_flow('water',.5)
  population('kv')
end
function M.on_load() resumed=f().phase=='frozen' end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local c=registry.record(x.c)
  if x.phase=='frozen' then
    if not resumed then return end
    assert(c.state.reads==x.saved.reads and c.active.source==polling)
    for _,phase in ipairs({'control','idle','polling'}) do assert(x.samples[phase]==120) end
    x.phase='done'; log('TC_STAT_TIMING_COLD_OK '..serpent.line(x.samples)); log('TC_COLD_OK'); return
  end
  assert(event.tick-x.origin<600,'timing deadline')
  local profile=helpers.create_profiler(); scheduler.tick(event.tick); profile.stop()
  assert(c.status=='running',serpent.line(c.diagnostic))
  for _,id in ipairs(x.neighbors) do assert(registry.record(id).status=='running') end
  if x.phase=='boot' then
    if c.state.pulses and c.state.pulses>=5 then x.phase='control'; x.phase_start=event.tick+60 end
    return
  end
  if event.tick<=x.phase_start then
    if event.tick==x.phase_start then
      x.before={reads=c.state.reads or 0,neighbors={}}
      for i,id in ipairs(x.neighbors) do x.before.neighbors[i]=registry.record(id).state.pulses end
    end
    return
  end
  if event.tick-x.phase_start<=120 then
    x.samples[x.phase]=x.samples[x.phase]+1
    log({'','TC_STAT_TIMING ',x.phase,' tick=',event.tick,' scheduler=',profile})
    if x.phase=='polling' then
      local machine=registry.get().ledger.machines[c.id]
      assert(machine.work>0 and machine.allocations>0)
      log('TC_STAT_CREDITS '..serpent.line{tick=event.tick,work=machine.work,allocations=machine.allocations,reads=c.state.reads})
      local p=helpers.create_profiler(); local stats=game.forces.player.get_item_production_statistics(game.surfaces[1])
      local total=0
      for i=1,300 do for _,side in ipairs({'input','output'}) do total=total+stats.get_flow_count{name='iron-plate',category=side,precision_index=defines.flow_precision_index.one_minute,sample_index=i,count=false} end end
      p.stop(); assert(total>=0); log({'','TC_STAT_NATIVE_HISTORY_TIME ',p})
    end
    return
  end
  assert(x.samples[x.phase]==120)
  for i,id in ipairs(x.neighbors) do assert(registry.record(id).state.pulses-x.before.neighbors[i]==121,'neighbor cadence changed') end
  if x.phase=='control' then
    for _,id in ipairs(x.idle) do assert(lifecycle.remove(id,'timing-control',true)) end
    population('production_statistics'); x.phase='idle'; x.phase_start=event.tick+60
  elseif x.phase=='idle' then
    runtime.save(c.id,polling,c.saved_revision); assert(runtime.activate(c.id,event.tick)); x.phase='polling'; x.phase_start=event.tick+60
  else
    assert(c.state.reads-x.before.reads==121 and registry.record(x.neighbors[1]).state.pulses>=540 and registry.record(x.neighbors[2]).state.pulses>=540)
    x.saved={reads=c.state.reads}; x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_STAT_TIMING_OK '..serpent.line(x.samples)); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
