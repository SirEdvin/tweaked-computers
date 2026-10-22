-- Incremental reachability, not Lua GC/weak-table state, controls saved indices.
local ownership=require('scripts.runtime.ownership')
local M={}
local function checkpoint()
  return {frame={locals={},slots={},tuples={}},owned={},owned_order={},symbols={},symbols_order={},
    intern={},bindings={},bindings_order={}}
end
local function own(c,t,keys)
  c.owned[t]={keys=keys}; c.owned_order[#c.owned_order+1]=t
  return t
end
local function collect(c,slots,locals)
  ownership.begin(c,{slots=slots,locals=locals})
  local pause={}; local actions=0
  while c.collection do
    local remaining=1
    local ok,e=pcall(ownership.advance,c,function(n)
      assert(n==1)
      if remaining==0 then error(pause,0) end
      remaining=remaining-1; actions=actions+1
    end)
    assert(ok or e==pause,type(e)=='table' and e.message or tostring(e))
    assert(actions<20000,'ownership traversal failed to advance')
  end
  return actions
end
function M.run()
  local c=checkpoint()
  local live=own(c,{}, {'self','value'})
  live.self=live; live.value=string.rep('x',100)
  local dead=own(c,{}, {'self'}); dead.self=dead
  c.frame.locals[1]=live; c.frame.locals[2]=live
  collect(c,0,2)
  assert(c.owned[live] and not c.owned[dead] and #c.owned_order==1,'strong registry retained unreachable cycle')
  local aliased_bytes=c.memory_bytes
  c.frame.locals[2]=nil; collect(c,0,2)
  assert(c.memory_bytes==aliased_bytes,'alias charged twice')
  c.frame.locals[1]=nil; collect(c,0,2)
  assert(next(c.owned)==nil and #c.owned_order==0 and c.memory_bytes<aliased_bytes)

  local facade,method,stale={},{},{}
  c.bindings[facade]={name='tc-42',wire='red',generation=1,kind='facade'}
  c.bindings[method]={name='tc-42',wire='red',generation=1,kind='method',method='get',facade=facade}
  c.bindings[stale]={name='tc-43',wire='green',generation=1,kind='facade'}
  c.bindings_order={facade,method,stale}; c.frame.locals[1]=method
  local used,unused={},{}
  c.symbols[used]='computer.getTick'; c.symbols[unused]='computer.log'
  c.symbols_order={used,unused}; c.intern={['computer.getTick']=used,['computer.log']=unused}
  c.frame.slots[1]=used
  collect(c,1,2)
  assert(c.bindings[method] and c.bindings[facade] and not c.bindings[stale] and #c.bindings_order==2)
  assert(c.intern['computer.getTick']==used and c.intern['computer.log']==nil and #c.symbols_order==1)
  c.frame.slots[1]=nil; c.frame.locals[1]=nil
  collect(c,1,2)
  assert(next(c.bindings)==nil and next(c.intern)==nil and next(c.symbols)==nil)
  local base=c.memory_bytes
  for i=1,40 do
    local t=own(c,{value=string.rep('x',100)}, {'value'})
    c.frame.locals[1]=t
    collect(c,1,2)
    assert(#c.owned_order==1 and c.memory_bytes>base,'cross-tick replacement leaked retained graph')
    if i==1 then aliased_bytes=c.memory_bytes else assert(c.memory_bytes==aliased_bytes) end
  end
  c.frame.locals[1]=nil; collect(c,1,2)
  assert(c.memory_bytes==base and next(c.owned)==nil,'exclusive resources not reclaimed')
  c.frame.tuples[1]={n=3,false,nil,7}; collect(c,1,2)
  local tuple_bytes=c.memory_bytes
  c.result=c.frame.tuples[1]; collect(c,1,2)
  assert(c.memory_bytes==tuple_bytes,'aliased internal tuple charged twice')
  log('TC_CONTRACT incremental-owned-cycle-alias-binding-reclamation')
end
return M
