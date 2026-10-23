-- Real sandbox jobs and real shared host owners; not production dispatch proof.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local snapshots=require('scripts.lifecycle-data')
local model=require('scripts.monitor-model')
local defs=require('scripts.device-definitions')
local preparation=require('scripts.services.kv-preparation')
local kv=require('scripts.services.kv')
local ownership=require('scripts.services.kv-memory')
local policy=require('scripts.runtime.resource-policy')
local sandbox=require('scripts.runtime.sandbox')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local function nop() end
local function build(x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.kv.entity_name,position={x,0},force='player'})
  return assert(lifecycle.build(body))
end
local function direct(rec,name,...)
  return kv.methods[name](nil,rec,'red',game.tick,nop,...)
end
local function session(rec,args)
  local account=memory.new(limits.runtime_memory_bytes,0)
  return {id=rec.id,args=args,pending={},saved={owned={},owned_order={},symbols={},bindings={},functions={}},
    ledger=admission.new(),account=account,owner=memory.owner(account),slices=0}
end
local function step(f,tick,credits,refuse)
  local context=admission.context(f.ledger,'kv-owned',tick); context.memory_owner=f.owner
  if credits then assert(admission.reserve(context,'work',limits.callback_work-credits)) end
  local g=sandbox.new(context,{},nil,f.saved)
  g.call_checkpoint(f.pending,refuse and {prepare=function() error({code='E_CAPACITY',message='injected result refusal'},0) end} or nil)
  local fn=g.service(function()
    local function spend(n)
      local j=f.pending.jobs and f.pending.jobs['kv:hset']
      if f.cold and not f.suspended and j and j.copy_index==8 then f.suspended=true; g.suspend() end
      g.spend(n)
    end
    return kv.guarded_methods.hset(nil,assert(registry.record(f.id)),'red',tick,spend,g,table.unpack(f.args))
  end)
  local ok,result=pcall(g.call,fn)
  return ok,result,g.work_suspended(),g.diagnostic(result)
end
local function monitor_contract()
  local rec={id='material-monitor',kind='monitor',monitor_settings=model.new(1,1)}
  local settings={version=1,scale=0.75,fg=3,bg=4,blink=true,palette=model.new(1,1).palette}
  snapshots.restore_monitor(rec,settings)
  assert(rec.monitor_settings.scale==0.75 and rec.monitor_settings.width==13 and rec.monitor_settings.height==8)
  local inventory=game.create_inventory(1); inventory[1].set_stack{name='tc-monitor',count=1}
  inventory[1].tags={tc_monitor=snapshots.import_monitor(settings)}
  assert(inventory[1].tags.tc_monitor.scale==0.75)
  local root=registry.get(); local previous=root.monitors
  local group={width_tiles=6,height_tiles=6,model=model.new(6,6)}
  root.monitors={version=1,groups={test=group},membership={[rec.id]='test'}}
  local old,old_settings,palette,cells=group.model,rec.monitor_settings,group.model.palette,group.model.cells
  settings.scale=0.1
  local ok=pcall(snapshots.apply_settings,rec,{version=1,kind='monitor',monitor=settings})
  assert(not ok and group.model==old and rec.monitor_settings==old_settings and old.palette==palette and old.cells==cells)
  for _,scale in ipairs({0,-1,1e100,1e-100,math.huge}) do
    settings.scale=scale
    assert(not pcall(snapshots.restore_monitor,rec,settings) and rec.monitor_settings==old_settings)
  end
  settings.scale=0.75
  snapshots.apply_settings(rec,{version=1,kind='monitor',monitor=settings})
  assert(group.model~=old and old.palette==palette and group.model.scale==0.75)
  -- Native sprite admission and serialized readback, not visual/GPU acceptance.
  for _,scale in ipairs({0.75,1.25,6,100,(2^23-1)*64/9}) do
    settings.scale=scale; snapshots.import_monitor(settings)
    local sprite=rendering.draw_sprite{surface=1,sprite='tc-monitor-fill',target={0,0},x_scale=3*scale,y_scale=4.5*scale,visible=false}
    assert(sprite.valid and sprite.x_scale==3*scale and sprite.y_scale==4.5*scale); sprite.destroy()
  end
  root.monitors=previous; inventory.destroy()
  log('TC_CONTRACT monitor-material-fractional-native-scale-and-atomic-group-preflight')
end
local function sort_contract()
  local prep=preparation
  local map={['']=true,['\0']=true,['a']=true,['aa']=true,['\255']=true,[string.rep('a',300)..'b']=true,[string.rep('a',300)..'a']=true}
  local f=session({id='sort'},{}); local job
  local context=admission.context(f.ledger,'sort',0); context.memory_owner=f.owner
  local guard=sandbox.new(context,{},nil,f.saved); guard.call_checkpoint(f.pending)
  job=guard.job('sort',function() return {copy={order={},fields=0}} end)
  local sorted
  for tick=1,5000 do
    context=admission.context(f.ledger,'sort',tick); context.memory_owner=f.owner
    assert(admission.reserve(context,'work',limits.callback_work-1))
    guard=sandbox.new(context,{},nil,f.saved); guard.call_checkpoint(f.pending)
    assert(guard.job('sort',function() error('sort restarted') end)==job)
    local ok,result=pcall(prep.sorted,map,guard.spend,job,guard)
    if ok then sorted=result; break end
    assert(guard.work_suspended())
  end
  local expected={}; for k in pairs(map) do expected[#expected+1]=k end; table.sort(expected)
  assert(sorted and #sorted==#expected)
  for i,k in ipairs(expected) do assert(sorted[i]==k) end
  memory.close(f.owner,nop)
  log('TC_CONTRACT one-credit-byte-sort-retains-comparison-and-append-progress')
end
function M.run()
  registry.initialize()
  sort_contract()
  monitor_contract()
  local rec=build(0)
  for i=1,40 do direct(rec,'set',string.format('key-%03d',i),'retained') end
  local operands={'hash','old','retained'}
  for i=1,48 do operands[#operands+1]='field-'..i; operands[#operands+1]='value-'..i end
  direct(rec,'hset',table.unpack(operands))
  ownership.maintenance(nop)
  local host,radar=policy.host_account(nop)
  local live=registry.get().kv_memory.live[rec.id]
  assert(live.owner.account==host and live.owner~=radar and live.owner.values[rec.database.entries])
  assert(live.owner.values[rec.database.entries.hash.fields] and host.reserved==0)
  local old=rec.database; local cap=limits.host_memory_bytes; limits.host_memory_bytes=host.used
  local ok,e=pcall(direct,rec,'set','refused','growth')
  limits.host_memory_bytes=cap; policy.host_account(nop)
  assert(not ok and e.resource=='host_memory' and rec.database==old and host.reserved==0)
  log('TC_CONTRACT shared-host-distinct-lifecycle-owner-and-preallocation-refusal')
  local imported=build(3); local snapshot=kv.snapshot(rec,game.tick)
  limits.host_memory_bytes=1
  kv.restore(imported,snapshot)
  assert(direct(imported,'hget','hash','old')=='retained' and host.limit==1 and host.used>host.limit)
  assert(registry.get().kv_memory.live[imported.id].owner.account==host)
  limits.host_memory_bytes=cap; policy.host_account(nop)
  assert(lifecycle.remove(imported.id,'fixture',true)); ownership.maintenance(nop)
  log('TC_CONTRACT grandfathered-import-keeps-data-and-adopts-real-host-debt')
  for _,query in ipairs({'getLimits','hgetall'}) do
    local read=session(rec,{}); local result
    for tick=1,100 do
      local ctx=admission.context(read.ledger,'read',tick); ctx.memory_owner=read.owner
      local g=sandbox.new(ctx,{},nil,read.saved); g.call_checkpoint(read.pending)
      -- Initialize once with a complete allowance; traversal then gets 32 units.
      if tick>1 then assert(admission.reserve(ctx,'work',limits.callback_work-32)) end
      local args=query=='hgetall' and {'hash'} or {}
      local paid=0
      local function spend(n)
        if tick==1 and paid>=8 then g.suspend() end
        g.spend(n); paid=paid+n
      end
      local ok,value=pcall(kv.guarded_methods[query],nil,rec,'red',tick,spend,g,table.unpack(args))
      if ok then assert(tick>1); result=value; break end
      assert(g.work_suspended())
    end
    assert(result and (query=='getLimits' and result.usage.total_hash_fields==49 or query=='hgetall' and result['field-48']=='value-48'))
    memory.close(read.owner,nop)
  end
  log('TC_CONTRACT owned-query-preparation-retains-full-defensive-inventory')
  local denied=session(rec,{'hash','new','value'})
  ok,e=step(denied,1,nil,true)
  assert(not ok and rec.database==old and host.reserved==0 and next(registry.get().kv_memory.jobs)==nil)
  memory.close(denied.owner,nop)
  log('TC_CONTRACT owned-result-refusal-before-KV-publication-releases-host-peak')
  local stale=session(rec,{'hash','new','value'})
  local waiting
  ok,e,waiting=step(stale,2,256); assert(not ok and waiting)
  rec.generation=rec.generation+1
  ok,e,waiting=step(stale,3)
  assert(not ok and not waiting and e.code=='E_BUSY' and rec.database==old and host.reserved==0)
  memory.close(stale.owner,nop)
  log('TC_CONTRACT suspended-KV-generation-replacement-refuses-once-without-effect')
  local expired=session(rec,{'hash','new','value'})
  direct(rec,'expire','hash',1); old=rec.database
  ok,e,waiting=step(expired,game.tick,256); assert(not ok and waiting)
  ok,e,waiting=step(expired,game.tick+60)
  assert(not ok and not waiting and e.code=='E_BUSY' and rec.database==old and host.reserved==0)
  memory.close(expired.owner,nop); direct(rec,'persist','hash')
  ownership.maintenance(nop)
  local f=session(rec,{'hash','new-a','value-a','new-b','value-b'})
  f.cold=true; f.phase='scan'; f.original=rec.database; f.revision=rec.kv_revision
  storage.tc_kv_owned=f
  game.speed=100
end
local function unchanged(f)
  local rec=assert(registry.record(f.id)); local j=assert(f.pending.jobs['kv:hset'])
  local host=registry.get().host_memory
  assert(rec.database==f.original and rec.kv_revision==f.revision and j.copy_index==8 and f.suspended)
  assert(host.used==f.host_used and host.reserved==f.host_reserved and f.account.used==f.used)
  assert(f.pending.service_result==nil and f.pending.call_result==nil)
end
function M.on_load()
  local f=storage.tc_kv_owned
  if f.phase=='frozen' then unchanged(f); loaded=true; log('TC_KV_OWNED_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_kv_owned
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then unchanged(f); loaded=false; f.phase='resume' end
  f.slices=f.slices+1; assert(f.slices<1000)
  local ok,result,wait,diagnostic=step(f,event.tick,256)
  assert(ok or wait,diagnostic.message)
  if f.phase=='scan' and f.suspended then
    assert(not ok and wait)
    f.phase='frozen'; f.host_used=registry.get().host_memory.used; f.host_reserved=registry.get().host_memory.reserved; f.used=f.account.used
    unchanged(f)
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if ok then
    assert(f.phase=='resume' and result==2)
    local rec=registry.record(f.id)
    assert(rec.kv_revision==f.revision+1 and rec.database~=f.original and rec.database.entries.hash.fields['new-a']=='value-a')
    assert(rec.database.entries['key-001']==f.original.entries['key-001'] and f.original.entries.hash.fields['new-a']==nil)
    assert(registry.get().host_memory.values[rec.database.entries['key-001']].owners>=2,'immutable retained entry was copied or unowned')
    local revision=rec.kv_revision
    local again,value=step(f,event.tick+1)
    assert(again and value==2 and rec.kv_revision==revision,'completed service effect replayed')
    ownership.maintenance(nop)
    assert(registry.get().host_memory.reserved==0 and next(registry.get().kv_memory.jobs)==nil)
    local owner=registry.get().kv_memory.live[rec.id].owner
    assert(owner.account==registry.get().host_memory and owner.values[rec.database] and owner.values[rec.database.entries.hash.fields])
    memory.close(f.owner,nop)
    assert(f.account.used==256 and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT real-owned-guard-KV-copy-sort-publication-cold-exactly-once')
    log('TC_COLD_OK')
  end
end
return M
