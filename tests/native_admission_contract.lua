local admission=require('scripts.runtime.admission')
local environment=require('scripts.runtime.environment')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local ledger=admission.new()
  assert(ledger.version==2)
  local ctx=admission.context(ledger,'host-only',7)
  assert(ctx.machine.allocations==nil and select('#',admission.bind(ctx))==1)
  local spend=admission.bind(ctx)
  assert(spend(500001),'retired callback ceiling still applies')
  local env=environment.new(ctx,{}); env.initialize()
  local before=ledger.total
  env.execute(assert(load('local t={}; for i=1,2048 do t[i]=i end; assert(#t==2048)','@computer','t',env.globals)))
  assert(ledger.total==before)
  local ceiling=limits.host_work_per_tick
  limits.host_work_per_tick=ledger.total+limits.maintenance_work_per_tick
  assert(not spend(1) and ledger.total==before,'live decrease renewed host credits')
  limits.host_work_per_tick=ceiling
  local trace={3,5,7,total=15}
  ledger.total=admission.host_ceiling(ledger,7)-9
  before=ledger.total
  assert(not admission.replay_work(ctx,trace) and ledger.total==before+8)
  assert(not pcall(admission.reserve,ctx,'allocations',1))
  admission.context(ledger,'next-tick',8)
  assert(not pcall(spend,1) and not pcall(admission.reserve,ctx,'work',1))
  local current=admission.context(ledger,'identity',8)
  local bound=admission.bind(current)
  ledger.machines.identity={work=0,compile=0}
  assert(not pcall(bound,1) and not pcall(admission.reserve,current,'work',1))
  log('TC_CONTRACT native-host-admission-live-ceilings-and-identity')
  local maintenance={maintenance_tick=17,maintenance_spent=123}
  local machine={work=50,compile=20,allocations=30}
  local old={version=1,tick=17,total=100,machines={legacy=machine},maintenance=maintenance}
  assert(admission.upgrade(old))
  assert(old.version==2 and old.tick==17 and old.total==100 and old.maintenance==maintenance)
  assert(old.machines.legacy==machine and machine.compile==20 and machine.work==0 and machine.allocations==nil)
  assert(admission.upgrade(old) and old.total==100)
  local remaining=admission.host_ceiling(old,17)-old.total
  assert(admission.reserve(admission.context(old,'legacy',17),'work',remaining))
  assert(not admission.reserve(admission.context(old,'neighbor',17),'work',1))
  for _,bad in ipairs({
    {version=99,tick=17,total=100,machines={}},
    {version=1,tick=17,total=100,machines={legacy={work=-1,compile=20,allocations=30}}},
    {version=1,tick=17,total=100,machines={legacy={work=50,compile=20,allocations='bad'}}},
    {version=1,tick=17,total=1,machines={legacy={work=50,compile=20,allocations=30}}}
  }) do
    local version,total,machines=bad.version,bad.total,bad.machines
    assert(not admission.upgrade(bad))
    assert(bad.version==version and bad.total==total and bad.machines==machines)
  end
  log('TC_CONTRACT native-ledger-conversion-without-refunds')
  local host,compile,maintenance_limit=limits.host_work_per_tick,limits.compile_work,limits.maintenance_work_per_tick
  limits.host_work_per_tick,limits.compile_work,limits.maintenance_work_per_tick=1000,400,0
  for _,kind in ipairs({'work','compile'}) do
    for _,replay in ipairs({false,true}) do
      local c=admission.context(admission.new(),'prepare',1)
      assert(admission.reserve(c,kind,250))
      if kind=='work' then assert(admission.reserve(c,'work',600)) end
      local spent=c.ledger.total
      admission.begin_preparation(c)
      local accepted
      if replay then accepted=(kind=='work' and admission.replay_work or admission.replay_compile)(c,{100,200,total=300})
      else assert(admission.reserve(c,kind,100)); accepted=admission.reserve(c,kind,200) end
      assert(not accepted and admission.finish_preparation(c) and c.preparation==nil)
      assert(c.ledger.total==spent+100,'preparation refusal refunded its accepted prefix')
    end
  end
  local c=admission.context(admission.new(),'bound-prepare',1)
  local bound_spend=admission.bind(c)
  assert(bound_spend(950)); admission.begin_preparation(c)
  assert(not bound_spend(100) and admission.finish_preparation(c))
  for _,kind in ipairs({'work','compile'}) do
    c=admission.context(admission.new(),'impossible',1)
    admission.begin_preparation(c)
    local amount=kind=='work' and 1001 or 401
    assert(not admission.reserve(c,kind,amount) and not admission.finish_preparation(c))
  end
  c=admission.context(admission.new(),'impossible-bound',1)
  admission.begin_preparation(c)
  assert(not admission.bind(c)(1001) and not admission.finish_preparation(c))
  limits.host_work_per_tick,limits.compile_work,limits.maintenance_work_per_tick=host,compile,maintenance_limit
  log('TC_CONTRACT preparation-prefix-admission-without-credit-refunds')
  log('TC_CONTRACT_TOTAL 3')
end
return M
