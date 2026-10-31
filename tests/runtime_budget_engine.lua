-- Real settings and registered production event handler; no client GUI claim.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local budgets=require('scripts.runtime.budget-settings')
local M={}
local loaded=false
local names={compile='tc-compile-work',work='tc-callback-work',allocations='tc-callback-allocations',host='tc-host-work-per-tick',maintenance='tc-maintenance-work-per-tick'}
local defaults={compile=1250000,work=500000,allocations=81920,host=5000000,maintenance=200000}
local keys={compile='compile_work',work='callback_work',allocations='callback_allocations',host='host_work_per_tick',maintenance='maintenance_work_per_tick'}
local serial=0
local function change(kind,value)
  settings.global[names[kind]]={value=value}
  assert(settings.global[names[kind]].value==value)
  -- Invoke the actual handler registered by control.lua with the engine payload.
  -- Direct assignment is not a player-generated settings GUI event.
  local handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
  handler{setting=names[kind],setting_type='runtime-global',tick=game.tick}
  local effective=kind=='maintenance' and math.min(value,limits.host_work_per_tick-1) or value
  assert(limits[keys[kind]]==effective,'live setting not applied: '..kind)
end
local function source(body)
  return 'function start(event) '..body..' end'
end
local function fresh()
  storage.tweaked_computers=nil
  return registry.initialize()
end
local function computer(body)
  serial=serial+1
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={serial*2,0},force='player'})
  local rec=registry.register('computer',entity)
  runtime.save(rec.id,source(body),0)
  local id,e=runtime.activate(rec.id,game.tick)
  assert(id,e and e.message)
  return rec
end
local function run(body)
  local root=fresh(); local rec=computer(body)
  assert(scheduler.dispatch(rec,game.tick),'callback indefinitely deferred')
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  return rec,root.ledger.machines[rec.id]
end
local function restored_defaults()
  for kind,value in pairs(defaults) do change(kind,value) end
end
local function frozen()
  local f=storage.tc_budget_fixture; local root=registry.get()
  assert(root.ledger.tick==f.tick and root.ledger.total==f.total)
  local ctx=admission.context(root.ledger,f.id,f.tick)
  for _,kind in ipairs({'compile','work','allocations'}) do
    assert(ctx.machine[kind]==f.spent[kind],'reload refreshed '..kind)
    assert(limits[keys[kind]]==f.values[kind],'reload lost '..kind..' setting')
  end
  assert(limits.host_work_per_tick==f.values.host)
  assert(limits.maintenance_work_per_tick==f.values.maintenance)
  assert(root.ledger.maintenance==root.scheduler and root.scheduler==f.scheduler)
  assert(root.scheduler.maintenance_spent==f.maintenance and root.scheduler.maintenance_tick==f.tick)
  assert(root.scheduler.render_reserved_work==f.reserved and root.marker==f.marker)
  return ctx
end
local function maintenance_contracts(report)
  local definitions=budgets.definitions
  local definition=definitions[#definitions]
  assert(definition.name==names.maintenance and definition.minimum_value==200000
    and definition.maximum_value==100000000 and definition.default_value==200000)
  local root=fresh(); local t=game.tick
  local spend=scheduler.maintenance(root,t,true)
  spend(25000)
  change('maintenance',300000)
  spend(275000)
  assert(not scheduler.try_maintenance(function() spend(1) end))
  change('maintenance',200000)
  assert(not scheduler.try_maintenance(function() spend(1) end))
  assert(root.scheduler.maintenance_spent==300000)
  -- Retained validation must accept an old spent total above the new ceiling.
  assert(not scheduler.try_maintenance(function() scheduler.maintenance(root,t,true)(1) end))
  change('maintenance',300001); spend(1)
  assert(root.scheduler.maintenance_spent==300001)
  local rec=computer('computer.setState("untouched",true)')
  change('host',200001)
  assert(admission.guest_ceiling(root.ledger,t)==0)
  local total=root.ledger.total; local queued=rec.queue[1]
  assert(not scheduler.dispatch(rec,t) and rec.queue[1]==queued and rec.status=='running')
  assert(root.ledger.total==total and rec.last_dispatch_tick==nil)
  -- Table-backed registration isolates scheduler entry -> authentic sampler
  -- refusal. Native subscription/output cleanup is covered by logic_engine.
  assert(runtime.subscribe(rec,'signal_changed','start'))
  scheduler.tick(t)
  assert(rec.status=='faulted' and rec.diagnostic.code=='E_BUSY',
    'scheduler entry deferral silently skipped fail-closed signal sampling')
  assert(root.scheduler.maintenance_spent==300001 and root.ledger.total==total)
  report('maintenance-live-increase-decrease-and-captured-spend-preserve-credits')

  change('host',600001); change('maintenance',300000)
  root=fresh(); local ctx=admission.context(root.ledger,'split',t)
  spend=scheduler.maintenance(root,t,true); spend(300000)
  assert(admission.reserve(ctx,'work',300001))
  change('maintenance',200000)
  assert(not admission.reserve(ctx,'work',1),'decrease refunded spent maintenance to guests')
  assert(not admission.replay_work(ctx,{1,total=1}) and ctx.machine.work==300001)
  change('host',600002)
  assert(admission.replay_work(ctx,{1,total=1}) and ctx.machine.work==300002)
  assert(root.scheduler.maintenance_spent+root.ledger.total==600002)
  report('maintenance-decrease-retains-shared-spent-headroom-and-cache-replay')

  root=fresh(); ctx=admission.context(root.ledger,'guest-first',t)
  change('host',700000)
  assert(admission.reserve(ctx,'work',480000))
  spend=scheduler.maintenance(root,t,true); spend(100000)
  change('maintenance',400000)
  spend(120000)
  assert(not scheduler.try_maintenance(function() spend(1) end),'increase reused spent guest headroom')
  assert(root.scheduler.maintenance_spent+root.ledger.total==700000)
  change('host',600000)
  assert(not scheduler.try_maintenance(function() spend(1) end))
  assert(not admission.reserve(ctx,'work',1) and root.ledger.total==480000)
  scheduler.tick(t)
  assert(root.scheduler.last_tick==t and root.scheduler.maintenance_spent==220000,
    'empty demand round crashed or reset retained spending')
  report('maintenance-increase-and-host-decrease-respect-combined-spent-work')

  change('maintenance',100000000); change('host',200001)
  assert(limits.host_work_per_tick==200001 and limits.maintenance_work_per_tick==200000)
  root=fresh(); ctx=admission.context(root.ledger,'minimum',t)
  assert(admission.reserve(ctx,'work',1) and not admission.reserve(ctx,'work',1))
  spend=scheduler.maintenance(root,t,true); spend(200000)
  assert(not scheduler.try_maintenance(function() spend(1) end))
  change('host',100000001)
  assert(limits.maintenance_work_per_tick==100000000)
  restored_defaults()
  report('maintenance-request-clamped-to-host-without-changing-host-setting')

  root=fresh(); change('maintenance',400000)
  spend=scheduler.maintenance(root,t)
  scheduler.request_render_work(root,t,160000,function() end)
  assert(root.scheduler.render_reserved_work==60000); spend(340000)
  spend=scheduler.maintenance(root,t+1)
  assert(root.scheduler.render_reserved_work==160000); spend(240000)
  spend=scheduler.maintenance(root,t+2)
  assert(root.scheduler.render_reserved_work==60000); spend(340000)
  local ok=pcall(scheduler.request_render_work,root,t+2,160001,function() end)
  assert(not ok,'larger maintenance widened whole-render admission')
  restored_defaults()
  report('maintenance-setting-preserves-render-reservations-and-baseline-service')
end
function M.run()
  local total=0
  local function report(name) total=total+1; log('TC_CONTRACT '..name) end
  for kind,value in pairs(defaults) do
    assert(settings.global[names[kind]],'missing runtime-global budget setting: '..names[kind])
    assert(settings.global[names[kind]].value==value and limits[keys[kind]]==value,'incorrect fivefold default')
  end
  assert(limits.maintenance_work_per_tick==200000 and limits.source_bytes==16384 and limits.state_bytes==65536)
  report('budget-fivefold-defaults-and-unchanged-structural-caps')
  for _,case in ipairs({{'compile',250000},{'work',100000},{'allocations',16384}}) do
    local kind,old=case[1],case[2]
    local ledger=admission.new(); local ctx=admission.context(ledger,'boundary',game.tick)
    assert(admission.reserve(ctx,kind,old+1),'old budget still enforced')
    assert(admission.reserve(ctx,kind,defaults[kind]-old-1))
    local spent=ledger.total
    assert(not admission.reserve(ctx,kind,1) and ledger.total==spent and ctx.machine[kind]==defaults[kind])
    change(kind,old)
    assert(not admission.reserve(ctx,kind,1) and ledger.total==spent,'lowering reset spent credits')
    change(kind,defaults[kind]+10)
    assert(admission.reserve(ctx,kind,10) and ctx.machine[kind]==defaults[kind]+10,'raising renewed rather than extended credits')
    change(kind,defaults[kind])
  end
  report('live-per-computer-boundaries-preserve-spent-credits')
  local ledger=admission.new()
  local ctx=admission.context(ledger,'shared',game.tick)
  assert(admission.reserve(ctx,'work',123))
  change('host',200123)
  assert(not admission.reserve(ctx,'work',1) and ledger.total==123 and ctx.machine.work==123)
  change('host',200124)
  assert(admission.reserve(ctx,'work',1) and ledger.total==124)
  change('host',defaults.host)
  report('live-shared-ceiling-preserves-ledger-and-maintenance')
  local rec,machine=run('local n=0; for i=1,30000 do n=n+1 end; computer.setState("n",n)')
  assert(rec.state.n==30000 and machine.work>100000 and machine.work<=defaults.work,serpent.line(machine))
  log('TC_BUDGET_WORK '..machine.work)
  report('compiled-callback-exceeds-old-work-budget')
  rec,machine=run('for i=1,2000 do local s=string.rep("x",20) end; computer.setState("done",true)')
  assert(rec.state.done and machine.allocations>16384 and machine.allocations<=defaults.allocations,serpent.line(machine))
  log('TC_BUDGET_ALLOCATIONS '..machine.allocations)
  report('compiled-callback-exceeds-old-allocation-budget')
  -- Too-small shared ceilings must not turn the worst-case reservation into
  -- permanent starvation for a small callback that actually fits.
  fresh(); rec=computer('computer.setState("small",true)')
  change('host',400000)
  local root=registry.get()
  assert(root.ledger.tick==game.tick)
  -- Existing authoring charges legitimately defer this tick. A fresh explicit
  -- tick demonstrates scheduling admission, not production latency.
  admission.context(root.ledger,rec.id,game.tick+1)
  assert(scheduler.dispatch(rec,game.tick+1))
  assert(rec.state.small and rec.status=='running')
  change('host',defaults.host)
  report('small-shared-ceiling-does-not-starve-small-callback')
  rec=select(1,run('local t=computer.getLimits(); assert(t.compile_work==1250000 and t.callback_work==500000 and t.callback_allocations==81920 and t.host_work_per_tick==5000000); t.callback_work=1; assert(computer.getLimits().callback_work==500000)'))
  change('work',600000)
  local plan,e=compiler.compile(source('assert(computer.getLimits().callback_work==600000)'),admission.context(admission.new(),'live-readback',game.tick))
  assert(plan,e and e.message)
  local context=admission.context(admission.new(),'live-readback',game.tick)
  local ok,diagnostic=compiler.run(plan,'start',{},function(guard) return runtime.services(rec,game.tick,guard) end,context)
  assert(ok,diagnostic and diagnostic.message)
  restored_defaults()
  report('guest-limits-reflect-live-settings-and-remain-defensive')
  for _,body in ipairs({
    'xpcall(function() while true do end end,function(e) computer.setState("unsafe",true) end)',
    'xpcall(function() error("x") end,function(e) while true do end end)',
    'pcall(function() xpcall(function() error("x") end,function(e) error("again") end) end)',
    'xpcall(function() error("x") end,function(e) while true do local t={} end end)',
    'xpcall(function() error("x") end,function(e) computer.stop() end)'
  }) do
    fresh()
    local bad=computer(body..'; computer.setState("unsafe",true)')
    local healthy=computer('local t=rawset({},"ready",false); assert(rawget(t,"ready")==false); computer.setState("healthy",true)')
    assert(scheduler.dispatch(bad,game.tick))
    assert(bad.status~='running' and bad.state.unsafe==nil)
    assert(scheduler.dispatch(healthy,game.tick) and healthy.status=='running' and healthy.state.healthy)
    local spent=runtime.context(bad,game.tick).machine.work
    assert(not scheduler.dispatch(bad,game.tick) and runtime.context(bad,game.tick).machine.work==spent)
  end
  report('expanded-globals-production-fatal-isolation-and-healthy-neighbors')
  maintenance_contracts(report)
  change('maintenance',400000)
  rec=select(1,run('local t=computer.getLimits(); assert(t.maintenance_work_per_tick==400000); t.maintenance_work_per_tick=1; assert(computer.getLimits().maintenance_work_per_tick==400000)'))
  restored_defaults()
  report('guest-maintenance-limit-live-readback-is-defensive')
  -- Freeze genuinely spent credits and non-default map settings for a cold load.
  root=fresh(); local retained=admission.context(root.ledger,'retained',game.tick)
  assert(admission.reserve(retained,'compile',321) and admission.reserve(retained,'work',123) and admission.reserve(retained,'allocations',45))
  local values={compile=1500000,work=600000,allocations=90000,host=6000000,maintenance=300000}
  for kind,value in pairs(values) do change(kind,value) end
  scheduler.maintenance(root,game.tick,true)(300000)
  change('maintenance',250000); values.maintenance=250000
  root.marker={retained=true}
  storage.tc_budget_fixture={phase='armed',id='retained',tick=game.tick,total=root.ledger.total,
    spent={compile=321,work=123,allocations=45},values=values,scheduler=root.scheduler,
    maintenance=300000,reserved=root.scheduler.render_reserved_work,marker=root.marker}
  log('TC_CONTRACT_TOTAL '..total)
end
function M.on_load()
  loaded=true
  if storage.tc_budget_fixture.phase=='frozen' then frozen(); log('TC_BUDGET_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_budget_fixture
  if f.phase=='armed' then
    loaded=false
    frozen(); f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='frozen' and loaded then
    local ctx=frozen(); local total=ctx.ledger.total
    change('work',123)
    assert(not admission.reserve(ctx,'work',1) and ctx.ledger.total==total)
    change('work',124)
    assert(admission.reserve(ctx,'work',1) and ctx.machine.work==124 and ctx.ledger.total==total+1)
    assert(not scheduler.try_maintenance(function() scheduler.maintenance(registry.get(),f.tick,true)(1) end))
    change('maintenance',300001)
    scheduler.maintenance(registry.get(),f.tick,true)(1)
    assert(registry.get().scheduler.maintenance_spent==300001)
    restored_defaults()
    assert(not scheduler.try_maintenance(function() scheduler.maintenance(registry.get(),f.tick,true)(1) end))
    -- Actual next production tick, not an explicit-clock latency claim.
    assert(event.tick>f.tick)
    scheduler.tick(event.tick)
    assert(registry.get().scheduler.last_tick==event.tick and registry.get().marker==f.marker)
    assert(registry.get().scheduler.maintenance_spent<=limits.maintenance_work_per_tick)
    log('TC_MAINTENANCE_COLD_SPENT_AND_NEXT_TICK_OK')
    local rec=computer('computer.setState("started",true)')
    f.computer=rec.id; f.active=rec.active; f.state=rec.state; f.phase='live'
  elseif f.phase=='live' then
    local root=registry.get(); local rec=registry.computer(f.computer)
    assert(rec.active==f.active and rec.state==f.state)
    change('maintenance',400000)
    scheduler.tick(event.tick)
    assert(rec.state.started and rec.status=='running' and rec.active==f.active and rec.state==f.state)
    scheduler.maintenance(root,event.tick,true)(300000-root.scheduler.maintenance_spent)
    local spent=root.scheduler.maintenance_spent; local total=root.ledger.total
    change('maintenance',250000)
    scheduler.tick(event.tick)
    assert(root.scheduler.maintenance_spent==spent and root.ledger.total==total)
    assert(rec.state.started and rec.status=='running' and rec.active==f.active and rec.state==f.state)
    f.phase='live-next'
  elseif f.phase=='live-next' then
    scheduler.tick(event.tick)
    local root=registry.get(); local rec=registry.computer(f.computer)
    assert(root.scheduler.last_tick==event.tick and root.scheduler.maintenance_spent<=250000)
    assert(rec.status=='running' and rec.state.started and rec.active==f.active and rec.state==f.state)
    restored_defaults(); f.phase='done'
    log('TC_MAINTENANCE_LIVE_PRODUCTION_TICKS_OK')
    log('TC_COLD_OK')
  end
end
function M.on_configuration_changed() end
return M
