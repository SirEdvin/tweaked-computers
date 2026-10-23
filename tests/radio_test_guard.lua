-- Explicit shared-guard contract double; native service fixtures are not VM proof.
local memory=require('scripts.runtime.memory')

local M={}
local function nop() end
function M.new(state,cut)
  state=state or {}
  state.account=state.account or memory.new(16*1024*1024,0)
  state.host=state.host or {}
  local guard={}
  guard.spend=function(n)
    assert(type(n)=='number' and n>=0)
    if cut and cut(state,n) then error({radio_suspend=true},0) end
    state.work=(state.work or 0)+n
  end
  guard.suspend=function() error({radio_suspend=true},0) end
  guard.prepare_empty_result=function() guard.spend(8); state.prepared=true end
  guard.prepare_boolean_result=guard.prepare_empty_result
  guard.host_resize=function(key,bytes)
    local item=state.host[key]
    if bytes==0 then
      if item then memory.close(item.owner,nop); state.host[key]=nil end
      return
    end
    if not item then
      item={value={},owner=memory.owner(state.account,bytes+256)}
    end
    memory.acquire(item.owner,item.value,bytes)
    state.host[key]=item
  end
  guard.job=function(name,initial)
    if not state.job then
      state.job_owner=memory.owner(state.account)
      state.job=initial(); state.job_name=name
      memory.acquire(state.job_owner,state.job,state.job.bytes or 512)
    end
    assert(state.job_name==name)
    return state.job
  end
  guard.job_resize=function(bytes) memory.resize(state.job_owner,state.job,bytes) end
  guard.finish=function()
    if state.job_owner then memory.close(state.job_owner,nop) end
    state.job_owner=nil; state.job=nil; state.job_name=nil; state.prepared=nil
  end
  return guard,state
end
function M.call(service,c,r,method,...)
  storage.radio_test_channels=storage.radio_test_channels or {}
  local guard=M.new(storage.radio_test_channels)
  local out=table.pack(pcall(service.methods[method],c,r,'red',game.tick,guard.spend,guard,...))
  guard.finish()
  if not out[1] then error(out[2],0) end
  return table.unpack(out,2,out.n)
end
return M
