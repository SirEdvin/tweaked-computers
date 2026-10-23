-- Deliberate native field adapters, never arbitrary guest property forwarding.
local catalog=require('scripts.configuration.catalog')
local validation=require('scripts.configuration.validation')
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local limits=require('scripts.runtime.limits')
local M={}
local function nop() end
local function unavailable(item,class,name)
  if class=='LuaAsteroidCollectorControlBehavior' and name=='connect_to_logistic_network' then return 'native_asteroid_no_logistic_connection' end
  if class=='LuaTurretControlBehavior' and name=='read_ammo' and item.entity.type=='electric-turret' then return 'ammo_or_fluid_turret_required' end
  if (class=='LuaAssemblingMachineControlBehavior' or class=='LuaFurnaceControlBehavior') and name=='include_fuel' and not item.entity.get_inventory(defines.inventory.fuel) then return 'fuel_inventory_required' end
  if class=='LuaRailSignalBaseControlBehavior' and name=='blue_signal' and item.entity.type~='rail-chain-signal' then return 'rail_chain_signal_only' end
  if class=='LuaLogisticContainerControlBehavior' and name=='circuit_exclusive_mode_of_operation' then
    local mode=item.entity.prototype.logistic_mode
    if mode~='requester' and mode~='buffer' then return 'logistic_mode_requester_or_buffer' end
  end
end
M.unavailable=unavailable
local function sorted(map) local keys={}; for k in pairs(map) do keys[#keys+1]=k end; table.sort(keys); return keys end
local function behavior(item)
  if item.protected then return nil,nil,'owned_mod_device_protected' end
  local cb=item.entity.get_control_behavior()
  if cb then return cb,cb.object_name end
  -- Discovery may describe possible settings, but must never create a behavior.
  local type_name=item.entity.type
  local aliases={['underground-belt']='TransportBelt',['loader-1x1']='Loader',['rail-signal']='RailSignalBase',['rail-chain-signal']='RailSignalBase'}
  local stem=aliases[type_name] or (type_name:sub(1,1):upper()..type_name:sub(2)):gsub('%-(%l)',string.upper)
  local class='Lua'..stem..'ControlBehavior'
  if not catalog.schemas[class] then return nil,nil,'no_supported_native_control_behavior' end
  return nil,class,'control_behavior_unset'
end
function M.summary(item,spend)
  spend(128)
  local _,class,reason=behavior(item); local fields=catalog.schemas[class] or {}
  local readable,writable={},{}
  for _,name in ipairs(sorted(fields)) do
    if fields[name].readable and not unavailable(item,class,name) then readable[#readable+1]=name end
    if fields[name].writable and not unavailable(item,class,name) then writable[#writable+1]=name end
  end
  if not reason and #writable==0 then reason='no_writable_native_settings' end
  return {behavior=class,readable=readable,writable=writable,sections=class=='LuaConstantCombinatorControlBehavior',reason=reason}
end
function M.capabilities(item,spend)
  spend(32)
  local cb,class,reason=behavior(item); local fields=catalog.schemas[class] or {}
  spend(catalog.schema_work[class] or 16)
  local settings={}; local observations={}
  for name,s in pairs(fields) do
    settings[name]=validation.public(s)
    if class=='LuaCargoLandingPadControlBehavior' and name=='circuit_exclusive_mode_of_operation' and not script.feature_flags.space_travel then
      settings[name].values={'none','send_contents'}; settings[name].constraints={'set_requests_requires_space_travel'}
    end
    local restriction=unavailable(item,class,name)
    if restriction then
      settings[name].writable=false; settings[name].unavailable_reason=restriction
      if restriction=='rail_chain_signal_only' then settings[name].readable=false end
    end
    if s.writable and s.concept=='CircuitConditionDefinition' then observations[name..'_fulfilled']={kind='boolean',readable=true,writable=false,clearable=false} end
  end
  if cb then
    local ok,value=pcall(function() return cb.disabled end)
    if ok and type(value)=='boolean' then observations.disabled={kind='boolean',readable=true,writable=false,clearable=false} end
  end
  local writable=false
  for _,s in pairs(fields) do if s.writable then writable=true end end
  if not reason and not writable then reason='no_writable_native_settings' end
  local caps={api_version=1,behavior=class,settings=settings,observations=observations,
    sections={supported=class=='LuaConstantCombinatorControlBehavior',fields=validation.public(catalog.section_fields),limits={}},reason=reason}
  return (data.copy(caps,spend,limits.host_memory_bytes))
end
local function read_snapshot(item,spend)
  spend(256)
  local cb,class=behavior(item); local result={values={},unset={},observations={}}
  for _,name in ipairs(sorted(catalog.schemas[class] or {})) do
    local schema=catalog.schemas[class][name]
    if schema.readable and not (unavailable(item,class,name)=='rail_chain_signal_only') then
      local value=cb and cb[name] or nil
      -- Do not use and/or for false values.
      if cb then value=cb[name] end
      local normal=validation.normal(schema,value)
      if normal==nil then result.unset[#result.unset+1]=name else result.values[name]=normal end
      if value~=nil and schema.concept=='CircuitConditionDefinition' and value.fulfilled~=nil then result.observations[name..'_fulfilled']=value.fulfilled end
    end
  end
  if cb then local ok,value=pcall(function() return cb.disabled end); if ok and type(value)=='boolean' then result.observations.disabled=value end end
  return data.copy(result,spend,limits.host_memory_bytes)
end
function M.snapshot(item,spend) return (read_snapshot(item,spend)) end
-- Signals/modes first, activation switches last; alphabetical within each rank.
local function order(fields)
  local keys=sorted(fields)
  local function rank(k)
    if k=='circuit_enable_disable' or k=='connect_to_logistic_network' or k:match('^set_') or k:match('^circuit_set_') then return 3 end
    if k:match('condition$') then return 2 end
    return 1
  end
  table.sort(keys,function(a,b) local ra,rb=rank(a),rank(b); return ra==rb and a<b or ra<rb end)
  return keys
end
function M.preflight(item,patch,spend,cursor)
  cursor=cursor or {}
  if not cursor.patch then
    local copy,stats=data.copy(patch,spend,limits.host_memory_bytes)
    spend(1); cursor.patch=copy; cursor.stats=stats; cursor.changes={}
  end
  patch=cursor.patch; local stats=cursor.stats
  if type(patch)~='table' then errors.raise('E_ARGUMENT','configuration patch object required') end
  for k in pairs(patch) do if k~='set' and k~='clear' then errors.raise('E_ARGUMENT','unknown patch key',tostring(k)) end end
  if patch.set~=nil and type(patch.set)~='table' then errors.raise('E_ARGUMENT','set map required','set') end
  if patch.clear~=nil and type(patch.clear)~='table' then errors.raise('E_ARGUMENT','clear array required','clear') end
  local _,class=behavior(item); local schemas=catalog.schemas[class] or {}; local changes=cursor.changes
  if cursor.behavior and cursor.behavior~=class then errors.raise('E_BUSY','target behavior changed while validating') end
  cursor.behavior=class
  if cursor.complete then return changes,schemas,patch,stats end
  local function admit(name)
    if type(name)~='string' then errors.raise('E_ARGUMENT','setting name required') end
    local schema=schemas[name]
    if not schema then
      if name=='disabled' or name:match('_fulfilled$') then errors.raise('E_READ_ONLY','observation cannot be set',name) end
      errors.raise(item.protected and 'E_READ_ONLY' or 'E_ARGUMENT','unknown/protected setting',name)
    end
    if not schema.writable or unavailable(item,class,name) then errors.raise('E_UNSUPPORTED',unavailable(item,class,name) or 'native setting not writable',name) end
    if changes[name] then errors.raise('E_ARGUMENT','repeated set/clear field',name) end
    return schema
  end
  for name,value in pairs(patch.set or {}) do
    if not changes[name] then
      local schema=admit(name)
      if not cursor.validation then spend(1); cursor.validation=validation.begin(schema,value,name) end
      validation.resume(cursor.validation,spend)
      if class=='LuaCargoLandingPadControlBehavior' and name=='circuit_exclusive_mode_of_operation' and value=='set_requests' and not script.feature_flags.space_travel then errors.raise('E_UNSUPPORTED','set_requests_requires_space_travel',name) end
      if schema.concept=='ProgrammableSpeakerCircuitParameters' then
        local instrument=item.entity.prototype.instruments[value.instrument_id+1]
        if not instrument or not instrument.notes[value.note_id+1] then errors.raise('E_RANGE','unknown speaker instrument/note',name) end
      end
      spend(stats.bytes+stats.nodes)
      local native=validation.native(schema,value)
      changes[name]={native=native,expected=validation.normal(schema,native)}
      cursor.validation=nil
    end
  end
  local n=0
  for key,name in pairs(patch.clear or {}) do
    n=n+1; if not errors.integer(key,1,#patch.clear) then errors.raise('E_ARGUMENT','clear must be dense array') end
    local schema=admit(name); if not schema.clearable then errors.raise('E_READ_ONLY','setting cannot be cleared',name) end
    changes[name]={clear=true}
  end
  if n~=#(patch.clear or {}) then errors.raise('E_ARGUMENT','clear must be dense array') end
  if item.protected and next(changes) then errors.raise('E_READ_ONLY','owned device cannot be configured') end
  cursor.complete=true
  return changes,schemas,patch,stats
end
local function healthy(item,origin)
  if origin.configuration_recovery and origin.configuration_recovery[item.id] then errors.raise('E_ENGINE','target adapter faulted; retained recovery requires host attention') end
end
function M.prepare(item,origin,patch,spend,cursor)
  healthy(item,origin)
  local changes,schemas,retained_patch,patch_stats=M.preflight(item,patch,spend,cursor)
  local _,class=behavior(item)
  local before,before_stats=read_snapshot(item,spend)
  local field_count=0; for _ in pairs(schemas) do field_count=field_count+1 end
  return {id=item.id,behavior=class,changes=changes,patch=retained_patch,before=before,
    work=3*(before_stats.bytes+patch_stats.bytes+field_count*128+1024)+4*(before_stats.nodes+patch_stats.nodes)+1024}
end
function M.commit(item,origin,plan,spend)
  healthy(item,origin)
  local _,class=behavior(item)
  if item.id~=plan.id or class~=plan.behavior or item.protected and next(plan.changes) then errors.raise('E_UNREACHABLE','prepared target identity or protection changed') end
  local schemas=catalog.schemas[class] or {}
  local changes,before,retained_patch=plan.changes,plan.before,plan.patch
  local current=read_snapshot(item,spend)
  if not validation.equal(current.values,before.values) or not validation.equal(current.unset,before.unset) then
    errors.raise('E_BUSY','target configuration changed while preparing; retry with current configuration')
  end
  for name in pairs(changes) do
    if not schemas[name] or not schemas[name].writable or unavailable(item,class,name) then errors.raise('E_UNSUPPORTED','prepared setting no longer writable',name) end
  end
  if next(changes)==nil then return current end
  -- Reserve every native setter, readback, restoration and defensive publication
  -- before any mutation. No spend call is allowed inside the native transaction.
  -- The replacement payload plus current snapshot bound copied values; the fixed
  -- per-field allowance covers normalized defaults and native getter/setter work.
  spend(plan.work)

  local cb=item.entity.get_control_behavior()
  local absent=not cb
  local function setall(values)
    for _,name in ipairs(order(values)) do cb[name]=values[name].native end
  end
  local ok,result=pcall(function()
    cb=cb or item.entity.get_or_create_control_behavior()
    if not cb then errors.raise('E_UNSUPPORTED','target has no native control behavior') end
    -- Creation is authorized only after whole-patch preflight. Capture its native
    -- defaults too, because restoring an absent behavior is not a delete operation.
    if absent then before=M.snapshot(item,nop) end
    setall(changes)
    local after=M.snapshot(item,nop)
    for name,change in pairs(changes) do
      if change.clear then
        -- A cleared native condition reads back its engine default, not necessarily nil.
        local s=schemas[name]; local default
        if s.concept=='CircuitConditionDefinition' then default=validation.normal(s,{comparator='<',constant=0})
        elseif s.concept=='ArithmeticCombinatorParameters' or s.concept=='SelectorCombinatorParameters' then default=validation.normal(s,{})
        elseif s.concept=='DeciderCombinatorParameters' then default=validation.normal(s,{conditions={{}},outputs={{}}}) end
        if not validation.equal(after.values[name],default) and after.values[name]~=nil then errors.raise('E_ENGINE','cleared setting readback differs',name) end
      elseif not validation.equal(after.values[name],change.expected) then errors.raise('E_ENGINE','native setter readback differs',name) end
    end
    return after
  end)
  if ok then return result end
  local restored=pcall(function()
    if not item.entity.valid or not cb or not cb.valid then error('target removed') end
    local prior={}
    for name in pairs(changes) do prior[name]={native=validation.native(schemas[name],before.values[name])} end
    setall(prior)
    local actual=M.snapshot(item,nop)
    if not validation.equal(actual.values,before.values) or not validation.equal(actual.unset,before.unset) then error('restoration readback differs') end
  end)
  if not restored then
    origin.configuration_recovery=origin.configuration_recovery or {}
    origin.configuration_recovery[item.id]={device=item.id,before=before,patch=retained_patch,
      tick=game.tick,reason='native failure; target-local restoration failed',behavior=class,created_behavior=absent}
  end
  local e=errors.new('E_ENGINE',restored and 'native update failed; target settings restored (external effects not rolled back)' or 'native update failed; restoration failed; target-local recovery retained')
  e.device=item.id; error(e,0)
end
function M.apply(item,origin,patch,spend)
  return M.commit(item,origin,M.prepare(item,origin,patch,spend),spend)
end
return M
