-- Exact-source cache must not change credits, partial refusal or trust caller data.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local parsing=require('scripts.runtime.parse_admission')
local limits=require('scripts.runtime.limits')
local M={}
local source='return {api_version=1,handlers={start=function(e) local t={1,2,3}; for i,v in ipairs(t) do assert(i==v) end end}}'
local serial=0
local function evict()
  local allowance=limits.compiler_cache_bytes
  limits.compiler_cache_bytes=1
  serial=serial+1
  local text='return {api_version=1,handlers={start=function(e) local n='..serial..' end}}'
  local ok,plan,problem=pcall(compiler.compile,text,admission.context(admission.new(),'evict',0))
  limits.compiler_cache_bytes=allowance
  assert(ok and plan,problem and problem.message or 'cache eviction probe failed')
end
local function context(remaining,shared)
  local ctx=admission.context(admission.new(),'comparison',0)
  ctx.machine.compile=limits.compile_work-remaining
  ctx.ledger.total=shared and limits.host_work_per_tick-limits.maintenance_work_per_tick-shared or ctx.machine.compile
  return ctx
end
-- Fitting summaries may batch charges; refusals must retain the exact cold prefix.
local function observed(text,ctx,mode)
  local reserve=admission.reserve
  local replay_proof=parsing.replay
  local prefix,used_replay={},false
  parsing.replay=function(charges) used_replay=true; return replay_proof(charges) end
  admission.reserve=function(c,kind,n)
    local ok=reserve(c,kind,n)
    if c==ctx and kind=='compile' and ok then prefix[#prefix+1]=n end
    return ok
  end
  local ok,plan,problem=pcall(compiler.compile,text,ctx,mode)
  admission.reserve=reserve
  parsing.replay=replay_proof
  assert(ok,plan)
  return plan,problem,table.concat(prefix,','),used_replay
end
function M.run()
  -- Source-derived cache keys must not be constructed before source admission.
  local format=string.format; local formats=0
  string.format=function(...) formats=formats+1; return format(...) end
  local ok,plan,problem=pcall(compiler.prepare,'--'..string.rep('x',100000),context(0))
  string.format=format
  assert(ok and not plan and problem.recoverable and problem.resource=='compile_work')
  assert(formats==0,'compiler constructed its cache key before source admission')
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
  for _,text in ipairs({'false','x=5; local y=6','return {api_version=1,handlers={}}'}) do
    for _,available in ipairs({0,1,100,1000,limits.compile_work}) do
      assert(compiler.compile(text,admission.context(admission.new(),'shell-warm',0),'shell'))
      local warm=context(available); local a,ae=compiler.compile(text,warm,'shell')
      evict()
      local cold=context(available); local b,be=compiler.compile(text,cold,'shell')
      assert(not not a==not not b and (not ae or ae.code==be.code and ae.message==be.message))
      assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total,'shell fallback cache changed charges')
      count=count+1
    end
  end
  local text='return {api_version=1,handlers={}}'
  local program=assert(compiler.compile(text,admission.context(admission.new(),'mode-program',0)))
  local shell=assert(compiler.compile(text,admission.context(admission.new(),'mode-shell',0),'shell'))
  assert(program.mode==nil and shell.mode=='shell' and program.generated~=shell.generated,'compiler modes shared an executable proof')
  assert(not compiler.compile('x=5',admission.context(admission.new(),'program-only',0)))
  local declaration=[[
local function increment(n) return n+1 end
function start(e) assert(sample(false,nil,3)==4) end
function sample(a,b,n) assert(a==false and b==nil); return increment(n) end
]]
  local measured=context(limits.compile_work)
  assert(compiler.compile(declaration,measured))
  local cost=measured.machine.compile
  local successes,refusals,partial=0,0,0
  for _,shared in ipairs({false,true}) do
    for _,available in ipairs({0,1,#declaration*2,#declaration*2+1,1000,cost-1,cost,cost+1,limits.compile_work}) do
      assert(compiler.compile(declaration,admission.context(admission.new(),'declaration-warm',0)))
      local warm=context(shared and limits.compile_work or available,shared and available or nil)
      local a,ae,ap,replayed=observed(declaration,warm)
      assert(replayed==(available>=#declaration*2+1),'cache lookup did not follow source admission')
      evict()
      local cold=context(shared and limits.compile_work or available,shared and available or nil)
      local b,be,bp,cached=observed(declaration,cold)
      assert(not cached,'eviction did not remove declaration proof')
      assert(not not a==not not b and (not ae or ae.code==be.code and ae.message==be.message))
      if not a then assert(ap==bp,'cache changed refused declaration charge prefix') end
      assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
      if a then successes=successes+1 else
        assert(ae.code=='E_BUDGET'); refusals=refusals+1
        if ap~='' then partial=partial+1 end
      end
      count=count+1
    end
  end
  assert(successes>0 and refusals>0 and partial>0)
  local mutable=assert(compiler.compile(declaration,admission.context(admission.new(),'declaration-mutation',0)))
  mutable.handlers.start=nil; mutable.handlers.injected=true
  mutable.generated='error("caller executable trusted")'; mutable.nodes=-1
  local ran,problem=compiler.run(mutable,'start',{}, {},admission.context(admission.new(),'declaration-run',0))
  assert(ran,problem and problem.message)
  local safe_declaration=assert(compiler.compile(declaration,admission.context(admission.new(),'declaration-readback',0)))
  assert(safe_declaration.source==declaration and safe_declaration.handlers.start and safe_declaration.handlers.sample
    and not safe_declaration.handlers.increment and not safe_declaration.handlers.injected
    and safe_declaration.nodes>0 and safe_declaration.generated~=mutable.generated)
  ran,problem=compiler.run(mutable,'injected',{}, {},admission.context(admission.new(),'injected',0))
  assert(not ran and problem.code=='E_NOT_FOUND')
  -- The same valid document has distinct program/shell semantics. Neither the
  -- cache nor caller mutations may turn shell global writes into exports.
  local shell_declaration=assert(compiler.compile(declaration,admission.context(admission.new(),'declaration-shell',0),'shell'))
  assert(shell_declaration.mode=='shell' and safe_declaration.mode==nil
    and shell_declaration.generated~=safe_declaration.generated)
  assert(not compiler.run(shell_declaration,'start',{}, {},admission.context(admission.new(),'declaration-mode-run',0)))
  local variant=assert(compiler.compile(declaration..'-- exact second source',admission.context(admission.new(),'exact-source',0)))
  assert(variant.source~=safe_declaration.source and variant.handlers.start)
  log('TC_COMPILER_CACHE_OK comparisons='..count..' exact-credits caller-isolation bounded-eviction mode-separated-shell-fallback')
end
return M
