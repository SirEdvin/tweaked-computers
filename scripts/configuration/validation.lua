local errors=require('scripts.runtime.errors')
local M={}
local registries={item='item',fluid='fluid',virtual='virtual_signal',entity='entity',recipe='recipe',
  ['space-location']='space_location',['asteroid-chunk']='asteroid_chunk',quality='quality'}
local wild={['signal-each']=true,['signal-anything']=true,['signal-everything']=true}
local aliases={['>=']='≥',['<=']='≤',['!=']='≠'}
function M.enum(path)
  local value=_G
  for part in path:gmatch('[^.]+') do value=value[part] end
  return value
end
local function fail(code,path,message) errors.raise(code,message,path) end
local function exists(registry,name,path)
  if type(name)~='string' or not registry or not prototypes[registry] or not prototypes[registry][name] then fail('E_RANGE',path,'unknown prototype identity') end
end
local function signal(value,path,role)
  exists(registries[value.type],value.name,path..'.name')
  if value.quality then exists('quality',value.quality,path..'.quality') end
  if wild[value.name] then
    local allowed=value.type=='virtual' and (
      (role=='condition_first' and value.name~='signal-each') or
      (role=='arithmetic_first' and value.name=='signal-each') or
      (role=='arithmetic_output' and value.name=='signal-each') or
      role=='decider_first' or
      role=='decider_output')
    if not allowed then fail('E_RANGE',path,'wildcard invalid in this signal role') end
  end
end
local function role_for(concept,key,context)
  if concept=='CircuitConditionDefinition' and key=='first_signal' then return 'condition_first' end
  if concept=='ArithmeticCombinatorParameters' then
    if key=='first_signal' then return 'arithmetic_first' end
    if key=='output_signal' then return 'arithmetic_output' end
  end
  if concept=='DeciderCombinatorCondition' and key=='first_signal' then return 'decider_first' end
  if concept=='DeciderCombinatorOutput' and key=='signal' then return 'decider_output' end
  if key=='second_signal' then return nil end
  return context
end
function M.validate(schema,value,path,context)
  local kind=schema.kind; local concept=schema.concept
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
      M.validate(schema.fields[key],v,path..'.'..key,role_for(concept,key,context))
    end
    for _,key in ipairs(schema.required or {}) do if value[key]==nil then fail('E_ARGUMENT',path..'.'..key,'required field missing') end end
    if schema.variants then
      local operation=value.operation or 'select'; local variant=schema.variants[operation]; local allowed={operation=true}
      if variant then
        for _,k in ipairs(variant.fields) do allowed[k]=true end
        for _,k in ipairs(variant.required) do if value[k]==nil then fail('E_ARGUMENT',path..'.'..k,'required operation field missing') end end
      end
      for key in pairs(value) do if not allowed[key] then fail('E_ARGUMENT',path..'.'..key,'field is not applicable to this operation') end end
    end
    if concept=='SignalID' or concept=='SignalIDBase' then signal(value,path,context)
    elseif concept=='CircuitConditionDefinition' then
      if value.constant~=nil and value.second_signal~=nil then fail('E_ARGUMENT',path,'constant and second_signal are exclusive') end
    elseif concept=='ArithmeticCombinatorParameters' then
      if value.output_signal and value.output_signal.name=='signal-each' and (not value.first_signal or value.first_signal.name~='signal-each') then fail('E_ARGUMENT',path,'each output requires each input') end
    elseif concept=='DeciderCombinatorParameters' then
      local each=false
      for _,c in ipairs(value.conditions) do if c.first_signal and c.first_signal.name=='signal-each' then each=true end end
      for _,o in ipairs(value.outputs) do if o.signal.name=='signal-each' and not each then fail('E_ARGUMENT',path,'each output requires an each condition') end end
    elseif concept=='BlueprintQualityID' then
      if value.name then exists('quality',value.name,path..'.name') end
    elseif concept=='LogisticFilter' then
      if value.max and value.min and value.max<value.min then fail('E_RANGE',path,'filter maximum below minimum') end
      if value.value and (value.min or 0)~=0 and type(value.value)=='table' and ((value.value.comparator or '=')~='=' or not value.value.quality) then fail('E_ARGUMENT',path,'nonzero filter requires exact quality') end
    end
  elseif kind=='array' then
    if type(value)~='table' or getmetatable(value) then fail('E_ARGUMENT',path,'dense array required') end
    local n=0; for k,v in pairs(value) do n=n+1; if not errors.integer(k,1,schema.max_items) then fail('E_ARGUMENT',path,'dense bounded indexes required') end; M.validate(schema.items,v,path..'['..k..']',context) end
    if n~=#value or n>schema.max_items then fail('E_ARGUMENT',path,'dense bounded array required') end
  elseif kind=='union' then
    local found=false
    for _,s in ipairs(schema.alternatives) do
      if (s.kind=='object' and type(value)=='table') or (s.kind=='string' and type(value)=='string') then
        M.validate(s,value,path,context); found=true; break
      end
    end
    if not found then fail('E_ARGUMENT',path,'no matching union alternative') end
    if concept=='QualityCondition' then exists('quality',type(value)=='string' and value or value.quality or 'normal',path)
    elseif concept=='SignalFilter' then
      local v=value
      if type(v)=='string' then v={type=prototypes.virtual_signal[v] and 'virtual' or 'item',name=v,quality='normal'} end
      signal({type=v.type or 'item',name=v.name,quality=v.quality},path,nil)
    end
  else fail('E_UNSUPPORTED',path,'explicit adapter required for this type') end
end
local function alternative(schema,value)
  for _,s in ipairs(schema.alternatives) do
    if (s.kind=='object' and type(value)=='table') or (s.kind=='string' and type(value)=='string') then return s end
  end
  fail('E_ENGINE',nil,'unknown native union value')
end
function M.native(schema,value)
  if value==nil then return nil end
  if schema.native_enum then return M.enum(schema.native_enum)[value] end
  if schema.kind=='union' then return M.native(alternative(schema,value),value) end
  if schema.kind=='object' then
    local result={}; for key,v in pairs(value) do result[key]=M.native(schema.fields[key],v) end
    if schema.concept=='SignalID' then result.quality=result.quality or 'normal' end
    return result
  end
  if schema.kind=='array' then local result={}; for i,v in ipairs(value) do result[i]=M.native(schema.items,v) end; return result end
  return value
end
local function networks(value) return {red=value==nil or value.red~=false,green=value==nil or value.green~=false} end
function M.normal(schema,value)
  if value==nil then return nil end
  if schema.native_enum then for name,v in pairs(M.enum(schema.native_enum)) do if v==value then return name end end; fail('E_ENGINE',nil,'unknown native enum value') end
  if schema.prototype_registry then return type(value)=='string' and value or value.name end
  if schema.concept=='QualityCondition' then
    if type(value)=='string' then return {quality=value,comparator='='} end
    return {quality=type(value.quality)=='table' and value.quality.name or value.quality or 'normal',comparator=aliases[value.comparator] or value.comparator or '='}
  end
  if schema.concept=='SignalFilter' then
    if type(value)=='string' then value={name=value,type=prototypes.virtual_signal[value] and 'virtual' or 'item'} end
    return {name=value.name,type=value.type or 'item',quality=type(value.quality)=='string' and value.quality or value.quality and value.quality.name or 'normal',comparator=aliases[value.comparator] or value.comparator or '='}
  end
  if schema.kind=='union' then return M.normal(alternative(schema,value),value) end
  if schema.kind=='object' then
    local result={}; for key,s in pairs(schema.fields) do if value[key]~=nil then result[key]=M.normal(s,value[key]) end end
    local c=schema.concept
    if c=='SignalID' or c=='SignalIDBase' then
      if not result.name then return nil end
      result.type=result.type or 'item'; if c=='SignalID' then result.quality=result.quality or 'normal' end
    elseif c=='CircuitConditionDefinition' or c=='DeciderCombinatorCondition' then
      result.comparator=aliases[result.comparator] or result.comparator or '<'
      if result.second_signal then result.constant=nil else result.constant=result.constant or 0 end
      if c=='DeciderCombinatorCondition' then
        result.compare_type=result.compare_type or 'or'; result.first_signal_networks=networks(result.first_signal_networks); result.second_signal_networks=networks(result.second_signal_networks)
      end
    elseif c=='CircuitNetworkSelection' then return networks(result)
    elseif c=='ArithmeticCombinatorParameters' then
      result.operation=result.operation or '*'
      if result.first_signal then result.first_constant=nil else result.first_constant=result.first_constant or 0 end
      if result.second_signal then result.second_constant=nil else result.second_constant=result.second_constant or 0 end
      result.first_signal_networks=networks(result.first_signal_networks); result.second_signal_networks=networks(result.second_signal_networks)
    elseif c=='DeciderCombinatorOutput' then
      result.constant=result.constant or 1
      if result.copy_count_from_input==nil then result.copy_count_from_input=true end
      result.networks=networks(result.networks)
    elseif c=='SelectorCombinatorParameters' then
      result.operation=result.operation or 'select'
      if result.operation=='select' then
        if not result.index_signal then result.index_constant=result.index_constant or 0 else result.index_constant=nil end
        if result.select_max==nil then result.select_max=true end
      elseif result.operation=='random' then result.random_update_interval=result.random_update_interval or 0
      elseif result.operation=='quality-transfer' then
        if result.select_quality_from_signal==nil then result.select_quality_from_signal=false end
        if result.select_quality_from_signal then result.quality_source_static=nil
        else result.quality_source_signal=nil; result.quality_source_static=result.quality_source_static or {name='normal'} end
      end
    elseif c=='BlueprintQualityID' then result.name=result.name or 'normal'
    elseif c=='LogisticFilter' then
      result.min=result.min or 0
      if result.value and result.value.type=='item' and not result.import_from and prototypes.space_location.nauvis then result.import_from='nauvis' end
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
    if k~='native_enum' and k~='concept' then
      if type(v)=='table' then result[k]=M.public(v) else result[k]=v end
    end
  end
  return result
end
return M
