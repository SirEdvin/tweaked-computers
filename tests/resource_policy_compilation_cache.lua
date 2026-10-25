-- Private cache warmth/eviction must not change synchronization or admission.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local registry=require('scripts.registry')
local M={}
function M.run()
  registry.initialize()
  local saved_cache,saved_compile,saved_host=limits.compiler_cache_bytes,limits.compile_work,limits.host_memory_bytes
  local native_load,native_reserve=load,memory.reserve
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
    local account=policy.host_account(function() end)
    local used,reserved=account.used,account.reserved
    local bytes
    _G.load=function(...)
      bytes=account.reserved-reserved
      return native_load(...)
    end
    local native_source=[[local function pack(...) return {...} end
function start(...)
  local x,y=1,2; local t={x,y,key="private native cache"}
  local function bump(n) x=x+n; return x,nil end
  for i=1,2 do t[i]=bump(i) end
  for k,v in pairs(t) do if k=="key" then break else y=y+v end end
  while x<10 do x=x+1 end
  repeat y=y-1 until y==0
  do local z=not false and #t or -1; assert(z) end
  local a,b=pack(...),t.key.."!"; assert(a,b)
end]]
    local a=admission.context(admission.new(),'native-cold',0)
    local b=admission.context(admission.new(),'native-warm',0)
    local requests={}
    memory.reserve=function(owner,amount)
      assert(owner.account==account)
      requests[#requests+1]={used=account.used+account.reserved,amount=amount,work=a.machine.compile}
      return native_reserve(owner,amount)
    end
    local plan,problem,first=compiler.prepare(native_source,a)
    _G.load,memory.reserve=native_load,native_reserve
    assert(plan and first,problem and problem.message)
    assert(bytes>#plan.generated*8,'lowering workspace was not admitted before native loading')
    assert(#requests>2 and requests[1].amount==9*192
      and requests[#requests].amount==#plan.generated*8,'workspace probe missed its real allocation boundaries')
    local second_plan,second_problem,second=compiler.prepare(native_source,b)
    assert(second_plan and second,second_problem and second_problem.message)
    assert(first==second,'warm reconstruction reloaded unchanged trusted native blocks')
    assert(a.machine.compile==b.machine.compile and a.ledger.total==b.ledger.total)
    local original=first(); local modified=second(); modified.entries.start=nil
    assert(original.entries.start and first().entries.start,'caller mutated cached executable data')
    local block_boundary,operand_boundary,liveness_boundary,quote_boundary
    for i,step in ipairs(requests) do
      if step.amount==2*192+8*48 then block_boundary=block_boundary or i end
      if step.amount==192+7*48 then operand_boundary=operand_boundary or i end
      if step.amount==2*192+2*48*#original.blocks then liveness_boundary=liveness_boundary or i end
      if step.amount==34+4*#'private native cache' then quote_boundary=quote_boundary or i end
    end
    assert(block_boundary and operand_boundary and liveness_boundary
      and block_boundary<liveness_boundary and operand_boundary<liveness_boundary,
      'graph growth was not admitted before liveness analysis')
    assert(quote_boundary and requests[#requests-1].amount>=32+#plan.generated,
      'quoted literal or final generated join was not admitted')
    -- Refuse graph construction as well as later analysis, with competing shortages.
    for _,index in ipairs({1,block_boundary,operand_boundary,quote_boundary,liveness_boundary,math.floor(#requests/2),#requests-1}) do
      local step=requests[index]
      for _,short_work in ipairs({false,true}) do
        assert(compiler.prepare(native_source,admission.context(admission.new(),'warm-lowering',0)))
        limits.host_memory_bytes=step.used+step.amount-1
        limits.compile_work=short_work and step.work-1 or saved_compile
        _G.load=function() error('refused lowering reached native loading') end
        local warm=admission.context(admission.new(),'lowering-warm',0)
        local refused,reason=compiler.prepare(native_source,warm)
        assert(not refused and reason.recoverable and reason.resource==(short_work and 'compile_work' or 'host_memory'))
        limits.compiler_cache_bytes=1
        local cold=admission.context(admission.new(),'lowering-cold',0)
        local denied,problem=compiler.prepare(native_source,cold)
        assert(not denied)
        for _,field in ipairs({'code','resource','setting','used','requested','limit'}) do
          assert(problem[field]==reason[field],'lowering refusal changed with cache warmth: '..field)
        end
        assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
        assert(account.used==used and account.reserved==reserved,'lowering refusal leaked workspace')
        _G.load=native_load
        limits.host_memory_bytes=saved_host; limits.compile_work=saved_compile; limits.compiler_cache_bytes=saved_cache
      end
    end
    -- One source key may change backend/mode; a foreign proof must never replay.
    local legacy=assert(compiler.compile(native_source,admission.context(admission.new(),'legacy-variant',0)))
    assert(legacy.generated~=plan.generated)
    local shell,problem,shell_factory=compiler.prepare(native_source,admission.context(admission.new(),'shell-variant',0),'shell')
    assert(shell and shell_factory and shell.mode=='shell' and shell_factory().entries.command,problem and problem.message)
    local changed=admission.context(admission.new(),'program-variant',0)
    local replaced,problem,replacement=compiler.prepare(native_source,changed)
    assert(replaced and replacement and replacement~=first and replacement().entries.start,problem and problem.message)
    assert(changed.machine.compile==a.machine.compile and changed.ledger.total==a.ledger.total)
    limits.compiler_cache_bytes=1
    local denied=admission.context(admission.new(),'evict-without-source-credit',0)
    denied.machine.compile=limits.compile_work
    local refused,diagnostic=compiler.prepare(native_source,denied)
    assert(not refused and diagnostic.recoverable and diagnostic.resource=='compile_work')
    limits.compiler_cache_bytes=saved_cache
    local c=admission.context(admission.new(),'native-evicted',0)
    local evicted_plan,evicted_problem,evicted_factory=compiler.prepare(native_source,c)
    assert(evicted_plan and evicted_factory and evicted_factory~=replacement,
      evicted_problem and evicted_problem.message or 'refused source prevented cache-limit reconciliation')
    assert(a.machine.compile==c.machine.compile and a.ledger.total==c.ledger.total)
    local blocked_source='function start() local x=0; '..string.rep('x=x+1; ',3000)..' end'
    limits.host_memory_bytes=used+reserved
    local blocked_context=admission.context(admission.new(),'frontend-memory-full',0)
    local denied,reason=compiler.prepare(blocked_source,blocked_context)
    assert(not denied and reason.recoverable and reason.resource=='host_memory',
      'full host memory entered the frontend instead of refusing before parsing')
    assert(blocked_context.machine.compile==#blocked_source*2+1,'full host memory traversed the source')
    assert(account.used==used and account.reserved==reserved,'frontend refusal leaked workspace')
    limits.host_memory_bytes=saved_host
    local invalid,syntax=compiler.prepare('function broken(',admission.context(admission.new(),'frontend-syntax',0))
    assert(not invalid and syntax.code=='E_PROGRAM')
    assert(account.used==used and account.reserved==reserved,'parser error leaked workspace')
    limits.compile_work=#native_source*2+2
    local partial,exhausted=compiler.prepare(native_source,admission.context(admission.new(),'frontend-work',0))
    limits.compile_work=saved_compile
    assert(not partial and exhausted.recoverable and exhausted.resource=='compile_work')
    assert(account.used==used and account.reserved==reserved,'frontend work refusal leaked workspace')
    local loads=0
    _G.load=function(...)
      loads=loads+1
      assert(account.used==used+128 and account.reserved==reserved+bytes,'native load ran without admitted workspace')
      return native_load(...)
    end
    limits.host_memory_bytes=used+reserved+128+bytes-1
    local warm=admission.context(admission.new(),'native-memory-warm',0)
    local refused,reason=compiler.prepare(native_source,warm)
    assert(not refused and reason.recoverable and reason.resource=='host_memory' and reason.setting=='tc-host-memory-bytes',
      'warm native preparation bypassed host memory admission')
    local request={}; compiler.hold(request,reason)
    assert(compiler.blocked(request),'unchanged native memory refusal retried')
    limits.compiler_cache_bytes=1
    local cold=admission.context(admission.new(),'native-memory-cold',0)
    local denied,problem=compiler.prepare(native_source,cold)
    assert(not denied and problem.code==reason.code and problem.used==reason.used and problem.requested==reason.requested)
    assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
    assert(loads==0 and account.used==used and account.reserved==reserved,'refused native load changed ownership')
    limits.host_memory_bytes=used+reserved+128+bytes
    assert(not compiler.blocked(request),'raised native memory allowance did not unblock reconstruction')
    local fitting,problem=compiler.prepare(native_source,admission.context(admission.new(),'native-memory-fit',0))
    assert(fitting and loads==1,problem and problem.message)
    assert(account.used==used and account.reserved==reserved,'successful native load leaked workspace')
    _G.load=function() error('injected native loader failure') end
    local failed,problem=compiler.prepare(native_source,admission.context(admission.new(),'native-memory-failure',0))
    assert(not failed and problem.message:find('injected native loader failure',1,true))
    assert(account.used==used and account.reserved==reserved,'failed native load leaked workspace')
    _G.load=native_load
    limits.host_memory_bytes=saved_host
    memory.configure(account,saved_host)
    local pressure=memory.owner(account,bytes)
    limits.host_memory_bytes=account.used+account.reserved+128+bytes-1
    local refused,reason=compiler.prepare(native_source,admission.context(admission.new(),'native-memory-pressure',0))
    assert(not refused and reason.resource=='host_memory')
    compiler.hold(request,reason); assert(compiler.blocked(request))
    memory.close(pressure,function() end)
    assert(not compiler.blocked(request),'released host memory did not unblock reconstruction')
    assert(compiler.prepare(native_source,admission.context(admission.new(),'native-memory-released',0)))
    limits.host_memory_bytes=saved_host
    memory.configure(account,saved_host)
    limits.compiler_cache_bytes=1
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
  _G.load,memory.reserve=native_load,native_reserve
  limits.compiler_cache_bytes=saved_cache; limits.compile_work=saved_compile; limits.host_memory_bytes=saved_host
  assert(ok,type(e)=='table' and e.message or tostring(e))
  log('TC_CONTRACT continuation-cache-warm-cold-evicted-and-partial-admission-equal')
end
return M
