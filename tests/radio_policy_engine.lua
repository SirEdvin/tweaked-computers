-- Actual native endpoints/queues and cold storage, with an explicit guard double.
-- VM job admission/cancellation and client audibility remain integration gates.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local radar=require('scripts.radar')
local modem=require('scripts.services.modem')
local speaker=require('scripts.services.speaker')
local carrier=require('scripts.speaker')
local peripheral=require('scripts.services.peripheral')
local audio=require('scripts.speaker-audio')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local memory=require('scripts.runtime.memory')
local harness=require('tests.radio_test_guard')
local catalogue_contract=require('tests.speaker_catalogue_contract')
local M={}; local resumed=false
local function nop() end
local function f() return storage.radio_policy end
local function record(id) return assert(registry.record(id)) end
local function failure(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
end
local function build(kind,x,surface,force)
  surface=surface or game.surfaces[1]
  local name=kind=='radar' and 'radar' or kind=='advanced' and 'tc-interplanetary-radar'
    or kind=='speaker' and 'programmable-speaker' or defs.devices[kind].entity_name
  local body=assert(surface.create_entity{name=name,position={x,0},force=force or 'player'})
  local rec
  if kind=='radar' or kind=='advanced' then rec=assert(radar.build(body))
  elseif kind=='speaker' then rec=assert(carrier.build(body))
  else lifecycle.on_built{entity=body}; rec=assert(registry.by_entity(body)) end
  lifecycle.power_entity(rec).energy=1000000; rec.powered=true
  if kind=='computer' then
    rec.run_id=rec.id..'/fixture'; rec.status='running'
    rec.active={source='function receive(e) end',revision=0,api_version=1,
      compiler_version=limits.compiler_version,storage_version=limits.storage_version,handlers={receive=true}}
  end
  return rec
end
local function connector(r,color)
  return r.native_carrier and r.body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true)
    or lifecycle.connector(r,'network',color)
end
local function connect(a,b,color)
  local ca,cb=connector(a,color),connector(b,color)
  if not ca.is_connected_to(cb) then assert(ca.connect_to(cb,false)) end
end
local function call(c,r,method,...) return harness.call(modem,c,r,method,...) end
local function clear(rec) rec.queue={}; rec.queue_bytes=0 end
local function subscribe(c,n)
  for _=1,n do runtime.subscribe(c,'modem_message','receive',nil,nop) end
end
local function power()
  for _,id in ipairs(registry.get().order) do
    local r=registry.record(id)
    if r and r.body.valid then lifecycle.power_entity(r).energy=1000000; r.powered=true end
  end
end
local function audio_double(state,fail)
  local authority,available=peripheral.authority,carrier.available
  local sink={id='fixture-speaker',body={position={x=0,y=0},surface={play_sound=function()
    f().submissions=f().submissions+1
    if fail then error('injected native dispatch failure') end
  end}}}
  peripheral.authority=function() return sink end; carrier.available=function() return true end
  local guard=harness.new(state)
  local ok,value=pcall(speaker.methods.playSound,{},sink,'red',game.tick,guard.spend,guard,'utility/wire_connect_pole',0)
  peripheral.authority,carrier.available=authority,available
  return ok,value
end
function M.run()
  registry.initialize(); storage.radio_policy={phase='armed',receivers={},submissions=0}
  local c,r=build('computer',0),build('radar',6); connect(c,r,'red'); connect(c,r,'green')
  f().computer=c.id; f().radar=r.id
  for ch=0,129 do call(c,r,'open',ch) end
  call(c,r,'open',65536); call(c,r,'open',9007199254740991)
  assert(r.modem.count==132 and call(c,r,'isOpen',65536) and call(c,r,'isOpen',9007199254740991))
  for _,v in ipairs({-1,0.5,9007199254740992,math.huge}) do failure('E_RANGE',function() call(c,r,'open',v) end) end
  local s=storage.radio_test_channels; local used=s.account.used; memory.configure(s.account,used)
  failure('E_CAPACITY',function() call(c,r,'open',555555) end)
  assert(not r.modem.channels[555555] and r.modem.count==132)
  call(c,r,'close',65536); assert(s.account.used<used)
  memory.configure(s.account,16*1024*1024)
  log('TC_CONTRACT safe-integer-channels-shared-lifetime-capacity-and-reduction')
  for i=1,3 do
    local rc,rr=build('computer',100*i),build('radar',100*i+6)
    connect(rc,rr,'red'); connect(rc,rr,'green'); subscribe(rc,4); call(rc,rr,'open',42)
    f().receivers[#f().receivers+1]={computer=rc.id,radar=rr.id}
  end
  call(c,r,'transmit',42,65536,{payload=string.rep('x',4097)})
  for _,pair in ipairs(f().receivers) do
    local rc=record(pair.computer); assert(#rc.queue==4 and #rc.queue[1].event.wires==2)
    assert(#rc.queue[1].event.message.payload==4097)
    rc.queue[1].event.message.payload='changed'; assert(#rc.queue[2].event.message.payload==4097)
    clear(rc)
  end
  for _=1,17 do call(c,r,'transmit',777,42,nil) end
  local full=record(f().receivers[2].computer)
  for _=1,limits.event_queue_entries do assert(runtime.enqueue(full,'receive',{name='modem_message'},game.tick)) end
  local first=full.queue[1]; call(c,r,'transmit',42,17,false)
  assert(#full.queue==limits.event_queue_entries and full.queue[1]==first and full.dropped_events.total==4)
  for _,pair in ipairs(f().receivers) do clear(record(pair.computer)) end
  log('TC_CONTRACT twelve-deliveries-large-payload-no-rate-ceiling-and-drop-newest')
  local staged={}
  local guard=harness.new(staged,function(state) return state.job and state.job.phase=='deliver' end)
  local ok,e=pcall(modem.methods.transmit,c,r,'red',game.tick,guard.spend,guard,42,17,'live-authority')
  assert(not ok and e.radio_suspend and #staged.job.plan==12)
  local detached,changed=f().receivers[2],f().receivers[3]
  for _,wire in ipairs({'red','green'}) do
    connector(record(detached.computer),wire).disconnect_from(connector(record(detached.radar),wire))
  end
  record(changed.radar).body.force=game.forces.enemy
  guard=harness.new(staged)
  modem.methods.transmit(c,r,'red',game.tick,guard.spend,guard,42,17,'live-authority'); guard.finish()
  assert(#record(f().receivers[1].computer).queue==4)
  assert(#record(detached.computer).queue==0 and #record(changed.computer).queue==0)
  record(changed.radar).body.force=game.forces.player
  for _,pair in ipairs({detached,changed}) do
    for _,wire in ipairs({'red','green'}) do connect(record(pair.computer),record(pair.radar),wire) end
  end
  for _,pair in ipairs(f().receivers) do clear(record(pair.computer)) end
  staged={}; guard=harness.new(staged,function(state)
    return state.job and state.job.phase=='deliver' and state.job.cursor==5
  end)
  ok,e=pcall(modem.methods.transmit,c,r,'red',game.tick,guard.spend,guard,42,17,'sender-detach')
  assert(not ok and e.radio_suspend and staged.job.cursor==5)
  connector(c,'red').disconnect_from(connector(r,'red'))
  guard=harness.new(staged)
  modem.methods.transmit(c,r,'red',game.tick,guard.spend,guard,42,17,'sender-detach')
  assert(staged.job.cursor==13); guard.finish(); connect(c,r,'red')
  local prefix=0
  for _,pair in ipairs(f().receivers) do prefix=prefix+#record(pair.computer).queue; clear(record(pair.computer)) end
  assert(prefix==4)
  log('TC_CONTRACT live-wire-force-and-sender-authority-rechecked-without-prefix-retry')
  local foreign=game.create_force('radio-policy-foreign')
  local fc,fr=build('computer',400,nil,foreign),build('radar',406,nil,foreign)
  connect(fc,fr,'red'); subscribe(fc,1); call(fc,fr,'open',42)
  local other=game.create_surface('radio-policy-other',{width=64,height=64})
  local oc,orr=build('computer',0,other),build('radar',6,other)
  connect(oc,orr,'red'); subscribe(oc,1); call(oc,orr,'open',42)
  call(c,r,'transmit',42,0,'scope'); assert(#fc.queue==0 and #oc.queue==0)
  for _,pair in ipairs(f().receivers) do clear(record(pair.computer)) end
  if script.active_mods['space-age'] then
    local ac,ar=build('computer',500),build('advanced',506)
    local bc,br=build('computer',20,other),build('advanced',26,other)
    connect(ac,ar,'red'); connect(bc,br,'red'); subscribe(bc,1); call(bc,br,'open',77)
    call(ac,ar,'transmit',77,0,'cross'); assert(#bc.queue==1 and bc.queue[1].event.distance==nil)
    clear(bc); call(c,r,'transmit',77,0,'mixed'); assert(#bc.queue==0)
  end
  log('TC_CONTRACT native-force-surface-and-advanced-tier-restrictions')
  local sound=build('speaker',12); connect(c,sound,'red')
  assert(#audio.index(nop)==65 and #audio.instrument('tc-fixture-large-notes',nop)==129)
  assert(harness.call(speaker,c,sound,'playNote','tc-fixture-large-notes',0,128))
  assert(harness.call(speaker,c,sound,'playNote',string.rep('long-native-name-',20),0,0))
  assert(harness.call(speaker,c,sound,'playSound','utility/wire_connect_pole',0)==true)
  f().audio={}; assert(audio_double(f().audio)); assert(f().submissions==1)
  assert(audio_double(f().audio)); assert(f().submissions==1)
  local bad={}; local ok,e=audio_double(bad,true); assert(not ok and e.code=='E_ENGINE')
  ok,e=audio_double(bad,true); assert(not ok and e.code=='E_ENGINE' and f().submissions==2)
  local blocked={}; local guard=harness.new(blocked,function(state) return state.job_name=='speaker-submit' end)
  ok,e=pcall(speaker.methods.playSound,c,sound,'red',game.tick,guard.spend,guard,'utility/wire_connect_pole',0)
  assert(not ok and e.radio_suspend and blocked.job and not blocked.job.attempted)
  guard=harness.new(blocked)
  assert(speaker.methods.playSound(c,sound,'red',game.tick,guard.spend,guard,'utility/wire_connect_pole',0))
  assert(blocked.job.attempted and not blocked.job.failed); guard.finish()
  for _=1,65 do assert(harness.call(speaker,c,sound,'playNote','piano',0,0)) end
  catalogue_contract.run()
  log('TC_CONTRACT native-audio-no-count-ceiling-before-effect-wait-and-no-failure-retry')
  f().broadcast={}
end
function M.on_load() resumed=f() and f().phase=='frozen' end
function M.on_tick()
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' and not resumed then return end
  power()
  local c,r=record(x.computer),record(x.radar)
  if x.phase=='armed' then
    local guard=harness.new(x.broadcast,function(state)
      return state.job and state.job.phase=='deliver' and state.job.cursor==5
    end)
    local ok,e=pcall(modem.methods.transmit,c,r,'red',game.tick,guard.spend,guard,42,17,'cold-once')
    assert(not ok and e.radio_suspend and x.broadcast.job.cursor==5,serpent.line(e))
    local count=0; for _,pair in ipairs(x.receivers) do count=count+#record(pair.computer).queue end
    assert(count==4)
    x.prefix={}; for i=1,4 do x.prefix[i]=x.broadcast.job.plan[i].item.event.sequence end
    x.sounds={}
    local sound_guard=harness.new(x.sounds,function(state)
      return state.job and state.job.offset and state.job.offset==10
    end)
    ok,e=pcall(audio.sounds,'utility/','',sound_guard.spend,sound_guard)
    assert(not ok and e.radio_suspend)
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(resumed and x.phase=='frozen'); resumed=false
  assert(x.broadcast.job.cursor==5)
  local unavailable=record(x.broadcast.job.plan[5].receiver); unavailable.body.energy=0; unavailable.powered=false
  local guard=harness.new(x.broadcast)
  modem.methods.transmit(c,r,'red',game.tick,guard.spend,guard,42,17,'cold-once')
  assert(x.broadcast.job.cursor==13)
  for i=1,4 do assert(x.broadcast.job.plan[i].item.event.sequence==x.prefix[i]) end
  local count=0; local seen={}
  for _,pair in ipairs(x.receivers) do
    for _,item in ipairs(record(pair.computer).queue) do
      count=count+1; assert(not seen[item.event.sequence]); seen[item.event.sequence]=true
      assert(item.event.message=='cold-once')
    end
  end
  assert(count==8)
  local sound_guard=harness.new(x.sounds)
  local page=audio.sounds('utility/','',sound_guard.spend,sound_guard)
  local expected=audio.sounds('utility/','',nop)
  assert(#page.sounds==#expected.sounds and page.next==expected.next)
  for i,path in ipairs(expected.sounds) do assert(page.sounds[i]==path) end
  sound_guard.finish()
  assert(audio_double(x.audio) and x.submissions==2)
  local before=x.broadcast.account.used; guard.finish(); assert(x.broadcast.account.used<before)
  x.phase='done'; log('TC_COLD_OK')
end
return M
