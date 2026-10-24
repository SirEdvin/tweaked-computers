-- Host-side bounded Data validation/copy. Never retains a caller-owned table.
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local M = {}
function M.copy(value, spend, ceiling, on_capacity)
  local stats, seen = {bytes=0,nodes=0}, {}
  local function charge(n)
    if spend then spend(n) end
    stats.bytes=stats.bytes+n
    if stats.bytes>(ceiling or limits.state_bytes) then
      if on_capacity then on_capacity(stats.bytes) end
      errors.raise('E_CAPACITY','Data byte capacity exceeded','data_bytes')
    end
  end
  local function visit(v,depth)
    if spend then spend(1) end
    stats.nodes=stats.nodes+1
    if depth>limits.data_depth then errors.raise('E_LIMIT','Data nesting limit exceeded') end
    local typ=type(v)
    if typ=='string' then
      if #v>limits.string_bytes then errors.raise('E_LIMIT','Data string limit exceeded') end
      charge(#v+8); return v
    elseif typ=='boolean' then charge(1); return v
    elseif typ=='number' then
      if not errors.finite(v) then errors.raise('E_ARGUMENT','Data number must be finite') end
      charge(8); return v
    elseif typ~='table' or getmetatable(v)~=nil then errors.raise('E_ARGUMENT','plain nonnil Data required') end
    if seen[v] then errors.raise('E_ARGUMENT','cyclic Data is not persistable') end
    seen[v]=true; charge(16)
    local result,kind,count,max={},nil,0,0
    for k,x in pairs(v) do
      count=count+1
      local kt=type(k)
      if kt=='string' then
        if #k>limits.string_bytes then errors.raise('E_LIMIT','Data key limit exceeded') end
        charge(#k+8)
      elseif kt=='number' and errors.integer(k,1,9007199254740991) then
        max=math.max(max,k); charge(8)
      else errors.raise('E_ARGUMENT','Data keys must be strings or dense indexes') end
      if kind and kind~=kt then errors.raise('E_ARGUMENT','Data arrays and maps cannot mix') end
      kind=kt; result[k]=visit(x,depth+1)
    end
    if kind=='number' and max~=count then errors.raise('E_ARGUMENT','Data array must be dense') end
    seen[v]=nil; return result
  end
  local result=visit(value,0)
  return result,stats
end
function M.key(key)
  if type(key)~='string' or #key==0 or #key>limits.identifier_bytes then errors.raise('E_ARGUMENT','bounded nonempty state key required') end
  return key
end
return M
