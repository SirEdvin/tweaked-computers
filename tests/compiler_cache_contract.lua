-- Exact-source cache must not change credits, partial refusal or trust caller data.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
local source='return {api_version=1,handlers={start=function(e) local t={1,2,3}; for i,v in ipairs(t) do assert(i==v) end end}}'
local serial=0
local function evict()
  for i=1,9 do
    serial=serial+1
    local text='return {api_version=1,handlers={start=function(e) local n='..serial..' end}}'
    assert(compiler.compile(text,admission.context(admission.new(),'evict',0)))
  end
end
local function context(remaining,shared)
  local ctx=admission.context(admission.new(),'comparison',0)
  ctx.machine.compile=limits.compile_work-remaining
  ctx.ledger.total=shared and limits.host_work_per_tick-limits.maintenance_work_per_tick-shared or ctx.machine.compile
  return ctx
end
function M.run()
  local count=0
  for _,available in ipairs({0,1,2,#source*2,#source*2+1,500,1000,2000,limits.compile_work}) do
    assert(compiler.compile(source,admission.context(admission.new(),'warm-up',0)))
    local warm=context(available); local a,ae=compiler.compile(source,warm)
    evict()
    local cold=context(available); local b,be=compiler.compile(source,cold)
    assert(not not a==not not b and (not ae or ae.code==be.code and ae.message==be.message))
    assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total,'cache changed partial compilation spending')
    count=count+1
  end
  for _,available in ipairs({0,1,100,1000}) do
    assert(compiler.compile(source,admission.context(admission.new(),'warm-up',0)))
    local warm=context(limits.compile_work,available); local a,ae=compiler.compile(source,warm)
    evict(); local cold=context(limits.compile_work,available); local b,be=compiler.compile(source,cold)
    assert(not a and not b and ae.code=='E_BUDGET' and be.code==ae.code)
    assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
    count=count+1
  end
  local ctx=admission.context(admission.new(),'mutation',0)
  local plan=assert(compiler.compile(source,ctx))
  plan.handlers.start=nil; plan.generated='error("caller executable trusted")'; plan.nodes=-1
  local ok,problem=compiler.run(plan,'start',{}, {},ctx)
  assert(ok,problem and problem.message)
  local safe=assert(compiler.compile(source,admission.context(admission.new(),'readback',0)))
  assert(safe.handlers.start and safe.generated~='error("caller executable trusted")' and safe.nodes>0)
  log('TC_COMPILER_CACHE_OK comparisons='..count..' exact-credits caller-isolation bounded-eviction')
end
return M
