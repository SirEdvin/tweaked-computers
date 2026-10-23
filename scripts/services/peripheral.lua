local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local network=require('scripts.network')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local principal=require('scripts.runtime.principal')
local M={}
local types={kv='kv_database',monitor='monitor',logic='logic_handler',configurator='configurator',recipe_searcher='recipe_searcher',radar='modem',speaker='speaker'}
local bindings={}; local revocations={}
local monitor_sync
function M.register_monitor_sync(binding)
  assert(not monitor_sync and type(binding.set)=='function' and type(binding.get)=='function')
  monitor_sync=binding
end
local directions={[0]='north',[4]='east',[8]='south',[12]='west'}
-- Closed family, fixed host methods; no guest extension/plugin registration.
-- resolve(member) may map a physical monitor tile to its logical anchor record.
for kind in pairs(types) do
  bindings[kind]={methods={getLimits=function() return limits end}}
end
function M.register_type(kind,binding)
  assert(types[kind] and type(binding)=='table' and type(binding.methods)=='table','unknown peripheral family')
  assert(not bindings[kind].installed,'duplicate peripheral family binding')
  local n=0
  for name,fn in pairs(binding.methods) do
    n=n+1; assert(type(name)=='string' and #name<=limits.identifier_bytes and type(fn)=='function','invalid peripheral method')
  end
  assert(n<=limits.tuple_entries and binding.methods.getLimits,'bounded methods including getLimits required')
  binding.installed=true; bindings[kind]=binding
end
function M.register_revocation(name,fn)
  assert(type(name)=='string' and type(fn)=='function' and not revocations[name],'invalid revocation hook')
  local n=0; for _ in pairs(revocations) do n=n+1 end; assert(n<4,'revocation hook capacity')
  revocations[name]=fn
end
local function resolved(member)
  local b=bindings[member.kind]
  local rec=member
  if b and b.resolve then rec=b.resolve(member) end
  if not rec or not types[rec.kind] then return nil end
  return rec
end
local function sorted(map,spend)
  local names={}; for name in pairs(map) do names[#names+1]=name end
  if spend then spend(#names+1) end
  table.sort(names,function(a,b) if spend then spend(#a+#b+1) end; return a<b end); return names
end
function M.inventory(computer,wire,spend)
  local members,parents=network.discover(computer,wire,spend)
  local inventory={}
  for _,member in ipairs(members) do
    spend(4)
    local rec=resolved(member)
    if rec and network.same_scope(rec.body,computer) and rec.force_index==computer.force_index
      and rec.surface_index==computer.surface_index and not inventory[rec.id] then
      inventory[rec.id]={name=rec.id,type=types[rec.kind],generation=rec.generation,member=member.id}
    end
  end
  return inventory,parents
end
local function target(inventory,name)
  local item=inventory[name]
  if not item then return nil end
  local member=registry.record(item.member); local rec=member and resolved(member)
  if not rec or rec.id~=name or rec.generation~=item.generation then return nil end
  return rec,item
end
M.resolve_inventory_item=target -- Host-only: logical displays are not registry tile IDs.
function M.revoke(computer,name,wire,reason,execution)
  local root=registry.get()
  local program_owner,shell_owner=principal.program(computer),principal.shell(computer)
  -- Exact current writer only. The cleanup walk is covered by callers' fixed
  -- safety/publication admission; it never executes player source.
  for _,id in ipairs(root.order) do
    local rec=registry.record(id); local owner=rec and rec.output_owner
    local current_owner=execution and principal.matches(owner,computer,execution)
      or not execution and (principal.matches(owner,computer,program_owner) or principal.matches(owner,computer,shell_owner))
    if rec and rec.kind=='logic' and rec.id==name and owner
      and owner.computer_id==computer.id and owner.wire==wire and current_owner then
      lifecycle.clear_output(rec)
    end
  end
  local names={}; for key in pairs(revocations) do names[#names+1]=key end; table.sort(names)
  local failed=false
  for _,key in ipairs(names) do
    local ok=pcall(revocations[key],computer,name,wire,reason,execution)
    if not ok then failed=true end
  end
  if failed then
    runtime.fault(computer,errors.new('E_ENGINE','authority revocation adapter failed; run stopped'),game.tick)
  end
end
local function check_name(name)
  if type(name)~='string' or #name==0 or #name>limits.identifier_bytes then errors.raise('E_ARGUMENT','bounded peripheral name required') end
end
function M.services(computer,tick,guard,execution)
  execution=execution or principal.program(computer)
  local handles=setmetatable({},{__mode='k'})
  local availability={} -- One non-yielding callback only, never retained across ticks.
  local inventories={}
  local authorized=false
  local spend=guard.spend
  local function current()
    guard.check()
    if not principal.live(computer,execution)
      or not computer.powered or not authorized and not lifecycle.connector(computer,'network','red') then
      errors.raise('E_NOT_FOUND','computer run no longer authorized')
    end
    authorized=true
  end
  local function inventory(wire)
    network.wire(wire)
    local proof=inventories[wire]
    if proof then
      if guard.replay_work then guard.replay_work(proof.charges)
      else for _,cost in ipairs(proof.charges) do spend(cost) end end
      return proof.inventory
    end
    -- Physical connectivity cannot change during this non-yielding guest
    -- callback: no guest service rewires/moves/removes entities. Preserve all
    -- original charges, and still resolve identity/generation on every use.
    local charges={total=0}
    local values=M.inventory(computer,wire,function(n) spend(n); charges[#charges+1]=n; charges.total=charges.total+n end)
    inventories[wire]={inventory=values,charges=charges}
    return values
  end
  local function lookup(name,wire)
    current(); check_name(name); network.wire(wire)
    return target(inventory(wire),name)
  end
  local function invoke(name,wire,generation,method,...)
    if execution.kind=='shell' and (method=='subscribe' or method=='unsubscribe') then
      errors.raise('E_UNSUPPORTED','subscriptions require a saved handler program')
    end
    -- Reprove physical authority even for captured functions/getLimits.
    local rec=lookup(name,wire)
    if not rec or (generation and rec.generation~=generation) then
      spend(limits.registry_entries*4+32); M.revoke(computer,name,wire,'wire_removed',execution)
      errors.raise('E_UNREACHABLE','peripheral binding is no longer reachable')
    end
    local fn=bindings[rec.kind].methods[method]
    if not fn then errors.raise('E_ARGUMENT','unknown peripheral method') end
    -- Only the reviewed monitor provider promises not to alter physical state.
    -- Unknown/test/other providers invalidate proofs even if they later throw.
    if not bindings[rec.kind].callback_stable then inventories={}; availability={}; authorized=false end
    if method=='getLimits' and select('#',...)~=0 then errors.raise('E_ARGUMENT','getLimits expects no arguments') end
    -- Logical providers prove all current members themselves. Their cached
    -- aggregate powered flag can lag paid topology maintenance after restoration.
    local available=bindings[rec.kind].available
    if method~='getLimits' and ((available and not available(rec,spend,availability))
      or (not available and (not rec.powered or not lifecycle.has_power(rec)))) then
      errors.raise('E_UNPOWERED','peripheral is unpowered')
    end
    if rec.kind=='speaker' and (method=='playNote' or method=='playSound') then guard.prepare_boolean_result() end
    if rec.kind=='radar' and method=='transmit' then guard.prepare_empty_result() end
    local hold=bindings[rec.kind].hold
    if hold and method:sub(1,3)~='get' and method:sub(1,2)~='is' then
      guard.prepare_empty_result(); guard.host_work(12,12)
      fn(computer,rec,wire,tick,spend,...)
      hold(rec,computer,execution)
      return
    end
    if bindings[rec.kind].with_principal then
      if bindings[rec.kind].with_guard then return fn(computer,rec,wire,tick,spend,execution,guard,...) end
      return fn(computer,rec,wire,tick,spend,execution,...)
    end
    if bindings[rec.kind].with_guard then return fn(computer,rec,wire,tick,spend,guard,...) end
    return fn(computer,rec,wire,tick,spend,...)
  end
  local function facade(rec,wire)
    local name,generation=rec.id,rec.generation; local methods={}
    for method in pairs(bindings[rec.kind].methods) do
      local key=method
      methods[key]=guard.service(function(...) return invoke(name,wire,generation,key,...) end)

    end
    local proxy=guard.namespace(methods,'peripheral method')
    if guard.shell_enabled or guard.continuation_enabled then
      for key,fn in pairs(methods) do
        guard.bind_value(fn,proxy,key)
      end
      guard.host_work(#name+64,#name+64)
      guard.bind_value(proxy,{name=name,wire=wire,generation=generation,kind=rec.kind})
    end
    handles[proxy]={name=name,wire=wire,generation=generation}
    return proxy
  end
  local api={}
  local function method(name,n,fn)
    api[name]=function(...)
      current()
      if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
      return fn(...)
    end
  end
  method('getNames',1,function(wire) return sorted(inventory(wire),spend) end)
  method('setMonitorSyncGroup',1,function(members)
    if not monitor_sync then errors.raise('E_UNSUPPORTED','monitor provider unavailable') end
    guard.prepare_empty_result()
    return monitor_sync.set(computer,tick,spend,members,execution)
  end)
  method('getMonitorSyncGroup',0,function()
    if not monitor_sync then errors.raise('E_UNSUPPORTED','monitor provider unavailable') end
    return monitor_sync.get(computer,spend,execution)
  end)
  method('isPresent',2,function(name,wire) return lookup(name,wire)~=nil end)
  method('getType',2,function(name,wire) local rec=lookup(name,wire); return rec and types[rec.kind] or nil end)
  method('getMethods',2,function(name,wire) local rec=lookup(name,wire); if rec then return sorted(bindings[rec.kind].methods,spend) end; return nil end)
  method('describe',2,function(name,wire)
    local rec=lookup(name,wire); if not rec then return nil end
    local b=rec.body; local def=defs.devices[rec.kind]
    local horizontal=rec.direction==0 or rec.direction==8
    local width=rec.native_carrier=='speaker' and 1 or rec.native_carrier=='radar' and (rec.modem_tier=='surface' and 3 or 5) or nil
    local info={name=rec.id,type=types[rec.kind],label=rec.label,powered=rec.powered,
      position={x=b.position.x,y=b.position.y},surface={index=b.surface.index,name=b.surface.name},
      quality=b.quality.name,direction=directions[width and b.direction or rec.direction],
      footprint={width=width or (horizontal and def.width or 1),height=width or (horizontal and 1 or def.width)},wire=wire}
    if width then info.modem_tier=rec.modem_tier; info.powered=lifecycle.has_power(rec) end
    if bindings[rec.kind].describe then info=bindings[rec.kind].describe(rec,wire,info) end
    return (data.copy(info,spend))
  end)
  method('wrap',2,function(name,wire) local rec=lookup(name,wire); if rec then return facade(rec,wire) end; return nil end)
  api.call=function(name,wire,method_name,...)
    current()
    if type(method_name)~='string' or #method_name>limits.identifier_bytes then errors.raise('E_ARGUMENT','method name required') end
    return invoke(name,wire,nil,method_name,...)
  end
  method('find',2,function(type_name,wire)
    if type(type_name)~='string' or #type_name>limits.identifier_bytes then errors.raise('E_ARGUMENT','peripheral type required') end
    local values=inventory(wire); local matches={}
    for _,name in ipairs(sorted(values,spend)) do if values[name].type==type_name then matches[#matches+1]=name end end
    if #matches>limits.tuple_entries then errors.raise('E_LIMIT','find result exceeds tuple limit; use getNames and wrap') end
    local result={}; for _,name in ipairs(matches) do result[#result+1]=facade(assert(target(values,name)),wire) end
    return table.unpack(result,1,#result)
  end)
  for _,key in ipairs({'getName','getWire'}) do
    local field=key=='getName' and 'name' or 'wire'
    method(key,1,function(proxy)
      local binding=handles[proxy]; if not binding then errors.raise('E_ARGUMENT','genuine facade from this callback required') end
      return binding[field]
    end)
    guard.accept_handle(api[key],1)
  end
  if guard.shell_enabled or guard.continuation_enabled then guard.binding_resolver(function(d,parent)
    if type(d)~='table' or type(d.name)~='string' or #d.name==0 or #d.name>limits.identifier_bytes
      or not bindings[d.kind] or not errors.integer(d.generation,1,9007199254740991)
      or (d.wire~='red' and d.wire~='green') then errors.raise('E_ARGUMENT','invalid retained peripheral identity') end
    spend(#d.name+32)
    if d.method then
      if type(d.method)~='string' or not bindings[d.kind].methods[d.method] then errors.raise('E_ARGUMENT','invalid retained peripheral method') end
      if parent then
        local identity=handles[parent]
        if not identity or identity.name~=d.name or identity.wire~=d.wire or identity.generation~=d.generation then errors.raise('E_ARGUMENT','captured method/facade identity mismatch') end
        return guard.get(parent,d.method)
      end
      local fn=guard.service(function(...) return invoke(d.name,d.wire,d.generation,d.method,...) end)
      guard.bind_value(fn,d); return fn
    end
    return facade({id=d.name,generation=d.generation,kind=d.kind},d.wire)
  end) end
  return {peripheral=api}
end
-- Each transition is committed before guest notification. A bounded durable job
-- retains undelivered transitions; an incomplete graph never publishes a prefix.
local function reason(computer,item)
  local member=registry.record(item.member)
  if not member or not member.body.valid then return 'removed' end
  if member.body.force.index~=computer.force_index then return 'force_changed' end
  if member.body.surface.index~=computer.surface_index then return 'surface_changed' end
  local rec=resolved(member)
  if not rec or rec.id~=item.name or rec.generation~=item.generation then return 'regrouped' end
  return 'wire_removed'
end
function M.reconcile_one(computer,wire,tick,spend)
  spend(16)
  computer.network_views=computer.network_views or {}
  local view=computer.network_views[wire]
  if not view or view.run_id~=computer.run_id then
    -- Baseline changes on a new run are not attachment snapshots.
    local ok,result=pcall(M.inventory,computer,wire,spend)
    if not ok then
      if type(result)=='table' and result.code then
        computer.network_views[wire]={run_id=computer.run_id,inventory={},diagnostic=result}; return
      end
      error(result,0)
    end
    computer.network_views[wire]={run_id=computer.run_id,inventory=result,tick=tick}; return
  end
  if not view.job then
    local ok,next_inventory=pcall(M.inventory,computer,wire,spend)
    local failure
    if not ok then
      if type(next_inventory)~='table' or not next_inventory.code then error(next_inventory,0) end
      failure=next_inventory; next_inventory={}
    end
    local changes={}
    for _,name in ipairs(sorted(view.inventory,spend)) do
      local old=view.inventory[name]; local new=next_inventory[name]
      if not new or new.generation~=old.generation then
        changes[#changes+1]={event='peripheral_detach',item=old,reason=failure and (failure.code=='E_LIMIT' and 'limit' or 'unavailable') or reason(computer,old)}
      end
    end
    for _,name in ipairs(sorted(next_inventory,spend)) do
      local old=view.inventory[name]; local new=next_inventory[name]
      if not old or old.generation~=new.generation then changes[#changes+1]={event='peripheral_attach',item=new} end
    end
    view.job={inventory=next_inventory,changes=changes,cursor=1,diagnostic=failure}
  end
  local job=view.job
  while job.cursor<=#job.changes do
    local change=job.changes[job.cursor]; local item=change.item
    -- Atomic event/cleanup publication reservation. runtime.emit then uses the
    -- already-paid bounded copy space; no prefix is repeated after deferral.
    spend(#registry.get().order*4+limits.subscriptions+128)
    local deliveries=0
    for _,sub in pairs(computer.subscriptions) do if sub.event_name==change.event then deliveries=deliveries+1 end end
    spend(deliveries*768+limits.subscriptions^2+128)
    if change.event=='peripheral_detach' then M.revoke(computer,item.name,wire,change.reason) end
    runtime.emit(computer.id,change.event,{peripheral=item.name,peripheral_type=item.type,wire=wire,reason=change.reason},tick)
    job.cursor=job.cursor+1
    if computer.status~='running' then return end
  end
  view.inventory=job.inventory; view.diagnostic=job.diagnostic; view.tick=tick; view.job=nil
end
function M.reconcile(tick,spend)
  local root=registry.get(); spend(limits.registry_entries+limits.active_computers^2+1)
  local ids={}; for _,id in ipairs(root.order) do local rec=root.computers[id]; if rec and rec.physical_version and rec.status=='running' then ids[#ids+1]=id end end
  table.sort(ids)
  if #ids==0 then return end
  local size=#ids*2; local cursor=math.min(root.scheduler.network_cursor or 1,size)
  -- At most 3 channel inventories per tick: 64 active computers/2 channels fit
  -- a 43-tick ordinary sweep; work/capacity refusal remains explicit diagnostic.
  for _=1,math.min(3,size) do
    local rec=root.computers[ids[math.floor((cursor-1)/2)+1]]; local wire=cursor%2==1 and 'red' or 'green'
    local admitted=scheduler.try_maintenance(function() M.reconcile_one(rec,wire,tick,spend) end)
    if not admitted then
      -- Diagnostic only; retain the exact pending transition/cursor for retry.
      if rec.network_views and rec.network_views[wire] then
        rec.network_views[wire].diagnostic=errors.new('E_NETWORK_PENDING','topology maintenance deferred; current calls still require a live proof')
      end
    end
    cursor=cursor%size+1; root.scheduler.network_cursor=cursor
  end
end
function M.authority(computer,name,wire,spend)
  local inventory,parents=M.inventory(computer,wire,spend)
  local rec,item=target(inventory,name)
  if not rec then return nil end
  return rec,network.witness(computer,registry.record(item.member),parents,spend)
end
function M.check_outputs(tick,spend)
  local root=registry.get()
  -- Prepay the complete walk and all native zero-bank cleanups independently of
  -- guest credits. Proof may defer; that clears output rather than trusting it.
  spend(#root.order*4)
  local owned=0
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and rec.kind=='logic' and rec.output_owner then owned=owned+1 end
  end
  spend(owned*256)
  for _,id in ipairs(root.order) do
    local rec=registry.record(id); local owner=rec and rec.kind=='logic' and rec.output_owner
    if owner then
      local computer=type(owner)=='table' and root.computers[owner.computer_id]; local valid=false
      if computer and principal.live(computer,{kind=owner.kind or 'program',id=owner.run_id}) and computer.powered then
        local safe,admitted,result=pcall(scheduler.try_maintenance,function()
          if owner.wire~='red' and owner.wire~='green' then return false end
          if owner.path and network.validate_witness(computer,owner.wire,owner.path,spend) then
            return owner.path[#owner.path]==rec.id
          end
          local reachable,path=M.authority(computer,rec.id,owner.wire,spend)
          if reachable then owner.path=path; return true end
          return false
        end)
        valid=safe and admitted and result==true
        if not safe then
          rec.authority_diagnostic=type(admitted)=='table' and admitted.code and admitted
            or errors.new('E_ENGINE','authority proof failed; output cleared')
        elseif not valid then rec.authority_diagnostic=errors.new('E_NETWORK_PENDING','authority absent or proof deferred; output cleared')
        else rec.authority_diagnostic=nil end
      end
      if not valid then lifecycle.clear_output(rec) end
    end
  end
end
runtime.register_services('peripheral',M.services)
principal.register_cleanup('logic-output',function(c,p)
  for _,id in ipairs(registry.get().order) do
    local rec=registry.record(id)
    if rec and rec.kind=='logic' and principal.matches(rec.output_owner,c,p) then lifecycle.clear_output(rec) end
  end
end)
registry.register_cleanup('network-owned-output',function(computer,run_id,reason)
  if computer.kind~='computer' then return end
  if reason~='power_loss' and reason~='authority_changed' then computer.network_views=nil end
  local root=registry.get()
  for _,id in ipairs(root.order) do
    local rec=registry.record(id); local owner=rec and rec.kind=='logic' and rec.output_owner
    if type(owner)=='table' and owner.computer_id==computer.id and owner.run_id==run_id then lifecycle.clear_output(rec) end
  end
end)
scheduler.register_phase('lifecycle','01-network-output-authority',M.check_outputs)
scheduler.register_phase('notifications','peripheral-topology',M.reconcile)
return M
