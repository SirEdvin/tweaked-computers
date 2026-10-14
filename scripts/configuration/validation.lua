local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local M={}
local registries={item='item',fluid='fluid',virtual='virtual_signal',entity='entity',recipe='recipe',
  ['space-location']='space_location',['asteroid-chunk']='asteroid_chunk',quality='quality'}
function M.enum(path)
  local value=_G
  for part in path:gmatch('[^.]+') do value=value[part] end
  return value
end
local function fail(code,path,message) errors.raise(code,message,path) end
local function exists(registry,name,path)
  if type(name)~='string' or not prototypes[registry] or not prototypes[registry][name] then fail('E_RANGE',path,'unknown prototype identity') end
end
function M.validate(schema,value,path,context)
  local kind=schema.kind
  if kind=='boolean' then
    if type(value)~='boolean' then fail('E_ARGUMENT',path,'boolean required') end
  elseif kind=='integer' or kind=='number' then
    if not errors.finite(value) or (kind=='integer' and value~=math.floor(value)) then fail('E_ARGUMENT',path,'finite numeric value required') end
    if value<(schema.min or -9007199254740991) or value>(schema.max or 9007199254740991) then fail('E_RANGE',path,'number outside schema range') end
  elseif kind=='string' then
    if type(value)~='string' then fail('E_ARGUMENT',path,'string required') end
    if #value>(schema.max_bytes or 256) or value:find('\0',1,true) then fail('E_RANGE',path,'invalid identity/string size') end
    if schema.prototype_registry then exists(schema.prototype_registry,value,path) end
  elseif kind=='enum' then
    local found=false; for _,v in ipairs(schema.values) do if v==value then found=true end end
    if not found then fail('E_RANGE',path,'unknown enum name') end
  elseif kind=='object' then
    if type(value)~='table' or getmetatable(value) then fail('E_ARGUMENT',path,'plain object required') end
    for key,v in pairs(value) do
      if not schema.fields[key] then fail(key=='fulfilled' and 'E_READ_ONLY' or 'E_ARGUMENT',path..'.'..tostring(key),'unknown or read-only nested field') end
      local role=context
      if schema.concept=='CircuitConditionDefinition' then
        if key=='first_signal' then role='condition_first' elseif key=='second_signal' then role='condition_second' end
      end
      M.validate(schema.fields[key],v,path..'.'..key,role)
    end
    for _,key in ipairs(schema.required or {}) do if value[key]==nil then fail('E_ARGUMENT',path..'.'..key,'required field missing') end end
    if schema.concept=='SignalID' or schema.concept=='SignalIDBase' then
      exists(registries[value.type],value.name,path..'.name')
      if value.quality then exists('quality',value.quality,path..'.quality') end
      if value.name=='signal-each' or value.name=='signal-anything' or value.name=='signal-everything' then
        if context~='condition_first' or value.type~='virtual' or value.name=='signal-each' then fail('E_RANGE',path,'wildcard invalid in this signal role') end
      end
    elseif schema.concept=='CircuitConditionDefinition' then
      if value.constant~=nil and value.second_signal~=nil then fail('E_ARGUMENT',path,'constant and second_signal are exclusive') end
      -- Nested validation above checks identity; repeat with precise wildcard role.
      if value.first_signal then M.validate(schema.fields.first_signal,value.first_signal,path..'.first_signal','condition_first') end
      if value.second_signal then M.validate(schema.fields.second_signal,value.second_signal,path..'.second_signal','condition_second') end
    end
  elseif kind=='array' then
    if type(value)~='table' or getmetatable(value) then fail('E_ARGUMENT',path,'dense array required') end
    local n=0; for k,v in pairs(value) do n=n+1; if not errors.integer(k,1,schema.max_items) then fail('E_ARGUMENT',path,'dense bounded indexes required') end; M.validate(schema.items,v,path..'['..k..']',context) end
    if n~=#value or n>schema.max_items then fail('E_ARGUMENT',path,'dense bounded array required') end
  elseif kind=='union' then
    for _,s in ipairs(schema.alternatives) do if pcall(M.validate,s,value,path,context) then return end end
    fail('E_ARGUMENT',path,'no matching union alternative')
  else fail('E_UNSUPPORTED',path,'explicit adapter required for this type') end
end
function M.native(schema,value)
  if value==nil then return nil end
  if schema.native_enum then return M.enum(schema.native_enum)[value] end
  if schema.kind=='object' then
    local result={}; for key,v in pairs(value) do result[key]=M.native(schema.fields[key],v) end
    if schema.concept=='SignalID' then result.quality=result.quality or 'normal' end
    return result
  end
  if schema.kind=='array' then local result={}; for i,v in ipairs(value) do result[i]=M.native(schema.items,v) end; return result end
  return value
end
function M.normal(schema,value)
  if value==nil then return nil end
  if schema.native_enum then for name,v in pairs(M.enum(schema.native_enum)) do if v==value then return name end end; fail('E_ENGINE',nil,'unknown native enum value') end
  if schema.prototype_registry then return type(value)=='string' and value or value.name end
  if schema.kind=='object' then
    local result={}; for key,s in pairs(schema.fields) do if value[key]~=nil then result[key]=M.normal(s,value[key]) end end
    if schema.concept=='SignalID' or schema.concept=='SignalIDBase' then
      if not result.name then return nil end
      result.type=result.type or 'item'; if schema.concept=='SignalID' then result.quality=result.quality or 'normal' end
    elseif schema.concept=='CircuitConditionDefinition' then
      result.comparator=result.comparator or '<'
      local aliases={['>=']='≥',['<=']='≤',['!=']='≠'}; result.comparator=aliases[result.comparator] or result.comparator
      if result.second_signal then result.constant=nil else result.constant=result.constant or 0 end
    end
    return result
  end
  if schema.kind=='array' then local result={}; for i,v in ipairs(value) do result[i]=M.normal(schema.items,v) end; return result end
  if schema.kind=='boolean' or schema.kind=='integer' or schema.kind=='number' or schema.kind=='string' or schema.kind=='enum' then return value end
  fail('E_ENGINE',nil,'native result needs explicit normalization')
end
function M.equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not M.equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
function M.public(schema)
  local result={}
  for k,v in pairs(schema) do
    if k~='native_enum' and k~='concept' and k~='variants' then
      if type(v)=='table' then result[k]=M.public(v) else result[k]=v end
    end
  end
  return result
end
return M
