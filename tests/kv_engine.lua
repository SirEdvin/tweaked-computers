-- Exact-engine compact contracts. Native entities/registrations/byte strings;
-- direct command tables are host contract checks, not graphical client evidence.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local lifecycle=require('scripts.lifecycle')
local peripheral=require('scripts.services.peripheral')
local kv=require('scripts.services.kv')
local example=require('examples.kv-program')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc08_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function err(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,
    'expected '..code..', got '..(type(e)=='table' and tostring(e.code) or tostring(e)))
end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local rec=assert(lifecycle.build(b))
  lifecycle.power_entity(rec).energy=defs.devices[kind].watts/30; rec.powered=true; return rec
end
local function command(rec,name,tick,...)
  return kv.methods[name](nil,rec,'red',tick,nop,...)
end
local function guest(c,body)
  local source='return {api_version=1,handlers={start=function(e) '..body..' end}}'
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local ok,diagnostic=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,diagnostic and (diagnostic.code..': '..diagnostic.message))
end
local function mine_event(rec,kind)
  -- Native temporary inventory/stack, table-backed event route. Actual robot
  -- event/transfer is independently exercised in the cold fixture below.
  local buffer=game.create_inventory(1); buffer[1].set_stack{name=defs.devices[rec.kind].name,count=1,quality=rec.body.quality}
  local old=rec.body
  lifecycle.on_removed{entity=old,buffer=buffer,tick=game.tick,name=kind}
  assert(not registry.record(rec.id)); old.destroy()
  return buffer
end
local function replace(buffer,x,y,robot)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices.kv.entity_name,position={x,y},force='player'})
  if robot then lifecycle.on_built{entity=b,stack=buffer[1]}
  else lifecycle.on_built{entity=b,consumed_items=buffer} end
  local rec=assert(registry.by_entity(b)); lifecycle.power_entity(rec).energy=1000; rec.powered=true; return rec
end
-- Forward the real engine lifecycle events in this isolated test mod's registry.
script.on_event(defines.events.on_robot_mined_entity,function(event)
  if registry.by_entity(event.entity) then lifecycle.on_removed(event); log('TC_KV_NATIVE_ROBOT_MINED') end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
  if event.entity.name==defs.devices.kv.entity_name then
    lifecycle.on_built(event)
    local rec=assert(registry.by_entity(event.entity))
    if f() and f().phase=='rebuilding' then f().real_placed=rec.id; log('TC_KV_NATIVE_ROBOT_BUILT') end
  end
end)
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
function M.run()
  registry.initialize(); storage.tc08_fixture={groups=0,phase='armed'}
  local rec=build('kv',3,0); local c=build('computer',0,0)
  c.status='running'; c.run_id=c.id..'/fixture'
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(rec,'network','red')))
  local rows={
    {'get',{'absent'},nil},{'type',{'absent'},'none'},{'ttl',{'absent'},-2},
    {'hget',{'absent','f'},nil},{'hexists',{'absent','f'},0},{'hlen',{'absent'},0},
    {'del',{'absent'},0},{'exists',{'absent'},0},{'expire',{'absent',1},0},{'persist',{'absent'},0},
    {'set',{'','\0'},'OK'},{'get',{''},'\0'},{'set',{'s',''},'OK'},{'get',{'s'},''},
    {'exists',{'s','s','no'},2},{'type',{'s'},'string'},{'ttl',{'s'},-1},
    {'hset',{'h','','a','f','b','f','\0'},2},{'hget',{'h','f'},'\0'},
    {'hget',{'h','missing'},nil},{'hexists',{'h',''},1},{'hlen',{'h'},2},
    {'hset',{'h','f','last','new','a','new','b'},1},{'hget',{'h','new'},'b'},
    {'hdel',{'h','new','new','f'},2},{'hdel',{'h',''},1},{'type',{'h'},'none'},
    {'ttl',{'h'},-2},{'del',{'s','s','no'},1}}
  for _,r in ipairs(rows) do
    local result=table.pack(command(rec,r[1],0,table.unpack(r[2])))
    assert(result.n==1 and result[1]==r[3],'contract mismatch '..r[1])
  end
  assert(next(command(rec,'hgetall',0,'none'))==nil)
  report('all-command-types-nil-arity-empty-nul-and-distinct-duplicate-counts')
  for name,args in pairs({get={'',1},set={'key',false},del={},exists={},hset={'h','f'},hdel={'h'},hgetall={},getLimits={1}}) do
    local old=rec.database; err('E_ARGUMENT',function() command(rec,name,0,table.unpack(args)) end); assert(rec.database==old)
  end
  for _,v in ipairs({123,true,{},function() end}) do err('E_ARGUMENT',function() command(rec,'set',0,'x',v) end) end
  err('E_LIMIT',function() command(rec,'get',0,string.rep('x',257)) end)
  command(rec,'set',0,'s','v'); command(rec,'hset',0,'h','f','v')
  for name,args in pairs({get={'h'},hget={'s','f'},hset={'s','f','v'},hdel={'s','f'},hexists={'s','f'},hgetall={'s'},hlen={'s'}}) do
    local old=rec.database; err('E_WRONGTYPE',function() command(rec,name,0,table.unpack(args)) end); assert(rec.database==old)
  end
  report('arity-nonstrings-limits-and-all-wrongtype-refusals-preserve-aliases')
  assert(command(rec,'expire',10,'h',2)==1)
  assert(command(rec,'ttl',40,'h')==2 and command(rec,'ttl',41,'h')==1)
  command(rec,'hset',50,'h','f','v2'); assert(command(rec,'ttl',50,'h')==1)
  command(rec,'hdel',50,'h','missing'); assert(rec.database.entries.h.deadline==130)
  assert(command(rec,'ttl',101,'h')==0 and command(rec,'get',130,'h')==nil)
  assert(command(rec,'hgetall',130,'h') and command(rec,'type',130,'h')=='none')
  command(rec,'hset',130,'h','fresh','v'); assert(command(rec,'ttl',130,'h')==-1)
  command(rec,'expire',130,'h',1); command(rec,'set',131,'h','replaced'); assert(command(rec,'ttl',132,'h')==-1)
  assert(command(rec,'expire',132,'h',0)==1 and command(rec,'type',132,'h')=='none')
  command(rec,'set',132,'h','v'); assert(command(rec,'expire',132,'h',-1)==1)
  command(rec,'set',132,'h','v'); command(rec,'expire',132,'h',1)
  assert(command(rec,'persist',133,'h')==1 and command(rec,'persist',133,'h')==0 and command(rec,'get',200,'h')=='v')
  err('E_RANGE',function() command(rec,'expire',0,'missing',1.5) end)
  err('E_RANGE',function() command(rec,'expire',9007199254740990,'missing',1) end)
  report('absolute-boundary-half-second-rounding-replacement-persist-and-safe-arithmetic')
  rec.database=kv.import{version=1,entries={}}
  command(rec,'hset',0,'a','f','old'); command(rec,'expire',0,'a',20)
  local old=rec.database
  err('E_CAPACITY',function() command(rec,'hset',0,'a','f',string.rep('x',8192),'g',string.rep('x',8192)) end)
  assert(rec.database==old and command(rec,'hget',0,'a','f')=='old' and old.entries.a.deadline==1200)
  err('E_BUSY',function() kv.methods.hset(nil,rec,'red',0,function() error({code='E_BUSY'},0) end,'a','f','new') end)
  assert(rec.database==old)
  local read=command(rec,'hgetall',0,'a'); read.f='bad'; assert(command(rec,'hget',0,'a','f')=='old')
  rec.database=kv.import{version=1,entries={}}
  command(rec,'set',0,'',string.rep('x',8192)); command(rec,'set',0,'k',string.rep('y',8191))
  assert(rec.database.bytes==16384)
  old=rec.database; err('E_CAPACITY',function() command(rec,'set',0,'new','x') end); assert(rec.database==old)
  command(rec,'expire',0,'',1); command(rec,'expire',0,'k',1)
  assert(command(rec,'get',60,'')==nil and #rec.database.order==2)
  command(rec,'set',60,'new','x'); assert(#rec.database.order==1 and rec.database.bytes==4)
  report('atomic-capacity-work-refusal-defensive-hash-and-expired-unreclaimed-capacity')
  rec.database=kv.import{version=1,entries={}}
  for i=1,128 do command(rec,'set',0,tostring(i),''); command(rec,'expire',0,tostring(i),1) end
  old=rec.database; err('E_CAPACITY',function() command(rec,'set',0,'129','') end); assert(rec.database==old)
  kv.reclaim(rec,60,nop); assert(#rec.database.order==0 and command(rec,'exists',60,'100')==0)
  while #rec.database.order>0 do kv.reclaim(rec,60,nop) end
  assert(rec.database.bytes==0 and rec.database.fields==0)
  for _,k in ipairs({'a','b'}) do for i=1,128 do command(rec,'hset',0,k,tostring(i),'') end end
  old=rec.database; err('E_CAPACITY',function() command(rec,'hset',0,'c','field','') end); assert(rec.database==old)
  err('E_CAPACITY',function() command(rec,'hset',0,'a','extra','') end)
  report('key-and-field-capacity-and-work-driven-reclamation')
  local snap=kv.snapshot(rec,0); local restored=kv.import(snap)
  assert(restored.bytes==rec.database.bytes and restored.fields==256)
  snap.entries[1].fields[1].value='mutated'; assert(command(rec,'hget',0,'a','1')=='')
  for _,bad in ipairs({{version=2,entries={}}, {version=1,entries={[2]={key='a',type='string',value='a'}}},
    {version=1,entries={{key='a',type='string',value='a'},{key='a',type='string',value='b'}}},
    {version=1,entries={{key='a',type='hash',fields={{field='f',value='v'},{field='f',value='w'}}}}},
    {version=1,entries={{key='a',type='string',value=function() end}}}}) do
    assert(not pcall(kv.import,bad)); assert(rec.database==old)
  end
  local cyclic={version=1}; cyclic.entries={cyclic}; assert(not pcall(kv.import,cyclic))
  local saved_header=rec.database; rec.database={version=99,recovery='retained'}
  kv.initialize(rec); assert(not rec.body.minable and rec.database.recovery=='retained')
  err('E_UNSUPPORTED',function() command(rec,'get',0,'x') end)
  rec.database=saved_header; kv.initialize(rec)
  local invalid=game.create_inventory(1); invalid[1].set_stack{name='tc-kv',count=1}
  invalid[1].tags={tc_kv={version=99,entries={}}}
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.kv.entity_name,position={20,0},force='player'})
  local robot=assert(game.surfaces[1].create_entity{name='construction-robot',position={20,3},force='player'})
  lifecycle.on_built{entity=body,stack=invalid[1],robot=robot}
  assert(not body.valid and invalid[1].tags.tc_kv.version==99)
  local cargo=robot.get_inventory(defines.inventory.robot_cargo)
  assert(cargo[1].valid_for_read and cargo[1].tags.tc_kv.version==99,'invalid snapshot refund lost tags')
  robot.destroy(); invalid.destroy()
  report('snapshot-copy-reserved-metadata-and-malformed-duplicate-cycle-function-refusal')
  -- Full accepted content across many entries maximizes meaningful metadata.
  rec.database=kv.import{version=1,entries={}}
  for i=1,128 do local k=tostring(i); command(rec,'set',game.tick,k,string.rep('\0',128-#k)) end
  assert(rec.database.bytes==16384)
  command(rec,'expire',game.tick,'1',2)
  local mined=mine_event(rec,defines.events.on_player_mined_entity)
  assert(mined[1].tags.tc_kv and #mined[1].tags.tc_kv.entries==128)
  local nextrec=replace(mined,3,0,false); assert(nextrec.id~=rec.id and nextrec.database.bytes==16384)
  assert(nextrec.database.entries['1'].deadline==120 and command(nextrec,'get',120,'1')==nil)
  local robotbuffer=mine_event(nextrec,defines.events.on_robot_mined_entity)
  rec=replace(robotbuffer,3,0,true); assert(rec.database.bytes==16384)
  local identity=rec.database
  lifecycle.on_built{entity=rec.body,stack=robotbuffer[1]}; assert(rec.database==identity)
  mined.destroy(); robotbuffer.destroy()
  report('maximum-content-item-tag-player-robot-event-routes-and-carried-expiry')
  local second=build('kv',6,0); assert(command(second,'get',0,'1')==nil)
  -- Native cloning inside on_init suppresses raised events; exercise the fixed
  -- table-backed route here, and a genuine on_tick clone event below.
  local clone=assert(rec.body.clone{position={9,0},surface=rec.body.surface,force=rec.body.force})
  if not registry.by_entity(clone) then lifecycle.on_cloned{source=rec.body,destination=clone} end
  local cloned=assert(registry.by_entity(clone)); assert(#cloned.database.order==0 and cloned.id~=rec.id)
  local blueprint=build('kv',12,0)
  lifecycle.on_built{entity=blueprint.body,tags={tc_kv=kv.snapshot(rec,0)}}
  assert(#blueprint.database.order==0)
  report('native-clone-identity-empty-data-and-blueprint-tags-never-copy-contents')
  -- Isolate real facade tests from the maximum snapshot content.
  rec.database=kv.import{version=1,entries={}}
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(rec,'network','red')))
  guest(c,[[local d=peripheral.find('kv_database','red'); assert(d)
    assert(d.set('guest','value')=='OK' and d.get('guest')=='value')
    assert(select('#',d.get('missing'))==1)
    local zero=string.char(0); assert(d.set(zero,zero)=='OK' and d.get(zero)==zero)
    d.hset('binary',zero,''); local binary=d.hgetall('binary'); assert(binary[zero]=='')
    assert(d.hset('h','f','v','f','last')==1 and d.hget('h','f')=='last')
    local h=d.hgetall('h'); h.f='changed'; assert(d.hget('h','f')=='last')
    local ok,e=pcall(d.set,'bad',{}); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(d.hset,'guest','f','v'); assert(not ok and e.code=='E_WRONGTYPE')
    local limit=d.getLimits(); assert(limit.bytes==16384); limit.bytes=1; assert(d.getLimits().bytes==16384)]])
  rec.database=kv.import{version=1,entries={}}
  command(rec,'hset',0,'max','',''..string.rep('x',8192))
  guest(c,[[local d=peripheral.find('kv_database','red'); local h=d.hgetall('max'); assert(string.len(h[''])==8192)]])
  local maximum=rec.database
  err('E_CAPACITY',function() command(rec,'hset',0,'max','another','') end); assert(rec.database==maximum)
  command(rec,'set',0,'guest','value')
  -- Two authorized computers observe the same database; distinct physical KV stays empty.
  local c2=build('computer',0,-3); c2.status='running'; c2.run_id=c2.id..'/fixture'
  assert(lifecycle.connector(c2,'network','red').connect_to(lifecycle.connector(rec,'network','red')))
  guest(c2,[[local d=peripheral.find('kv_database','red'); assert(d.get('guest')=='value'); d.set('guest','second')]])
  guest(c,[[local d=peripheral.find('kv_database','red'); assert(d.get('guest')=='second')]])
  rec.powered=false; lifecycle.power_entity(rec).energy=0
  guest(c,[[local d=peripheral.find('kv_database','red'); assert(d.getLimits().keys==128)
    local ok,e=pcall(d.get,'guest'); assert(not ok and e.code=='E_UNPOWERED')]])
  command(rec,'expire',0,'guest',1); assert(command(rec,'get',60,'guest')==nil)
  report('compiled-native-facades-sharing-malicious-values-static-limits-and-unpowered-expiry')
  rec.powered=true; lifecycle.power_entity(rec).energy=1000
  runtime.save(c.id,example,c.saved_revision); assert(runtime.activate(c.id,game.tick))
  assert(scheduler.dispatch(c,game.tick)); assert(c.status=='running',c.diagnostic and c.diagnostic.message)
  assert(command(rec,'hget',game.tick,'machine','owner')==c.id)
  assert(command(rec,'ttl',game.tick,'machine')==30 and next(c.timers))
  report('packaged-native-example-real-save-activation-and-scheduler-effects')
  for _,r in ipairs({c,c2,second,cloned,blueprint}) do lifecycle.remove(r.id,'fixture-cleanup',true) end
  -- Actual native construction robot mines a maximum accepted database.
  rec.database=kv.import{version=1,entries={}}
  for i=1,128 do local k=tostring(i); command(rec,'set',game.tick,k,string.rep('\0',128-#k)) end
  command(rec,'expire',game.tick,'1',5)
  local surface=game.surfaces[1]
  local roboport=assert(surface.create_entity{name='roboport',position={0,5},force='player'})
  roboport.energy=100000000; roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=1}
  local chest=assert(surface.create_entity{name='storage-chest',position={5,5},force='player'})
  local pole=assert(surface.create_entity{name='substation',position={0,10},force='player'})
  local power=assert(surface.create_entity{name='electric-energy-interface',position={-3,10},force='player'})
  power.power_production=10000000; power.power_usage=0
  f().roboport=roboport; f().chest=chest; f().rec=rec.id; f().deadline=rec.database.entries['1'].deadline
  f().started_tick=game.tick
  assert(rec.body.order_deconstruction('player'))
  report('actual-native-robot-mining-armed')
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function unchanged()
  local s=f().saved
  assert(f().carried[1].tags.tc_kv.entries[1].deadline==s.deadline)
  assert(f().carried[1].tags.tc_kv.entries[1].value==s.value)
  assert(registry.get().scheduler.maintenance_spent==s.maintenance)
  assert(f().restored.database==s.alias and f().restored.id==s.identity)
  assert(#f().restored.database.order==128 and f().restored.database.bytes==16384)
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  if f().phase=='done' then return end
  if f().phase=='frozen' then
    if not loaded then return end
    unchanged()
    -- Kept in a genuine native item through the cold save. Restore only after
    -- the absolute deadline; never grant a renewed duration while carried.
    if event.tick<f().deadline then return end
    loaded=false
    assert(not f().restored.powered and command(f().restored,'get',event.tick,'1')==nil)
    assert(f().chest.get_inventory(defines.inventory.chest).insert(f().carried[1])==1)
    f().carried[1].clear(); f().roboport.active=true; f().roboport.energy=100000000
    f().phase='rebuilding'; f().rebuild_tick=event.tick
    assert(game.surfaces[1].create_entity{name='entity-ghost',inner_name=defs.devices.kv.entity_name,position={3,0},force='player'})
    return
  elseif f().phase=='rebuilding' then
    assert(event.tick-f().rebuild_tick<1200,'native robot rebuild deadline exceeded')
    if not f().real_placed then return end
    local restored=assert(registry.record(f().real_placed))
    assert(restored.id~=f().rec and restored.database.entries['1'].deadline==f().deadline)
    assert(command(restored,'get',event.tick,'1')==nil and command(restored,'ttl',event.tick,'1')==-2)
    assert(command(restored,'get',event.tick,'2')==string.rep('\0',127))
    while restored.database.entries['1'] do kv.reclaim(restored,event.tick,nop) end
    assert(restored.database.bytes==16256)
    f().phase='done'; log('TC_COLD_OK'); return
  end
  loaded=false
  if not f().clone_checked then
    local source=assert(registry.record(f().rec))
    local clone=assert(source.body.clone{position={9,0},surface=source.body.surface,force=source.body.force})
    local rec=assert(registry.by_entity(clone),'native on_tick clone event was not forwarded')
    assert(#rec.database.order==0 and rec.id~=source.id)
    lifecycle.remove(rec.id,'fixture-cleanup',true); f().clone_checked=true
    log('TC_KV_NATIVE_CLONE_OK')
  end
  assert(event.tick-f().started_tick<1200,'native robot mining deadline exceeded')
  local inventory=f().chest.get_inventory(defines.inventory.chest)
  local stack
  for i=1,#inventory do if inventory[i].valid_for_read and inventory[i].name=='tc-kv' then stack=inventory[i]; break end end
  if not stack then return end
  assert(not registry.record(f().rec),'actual robot removal was not forwarded')
  assert(stack.tags.tc_kv and #stack.tags.tc_kv.entries==128,'native robot lost snapshot')
  local carried=game.create_inventory(1); carried[1].set_stack(stack); stack.clear()
  f().carried=carried
  -- Validate another ordinary save/load alias while the genuine mined item is carried.
  local restored=build('kv',12,0)
  kv.restore(restored,carried[1].tags.tc_kv)
  lifecycle.power_entity(restored).energy=0; restored.powered=false; restored.body.active=false
  f().restored=restored
  local spend=scheduler.maintenance(registry.get(),event.tick); spend(77)
  f().saved={deadline=f().deadline,value=carried[1].tags.tc_kv.entries[1].value,
    alias=restored.database,identity=restored.id,maintenance=registry.get().scheduler.maintenance_spent}
  f().phase='frozen'; f().roboport.active=false; f().chest.active=false
  log('TC_KV_NATIVE_ROBOT_TRANSFER_OK'); game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
