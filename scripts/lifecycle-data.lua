-- Fixed host-only material and source/settings formats. Never compile on import.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local model=require('scripts.monitor-model')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local M={}
local MAX=9007199254740991
local function fail(message) errors.raise('E_ARGUMENT',message) end
local function shape(t,allowed,max)
  if type(t)~='table' or getmetatable(t)~=nil then fail('plain lifecycle snapshot required') end
  local n=0
  for k in pairs(t) do n=n+1; if n>max or not allowed[k] then fail('unknown lifecycle snapshot field') end end
end
local function text(s) if type(s)~='string' then fail('source/label string required') end; return s end
local function integer(n) if not errors.integer(n,0,MAX) then fail('invalid retained revision/version') end; return n end

local function active_copy(a)
  if a==nil then return nil end
  shape(a,{source=true,revision=true,api_version=true,compiler_version=true,storage_version=true,handlers=true},6)
  local result={source=text(a.source),revision=integer(a.revision),
    api_version=integer(a.api_version),compiler_version=integer(a.compiler_version),storage_version=integer(a.storage_version),handlers={}}
  if type(a.handlers)~='table' or getmetatable(a.handlers)~=nil then fail('plain retained handler inventory required') end
  for name,v in pairs(a.handlers) do
    if type(name)~='string' or #name==0 or v~=true then fail('invalid retained handler inventory') end
    result.handlers[name]=true
  end
  return result
end
-- Material transport checks Data shape iteratively, not new-write quotas.
local function material_data(value)
  local root,seen,stats={},{},{bytes=0,nodes=0}
  local stack={{value=value,parent=root,key=1}}
  while #stack>0 do
    local item=table.remove(stack); local v=item.value
    if item.exit then seen[v]=nil
    else
      stats.nodes=stats.nodes+1
      local typ=type(v)
      if typ=='string' then stats.bytes=stats.bytes+#v+8; item.parent[item.key]=v
      elseif typ=='boolean' then stats.bytes=stats.bytes+1; item.parent[item.key]=v
      elseif typ=='number' and errors.finite(v) then stats.bytes=stats.bytes+8; item.parent[item.key]=v
      elseif typ=='table' and getmetatable(v)==nil then
        if seen[v] then fail('cyclic material Data') end
        seen[v]=true; stats.bytes=stats.bytes+16
        local copy={}; item.parent[item.key]=copy
        stack[#stack+1]={value=v,exit=true}
        local kind,count,maximum=nil,0,0
        for k,x in pairs(v) do
          local kt=type(k); count=count+1
          if kt=='string' then stats.bytes=stats.bytes+#k+8
          elseif kt=='number' and errors.integer(k,1,MAX) then
            stats.bytes=stats.bytes+8; maximum=math.max(maximum,k)
          else fail('Data keys must be strings or dense indexes') end
          if kind and kind~=kt then fail('Data arrays and maps cannot mix') end
          kind=kt; stack[#stack+1]={value=x,parent=copy,key=k}
        end
        if kind=='number' and maximum~=count then fail('Data array must be dense') end
      else fail('plain finite nonnil Data required') end
    end
  end
  return root[1],stats
end
local function state_copy(state)
  if type(state)~='table' or getmetatable(state)~=nil then fail('plain computer state map required') end
  local out,sizes,node_sizes={}, {}, {}; local bytes,nodes,count=16,1,0
  for k,v in pairs(state) do
    if type(k)~='string' or #k==0 then fail('nonempty state key required') end
    count=count+1
    local copy,stats=material_data(v)
    local size=stats.bytes+#k+16; bytes=bytes+size; nodes=nodes+stats.nodes
    out[k]=copy; sizes[k]=size; node_sizes[k]=stats.nodes
  end
  return out,bytes,nodes,count,sizes,node_sizes
end
function M.import_computer(s,settings_only)
  shape(s,{version=true,saved_source=true,saved_revision=true,active=true,state=true,label=true},6)
  if s.version~=1 then errors.raise('E_UNSUPPORTED','unsupported computer item; original data retained') end
  local c={saved_source=text(s.saved_source),saved_revision=integer(s.saved_revision)}
  if s.label~=nil then c.label=text(s.label) end
  if not settings_only then
    c.active=active_copy(s.active)
    c.state,c.state_bytes,c.state_nodes,c.state_entries,c.state_sizes,c.state_node_sizes=state_copy(s.state)
  elseif s.active~=nil or s.state~=nil then fail('blueprint/settings must not carry state or active execution') end
  return c
end
function M.computer_snapshot(rec,settings_only)
  if rec.schema_version~=1 then errors.raise('E_UNSUPPORTED','unsupported computer schema; source and state retained') end
  local s={version=1,saved_source=rec.saved_source,saved_revision=rec.saved_revision,label=rec.label}
  if not settings_only then s.active=rec.active; s.state=rec.state end
  local c=M.import_computer(s,settings_only)
  return {version=1,saved_source=c.saved_source,saved_revision=c.saved_revision,label=c.label,active=c.active,state=c.state}
end
function M.restore_computer(rec,s,settings_only)
  local c=M.import_computer(s,settings_only)
  if settings_only and rec.saved_revision==MAX then errors.raise('E_CAPACITY','destination source revision exhausted') end
  local saved,active
  local ok,problem=pcall(function()
    saved=policy.source_owner(c.saved_source,not settings_only)
    if c.active then active=policy.source_owner(c.active,not settings_only) end
  end)
  if not ok then memory.retire(saved); memory.retire(active); error(problem,0) end
  if not runtime.retire(rec,'stopped','settings_copy') then
    memory.retire(saved); memory.retire(active)
    errors.raise('E_ENGINE','old run cleanup failed; data retained')
  end
  memory.retire(rec.saved_source_memory); memory.retire(rec.active_source_memory)
  rec.saved_source_memory=saved; rec.active_source_memory=active
  rec.saved_source=c.saved_source; rec.saved_revision=settings_only and rec.saved_revision+1 or c.saved_revision
  rec.label=c.label; rec.active=c.active
  if not settings_only then
    for _,k in ipairs({'state','state_bytes','state_nodes','state_entries','state_sizes','state_node_sizes'}) do rec[k]=c[k] end
  end
  rec.run_id=nil; rec.diagnostic=nil; rec.candidate_diagnostic=nil
  rec.network_views=nil; rec.network_job=nil; rec.needs_input_resync=nil
  rec.body.minable=true; rec.mining_guard=nil
end
function M.initialize_computer(rec)
  local ok,e=pcall(M.computer_snapshot,rec,false)
  rec.body.minable=ok; rec.mining_guard=not ok and 'unsupported-computer-data' or nil
  if not ok then runtime.retire(rec,'faulted','unsupported_retained_data'); rec.diagnostic=type(e)=='table' and e or errors.new('E_UNSUPPORTED','retained computer data needs host recovery') end
end
function M.monitor_snapshot(rec)
  local root=registry.get(); local state=root.monitors
  if state and state.version~=1 then errors.raise('E_UNSUPPORTED','unsupported monitor data retained') end
  local g=state and state.groups[state.membership[rec.id]]
  local m=g and g.model or rec.monitor_settings or model.new(1,1)
  local palette={}; for i=1,16 do local p=m.palette[i]; palette[i]={p[1],p[2],p[3]} end
  return M.import_monitor{version=1,scale=m.scale,fg=m.fg,bg=m.bg,blink=m.blink,palette=palette}
end
local function monitor_size(w,h,scale)
  if not errors.finite(scale) or scale<=0 then fail('positive finite monitor scale required') end
  -- Native MapPosition is signed 24.8; reject cells outside its coordinate domain.
  if not errors.finite(9*scale) or 9*scale/64>2^23-1/256 then fail('unrepresentable native monitor geometry') end
  local width,height=model.size(w,h,scale)
  if not errors.integer(width,1,MAX) or not errors.integer(height,1,MAX)
    or not errors.integer(width*height,1,MAX) then fail('unrepresentable monitor dimensions') end
  if width*height>model.limits.cells then errors.raise('E_CAPACITY','monitor storage admission requires shared host ownership') end
  return width,height
end
function M.import_monitor(s)
  shape(s,{version=true,scale=true,fg=true,bg=true,blink=true,palette=true},6)
  if s.version~=1 then errors.raise('E_UNSUPPORTED','unsupported monitor item settings') end
  monitor_size(1,1,s.scale)
  if not errors.integer(s.fg,0,15)
    or not errors.integer(s.bg,0,15) or type(s.blink)~='boolean' then fail('invalid monitor settings') end
  if type(s.palette)~='table' or getmetatable(s.palette)~=nil then fail('plain palette required') end
  local n=0; local palette={}
  for k in pairs(s.palette) do n=n+1; if not errors.integer(k,1,16) then fail('invalid palette index') end end
  if n~=16 then fail('sixteen palette entries required') end
  for i=1,16 do
    local p=s.palette[i]; shape(p,{[1]=true,[2]=true,[3]=true},3); palette[i]={}
    for j=1,3 do if not errors.finite(p[j]) or p[j]<0 or p[j]>1 then fail('invalid palette channel') end; palette[i][j]=p[j] end
  end
  return {version=1,scale=s.scale,fg=s.fg,bg=s.bg,blink=s.blink,palette=palette}
end
local function monitor_settings(settings,w,h,previous)
  local width,height=monitor_size(w,h,settings.scale)
  local inherit={x=previous and previous.x or 1,y=previous and previous.y or 1,
    scale=settings.scale,fg=settings.fg,bg=settings.bg,blink=settings.blink,palette=settings.palette}
  local m
  if previous and previous.width==width and previous.height==height then
    m={}; for k,v in pairs(previous) do m[k]=v end
    for k,v in pairs(inherit) do m[k]=v end
  else m=model.new(w,h,inherit) end
  m.revision=previous and previous.revision+2 or m.revision
  model.invalidate(m)
  return m
end
function M.restore_monitor(rec,s)
  local settings=M.import_monitor(s)
  -- No obsolete group buffer or cursor travels with a tile.
  rec.monitor_settings=monitor_settings(settings,1,1)
end
function M.settings(rec)
  if rec.kind=='computer' then return {version=1,kind=rec.kind,computer=M.computer_snapshot(rec,true)} end
  if rec.kind=='monitor' then return {version=1,kind=rec.kind,monitor=M.monitor_snapshot(rec)} end
  return {version=1,kind=rec.kind}
end
function M.apply_settings(rec,s)
  shape(s,{version=true,kind=true,computer=true,monitor=true},4)
  if s.version~=1 or s.kind~=rec.kind then fail('settings family/version mismatch') end
  if rec.kind=='computer' then M.restore_computer(rec,s.computer,true)
  elseif rec.kind=='monitor' then
    local settings=M.import_monitor(s.monitor)
    local root=registry.get(); local state=root.monitors; local g=state and state.groups[state.membership[rec.id]]
    local tile=monitor_settings(settings,1,1)
    local replacement=g and monitor_settings(settings,g.width_tiles,g.height_tiles,g.model)
    -- Preflight the whole group before publishing either settings or palette.
    rec.monitor_settings=tile
    if g then g.model=replacement end
  elseif s.computer~=nil or s.monitor~=nil then fail('unexpected family settings') end
end
function M.initialize_existing()
  local root=registry.get(); if not root then return end
  if not registry.supported(root) then
    -- Fixed cleanup only. Unknown data stays untouched, no source execution.
    local n=0
    for _,rec in pairs(root.computers or {}) do n=n+1; if n>limits.registry_entries then break end
      registry.cleanup(rec,rec.run_id,'unsupported_storage'); rec.status='faulted'; rec.powered=false
      if rec.body and rec.body.valid then rec.body.minable=false end
    end
    return
  end
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and rec.kind=='computer' and rec.body.valid then M.initialize_computer(rec) end
  end
end
lifecycle.register_item_adapter('computer',{initialize=M.initialize_computer,snapshot=function(rec) return M.computer_snapshot(rec,false) end,
  restore=function(rec,s) return M.restore_computer(rec,s,false) end,tag='tc_computer'})
lifecycle.register_item_adapter('monitor',{initialize=function() end,snapshot=M.monitor_snapshot,restore=M.restore_monitor,tag='tc_monitor'})
return M
