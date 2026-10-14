local peripheral=require('scripts.services.peripheral')
local targets=require('scripts.configuration.targets')
local adapters=require('scripts.configuration.adapters')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local common_limits=require('scripts.runtime.limits')
local sections=require('scripts.configuration.sections')
local M={}
local function keys(map) local result={}; for k in pairs(map) do result[#result+1]=k end; table.sort(result); return result end
function M.describe(item,wire,spend)
  local entity=item.entity; local summary=adapters.summary(item,spend)
  local direction
  for name,value in pairs(defines.direction) do if value==entity.direction then direction=name; break end end
  return (data.copy({id=item.id,prototype=entity.name,type=entity.type,position={x=entity.position.x,y=entity.position.y},
    surface={index=entity.surface.index,name=entity.surface.name},direction=direction,quality=entity.quality.name,
    target_wire=wire,connected_connector_ids=keys(item.connectors),configurable=#summary.writable>0,
    configuration=summary},spend))
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
  for k,v in pairs(adapters.limits) do limits[k]=v end
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
peripheral.register_type('configurator',{methods=methods})
return M
