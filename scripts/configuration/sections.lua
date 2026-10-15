-- Target-local constant section operations. Shared contents are never written.
local catalog=require('scripts.configuration.catalog')
local validation=require('scripts.configuration.validation')
local adapters=require('scripts.configuration.adapters')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local M={}
local limits=adapters.limits
local function nop() end
local function control(item,create)
  if item.protected then errors.raise('E_READ_ONLY','owned device protected') end
  if item.entity.type~='constant-combinator' then errors.raise('E_UNSUPPORTED','constant combinator required') end
  return item.entity.get_control_behavior() or (create and item.entity.get_or_create_control_behavior())
end
local function index(i)
  if not errors.integer(i,1,4294967295) then errors.raise('E_ARGUMENT','positive native section index required') end
end
local function type_name(value)
  for name,v in pairs(defines.logistic_section_type) do if value==v then return name end end
  errors.raise('E_ENGINE','unknown native section type')
end
local function read(section,spend)
  spend(128)
  if section.filters_count>limits.section_filters then errors.raise('E_LIMIT','native section filter capacity exceeds supported envelope') end
  spend(section.filters_count*64)
  local filters={}
  for i=1,section.filters_count do
    local value=section.get_slot(i)
    if value.value then
      local v=validation.normal(catalog.section_fields.filters.items,value); v.index=i
      filters[#filters+1]=v
    end
  end
  local fields=validation.public(catalog.section_fields)
  for name,s in pairs(fields) do
    s.writable=section.is_manual
    if not section.is_manual then s.unavailable_reason='nonmanual_section' end
    if name=='filters' and section.group~='' then s.writable=false; s.unavailable_reason='shared_group_detach_first' end
  end
  return {index=section.index,type=type_name(section.type),is_manual=section.is_manual,active=section.active,
    group=section.group,multiplier=section.multiplier,filters=filters,filters_count=section.filters_count,capabilities=fields}
end
function M.get(item,spend)
  local cb=control(item,false); local result={}
  if cb then
    if cb.sections_count>limits.sections then errors.raise('E_LIMIT','native section capacity exceeds supported envelope') end
    for i=1,cb.sections_count do result[#result+1]=read(assert(cb.get_section(i)),spend) end
  end
  return (data.copy(result,spend,limits.configuration_bytes))
end
local function fields(value,spend,patch)
  value=data.copy(value,spend,limits.configuration_bytes)
  if type(value)~='table' then errors.raise('E_ARGUMENT','section object required') end
  local set=value
  if patch then
    for k in pairs(value) do if k~='set' and k~='clear' then errors.raise('E_ARGUMENT','unknown section patch key',tostring(k)) end end
    if value.clear~=nil then
      if type(value.clear)~='table' or next(value.clear) then errors.raise('E_READ_ONLY','section fields cannot be cleared; replace filters with an empty array') end
    end
    set=value.set or {}
    if type(set)~='table' then errors.raise('E_ARGUMENT','section set map required') end
  end
  for name,v in pairs(set) do
    local schema=catalog.section_fields[name]
    if not schema then errors.raise('E_ARGUMENT','unknown section field',tostring(name)) end
    validation.validate(schema,v,name)
  end
  if set.filters then
    local seen={}
    local identities={}
    for _,v in ipairs(set.filters) do
      if seen[v.index] then errors.raise('E_ARGUMENT','duplicate filter index','filters') end
      seen[v.index]=true
      local normal=validation.normal(catalog.section_fields.filters.items,validation.native(catalog.section_fields.filters.items,v))
      if normal.value then
        local pieces={}; local bytes=0
        for _,s in ipairs({normal.value.type,normal.value.name,normal.value.quality,normal.value.comparator,normal.import_from or ''}) do
          spend(#s*2+32); local piece=#s..':'..s; pieces[#pieces+1]=piece; bytes=bytes+#piece
        end
        spend(bytes*2+16); local key=table.concat(pieces)
        if identities[key] then errors.raise('E_ARGUMENT','duplicate native filter identity','filters') end
        identities[key]=true
      end
    end
  end
  return set,value
end
local function filters_native(section,filters)
  section.filters={}
  for _,v in ipairs(filters) do
    local native=validation.native(catalog.section_fields.filters.items,v); native.index=nil
    section.set_slot(v.index,native)
  end
end
local function write(section,values,before)
  -- Detaching is explicit and preserves effective contents before replacements.
  if values.group~=nil and values.group~=section.group then
    section.group=values.group
    if values.group=='' then filters_native(section,before and before.filters or {}) end
  end
  if values.filters~=nil then filters_native(section,values.filters) end
  if values.multiplier~=nil then section.multiplier=values.multiplier end
  if values.active~=nil then section.active=values.active end
end
local function verify(section,values,before)
  local actual=read(section,nop)
  for name,v in pairs(values) do
    local expected=validation.normal(catalog.section_fields[name],validation.native(catalog.section_fields[name],v))
    if name=='filters' then
      local effective={}; for _,v in ipairs(expected) do if v.value then effective[#effective+1]=v end end
      expected=effective; table.sort(expected,function(a,b) return a.index<b.index end)
    end
    local equal=validation.equal(actual[name],expected)
    -- Native multiplier is float32; return its exact readback, allowing only its
    -- documented storage-rounding envelope during verification.
    if name=='multiplier' then equal=math.abs(actual[name]-expected)<=2^-23*math.max(math.abs(expected),2^-126) end
    if not equal then error('section native readback differs: '..name) end
  end
  if values.group=='' and values.filters==nil and before and not validation.equal(actual.filters,before.filters) then error('detach lost effective contents') end
  return actual
end
local function guard(item,origin)
  if origin.configuration_recovery and origin.configuration_recovery[item.id] then errors.raise('E_ENGINE','target adapter faulted; retained recovery requires host attention') end
  local n=0; for _ in pairs(origin.configuration_recovery or {}) do n=n+1 end
  if n>=limits.target_nodes then errors.raise('E_CAPACITY','adapter recovery inventory full') end
end
local function failure(item,origin,before,request,restore)
  local restored=pcall(restore)
  if not restored then
    origin.configuration_recovery=origin.configuration_recovery or {}
    origin.configuration_recovery[item.id]={device=item.id,before=before,patch=request,tick=game.tick,
      behavior='LuaConstantCombinatorControlBehavior',reason='section failure; target-local restoration failed'}
  end
  errors.raise('E_ENGINE',restored and 'section update failed; target-local settings restored' or 'section update failed; target-local recovery retained')
end
function M.set(item,origin,i,patch,spend)
  index(i); guard(item,origin)
  local values,request=fields(patch,spend,true)
  local before_all=M.get(item,spend); local before=before_all[i]
  if not before then errors.raise('E_NOT_FOUND','section does not exist') end
  if not before.is_manual then errors.raise('E_READ_ONLY','nonmanual section protected') end
  local final_group=values.group
  if final_group==nil then final_group=before.group end
  if values.filters~=nil and final_group~='' then errors.raise('E_SHARED_SCOPE','shared filter writes refused; explicitly detach first') end
  -- Reserve bounded setter + readback + restoration including saved effective filters.
  local _,stats=data.copy({before=before_all,request=request},spend,limits.configuration_bytes)
  spend(stats.bytes*3+stats.nodes*4+(#before.filters+#(values.filters or {}))*64+1024)
  local section=assert(control(item,false).get_section(i))
  local ok,result=pcall(function()
    write(section,values,before); verify(section,values,before)
    return M.get(item,nop)[i]
  end)
  if ok then return result end
  failure(item,origin,before_all,request,function()
    -- Never restore shared contents: only detach/local copies can have changed them.
    if section.group~=before.group then section.group=before.group end
    if before.group=='' then filters_native(section,before.filters) end
    section.multiplier=before.multiplier; section.active=before.active
    if not validation.equal(M.get(item,nop),before_all) then error('section restoration differs') end
  end)
end
function M.add(item,origin,definition,spend)
  guard(item,origin)
  local values,request=fields(definition,spend,false)
  local before=M.get(item,spend)
  if #before>=limits.sections then errors.raise('E_CAPACITY','section limit exceeded') end
  if (values.group or '')~='' and values.filters~=nil then errors.raise('E_SHARED_SCOPE','group assignment cannot write shared contents') end
  local _,stats=data.copy({before=before,request=request},spend,limits.configuration_bytes)
  local cb=control(item,false); local absent=not cb
  spend(stats.bytes*3+stats.nodes*4+#(values.filters or {})*64+1024+(absent and 16384 or 0))
  local section
  local ok,result=pcall(function()
    cb=cb or control(item,true)
    if absent then before=M.get(item,nop) end -- Native defaults cannot be deleted.
    section=cb.add_section(values.group or '')
    if not section then errors.raise('E_CAPACITY','engine refused new section') end
    local settings={active=values.active,multiplier=values.multiplier,filters=values.filters}
    if settings.active==nil then settings.active=true end
    if settings.multiplier==nil then settings.multiplier=1 end
    if (values.group or '')=='' and settings.filters==nil then settings.filters={} end
    write(section,settings)
    verify(section,settings)
    if cb.sections_count~=#before+1 then error('section inventory readback differs') end
    M.get(item,nop) -- Capacity/readback errors stay inside target-local recovery.
    return section.index
  end)
  if ok then return result end
  failure(item,origin,before,request,function()
    if section and section.valid then assert(cb.remove_section(section.index)) end
    if not validation.equal(M.get(item,nop),before) then error('add restoration differs') end
  end)
end
function M.remove(item,origin,i,spend)
  index(i); guard(item,origin)
  local before=M.get(item,spend); if not before[i] then return false end
  if not before[i].is_manual then errors.raise('E_READ_ONLY','nonmanual section protected') end
  local _,stats=data.copy(before,spend,limits.configuration_bytes)
  local filter_count=0; for _,s in ipairs(before) do filter_count=filter_count+s.filters_count end
  spend(stats.bytes*3+stats.nodes*4+filter_count*64+#before*128+1024)
  local cb=control(item,false)
  local ok,result=pcall(function()
    assert(cb.remove_section(i),'engine refused section removal')
    local after=M.get(item,nop)
    local expected={}
    for n,v in ipairs(before) do
      if n~=i then
        local copy=data.copy(v,nop,limits.configuration_bytes)
        if n>i then copy.index=copy.index-1 end
        expected[#expected+1]=copy
      end
    end
    assert(validation.equal(after,expected),'remove readback differs')
    return true
  end)
  if ok then return result end
  failure(item,origin,before,{remove=i},function()
    if validation.equal(M.get(item,nop),before) then return end
    -- Rebuild only the affected manual suffix. Never touch a nonmanual neighbor.
    for n=i,#before do if not before[n].is_manual then error('cannot restore native nonmanual suffix') end end
    for n=cb.sections_count,i,-1 do assert(cb.remove_section(n)) end
    for n=i,#before do
      local old=before[n]; local section=assert(cb.add_section(old.group))
      write(section,{active=old.active,multiplier=old.multiplier,filters=old.group=='' and old.filters or nil})
    end
    assert(validation.equal(M.get(item,nop),before),'remove restoration differs')
  end)
end
return M
