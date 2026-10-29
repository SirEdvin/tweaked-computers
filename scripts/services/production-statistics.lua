-- Native local snapshots only; the facade owns authority, power and transfer.
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local peripheral=require('scripts.services.peripheral')
local M={}
local windows={five_seconds=true,one_minute=true,ten_minutes=true,one_hour=true,ten_hours=true,
  fifty_hours=true,two_hundred_fifty_hours=true,one_thousand_hours=true}
local function native(fn,...)
  local ok,value=pcall(fn,...)
  if not ok then errors.raise('E_ENGINE','native statistics access failed') end
  return value
end
local function arity(n,...)
  if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
end
local function name(value,field,spend)
  if type(value)~='string' or #value==0 then errors.raise('E_ARGUMENT','nonempty string required',field) end
  if #value>limits.string_bytes then errors.raise('E_LIMIT','string exceeds Data limit',field) end
  spend(#value+1); return value
end
local function category(kind,spend)
  name(kind,'kind',spend)
  if kind~='item' and kind~='fluid' and kind~='pollution' then errors.raise('E_RANGE','unknown statistics kind','kind') end
end
local function precision(window,spend)
  name(window,'window',spend)
  if not windows[window] then errors.raise('E_RANGE','unknown statistics window','window') end
  return defines.flow_precision_index[window]
end
local function statistics(rec,kind,spend)
  spend(32)
  return native(function()
    local body=rec.body
    if kind=='item' then return body.force.get_item_production_statistics(body.surface) end
    if kind=='fluid' then return body.force.get_fluid_production_statistics(body.surface) end
    return body.surface.pollution_statistics
  end)
end
local function finite(value)
  if not errors.finite(value) then errors.raise('E_UNSUPPORTED','nonfinite native statistics value') end
  return value
end
local function counts(stats,kind,side,spend)
  spend(32)
  local map=native(function() return stats[side..(kind=='item' and '_quality_counts' or '_counts')] end)
  if type(map)~='table' then errors.raise('E_UNSUPPORTED','unsupported native statistics map') end
  return map
end
local function flow(stats,id,side,index,sample,spend)
  spend(32)
  return finite(native(stats.get_flow_count,{name=id,category=side,precision_index=index,sample_index=sample,count=false}))
end
local function bulk(rec,tick,spend,kind,index)
  local stats=statistics(rec,kind,spend)
  local result={tick=tick}
  for _,side in ipairs({'input','output'}) do
    local map=counts(stats,kind,side,spend)
    -- The native getters already detach these maps; do not make a second copy.
    for key,value in pairs(map) do
      if type(key)~='string' then errors.raise('E_UNSUPPORTED','unsupported native statistics key') end
      spend(#key+1)
      if kind=='item' then
        if type(value)~='table' then errors.raise('E_UNSUPPORTED','unsupported native quality map') end
        for item,total in pairs(value) do
          if type(item)~='string' then errors.raise('E_UNSUPPORTED','unsupported native item key') end
          spend(#item+1); finite(total)
          if index then value[item]=flow(stats,{name=item,quality=key},side,index,nil,spend) end
        end
      else
        finite(value)
        if index then map[key]=flow(stats,key,side,index,nil,spend) end
      end
    end
    result[side]=map
  end
  return result
end
local methods={}
function methods.getLimits(_,_,_,_,spend,...)
  arity(0,...)
  local result={}; for k,v in pairs(limits) do spend(#k+1); result[k]=v end
  return result
end
function methods.getTotals(_,rec,_,tick,spend,...)
  arity(1,...); local kind=...; category(kind,spend)
  return bulk(rec,tick,spend,kind)
end
function methods.getRates(_,rec,_,tick,spend,...)
  arity(2,...); local kind,window=...; category(kind,spend)
  return bulk(rec,tick,spend,kind,precision(window,spend))
end
function methods.getHistory(_,rec,_,tick,spend,...)
  local n=select('#',...)
  if n~=3 and n~=4 then errors.raise('E_ARGUMENT','getHistory expects three or four arguments; use dot calls') end
  local kind,key,window,quality=...
  category(kind,spend); name(key,'name',spend); local index=precision(window,spend)
  if kind~='item' and quality~=nil then errors.raise('E_ARGUMENT','quality is item-only','quality') end
  if kind=='item' then
    if quality==nil then quality='normal' end
    name(quality,'quality',spend)
    spend(32)
    if not native(function() return prototypes.quality[quality] end) then errors.raise('E_RANGE','unknown quality','quality') end
  end
  local stats=statistics(rec,kind,spend)
  spend(32)
  local known=native(function() return prototypes[kind=='pollution' and 'entity' or kind][key] end)
  if not known and kind=='pollution' then
    known=counts(stats,kind,'input',spend)[key]~=nil or counts(stats,kind,'output',spend)[key]~=nil
  end
  if not known then errors.raise('E_RANGE','unknown statistics identity','name') end
  local id=kind=='item' and {name=key,quality=quality} or key
  local result={tick=tick,input={},output={}}
  for i=1,300 do
    result.input[i]=flow(stats,id,'input',index,i,spend)
    result.output[i]=flow(stats,id,'output',index,i,spend)
  end
  return result
end
M.methods=methods
peripheral.register_type('production_statistics',{methods=methods})
return M
