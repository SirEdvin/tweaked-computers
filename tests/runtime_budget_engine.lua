-- Real settings and registered production event handler; no client GUI claim.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
local loaded=false
local names={compile='tc-compile-work',work='tc-callback-work',allocations='tc-callback-allocations',host='tc-host-work-per-tick'}
local defaults={compile=1250000,work=500000,allocations=81920,host=5000000}
local keys={compile='compile_work',work='callback_work',allocations='callback_allocations',host='host_work_per_tick'}
local serial=0
local function change(kind,value)
  settings.global[names[kind]]={value=value}
  assert(settings.global[names[kind]].value==value)
  -- Invoke the actual handler registered by control.lua with the engine payload.
  -- Direct assignment is not a player-generated settings GUI event.
  local handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
  handler{setting=names[kind],setting_type='runtime-global',tick=game.tick}
  assert(limits[keys[kind]]==value,'live setting not applied: '..kind)
end
local function source(body)
  return 'return {api_version=1,handlers={start=function(event) '..body..' end}}'
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
  return ctx
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
  -- Freeze genuinely spent credits and non-default map settings for a cold load.
  root=fresh(); local retained=admission.context(root.ledger,'retained',game.tick)
  assert(admission.reserve(retained,'compile',321) and admission.reserve(retained,'work',123) and admission.reserve(retained,'allocations',45))
  local values={compile=1500000,work=600000,allocations=90000,host=6000000}
  for kind,value in pairs(values) do change(kind,value) end
  storage.tc_budget_fixture={phase='armed',id='retained',tick=game.tick,total=root.ledger.total,
    spent={compile=321,work=123,allocations=45},values=values}
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
    restored_defaults(); f.phase='done'
    log('TC_COLD_OK')
  end
end
function M.on_configuration_changed() end
return M
