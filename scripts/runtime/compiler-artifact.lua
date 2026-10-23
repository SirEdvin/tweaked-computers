-- Separate syntax admission and lazy native reconstruction of ABI-9 blocks.
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local function refused(cost)
  local e=errors.new('E_CAPACITY','native compiler block needs '..cost..' compile/host work units; increase the configured slice')
  e.recoverable=true; e.field='compile_work'; return e
end
local function native(text)
  local factory,problem=load('return '..text,'@continuation','t',{})
  if not factory then return nil,errors.new('E_PROGRAM','generated continuation: '..problem) end
  return factory
end
function M.check(job,context)
  if job.native_checked then return true end
  local a=job.result.artifact
  local cursor=job.native_cursor
  if not cursor then cursor={block=1,phase='block'}; job.native_cursor=cursor end
  while cursor.block<=#a.blocks do
    local text
    if cursor.phase=='block' then text=a.blocks[cursor.block]
    else
      local key,value=next(a.cleanup[cursor.block],cursor.key)
      if not key then cursor.block=cursor.block+1; cursor.phase='block'; cursor.key=nil
      else text=value; cursor.next_key=key end
    end
    if text then
      local cost=#text+8
      if context and not admission.reserve(context,'compile',cost) then
        if cost>math.min(limits.compile_work,admission.guest_ceiling(context.ledger,context.tick)) then return nil,refused(cost) end
        job.wait_tick=context.tick; return nil,nil,'wait'
      end
      local factory,e=native(text)
      if not factory then return nil,e end
      job.work=job.work+cost
      if cursor.phase=='block' then
        a.native_cost=a.native_cost or {}; a.native_cost[cursor.block]=cost
        cursor.phase='cleanup'
      else
        a.native_cost[cursor.block]=a.native_cost[cursor.block]+cost
        cursor.key=cursor.next_key; cursor.next_key=nil
      end
    end
  end
  job.native_cursor=nil; job.native_checked=true
  return true
end
-- admit(cost,guard) MUST either prepay compile+host credits, privately suspend, or
-- refuse an atom larger than a fresh slice. It runs before native load/effects.
function M.factory(plan,admit)
  assert(type(admit)=='function','native reconstruction admission required')
  local a=plan.artifact
  return function()
    local ready,functions,bytes={},{},0
    local executable={entries=a.entries,protos=a.protos,symbols=a.symbols,strings=a.strings,
      calls=a.calls,call_count=a.call_count,slots=a.slots,locals=a.locals,cleanup=ready}
    executable.blocks=setmetatable({}, {
      __len=function() return #a.blocks end,
      __index=function(_,pc)
        if not a.blocks[pc] then return end
        return function(frame,runtime)
          local cost=assert(a.native_cost[pc],'unvalidated compiler block')
          admit(cost,runtime.guard)
          if not functions[pc] then
            if bytes+cost>limits.compiler_cache_bytes then functions={}; ready={}; executable.cleanup=ready; bytes=0 end
            local factory,e=native(a.blocks[pc]); if not factory then error(e,0) end
            local fn=factory(); local row={}
            for successor,text in pairs(a.cleanup[pc]) do
              local cleanup,problem=native(text); if not cleanup then error(problem,0) end
              row[successor]=cleanup()
            end
            functions[pc]=fn; ready[pc]=row; bytes=bytes+cost
          end
          local fn=functions[pc]
          -- An oversized current row is execution workspace, never retained as a cache hit.
          if cost>limits.compiler_cache_bytes then functions[pc]=nil; bytes=0 end
          return fn(frame,runtime)
        end
      end,
    })
    return executable
  end
end
return M
