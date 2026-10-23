-- Saved strong indices are ephemerons: only roots/guest edges keep values alive.
local errors=require('scripts.runtime.errors')
local memory=require('scripts.runtime.memory')
local M={}
local binding_fields={'name','wire','generation','kind','method','facade'}
local resource_fields={'code','message','resource','setting','used','requested','limit','recoverable','line','column'}
local function push(gc,value,kind,count)
  gc.queue[#gc.queue+1]={value=value,kind=kind,cursor=1,count=count}
end
function M.begin(checkpoint,executable)
  local f=checkpoint.frame
  local gc={queue={},head=1,seen={},records={},strings={},bytes=128+16*(executable.locals+executable.slots),
    phase='mark',cursor=1,order={}}
  gc.records[checkpoint]=true
  if checkpoint.source then push(gc,checkpoint.source); push(gc,checkpoint.handler) end
  if checkpoint.symbol_roots then push(gc,checkpoint.symbol_roots,'range',#checkpoint.symbol_roots) end
  push(gc,f.locals,'range',executable.locals)
  push(gc,f.slots,'range',executable.slots)
  push(gc,f.tuples,'tuples',executable.slots)
  push(gc,checkpoint.event_initialized and f.event or nil)
  push(gc,checkpoint.shell_root)
  push(gc,checkpoint.result,'tuple')
  if f.pending then
    push(gc,f.pending.call_result,'tuple'); push(gc,f.pending.service_result,'tuple')
    local prepared=f.pending.prepared
    if prepared then push(gc,prepared.called,'tuple'); push(gc,prepared.values,'tuple') end
  end
  checkpoint.collection=gc
end
local function malformed() errors.raise('E_UNSUPPORTED','invalid continuation ownership graph; retained') end
-- One admitted action changes one cursor/edge only; native hash cursors never persist.
function M.advance(checkpoint,spend,memory_owner)
  local gc=assert(checkpoint.collection)
  if memory_owner then
    if memory_owner.id~=checkpoint.memory_owner or memory_owner.closed or memory_owner.closing then malformed() end
  elseif checkpoint.memory_owner~=nil then malformed() end
  local function scalar(value)
    local kind=type(value)
    if kind=='string' then
      if not gc.strings[value] then gc.strings[value]=true; gc.bytes=gc.bytes+#value+32 end
    elseif kind~='nil' and kind~='number' and kind~='boolean' then malformed() end
  end
  while gc.phase=='mark' do
    local job=gc.queue[gc.head]
    if not job then gc.phase='owned'; gc.cursor=1; break end
    spend(1)
    local value=job.value
    local done=true
    if job.kind=='range' or job.kind=='tuples' or job.kind=='tuple' then
      if value~=nil then
        if type(value)~='table' or getmetatable(value) then malformed() end
        local count=job.count or value.n
        if not errors.integer(count,0,9007199254740991) then malformed() end
        if job.kind=='tuple' and job.cursor==1 then
          if gc.records[value] then count=0
          else gc.records[value]=true; gc.bytes=gc.bytes+64+16*count end
        end
        if job.cursor<=count then
          push(gc,value[job.cursor],job.kind=='tuples' and 'tuple' or nil)
          job.cursor=job.cursor+1; done=false
        end
      end
    elseif job.kind=='edges' then
      local keys=assert(checkpoint.owned[value]).keys
      local key=keys[job.cursor]
      if key~=nil then
        push(gc,key); push(gc,value[key]); job.cursor=job.cursor+1; done=false
      end
    elseif job.kind=='binding' then
      local descriptor=assert(checkpoint.bindings[value])
      local key=binding_fields[job.cursor]
      if key then push(gc,descriptor[key]); job.cursor=job.cursor+1; done=false end
    elseif job.kind=='resource' then
      if job.cursor==1 then gc.bytes=gc.bytes+256 end
      local key=resource_fields[job.cursor]
      if key then push(gc,value[key]); job.cursor=job.cursor+1; done=false end
    elseif type(value)=='table' then
      if getmetatable(value) then malformed() end
      if not gc.seen[value] then
        gc.seen[value]=true
        local owned=checkpoint.owned[value]
        local symbol=checkpoint.symbols[value]
        local binding=checkpoint.bindings[value]
        if owned then
          if type(owned)~='table' or type(owned.keys)~='table' then malformed() end
          gc.bytes=gc.bytes+192+48*#owned.keys
          push(gc,value,'edges')
          if owned.resource then push(gc,owned.resource,'resource') end
        elseif symbol then gc.bytes=gc.bytes+192+2*48+16; push(gc,symbol)
        elseif binding then gc.bytes=gc.bytes+2*192+6*48+16+48; push(gc,value,'binding')
        else malformed() end
      end
    else scalar(value) end
    if done then gc.queue[gc.head]=false; gc.head=gc.head+1 end
  end
  while gc.phase~='mark' and gc.phase~='memory' do
    local field=gc.phase
    local order=checkpoint[field..'_order']
    local value=order[gc.cursor]
    if value~=nil then
      spend(1)
      if gc.seen[value] then gc.order[#gc.order+1]=value
      else
        if field=='symbols' then checkpoint.intern[checkpoint.symbols[value]]=nil end
        checkpoint[field][value]=nil
      end
      gc.cursor=gc.cursor+1
    else
      checkpoint[field..'_order']=gc.order
      gc.order={}; gc.cursor=1
      if field=='owned' then gc.phase='symbols'
      elseif field=='symbols' then gc.phase='bindings'
      elseif memory_owner then gc.phase='memory'; gc.memory_cursor=memory_owner.head
      else checkpoint.memory_bytes=gc.bytes; checkpoint.collection=nil; return end
    end
  end
  while gc.phase=='memory' do
    local node=gc.memory_cursor
    if not node then checkpoint.memory_bytes=gc.bytes; checkpoint.collection=nil; return end
    spend(1)
    local successor=node.next
    if not (gc.seen[node.value] or gc.strings[node.value] or gc.records[node.value]) then
      memory.release(memory_owner,node.value)
    end
    gc.memory_cursor=successor
  end
end
return M
