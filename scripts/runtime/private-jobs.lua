-- Private plain graphs share the continuation ledger, never guest Data ownership.
local errors=require('scripts.runtime.errors')
local memory=require('scripts.runtime.memory')
local M={}
local function guest(checkpoint,value)
  return checkpoint.owned[value] or checkpoint.symbols[value] or checkpoint.bindings[value] or checkpoint.functions[value]
end
function M.admit(checkpoint,owner,value,spend)
  local queue,seen,items={value},{},{}
  local head=1
  while queue[head]~=nil do
    spend(1)
    local v=queue[head]; head=head+1
    local kind=type(v)
    if kind=='table' then
      if getmetatable(v) then errors.raise('E_UNSUPPORTED','private job requires plain data') end
      if not seen[v] and not guest(checkpoint,v) then
        seen[v]=true
        local count=0
        for k,x in pairs(v) do spend(1); count=count+1; queue[#queue+1]=k; queue[#queue+1]=x end
        items[#items+1]={v,192+48*count}
      end
    elseif kind=='string' then items[#items+1]={v,#v+32}
    elseif kind~='number' and kind~='boolean' then errors.raise('E_UNSUPPORTED','private job contains a native value') end
  end
  if owner then memory.acquire_all(owner,items) end
end
return M
