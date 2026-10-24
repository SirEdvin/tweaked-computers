-- Real guard/owner and native connectors; freeze after cached authority, before effect.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local peripheral=require('scripts.services.peripheral')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local sandbox=require('scripts.runtime.sandbox')
local errors=require('scripts.runtime.errors')
local contracts=require('tests.resource_policy_discovery')
local M={}; local loaded=false
local function f() return storage.tc_inventory_cache_cold end
local function conn(r) return assert(lifecycle.connector(r,'network','red')) end
local function build(kind,x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
  lifecycle.on_built{entity=body}; local r=assert(registry.by_entity(body)); r.powered=true
  lifecycle.power_entity(r).energy=100000; return r
end
peripheral.register_type('monitor',{callback_stable=true,with_guard=true,methods={
  getLimits=function() return {} end,
  probe=function(c,r,wire,tick,spend,g)
    assert(f().hits>0,'probe did not exercise cached discovery')
    if f().phase=='running' then f().paused=true; g.suspend() end
    g.prepare_empty_result(); f().effects=f().effects+1
  end,
}})
function M.run()
  registry.initialize()
  local c,m=build('computer',0),build('monitor',3)
  c.status='running'; c.run_id=c.id..'/cache-cold'; assert(conn(c).connect_to(conn(m)))
  local account=memory.new(limits.runtime_memory_bytes,4096)
  local owner=memory.owner(account)
  storage.tc_inventory_cache_cold={phase='running',c=c.id,m=m.id,ledger=admission.new(),checkpoint={},
    account=account,owner=owner,hits=0,effects=0,done=0,steps=0,
    source='function start() local m=peripheral.wrap('..string.format('%q',m.id)..",'red'); local ok,e=pcall(m.probe); assert(not ok and e.code=='E_UNREACHABLE'); computer.finished() end"}
  local origin=build('computer',30); origin.status='running'; origin.run_id=origin.id..'/progress'
  local previous=origin
  for i=1,12 do local member=build('monitor',30+i*3); assert(conn(previous).connect_to(conn(member))); previous=member end
  assert(conn(previous).connect_to(conn(origin),false))
  local graph_account=memory.new(limits.runtime_memory_bytes,4096)
  f().progress={c=origin.id,target=previous.id,account=graph_account,owner=memory.owner(graph_account),
    ledger=admission.new(),pending={},checkpoint={owned={},owned_order={},symbols={},bindings={},functions={}}}
end
function M.on_load()
  loaded=f().phase=='frozen'
  if loaded then
    assert(f().paused and f().effects==0 and f().hits>0)
    local p=f().progress; local job=p.pending.jobs['peripheral-inventory-red']
    assert(job.graph.cursor==p.saved_cursor and #job.graph.queue==p.saved_queue and p.owner.account.used==p.saved_used)
    assert(p.ledger.total==p.saved_work); contracts.assert_owned(p.owner,job)
    log('TC_COLD_ON_LOAD_UNCHANGED')
  end
end
local function advance_progress(x,tick)
  local p=x.progress; if p.done or x.phase=='running' and p.paused then return end
  local c=registry.record(p.c); lifecycle.power_entity(c).energy=100000
  local ctx=admission.context(p.ledger,c.id,tick); ctx.memory_owner=p.owner
  -- Spend the rest of this real tick's slice; never lower or renew production limits.
  assert(admission.reserve(ctx,'work',limits.callback_work-512))
  local g=sandbox.new(ctx,{},nil,p.checkpoint); g.call_checkpoint(p.pending)
  if x.phase=='resume' and not p.pressure_checked then memory.configure(p.account,p.account.used) end
  local ok,result=pcall(peripheral.services(c,tick,g).peripheral.isPresent,p.target,'red')
  local job=assert(p.pending.jobs['peripheral-inventory-red'])
  contracts.assert_owned(p.owner,job)
  if not ok and errors.resource_diagnostic(result) then
    assert(x.phase=='resume' and not p.pressure_checked)
    p.pressure_checked=true; memory.configure(p.account,limits.runtime_memory_bytes); return
  end
  if not ok then
    assert(g.work_suspended(),'graph progress failed outside work pressure')
    if job.graph and job.graph.cursor>1 and job.graph.cursor<=#job.graph.queue then
      p.paused=true; p.saved_cursor=job.graph.cursor; p.saved_queue=#job.graph.queue
      p.saved_used=p.account.used; p.saved_work=p.ledger.total
    end
  else
    assert(x.phase=='resume' and p.pressure_checked and result,'graph completed without the required cold/pressure boundary')
    local count=0; for _ in pairs(job.inventory) do count=count+1 end; assert(count==12)
    memory.close(p.owner,function() end); assert(next(p.account.values)==nil and p.account.reserved==0)
    p.done=true
    log('TC_DISCOVERY_PROGRESS_OK partial-cycle paid-cold-cursor lower-refuse-raise complete-12 released')
  end
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local c,m=registry.record(x.c),registry.record(x.m)
  lifecycle.power_entity(c).energy=100000; lifecycle.power_entity(m).energy=100000
  if x.phase=='frozen' then
    if not loaded then return end
    loaded=false; x.phase='resume'; assert(conn(c).disconnect_from(conn(m)))
  end
  x.steps=x.steps+1; assert(x.steps<100,'cache cold run did not finish')
  advance_progress(x,event.tick)
  if x.completed then
    if x.progress.done then x.phase='done'; log('TC_COLD_OK') end
    return
  end
  local ctx=admission.context(x.ledger,c.id,event.tick); ctx.memory_owner=x.owner
  local plan,e=compiler.compile(x.source,ctx); assert(plan,e and e.message)
  local ok,problem,control=compiler.run(plan,'start',nil,function(g)
    local try=assert(g.try_job_work,'missing cached discovery admission')
    g.try_job_work=function(...) local result=try(...); if result then x.hits=x.hits+1 end; return result end
    local services=peripheral.services(c,event.tick,g)
    services.computer={finished=function() g.prepare_empty_result(); x.done=x.done+1 end}
    return services
  end,ctx,x.checkpoint)
  if x.phase=='running' and x.paused and x.progress.paused then
    assert(not ok and control=='wait' and not problem and x.effects==0)
    local pending=assert(x.checkpoint.frame.pending)
    local job=assert(pending.jobs['peripheral-inventory-red'])
    assert(job.graph and job.inventory and job.inventory[m.id])
    contracts.assert_owned(x.owner,job)
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if ok then
    assert(x.phase=='resume' and x.done==1 and x.effects==0)
    memory.close(x.owner,function() end)
    assert(next(x.account.values)==nil and x.account.reserved==0)
    x.completed=true; log('TC_INVENTORY_CACHE_COLD_OK cached-job cold-authority exact-once owner-released')
    if x.progress.done then x.phase='done'; log('TC_COLD_OK') end
  else assert(control=='wait' and not problem,problem and problem.message or control) end
end
return M
