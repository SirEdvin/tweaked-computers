-- Device-owned plain state; GUI/render/session ownership never enters this graph.
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local charts
if script and script.active_mods['factorio-charts'] then charts=require('__factorio-charts__/charts') end
local M={tabs=6,charts=charts}
-- Positive width: (900/32 - 2 - .1*(n+1))/n > 0, unchanged upstream geometry.
M.bar_entries=math.ceil((900/32-2)/.1)-2
local function fail(code,message) errors.raise(code,message) end
local function fields(t,allowed)
  if type(t)~='table' or getmetatable(t) then fail('E_ARGUMENT','plain dashboard record required') end
  for k in pairs(t) do if not allowed[k] then fail('E_ARGUMENT','unknown dashboard field') end end
end
local function text(s,nonempty,identifier)
  if type(s)~='string' or nonempty and #s==0 then fail('E_ARGUMENT','display text/name required') end
  if #s>(identifier and limits.identifier_bytes or limits.string_bytes) then fail('E_LIMIT','dashboard text limit exceeded') end
  return s
end
local function array(t)
  if type(t)~='table' or getmetatable(t) then fail('E_ARGUMENT','dense dashboard array required') end
  local n=0; for k in pairs(t) do n=n+1; if not errors.integer(k,1,limits.table_entries) then fail('E_ARGUMENT','dense dashboard array required') end end
  if n>limits.table_entries then fail('E_LIMIT','Data entry limit exceeded') end
  for i=1,n do if t[i]==nil then fail('E_ARGUMENT','dense dashboard array required') end end
  return n
end
local function names(t)
  local n=array(t); if n==0 then fail('E_ARGUMENT','nonempty chart names required') end
  local seen={}
  for _,name in ipairs(t) do text(name,true,true); if seen[name] then fail('E_ARGUMENT','duplicate chart name') end; seen[name]=true end
end
function M.slot(slot)
  if not errors.integer(slot,1,M.tabs) then fail('E_RANGE','dashboard slot must be 1..6') end
  return tostring(slot)
end
function M.new() return {version=1,generation=0,tabs={}} end
function M.current(rec)
  local m=rec.dashboard
  if type(m)~='table' or m.version~=1 or type(m.tabs)~='table' then fail('E_UNSUPPORTED','dashboard data unsupported; retained for recovery') end
  return m
end
local allowed={row={id=true,type=true,children=true},column={id=true,type=true,children=true},
  label={id=true,type=true,text=true},button={id=true,type=true,text=true,enabled=true},
  line={id=true,type=true,series=true,capacity=true,format=true},stacked_bars={id=true,type=true,phases=true}}
function M.definition(def,spend,restoring)
  -- The existing Data walk proves depth, density, total nodes/bytes and isolation.
  local out=data.copy(def,spend,limits.peripheral_call_bytes)
  fields(out,{title=true,content=true}); text(out.title,true)
  local seen={}
  local function node(n)
    if type(n)~='table' or not allowed[n.type] then fail('E_ARGUMENT','unsupported dashboard widget') end
    fields(n,allowed[n.type]); text(n.id,true,true)
    if seen[n.id] then fail('E_ARGUMENT','duplicate dashboard widget ID') end; seen[n.id]=true
    if n.type=='row' or n.type=='column' then array(n.children); for _,child in ipairs(n.children) do node(child) end
    elseif n.type=='label' or n.type=='button' then
      text(n.text,n.type=='button')
      if n.type=='button' then
        if n.enabled==nil then n.enabled=true end
        if type(n.enabled)~='boolean' then fail('E_ARGUMENT','button enabled must be boolean') end
      end
    else
      if not charts and not restoring then fail('E_UNSUPPORTED','factorio-charts is not enabled') end
      if n.type=='line' then
        names(n.series)
        if #n.series>(charts and charts.colors.get_max_series() or 12) then fail('E_RANGE','upstream line series domain exceeded') end
        if not errors.integer(n.capacity,2,limits.table_entries) then fail('E_RANGE','line capacity outside native/Data domain') end
        n.format=n.format or 'number'
        if n.format~='number' and n.format~='percent' and n.format~='time' then fail('E_RANGE','unsupported line label format') end
      else names(n.phases) end
    end
  end
  node(out.content); return out
end
local function walk(n,fn)
  fn(n); for _,child in ipairs(n.children or {}) do walk(child,fn) end
end
function M.widget(tab,id,kind)
  text(id,true,true); local found
  if not tab then fail('E_NOT_FOUND','dashboard tab not found') end
  walk(tab.definition.content,function(n) if n.id==id then found=n end end)
  if not found then fail('E_NOT_FOUND','dashboard widget not found') end
  if kind and found.type~=kind then fail('E_ARGUMENT','wrong dashboard widget kind') end
  return found
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
M.equal=equal
local function compatible(a,b)
  return a and a.type==b.type and (b.type=='line' and a.capacity==b.capacity and equal(a.series,b.series)
    or b.type=='stacked_bars' and equal(a.phases,b.phases))
end
local function fresh(n)
  if n.type=='line' then
    -- Same single-interval shape used by the library, including its empty fields.
    return {name=n.id,data={},index=0,sum={},counts={},ticks=1,length=n.capacity,viewer_count=0,guis={},line_ids={}}
  end
  return {}
end
local function metric(value,spend)
  local stats=data.measure(value,spend,limits.peripheral_call_bytes); return stats.bytes,stats.nodes
end
-- Reserve complete line vectors analytically, without allocating the empty window.
function M.usage(model,spend)
  data.measure(model,spend,limits.peripheral_call_bytes)
  local bytes,nodes=metric({version=1,generation=model.generation,tabs={}},spend)
  for key,tab in pairs(model.tabs) do
    local b,n=metric({definition=tab.definition,generation=tab.generation,charts={}},spend)
    bytes=bytes+#key+8+b; nodes=nodes+n
    walk(tab.definition.content,function(widget)
      if widget.type=='line' then
        local empty=fresh(widget); local rb,rn=metric(empty,spend)
        local vector,totals={},{}
        for _,name in ipairs(widget.series) do vector[name]=0; totals[name]=0 end
        local vb,vn=metric(vector,spend); local tb,tn=metric(totals,spend)
        -- Empty data/sum/counts maps already belong to rb/rn.
        bytes=bytes+#widget.id+8+rb+(vb+8)*widget.capacity+2*(tb-16)
        nodes=nodes+rn+vn*widget.capacity+2*(tn-1)
      elseif widget.type=='stacked_bars' then
        local rb,rn=metric(tab.charts[widget.id],spend)
        bytes=bytes+#widget.id+8+rb; nodes=nodes+rn
      end
    end)
  end
  return bytes,nodes
end
function M.admit(candidate,previous,spend)
  local bytes,nodes=M.usage(candidate,spend)
  local oldbytes,oldnodes=0,0
  if previous then oldbytes,oldnodes=M.usage(previous,spend) end
  if bytes>limits.state_bytes and bytes>oldbytes then fail('E_CAPACITY','dashboard shared state reservation exceeded') end
  if nodes>limits.data_nodes and nodes>oldnodes then fail('E_LIMIT','dashboard reserved Data node limit exceeded') end
  return candidate
end
function M.replace(previous,key,definition,spend,preparing)
  local old=previous.tabs[key]
  if old and equal(old.definition,definition) then return previous end
  local tab={definition=definition,generation=previous.generation+1,charts={}}
  if not errors.integer(tab.generation,1,9007199254740991) then fail('E_CAPACITY','layout identity exhausted') end
  walk(definition.content,function(n)
    if n.type=='line' or n.type=='stacked_bars' then
      local before
      if old then walk(old.definition.content,function(w) if w.id==n.id then before=w end end) end
      tab.charts[n.id]=compatible(before,n) and old.charts[n.id] or fresh(n)
    end
  end)
  local candidate={version=1,generation=tab.generation,tabs={}}
  for k,v in pairs(previous.tabs) do candidate.tabs[k]=v end
  candidate.tabs[key]=tab
  return preparing and candidate or M.admit(candidate,previous,spend)
end
function M.set_tab(rec,slot,definition,spend,restoring)
  local key=M.slot(slot); local previous=M.current(rec)
  local normalized=M.definition(definition,spend,restoring)
  local candidate=M.replace(previous,key,normalized,spend)
  rec.dashboard=candidate
end
function M.set_leaf(rec,slot,id,value,enabled,spend)
  local key=M.slot(slot); local previous=M.current(rec); local old=previous.tabs[key]
  local widget=M.widget(old,id)
  if enabled then
    if widget.type~='button' or type(value)~='boolean' then fail('E_ARGUMENT','button/boolean required') end
  else
    if widget.type~='button' and widget.type~='label' then fail('E_ARGUMENT','label or button required') end
    text(value,widget.type=='button')
  end
  local definition=data.copy(old.definition,spend,limits.peripheral_call_bytes)
  local changed=M.widget({definition=definition},id)
  if enabled then changed.enabled=value else changed.text=value end
  local candidate={version=1,generation=previous.generation,tabs={}}
  for k,v in pairs(previous.tabs) do candidate.tabs[k]=v end
  candidate.tabs[key]={definition=definition,generation=old.generation,charts=old.charts}
  M.admit(candidate,previous,spend); rec.dashboard=candidate
end
local function vector(value,series,spend,nonnegative)
  local copy=data.copy(value,spend,limits.peripheral_call_bytes); local allowed={}
  for _,name in ipairs(series) do allowed[name]=true end
  fields(copy,allowed)
  for _,name in ipairs(series) do
    if not errors.finite(copy[name]) or nonnegative and copy[name]<0 then fail('E_RANGE','finite complete chart vector required') end
  end
  return copy
end
local function line_range(low,high)
  if low==high then low=low-1; high=high+1 end
  local span=high-low; if span==0 then span=1 end
  -- Match upstream grid multiplication and division before any native draw.
  if not errors.finite(low) or not errors.finite(high) or not errors.finite(span*4)
    or not errors.finite((700/32-1.5)/span) then fail('E_RANGE','line renderer range overflow') end
end
function M.append(rec,slot,id,value,spend)
  local tab=M.current(rec).tabs[M.slot(slot)]; local n=M.widget(tab,id,'line')
  local v=vector(value,n.series,spend); local ring=tab.charts[id]; local old=ring.data[ring.index+1]
  local global_low,global_high=math.huge,-math.huge
  -- Validate the exact subtraction/addition order and every plotted range first.
  for _,name in ipairs(n.series) do
    local sum=(ring.sum[name] or 0)-(old and old[name] or 0)+v[name]
    if not errors.finite(sum) then fail('E_RANGE','line sum overflow') end
    local low,high=v[name],v[name]
    for i,point in ipairs(ring.data) do
      spend(1)
      if i~=ring.index+1 then low=math.min(low,point[name]); high=math.max(high,point[name]) end
    end
    global_low=math.min(global_low,low); global_high=math.max(global_high,high)
  end
  line_range(global_low,global_high)
  spend(#n.series*4+1)
  charts.time_series.add_datapoint({ring},v)
end
function M.bars(rec,slot,id,value,spend)
  local previous=M.current(rec); local key=M.slot(slot); local tab=previous.tabs[key]
  local n=M.widget(tab,id,'stacked_bars'); local count=array(value)
  if count>M.bar_entries then fail('E_RANGE','upstream positive bar width domain exceeded') end
  local bars={}
  for i=1,count do
    bars[i]=vector(value[i],n.phases,spend,true)
    local sum=0; for _,name in ipairs(n.phases) do sum=sum+bars[i][name] end
    if not errors.finite(sum*1.1*4) then fail('E_RANGE','bar renderer total overflow') end
  end
  local candidate={version=1,generation=previous.generation,tabs={}}
  for k,v in pairs(previous.tabs) do candidate.tabs[k]=v end
  local replacement={definition=tab.definition,generation=tab.generation,charts={}}
  for k,v in pairs(tab.charts) do replacement.charts[k]=v end
  replacement.charts[id]=bars; candidate.tabs[key]=replacement
  M.admit(candidate,previous,spend); rec.dashboard=candidate
end
function M.clear(rec,slot,id,spend)
  local tab=M.current(rec).tabs[M.slot(slot)]; local n=M.widget(tab,id)
  if n.type~='line' and n.type~='stacked_bars' then fail('E_ARGUMENT','chart required') end
  spend(128); tab.charts[id]=fresh(n)
end
function M.import(value,spend)
  fields(value,{version=true,generation=true,tabs=true})
  if value.version~=1 or not errors.integer(value.generation,0,9007199254740991) then
    fail('E_UNSUPPORTED','unsupported dashboard snapshot; original retained')
  end
  local copied=data.copy(value,spend,limits.peripheral_call_bytes)
  for key,tab in pairs(copied.tabs) do
    if type(key)~='string' or not key:match('^[1-6]$') then fail('E_ARGUMENT','invalid retained dashboard slot') end
    fields(tab,{definition=true,generation=true,charts=true})
    if not errors.integer(tab.generation,1,copied.generation) then fail('E_ARGUMENT','invalid retained layout identity') end
    tab.definition=M.definition(tab.definition,spend,true)
    local expected={}
    walk(tab.definition.content,function(n)
      if n.type=='line' or n.type=='stacked_bars' then
        expected[n.id]=true; local retained=tab.charts[n.id]
        if n.type=='line' then
          fields(retained,{name=true,data=true,index=true,sum=true,counts=true,ticks=true,length=true,
            viewer_count=true,guis=true,line_ids=true})
          if retained.name~=n.id or retained.length~=n.capacity or retained.ticks~=1 or retained.viewer_count~=0
            or not errors.integer(retained.index,0,n.capacity-1) or next(retained.guis) or next(retained.line_ids) then fail('E_ARGUMENT','invalid retained line metadata') end
          local count=array(retained.data)
          if count>n.capacity or count<n.capacity and retained.index~=count then fail('E_ARGUMENT','invalid retained ring order') end
          local low,high=math.huge,-math.huge
          for _,v in ipairs(retained.data) do
            vector(v,n.series,spend)
            for _,name in ipairs(n.series) do low=math.min(low,v[name]); high=math.max(high,v[name]) end
          end
          if count>0 then line_range(low,high) end
          local allowed_names={}
          for _,name in ipairs(n.series) do
            allowed_names[name]=true
            if count>0 and (retained.counts[name]~=count or not errors.finite(retained.sum[name]))
              or count==0 and (retained.counts[name]~=nil or retained.sum[name]~=nil) then fail('E_ARGUMENT','invalid retained line totals') end
          end
          fields(retained.counts,allowed_names); fields(retained.sum,allowed_names)
        else
          if array(retained)>M.bar_entries then fail('E_RANGE','invalid retained bar geometry') end
          for _,v in ipairs(retained) do
            vector(v,n.phases,spend,true)
            local sum=0; for _,name in ipairs(n.phases) do sum=sum+v[name] end
            if not errors.finite(sum*1.1*4) then fail('E_RANGE','invalid retained bar range') end
          end
        end
      end
    end)
    fields(tab.charts,expected)
  end
  -- Restore accepted state under a lowered allowance; this grants no new growth.
  M.usage(copied,spend)
  return copied
end
return M
