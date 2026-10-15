-- Small two-process fixture using real simulation ticks and retained native source.
local contracts = require('tests.computer_contract')
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local scheduler = require('scripts.scheduler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local M = {}
local loaded=false
local origin_source=[[return {api_version=1,handlers={
  start=function(e)
    computer.setState('boots',(computer.getState('boots') or 0)+1)
    computer.setState('once',0); computer.setState('restores',0)
    local payload={false,'',3}
    computer.setState('timer',computer.after(7,'once',payload)); payload[3]=99
    computer.every(3,'periodic')
    computer.on('power_restored','restore')
  end,
  once=function(e)
    assert(e.payload[1]==false and e.payload[2]=='' and e.payload[3]==3)
    computer.setState('once',computer.getState('once')+1)
    computer.log('one-shot')
  end,
  periodic=function(e) computer.setState('periods',(computer.getState('periods') or 0)+1) end,
  restore=function(e) computer.setState('restores',computer.getState('restores')+1) end
}}]]
local function scalar_graph(value,seen)
  local typ=type(value)
  assert(typ~='function' and typ~='thread','executable persisted')
  if typ~='table' then return end
  if value.object_name then return end -- Host-only LuaEntity references in registry.
  assert(getmetatable(value)==nil,'unexpected persisted metatable')
  if seen[value] then return end
  seen[value]=true
  for k,v in pairs(value) do scalar_graph(k,seen); scalar_graph(v,seen) end
end
local function snapshot(rec)
  local root=registry.get(); local machine=root.ledger.machines[rec.id]
  local timers={}
  for id,timer in pairs(rec.timers) do timers[id]={deadline=timer.deadline,sequence=timer.sequence} end
  return {run_id=rec.run_id,source=rec.active.source,revision=rec.active.revision,
    saved_source=rec.saved_source,saved_revision=rec.saved_revision,boots=rec.state.boots,
    sequence=root.next_sequence,ledger_tick=root.ledger.tick,total=root.ledger.total,
    work=machine.work,compile=machine.compile,allocations=machine.allocations,
    scheduler_tick=root.scheduler.last_tick,maintenance_spent=root.scheduler.maintenance_spent,
    queue_sequence=rec.queue[1].event.sequence,timers=timers,body_unit=rec.body.unit_number}
end
local function verify_frozen()
  local fixture=storage.tc03_fixture; local root=registry.get(); local rec=registry.computer(fixture.id)
  local saved=fixture.snapshot; local now=snapshot(rec)
  for _,key in ipairs({'run_id','source','revision','saved_source','saved_revision','boots','sequence','ledger_tick','total','work','compile','allocations','scheduler_tick','maintenance_spent','queue_sequence','body_unit'}) do
    assert(now[key]==saved[key],'cold load changed '..key)
  end
  assert(rec.active.source==origin_source and rec.saved_source~=rec.active.source)
  assert(rec.state.once==0 and rec.state.restores==0)
  for id,timer in pairs(saved.timers) do assert(now.timers[id] and now.timers[id].deadline==timer.deadline and now.timers[id].sequence==timer.sequence) end
  assert(rec.queue[1].event.run_id==rec.run_id and rec.queue[1].handler=='restore')
  scalar_graph(root,{})
  return rec
end
function M.run()
  contracts.run()
  storage.tweaked_computers=nil; registry.initialize()
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,4},force='player'})
  local rec=registry.register('computer',entity)
  runtime.save(rec.id,origin_source,0)
  assert(runtime.activate(rec.id,game.tick))
  storage.tc03_fixture={phase='armed',id=rec.id}
  scalar_graph(registry.get(),{})
end
function M.on_load()
  loaded=true -- Ephemeral only: game unavailable, storage is read-only.
  if storage.tc03_fixture.phase=='frozen' then
    verify_frozen()
    log('TC_COLD_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local fixture=storage.tc03_fixture
  if fixture.phase=='frozen' then
    if not loaded then return end -- First process remains frozen until actual save.
    local rec=verify_frozen(); local saved=fixture.snapshot
    local ctx=admission.context(registry.get().ledger,rec.id,saved.ledger_tick)
    assert(ctx.machine.work==saved.work and ctx.machine.compile==saved.compile and ctx.machine.allocations==saved.allocations)
    -- A one-unit refusal on a real retained ledger, without granting a new tick.
    assert(not admission.reserve(ctx,'work',limits.callback_work+1-saved.work))
    assert(ctx.machine.work==saved.work and ctx.ledger.total==saved.total)
    loaded=false; fixture.phase='resumed'
    log('TC_COLD_RECONSTRUCT_BEGIN')
  elseif fixture.phase=='armed' then
    loaded=false; scheduler.tick(event.tick)
    local rec=registry.computer(fixture.id)
    assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
    assert(rec.state.boots==1)
    -- Keep committed editor source different from the active run snapshot.
    runtime.save(rec.id,'return {api_version=1,handlers={start=function(e) error("saved-only source executed") end}}',rec.saved_revision)
    runtime.emit(rec.id,'power_restored',{outage_start_tick=0,restored_tick=event.tick},event.tick)
    fixture.phase='frozen'; fixture.snapshot=snapshot(rec); fixture.freeze_tick=event.tick
    scalar_graph(registry.get(),{})
    game.server_save('tc03-snapshot')
    log('TC_COLD_SNAPSHOT_REQUESTED')
    return
  end
  if fixture.phase=='resumed' then
    scheduler.tick(event.tick)
    local rec=registry.computer(fixture.id)
    assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
    assert(rec.state.boots==1,'startup replayed')
    if event.tick>=fixture.freeze_tick+10 then
      assert(rec.state.once==1 and rec.state.restores==1 and rec.state.periods>=3)
      local once=0; for _,entry in ipairs(rec.logs) do if entry.text=='one-shot' then once=once+1 end end
      assert(once==1,'one-shot replayed')
      scalar_graph(registry.get(),{})
      fixture.phase='done'
      log('TC_COLD_OK retained-source no-startup-replay once-only FIFO same-tick-ledger data-only')
    end
  end
end
return M
