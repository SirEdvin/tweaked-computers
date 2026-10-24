-- Real scheduled broadcast; inject one private pause after four deliveries.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local radar=require('scripts.radar')
require('scripts.services.modem')
local M={}; local loaded=false
local function state() return storage.modem_broadcast_fixture end
local function job(c)
  local pending=c.invocation and c.invocation.checkpoint.frame.pending
  return pending and pending.jobs and pending.jobs['modem-transmit']
end
runtime.register_services('modem-broadcast-fixture',function(rec,tick,g)
  local s=state()
  if s and rec.id==s.sender then
    local spend=g.spend
    g.spend=function(n)
      local current=job(rec)
      if s.pause and current and current.phase=='deliver' and current.cursor==5 then
        s.pause=false; g.suspend()
      end
      return spend(n)
    end
  end
  return {}
end)
local sender=[[
function start() computer.setState('starts',(computer.getState('starts') or 0)+1) end
function send()
  local m=assert(peripheral.find('modem','red'))
  assert(select('#',m.transmit(42,9007199254740991,{blob=string.rep('x',4097)}))==0)
  computer.setState('sent',(computer.getState('sent') or 0)+1)
end]]
local receiver=[[
function start()
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  local m=assert(peripheral.find('modem','red')); m.open(42)
  for i=1,4 do computer.on('modem_message','receive') end
  computer.setState('ready',true)
end
function receive(e)
  assert(e.name=='modem_message' and e.channel==42 and e.replyChannel==9007199254740991)
  assert(e.wire=='red' and #e.wires==2 and e.wires[1]=='red' and e.wires[2]=='green')
  assert(#e.message.blob==4097 and e.distance>0 and e.sent_tick<=computer.getTick())
  local count=computer.getState('count') or 0
  assert(count<8,'broadcast delivery was repeated')
  computer.setState('count',count+1); e.message.blob='private mutation'
end]]
local function record(id) return assert(registry.record(id)) end
local function power(rec) lifecycle.power_entity(rec).energy=1000000; rec.powered=true end
local function pair(x,source)
  local surface=game.surfaces[1]
  local c=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.computer.entity_name,position={x,0},force='player'})))
  local r=assert(radar.build(assert(surface.create_entity{name='radar',position={x+6,0},force='player'})))
  for _,color in ipairs({'red','green'}) do
    assert(lifecycle.connector(c,'network',color).connect_to(r.body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true),false))
  end
  power(c); power(r)
  assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
  return c,r
end
function M.run()
  registry.initialize()
  local c,r=pair(0,sender)
  local s={phase='starting',sender=c.id,radar=r.id,receivers={},pause=false}; storage.modem_broadcast_fixture=s
  for i=1,3 do local rc,rr=pair(i*100,receiver); s.receivers[i]={computer=rc.id,radar=rr.id} end
end
function M.on_load() if state() and state().phase=='frozen' then loaded=true end end
function M.on_tick(event)
  local s=state(); if not s or s.phase=='done' then return end
  local c=record(s.sender)
  if s.phase=='frozen' then
    if not loaded then return end
    loaded=false
    local current=assert(job(c)); assert(current.cursor==5 and #current.plan==12 and c.run_id==s.run_id)
    assert(c.state.starts==1)
    for i=1,4 do assert(current.plan[i].item.event.sequence==s.prefix[i]) end
    s.unavailable=current.plan[5].receiver; s.dropped_computer=current.plan[5].computer
    s.phase='sending'; s.reloaded=true
    log('TC_CONTRACT cold-real-guard-broadcast-prefix-and-paid-plan')
  end
  assert(event.tick<1800,'broadcast timed out: '..serpent.line(c.diagnostic or c.resource_refusal))
  for _,id in ipairs(registry.get().order) do
    local rec=record(id)
    if id==s.unavailable then lifecycle.power_entity(rec).energy=0; rec.powered=false else power(rec) end
  end
  scheduler.tick(event.tick)
  for _,id in ipairs(registry.get().order) do
    local rec=record(id)
    if rec.kind=='computer' then assert(rec.status~='faulted' and not rec.diagnostic and not rec.resource_refusal,serpent.line(rec.diagnostic or rec.resource_refusal)) end
  end
  if s.phase=='starting' then
    for _,target in ipairs(s.receivers) do if not record(target.computer).state.ready or record(target.computer).invocation then return end end
    if c.invocation or c.start_pending then return end
    assert(runtime.enqueue(c,'send',{name='send'},event.tick)); s.phase='priming'
  elseif s.phase=='priming' then
    if c.invocation or c.state.sent~=1 then return end
    for _,target in ipairs(s.receivers) do
      local rec=record(target.computer)
      if rec.invocation or #rec.queue>0 or rec.state.count~=4 then return end
      assert(not rec.dropped_events or rec.dropped_events.total==0)
    end
    log('TC_CONTRACT native-twelve-independent-large-payload-deliveries-once')
    s.pause=true; assert(runtime.enqueue(c,'send',{name='send'},event.tick)); s.phase='sending'
  elseif s.phase=='sending' then
    local current=job(c)
    if not s.reloaded and not s.pause and current and current.phase=='deliver' and current.cursor==5 then
      assert(#current.plan==12 and c.state.sent==1)
      s.prefix={}; for i=1,4 do s.prefix[i]=assert(current.plan[i].item.event.sequence) end
      for i=5,12 do assert(current.plan[i].item.event.sequence==nil) end
      s.run_id=c.run_id; s.phase='frozen'
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
    if c.invocation or c.state.sent~=2 then return end
    assert(s.reloaded,'broadcast never reached its cold prefix boundary')
    assert(c.state.starts==1)
    for _,target in ipairs(s.receivers) do
      local rec=record(target.computer)
      local unavailable=rec.id==s.dropped_computer
      assert(rec.state.starts==1)
      if rec.invocation or #rec.queue>0 or rec.state.count~=(unavailable and 4 or 8) then return end
      if unavailable then
        assert(rec.dropped_events and rec.dropped_events.total==4 and rec.dropped_events.last_kind=='modem_message'
          and rec.dropped_events.last_reason=='modem_destination_unavailable','unavailable prepared deliveries must be counted once')
      else assert(not rec.dropped_events or rec.dropped_events.total==0) end
    end
    runtime.stop(c.id)
    for _,target in ipairs(s.receivers) do runtime.stop(target.computer) end
    s.phase='done'; log('TC_CONTRACT native-twelve-planned-deliveries-eight-once-four-observable-unavailable')
    log('TC_COLD_OK')
  end
end
return M
