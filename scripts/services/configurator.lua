local peripheral=require('scripts.services.peripheral')
local targets=require('scripts.configuration.targets')
local adapters=require('scripts.configuration.adapters')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local common_limits=require('scripts.runtime.limits')
local sections=require('scripts.configuration.sections')
local M={}
-- Host-only identity summary; do not load adapters or configuration schemas.
function M.inspect(rec,tick,spend)
  local union,groups={},{}
  for _,wire in ipairs({'red','green'}) do
    for id,item in pairs(targets.inventory(rec,wire,spend)) do
      spend(#id+#item.entity.name+16)
      local entry=union[id]
      if not entry then entry={prototype=item.entity.name}; union[id]=entry end
      entry[wire]=true
    end
  end
  for _,item in pairs(union) do
    spend(#item.prototype+16)
    local g=groups[item.prototype]
    if not g then g={prototype=item.prototype,red=0,green=0,total=0}; groups[item.prototype]=g end
    g.total=g.total+1
    if item.red then g.red=g.red+1 end
    if item.green then g.green=g.green+1 end
  end
  local result={}
  for _,g in pairs(groups) do result[#result+1]=g end
  table.sort(result,function(a,b) spend(#a.prototype+#b.prototype+1); return a.prototype<b.prototype end)
  return {tick=tick,groups=result}
end
local function keys(map) local result={}; for k in pairs(map) do result[#result+1]=k end; table.sort(result); return result end
function M.describe(item,wire,spend)
  local entity=item.entity; local summary=adapters.summary(item,spend)
  local direction
  for name,value in pairs(defines.direction) do if value==entity.direction then direction=name; break end end
  return (data.copy({id=item.id,prototype=entity.name,type=entity.type,position={x=entity.position.x,y=entity.position.y},
    surface={index=entity.surface.index,name=entity.surface.name},direction=direction,quality=entity.quality.name,
    target_wire=wire,connected_connector_ids=keys(item.connectors),configurable=#summary.writable>0,
    configuration=summary},spend,common_limits.host_memory_bytes))
end
local methods={}
local function method(name,n,fn)
  methods[name]=function(c,rec,wire,tick,spend,...)
    if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
    return fn(rec,spend,...)
  end
end
method('getLimits',0,function(rec,spend)
  local limits=data.copy(common_limits,spend)
  return limits
end)
method('getDevices',1,function(rec,spend,wire)
  local inventory=targets.inventory(rec,wire,spend); local result={}
  for _,id in ipairs(keys(inventory)) do result[#result+1]=M.describe(inventory[id],wire,spend) end
  return result
end)
method('getDevice',2,function(rec,spend,id,wire)
  local item=targets.lookup(rec,id,wire,spend,true); if item then return M.describe(item,wire,spend) end
  return nil
end)
method('getCapabilities',2,function(rec,spend,id,wire) return adapters.capabilities(targets.lookup(rec,id,wire,spend),spend) end)
method('getConfiguration',2,function(rec,spend,id,wire) return adapters.snapshot(targets.lookup(rec,id,wire,spend),spend) end)
method('setConfiguration',3,function(rec,spend,id,patch,wire) return adapters.apply(targets.lookup(rec,id,wire,spend),rec,patch,spend) end)
method('getSections',2,function(rec,spend,id,wire) return sections.get(targets.lookup(rec,id,wire,spend),spend) end)
method('addSection',3,function(rec,spend,id,definition,wire) return sections.add(targets.lookup(rec,id,wire,spend),rec,definition,spend) end)
method('setSection',4,function(rec,spend,id,index,patch,wire) return sections.set(targets.lookup(rec,id,wire,spend),rec,index,patch,spend) end)
method('removeSection',3,function(rec,spend,id,index,wire) return sections.remove(targets.lookup(rec,id,wire,spend),rec,index,spend) end)
M.methods=methods
local mutations={
  setConfiguration={prepare=function(item,rec,args,spend,cursor) return adapters.prepare(item,rec,args[2],spend,cursor) end,commit=adapters.commit},
  addSection={prepare=function(item,rec,args,spend,cursor) return sections.prepare_add(item,rec,args[2],spend,cursor) end,commit=sections.commit},
  setSection={prepare=function(item,rec,args,spend,cursor) return sections.prepare_set(item,rec,args[2],args[3],spend,cursor) end,commit=sections.commit},
  removeSection={prepare=function(item,rec,args,spend) return sections.prepare_remove(item,rec,args[2],spend) end,commit=sections.commit},
}
local arities={setConfiguration=3,addSection=3,setSection=4,removeSection=3}
local guarded={}
for name,fn in pairs(methods) do
  local mutation=mutations[name]
  guarded[name]=function(c,rec,wire,tick,spend,guard,...)
    if not mutation or not guard.job then return fn(c,rec,wire,tick,spend,...) end
    local args=table.pack(...)
    if args.n~=arities[name] then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
    -- The common owner must prepay both native readback and retained recovery.
    if not guard.commit_configuration then errors.raise('E_BUSY','configurator transaction resource admission unavailable') end
    local id,target_wire=args[1],args[args.n]
    local job=guard.job('configurator.'..name,function() return {id=id,wire=target_wire,phase='prepare',prepare={}} end)
    if job.id~=id or job.wire~=target_wire then errors.raise('E_ARGUMENT','configuration job identity changed') end
    if job.phase=='prepare' then
      local item=targets.lookup(rec,id,target_wire,spend)
      local plan=mutation.prepare(item,rec,args,spend,job.prepare)
      spend(1); job.plan=plan; job.prepare=nil; job.phase='commit'
      guard.suspend()
    end
    return guard.commit_configuration(rec,job.plan,function(commit_spend)
      local item=targets.lookup(rec,id,target_wire,commit_spend)
      return mutation.commit(item,rec,job.plan,commit_spend)
    end)
  end
end
M.guarded_methods=guarded -- Host fixtures exercise the private continuation contract.
peripheral.register_type('configurator',{methods=guarded,with_guard=true})
return M
