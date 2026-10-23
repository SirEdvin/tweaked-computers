-- Private cache warmth/eviction must not change synchronization or admission.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local saved_cache,saved_compile=limits.compiler_cache_bytes,limits.compile_work
  local source=[[function start()
    computer.log('cache-prefix'); local n=0
    while n<300000 do n=n+1 end
    computer.log(n)
  end]]
  local function slice()
    local ledger=admission.new(); local effects={}; local state={}
    local plan={source=source,api_version=1,compiler_version=limits.compiler_version}
    local ok,problem,control=compiler.run(plan,'start',{}, {computer={log=function(v) effects[#effects+1]=v end}},
      admission.context(ledger,'cache-test',1),state)
    return {ok=ok,problem=problem,control=control,state=state,machine=ledger.machines['cache-test'],
      total=ledger.total,effects=effects}
  end
  local function equal(a,b)
    assert(a.ok==b.ok and a.control==b.control and a.total==b.total)
    for _,kind in ipairs({'compile','work','allocations'}) do assert(a.machine[kind]==b.machine[kind],kind..' changed with cache warmth') end
    assert((a.problem and a.problem.code)==(b.problem and b.problem.code))
    assert((a.state.frame and a.state.frame.pc)==(b.state.frame and b.state.frame.pc),'cache changed paused position')
    assert(#a.effects==#b.effects)
    for i=1,#a.effects do assert(a.effects[i]==b.effects[i]) end
  end
  local ok,e=pcall(function()
    local native_source='function start() local x="private native cache"; assert(x~=nil) end'
    local a=admission.context(admission.new(),'native-cold',0)
    local b=admission.context(admission.new(),'native-warm',0)
    local plan,problem,first=compiler.prepare(native_source,a)
    assert(plan and first,problem and problem.message)
    local second_plan,second_problem,second=compiler.prepare(native_source,b)
    assert(second_plan and second,second_problem and second_problem.message)
    assert(first==second,'warm reconstruction reloaded unchanged trusted native blocks')
    assert(a.machine.compile==b.machine.compile and a.ledger.total==b.ledger.total)
    local original=first(); local modified=second(); modified.entries.start=nil
    assert(original.entries.start and first().entries.start,'caller mutated cached executable data')
    limits.compiler_cache_bytes=1
    local c=admission.context(admission.new(),'native-evicted',0)
    local evicted_plan,evicted_problem,evicted_factory=compiler.prepare(native_source,c)
    assert(evicted_plan and evicted_factory and evicted_factory~=first,evicted_problem and evicted_problem.message)
    assert(a.machine.compile==c.machine.compile and a.ledger.total==c.ledger.total)
    local evicted=slice(); assert(evicted.control=='wait' and #evicted.effects==1)
    limits.compiler_cache_bytes=saved_cache
    local cold=slice(); local warm=slice()
    equal(evicted,cold); equal(cold,warm)
    limits.compile_work=cold.machine.compile-1
    local warm_short=slice()
    assert(not warm_short.ok and warm_short.problem.code=='E_BUDGET' and #warm_short.effects==0)
    limits.compiler_cache_bytes=1
    local cold_short=slice(); equal(warm_short,cold_short)
    limits.compiler_cache_bytes=saved_cache; limits.compile_work=saved_compile
    local full=slice(); equal(cold,full)
  end)
  limits.compiler_cache_bytes=saved_cache; limits.compile_work=saved_compile
  assert(ok,type(e)=='table' and e.message or tostring(e))
  log('TC_CONTRACT continuation-cache-warm-cold-evicted-and-partial-admission-equal')
end
return M
