-- Native settings and material transport; direct commands are host contracts.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local snapshots=require('scripts.lifecycle-data')
local blueprints=require('scripts.blueprints')
local kv=require('scripts.services.kv')
local budgets=require('scripts.runtime.budget-settings')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local M={}
local loaded=false
local function nop() end
local function f() return storage.tc_kv_policy end
local function command(rec,name,...)
  return kv.methods[name](nil,rec,'red',game.tick,nop,...)
end
local function change(key,value)
  local name='tc-'..key:gsub('_','-')
  settings.global[name]={value=value}; budgets.refresh()
  assert(settings.global[name].value==value and limits[key]==value)
end
local function defaults()
  for _,definition in ipairs(budgets.definitions) do
    if definition.key:sub(1,3)=='kv_' or definition.key=='state_bytes' then change(definition.key,definition.default_value) end
  end
end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  return assert(lifecycle.build(body))
end
local function refusal(rec,key,fn)
  local before=rec.database
  local ok,e=pcall(fn)
  assert(not ok and type(e)=='table' and e.setting=='tc-kv-'..key:gsub('_','-')
    and e.resource=='kv_'..key and e.recoverable and e.requested>0,
    'expected '..key..' refusal: '..serpent.line(e))
  assert(before==rec.database,'refusal published candidate')
end
local function reset(rec) rec.database=kv.import{version=1,entries={}}; defaults() end
local function policy_contracts(rec)
  for _,case in ipairs({
    {'keys',1,{'set','a',''}, {'set','b',''}},
    {'bytes',2,{'set','a','x'}, {'set','a','xx'}},
    {'key_bytes',1,nil, {'set','aa',''}},
    {'value_bytes',1,nil, {'set','a','xx'}},
    {'hash_fields',1,{'hset','h','a',''}, {'hset','h','b',''}},
    {'hash_bytes',2,{'hset','h','a','x'}, {'hset','h','a','xx'}},
    {'total_hash_fields',1,{'hset','h','a',''}, {'hset','g','b',''}},
    {'command_arguments',2,nil, {'hset','h','a',''}},
    {'command_bytes',2,nil, {'set','a','xx'}},
    {'snapshot_bytes',209,{'set','a',''}, {'set','a','x'}}
  }) do
    reset(rec); change('kv_'..case[1],case[2])
    local q=command(rec,'getLimits')
    assert(q[case[1]]==case[2] and q.resources['kv_'..case[1]].limit==case[2] and q.policy_version==2)
    q.resources['kv_'..case[1]].limit=0; assert(command(rec,'getLimits')[case[1]]==case[2])
    if case[3] then command(rec,table.unpack(case[3])) end
    refusal(rec,case[1],function() command(rec,table.unpack(case[4])) end)
    change('kv_'..case[1],case[2]+100)
    command(rec,table.unpack(case[4]))
  end
  log('TC_CONTRACT all-ten-native-KV-settings-effective-refusal-raise-and-detached-query')
  reset(rec)
  for key,value in pairs({kv_keys=400,kv_bytes=200000,kv_key_bytes=400,kv_value_bytes=10000,
    kv_hash_fields=400,kv_hash_bytes=100000,kv_total_hash_fields=400,kv_command_arguments=1000,
    kv_command_bytes=200000,kv_snapshot_bytes=300000}) do change(key,value) end
  for i=1,300 do command(rec,'set','large-'..i,'value') end
  local args={'large-hash'}
  for i=1,300 do args[#args+1]='field-'..i; args[#args+1]='value' end
  command(rec,'hset',table.unpack(args))
  local long=string.rep('k',300)
  command(rec,'set',long,string.rep('v',9000))
  local snapshot=kv.snapshot(rec,game.tick)
  defaults(); kv.initialize(rec)
  assert(rec.body.minable and command(rec,'getLimits').usage.over_limit)
  local complete=kv.inspect(rec,game.tick,nop)
  assert(#complete.entries==302 and #command(rec,'get',long)==9000 and command(rec,'hlen','large-hash')==300)
  local fields=0
  for _,entry in ipairs(complete.entries) do if entry.type=='hash' then fields=fields+#entry.fields end end
  assert(fields==300 and #kv.import(snapshot).order==302)
  command(rec,'set',long,string.rep('v',8500)); command(rec,'hdel','large-hash','field-1')
  assert(#command(rec,'get',long)==8500 and command(rec,'hlen','large-hash')==299)
  command(rec,'expire',long,1)
  assert(kv.methods.get(nil,rec,'red',game.tick+60,nop,long)==nil)
  refusal(rec,'key_bytes',function() kv.methods.set(nil,rec,'red',game.tick+60,nop,long,'new') end)
  log('TC_CONTRACT above-former-shape-ceilings-full-browser-and-grandfathered-import')
  reset(rec)
  command(rec,'set','long-key','retained-value')
  command(rec,'hset','hash-key','long-field','field-value','second','other')
  command(rec,'expire','hash-key',1000)
  local deadline=rec.database.entries['hash-key'].deadline
  for _,definition in ipairs(budgets.definitions) do
    if definition.key:sub(1,3)=='kv_' then change(definition.key,1) end
  end
  kv.initialize(rec); assert(rec.body.minable and not rec.mining_guard)
  assert(command(rec,'get','long-key')=='retained-value')
  assert(command(rec,'hget','hash-key','long-field')=='field-value')
  assert(command(rec,'exists','long-key')==1 and command(rec,'exists','hash-key')==1)
  refusal(rec,'command_arguments',function() command(rec,'exists','long-key','long-key') end)
  local view=kv.inspect(rec,game.tick,nop)
  assert(#view.entries==2 and #view.entries[1].fields==2)
  view.entries[1].fields[1].value='not owned'; assert(command(rec,'hget','hash-key','long-field')=='field-value')
  command(rec,'set','long-key','short')
  command(rec,'hset','hash-key','long-field','x')
  assert(rec.database.entries['hash-key'].deadline==deadline)
  assert(command(rec,'hdel','hash-key','second')==1)
  assert(command(rec,'getLimits').usage.over_limit)
  local before=rec.database
  assert(not pcall(command,rec,'hset','hash-key','new-field','new-value') and rec.database==before)
  local restored={database=kv.import(kv.snapshot(rec,game.tick))}
  assert(restored.database.bytes==rec.database.bytes and restored.database.entries['hash-key'].deadline==deadline)
  assert(command(rec,'persist','hash-key')==1)
  assert(command(rec,'expire','hash-key',0)==1)
  assert(command(rec,'del','long-key')==1 and rec.database.bytes==0)
  log('TC_CONTRACT grandfathered-read-full-inspection-shrink-delete-expiry-and-transport')
  reset(rec)
  command(rec,'hset','h','a','old','b','kept'); command(rec,'expire','h',1000)
  local before=rec.database; local count=0
  kv.methods.hset(nil,rec,'red',game.tick,function() count=count+1 end,'h','a','new','c','new')
  for stop=1,count do
    rec.database=before; local step=0; local marker={}
    local ok,e=pcall(kv.methods.hset,nil,rec,'red',game.tick,function()
      step=step+1; if step==stop then error(marker,0) end
    end,'h','a','new','c','new')
    assert(not ok and e==marker and rec.database==before and before.entries.h.fields.a=='old')
  end
  reset(rec)
  for i=1,20 do command(rec,'set',tostring(i),''); command(rec,'expire',tostring(i),1) end
  local marker={}; local paid=0
  assert(not pcall(kv.reclaim,rec,game.tick+60,function()
    paid=paid+1; if paid==4 then error(marker,0) end
  end))
  assert(#rec.database.order==17 and kv.audit(rec.database))
  kv.reclaim(rec,game.tick+60,nop); assert(#rec.database.order==0)
  log('TC_CONTRACT every-precommit-work-refusal-and-paid-reclamation-progress')
  reset(rec)
end
local function computer_contracts(rec)
  local state={}
  for i=1,4 do state['k'..i]=string.rep(string.char(i),i==4 and 16264 or 16384) end
  local material={version=1,saved_source='-- saved\nreturn {}',saved_revision=7,label='material label',
    active={source='-- active\nreturn {}',revision=6,api_version=1,compiler_version=2,storage_version=1,handlers={start=true}},state=state}
  snapshots.restore_computer(rec,material,false)
  assert(rec.state_bytes==65536 and rec.status=='stopped')
  change('state_bytes',1); snapshots.initialize_computer(rec)
  assert(rec.body.minable and snapshots.computer_snapshot(rec,false).state.k4==state.k4)
  -- Supported material above the removed independent transport/shape ceilings.
  local large={version=1,saved_source=string.rep('s',140000),saved_revision=1,label=string.rep('l',300),state={}}
  large.state[string.rep('k',300)]={string.rep('v',20000),true,1}
  for i=1,300 do large.state['s'..i]=i end
  local copy=snapshots.import_computer(large,false)
  assert(#copy.saved_source==140000 and copy.state_entries==301)
  assert(copy.state[string.rep('k',300)]~=large.state[string.rep('k',300)])
  local deep={}; local cursor=deep
  for _=1,200 do cursor.child={}; cursor=cursor.child end
  large.state.deep=deep; assert(snapshots.import_computer(large,false).state.deep)
  local shared={value=1}; large.state={a=shared,b=shared}
  copy=snapshots.import_computer(large,false); assert(copy.state.a~=copy.state.b)
  local cycle={}; cycle.self=cycle
  for _,bad in ipairs({cycle,{bad=function() end},{bad=0/0},{bad=setmetatable({},{})},
    {bad={[1]='a',[3]='b'}},{bad={[1]='a',field='b'}}}) do
    local old=rec.state
    assert(not pcall(snapshots.restore_computer,rec,{version=1,saved_source='',saved_revision=0,state=bad},false))
    assert(rec.state==old and rec.saved_revision==7)
  end
  local invalid=snapshots.computer_snapshot(rec,false); invalid.continuation={}
  assert(not pcall(snapshots.import_computer,invalid,false))
  local settings_only=snapshots.settings(rec)
  assert(settings_only.computer.state==nil and settings_only.computer.active==nil)
  assert(not pcall(snapshots.import_computer,material,true))
  -- Exercise native item serialization above the former 131072-byte ceiling.
  local inv=game.create_inventory(1); inv[1].set_stack{name='tc-computer',count=1}
  inv[1].tags={tc_computer=large}
  local from_item=snapshots.import_computer(inv[1].tags.tc_computer,false)
  assert(from_item.saved_source==large.saved_source and from_item.label==large.label)
  inv.destroy()
  log('TC_CONTRACT computer-max-state-grandfathered-shape-validation-and-large-native-item')
end
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
script.on_event(defines.events.on_robot_mined_entity,function(event)
  local rec=registry.by_entity(event.entity)
  if rec then
    lifecycle.on_removed(event)
    f().mined[rec.kind]=true; log('TC_POLICY_NATIVE_MINED '..rec.kind)
  end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
  if defs.by_name[event.entity.name]=='kv' or defs.by_name[event.entity.name]=='computer' then
    lifecycle.on_built(event)
    local rec=assert(registry.by_entity(event.entity))
    f().rebuilt[rec.kind]=rec.id; log('TC_POLICY_NATIVE_BUILT '..rec.kind)
  end
end)
function M.run()
  registry.initialize(); defaults()
  storage.tc_kv_policy={phase='armed',mined={},rebuilt={},ids={},carried=game.create_inventory(2)}
  local db=build('kv',3,0); policy_contracts(db)
  local computer=build('computer',-3,0); computer_contracts(computer)
  for i=1,128 do local key=tostring(i); command(db,'set',key,string.rep('\0',128-#key)) end
  command(db,'expire','1',5)
  assert(db.database.bytes==16384 and #db.database.order==128)
  f().deadline=db.database.entries['1'].deadline
  for _,definition in ipairs(budgets.definitions) do
    if definition.key:sub(1,3)=='kv_' then change(definition.key,1) end
  end
  kv.initialize(db); snapshots.initialize_computer(computer)
  assert(db.body.minable and computer.body.minable)
  f().ids={kv=db.id,computer=computer.id}
  f().database_alias=db.database; f().state_alias=computer.state
  local bp_inventory=game.create_inventory(1); bp_inventory[1].set_stack{name='blueprint',count=1}
  local bp=bp_inventory[1]
  local mapping=bp.create_blueprint{surface=game.surfaces[1],force='player',area={{-6,-3},{6,3}}}
  assert(blueprints.prepare(bp,mapping))
  local selected=0
  for _,entry in ipairs(bp.get_blueprint_entities()) do
    local s=entry.tags and entry.tags.tc_settings
    if s then
      selected=selected+1
      assert(not s.database and not s.tc_kv)
      if s.computer then assert(s.computer.saved_source==computer.saved_source and not s.computer.state and not s.computer.active) end
    end
  end
  assert(selected==2); bp_inventory.destroy()
  local surface=game.surfaces[1]
  local roboport=assert(surface.create_entity{name='roboport',position={0,6},force='player'})
  roboport.energy=100000000; roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=2}
  f().roboport=roboport
  f().chest=assert(surface.create_entity{name='storage-chest',position={5,6},force='player'})
  assert(surface.create_entity{name='substation',position={0,11},force='player'})
  local power=assert(surface.create_entity{name='electric-energy-interface',position={-3,11},force='player'})
  power.power_production=10000000; power.power_usage=0
  f().started=game.tick
  log('TC_CONTRACT native-blueprint-source-only-and-grandfathered-mining-armed')
end
local function unchanged()
  local x=f()
  assert(limits.kv_bytes==1 and limits.state_bytes==1)
  local db=assert(registry.record(x.live_kv)); local computer=assert(registry.record(x.live_computer))
  assert(db.database==x.database_alias and computer.state==x.state_alias)
  assert(db.database.bytes==16384 and #db.database.order==128 and computer.state_bytes==65536)
  assert(x.carried[1].tags.tc_kv.entries[1].deadline==x.deadline)
  assert(#x.carried[1].tags.tc_kv.entries==128 and x.carried[2].tags.tc_computer.state.k1==computer.state.k1)
end
function M.on_load()
  budgets.refresh()
  if f().phase=='frozen' then unchanged(); loaded=true; log('TC_POLICY_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local x=f()
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged()
    if event.tick<x.deadline then return end
    local db=registry.record(x.live_kv)
    assert(command(db,'get','1')==nil and command(db,'get','2')==string.rep('\0',127))
    assert(#kv.inspect(db,event.tick,nop).entries==127)
    local old=db.database
    assert(not pcall(command,db,'set','new','growth') and db.database==old)
    command(db,'set','2','short'); assert(command(db,'get','2')=='short')
    command(db,'del','3'); assert(command(db,'getLimits').usage.over_limit)
    defaults(); command(db,'set','new','after raise')
    assert(command(db,'get','new')=='after raise')
    -- Replacement occurs while settings are low again, not after raising them.
    for _,definition in ipairs(budgets.definitions) do
      if definition.key:sub(1,3)=='kv_' or definition.key=='state_bytes' then change(definition.key,1) end
    end
    for i=1,2 do assert(x.chest.get_inventory(defines.inventory.chest).insert(x.carried[i])==1); x.carried[i].clear() end
    x.roboport.active=true; x.roboport.energy=100000000; x.chest.active=true
    x.phase='rebuilding'; x.started=event.tick
    for kind,position in pairs({kv={3,0},computer={-3,0}}) do
      assert(game.surfaces[1].create_entity{name='entity-ghost',inner_name=defs.devices[kind].entity_name,position=position,force='player'})
    end
    return
  elseif x.phase=='rebuilding' then
    assert(event.tick-x.started<1200,'native rebuild deadline exceeded')
    if not x.rebuilt.kv or not x.rebuilt.computer then return end
    local db=assert(registry.record(x.rebuilt.kv)); local c=assert(registry.record(x.rebuilt.computer))
    assert(db.id~=x.ids.kv and c.id~=x.ids.computer)
    assert(db.database.bytes==16384 and #db.database.order==128 and db.database.entries['1'].deadline==x.deadline)
    assert(command(db,'get','1')==nil and command(db,'get','2')==string.rep('\0',127))
    assert(command(db,'getLimits').usage.over_limit)
    assert(c.state_bytes==65536 and c.state.k1==registry.record(x.live_computer).state.k1)
    assert(c.saved_revision==7 and c.active.revision==6 and c.saved_source~=c.active.source and c.label=='material label')
    assert(c.status=='stopped' and not c.run_id and not c.continuation and next(c.queue)==nil
      and next(c.timers)==nil and next(c.subscriptions)==nil)
    defaults(); x.phase='done'
    log('TC_CONTRACT actual-native-KV-and-computer-mining-cold-replacement-lower-raise-expiry')
    log('TC_COLD_OK'); return
  end
  if not x.cloned then
    for i,kind in ipairs({'kv','computer'}) do
      local source=registry.record(x.ids[kind])
      local body=assert(source.body.clone{position={i*6,15},surface=source.body.surface,force='player'})
      local rec=assert(registry.by_entity(body),'native clone event missing')
      assert(rec.id~=source.id)
      if kind=='kv' then assert(#rec.database.order==0)
      else assert(rec.saved_source==source.saved_source and not rec.active and next(rec.state)==nil and not rec.run_id) end
      lifecycle.remove(rec.id,'fixture-cleanup',true)
      assert(source.body.order_deconstruction('player'))
    end
    x.cloned=true; log('TC_POLICY_NATIVE_CLONE_ISOLATION')
  end
  assert(event.tick-x.started<1200,'native mining deadline exceeded')
  local inventory=x.chest.get_inventory(defines.inventory.chest)
  for i=1,#inventory do
    local stack=inventory[i]
    if stack.valid_for_read then
      local slot=stack.name=='tc-kv' and 1 or stack.name=='tc-computer' and 2
      if slot then assert(not x.carried[slot].valid_for_read); x.carried[slot].set_stack(stack); stack.clear() end
    end
  end
  if not x.carried[1].valid_for_read or not x.carried[2].valid_for_read then return end
  assert(x.mined.kv and x.mined.computer and not registry.record(x.ids.kv) and not registry.record(x.ids.computer))
  local db=build('kv',12,0); kv.restore(db,x.carried[1].tags.tc_kv)
  local c=build('computer',-12,0); snapshots.restore_computer(c,x.carried[2].tags.tc_computer,false)
  x.live_kv=db.id; x.live_computer=c.id; x.database_alias=db.database; x.state_alias=c.state
  x.roboport.active=false; x.chest.active=false; x.phase='frozen'
  unchanged(); game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
