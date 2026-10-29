-- Stateless installed metadata; authority and defensive transfer stay in the facade.
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local peripheral=require('scripts.services.peripheral')
local M={}
local function unsupported(field) errors.raise('E_UNSUPPORTED','unsupported catalogue metadata',field) end
local function native(fn)
  local ok,value=pcall(fn)
  if not ok then errors.raise('E_ENGINE','catalogue access failed') end
  return value
end
local function arity(n,...)
  if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
end
local function name(value,spend)
  if type(value)~='string' or #value==0 then errors.raise('E_ARGUMENT','nonempty name required','name') end
  if #value>limits.string_bytes then errors.raise('E_LIMIT','name exceeds string limit','name') end
  spend(#value+1)
  return value
end
local function number(value,field,minimum,integer)
  if not errors.finite(value) or minimum and value<minimum
    or integer and (value%1~=0 or value>9007199254740991) then unsupported(field) end
  return value
end
local function reference(value)
  if value==nil then return nil end
  return value.name
end
local function common(p,kind)
  return {type=kind,name=p.name,prototype_type=p.type,group=p.group.name,subgroup=p.subgroup.name,
    order=p.order,hidden=p.hidden,hidden_in_factoriopedia=p.hidden_in_factoriopedia,parameter=p.parameter,
    factoriopedia_alternative=reference(p.factoriopedia_alternative)}
end
local function project(p,kind,spend)
  -- Admit native materialization before reading; no guard call is caught as E_ENGINE.
  spend(32)
  local result=native(function()
    local t=common(p,kind)
    if kind=='item' then
      t.stack_size=p.stack_size; t.stackable=p.stackable; t.weight=p.weight
      t.default_rocket_lift_weight=prototypes.utility_constants.default_rocket_lift_weight
      t.fuel_value=p.fuel_value; t.fuel_categories=p.fuel_categories or {}
      t.burnt_result=reference(p.burnt_result); t.spoil_ticks=p.get_spoil_ticks('normal')
      t.quality_affects_spoil_ticks=p.quality_affects_spoil_ticks; t.spoil_result=reference(p.spoil_result)
      t.place_result=reference(p.place_result); t.default_import_location=reference(p.default_import_location)
    else
      t.default_temperature=p.default_temperature; t.max_temperature=p.max_temperature
      t.gas_temperature=p.gas_temperature; t.heat_capacity=p.heat_capacity
      t.fuel_value=p.fuel_value; t.emissions_multiplier=p.emissions_multiplier
    end
    return t
  end)
  for _,key in ipairs({'type','name','prototype_type','group','subgroup','order'}) do
    if type(result[key])~='string' then unsupported(key) end
  end
  for _,key in ipairs({'hidden','hidden_in_factoriopedia','parameter'}) do
    if type(result[key])~='boolean' then unsupported(key) end
  end
  if kind=='item' then
    number(result.stack_size,'stack_size',1,true)
    number(result.weight,'weight',0)
    number(result.default_rocket_lift_weight,'default_rocket_lift_weight',0)
    if result.default_rocket_lift_weight==0 then unsupported('default_rocket_lift_weight') end
    number(result.spoil_ticks,'spoil_ticks',0,true)
    if type(result.stackable)~='boolean' or type(result.quality_affects_spoil_ticks)~='boolean' then unsupported('item flags') end
    if result.weight>0 then
      result.rocket_capacity=number(math.floor(result.default_rocket_lift_weight/result.weight),'rocket_capacity',0,true)
    end
    if type(result.fuel_categories)~='table' then unsupported('fuel_categories') end
    if #result.fuel_categories>limits.table_entries then errors.raise('E_LIMIT','fuel categories exceed Data limits') end
    local categories={}
    for i,v in ipairs(result.fuel_categories) do
      if type(v)~='string' then unsupported('fuel_categories') end
      spend(#v+1); categories[i]=v
    end
    result.fuel_categories=categories
    for _,key in ipairs({'burnt_result','spoil_result','place_result','default_import_location'}) do
      if result[key]~=nil and type(result[key])~='string' then unsupported(key) end
    end
  else
    for _,key in ipairs({'default_temperature','max_temperature','gas_temperature'}) do number(result[key],key) end
    for _,key in ipairs({'heat_capacity','emissions_multiplier'}) do number(result[key],key,0) end
  end
  number(result.fuel_value,'fuel_value',0)
  if result.factoriopedia_alternative~=nil and type(result.factoriopedia_alternative)~='string' then unsupported('factoriopedia_alternative') end
  return result
end
local methods={}
function methods.getLimits(_,_,_,_,spend,...)
  arity(0,...)
  local result={}
  for k,v in pairs(limits) do spend(#k+1); result[k]=v end
  return result
end
local function lookup(kind,spend,...)
  arity(1,...)
  local key=name(...,spend)
  spend(32)
  local p=native(function() return prototypes[kind][key] end)
  if not p then errors.raise('E_RANGE','unknown prototype name','name') end
  return project(p,kind,spend)
end
local function names(kind,spend,...)
  arity(0,...)
  spend(32)
  local catalogue=native(function() return prototypes[kind] end)
  local result={}; local bytes=0
  local iterator=native(function() return {pairs(catalogue)} end)
  local key
  -- Bound staging by the same dense-array Data entry/node/byte allowances.
  while true do
    spend(1)
    key=native(function() return iterator[1](iterator[2],key) end)
    if key==nil then break end
    if type(key)~='string' then unsupported('name') end
    local count=#result+1
    bytes=bytes+#key
    if count>limits.table_entries or count+1>limits.data_nodes or #key>limits.string_bytes
      or bytes>limits.peripheral_call_bytes then errors.raise('E_LIMIT','complete catalogue exceeds Data limits') end
    spend(#key+1); result[count]=key
  end
  table.sort(result,function(a,b) spend(#a+#b+1); return a<b end)
  return result
end
function methods.getItem(_,_,_,_,spend,...) return lookup('item',spend,...) end
function methods.getFluid(_,_,_,_,spend,...) return lookup('fluid',spend,...) end
function methods.listItems(_,_,_,_,spend,...) return names('item',spend,...) end
function methods.listFluids(_,_,_,_,spend,...) return names('fluid',spend,...) end
M.methods=methods
peripheral.register_type('factoriopedia_interface',{methods=methods})
return M
