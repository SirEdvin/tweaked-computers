-- Small two-process fixture using real simulation ticks and retained native source.
local contracts = require('tests.computer_contract')
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local scheduler = require('scripts.scheduler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local M = {}
local loaded=false
local origin_source=[[function start(e)
  local data={}; rawset(data,'ready',false); computer.setState('raw_data',data)
  print(_VERSION,false,nil,3)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('once',0); computer.setState('restores',0)
  local payload={false,'',3}
  computer.setState('timer',computer.after(7,'once',payload)); payload[3]=99
  computer.every(3,'periodic')
  computer.on('power_restored','restore')
end

function once(e)
  assert(e.payload[1]==false and e.payload[2]=='' and e.payload[3]==3)
  computer.setState('once',computer.getState('once')+1)
  computer.log('one-shot')
end

function periodic(e) computer.setState('periods',(computer.getState('periods') or 0)+1) end

function restore(e) computer.setState('restores',computer.getState('restores')+1) end]]
local declaration_source=[[
local function increment(n) return n+1 end
function start(e)
  local data={}; rawset(data,'ready',false); computer.setState('raw_data',data)
  print(_VERSION,false,nil,3)
  computer.setState('boots',increment(computer.getState('boots') or 0))
  computer.setState('once',0); computer.setState('order','')
  assert(sample()==1)
  local payload={false,'',3}
  computer.setState('timer',computer.after(7,'sample',payload)); payload[3]=99
  computer.every(3,'periodic')
  computer.on('power_restored','restore')
end
function sample(e)
  local n=increment(computer.getState('samples') or 0)
  computer.setState('samples',n)
  if e then
    assert(e.name=='timer' and e.timer_id==computer.getState('timer'))
    assert(e.payload[1]==false and e.payload[2]=='' and e.payload[3]==3)
    assert(e.computer_id==computer.getID())
    computer.setState('once',increment(computer.getState('once')))
    computer.setState('envelope',e)
    computer.log('declaration-one-shot')
  else computer.log('declaration-immediate') end
  return n
end
function periodic(e) computer.setState('periods',increment(computer.getState('periods') or 0)) end
function restore(e)
  assert(e.name=='power_restored' and e.computer_id==computer.getID())
  computer.setState('order',computer.getState('order')..e.tag)
end
]]
local function clone(value)
  if type(value)~='table' then return value end
  local result={}; for k,v in pairs(value) do result[k]=clone(v) end; return result
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function retained(rec)
  local result={}
  for _,key in ipairs({'active','saved_source','saved_revision','run_id','run_generation','status',
    'state','state_sizes','state_bytes','state_nodes','state_node_sizes','state_entries',
    'logs','log_bytes','queue','queue_bytes','timers','subscriptions','last_dispatch_tick'}) do
    result[key]=clone(rec[key])
  end
  result.body_unit=rec.body.unit_number
  return result
end
local function complete_snapshot()
  local f=storage.tc03_fixture; local r=registry.get()
  return {legacy=retained(registry.computer(f.id)),declaration=retained(registry.computer(f.declaration)),
    collision=f.collision and retained(registry.computer(f.collision)),
    ledger=clone(r.ledger),scheduler=clone(r.scheduler),sequence=r.next_sequence}
end
local function baseline_snapshot(rec)
  local r=registry.get()
  return {record=retained(rec),ledger=clone(r.ledger),scheduler=clone(r.scheduler),sequence=r.next_sequence}
end
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
  if fixture.baseline_expected then
    assert(equal(baseline_snapshot(rec),fixture.baseline_expected),'baseline active/state/work graph rewritten on load')
  end
  if fixture.declaration then
    assert(equal(complete_snapshot(),fixture.expected),'cold load changed full source/state/work graph')
    local plain=registry.computer(fixture.declaration)
    assert(plain.active.source==declaration_source and plain.saved_source~=plain.active.source)
    assert(plain.state.boots==1 and plain.state.samples==1 and plain.state.once==0 and plain.state.order=='')
    assert(plain.active.handlers.start and plain.active.handlers.sample and not plain.active.handlers.increment)
    assert(#plain.queue==2 and plain.queue[1].event.tag=='a' and plain.queue[2].event.tag=='b'
      and plain.queue[1].event.sequence<plain.queue[2].event.sequence)
    assert(plain.active==fixture.active_alias and plain.state==fixture.state_alias
      and plain.timers==fixture.timers_alias and plain.queue==fixture.queue_alias,'cold identity loss')
  end
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
  local plain=registry.register('computer',assert(game.surfaces[1].create_entity{name='constant-combinator',position={4,4},force='player'}))
  runtime.save(plain.id,declaration_source,0)
  assert(runtime.activate(plain.id,game.tick))
  storage.tc03_fixture={phase='armed',id=rec.id,declaration=plain.id}
  local collision=registry.register('computer',assert(game.surfaces[1].create_entity{name='constant-combinator',position={8,4},force='player'}))
  runtime.save(collision.id,'function start() computer.setState("kept",true) end',0)
  assert(runtime.activate(collision.id,game.tick)); storage.tc03_fixture.collision=collision.id
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
    if fixture.declaration then
      local plain=registry.computer(fixture.declaration)
      local c=admission.context(registry.get().ledger,plain.id,saved.ledger_tick)
      local machine=clone(c.machine); local total=c.ledger.total
      assert(machine.work>0 and machine.compile>0 and machine.allocations>0)
      for kind,ceiling in pairs({work=limits.callback_work,compile=limits.compile_work,allocations=limits.callback_allocations}) do
        assert(not admission.reserve(c,kind,ceiling+1-machine[kind]))
        assert(equal(c.machine,machine) and c.ledger.total==total,'cold refusal renewed credits')
      end
      scheduler.tick(saved.scheduler_tick)
      assert(equal(complete_snapshot(),fixture.expected),'same-tick cold dispatch replayed work')
      log('TC_COLD_DECLARATION_FROZEN exact-active-source aliases full-ledger FIFO no-load-work')
    else
      -- An authentic baseline 0.1.9 fixture has no declaration peer. Its original
      -- active record must pass unchanged, not be synthesized or reactivated.
      assert(rec.active.api_version==1 and rec.active.compiler_version==2 and rec.active.storage_version==1)
      assert(fixture.baseline_expected,'baseline acceptance requires authentic external before-snapshot observer')
      log('TC_COLD_LEGACY_BASELINE_COMPATIBLE original-source-run-body-credits')
    end
    loaded=false; fixture.phase='resumed'
    log('TC_COLD_RECONSTRUCT_BEGIN')
  elseif fixture.phase=='armed' then
    loaded=false; scheduler.tick(event.tick)
    local rec=registry.computer(fixture.id)
    assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
    assert(rec.state.boots==1)
    -- Keep committed editor source different from the active run snapshot.
    runtime.save(rec.id,'function start(e) error("saved-only source executed") end',rec.saved_revision)
    runtime.emit(rec.id,'power_restored',{outage_start_tick=0,restored_tick=event.tick},event.tick)
    if fixture.declaration then
      local plain=registry.computer(fixture.declaration)
      assert(plain.status=='running' and plain.state.boots==1 and plain.state.samples==1,
        plain.diagnostic and plain.diagnostic.message)
      runtime.save(plain.id,'function start(e) error("new saved-only declaration executed") end',plain.saved_revision)
      local payload={tag='a'}; runtime.emit(plain.id,'power_restored',payload,event.tick); payload.tag='changed'
      runtime.emit(plain.id,'power_restored',{tag='b'},event.tick)
      fixture.active_alias=plain.active; fixture.state_alias=plain.state
      fixture.timers_alias=plain.timers; fixture.queue_alias=plain.queue
      if fixture.collision then
        local old=registry.computer(fixture.collision)
        assert(old.state.kept)
        fixture.collision_source='function xpcall() end\nfunction start() computer.setState("unsafe",true) end'
        old.active.source=fixture.collision_source
        runtime.save(old.id,fixture.collision_source,old.saved_revision)
        assert(runtime.enqueue(old,'start',{name='fixture'},event.tick))
      end
      fixture.expected=complete_snapshot()
    end
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
      assert(rec.state.raw_data.ready==false)
      local printed=0; for _,entry in ipairs(rec.logs) do if entry.text=='Lua 5.2\tfalse\tnil\t3' then printed=printed+1 end end
      assert(printed==1,'saved print replayed or lost')
      local once=0; for _,entry in ipairs(rec.logs) do if entry.text=='one-shot' then once=once+1 end end
      assert(once==1,'one-shot replayed')
      assert(rec.run_id==fixture.snapshot.run_id and rec.active.source==origin_source and rec.run_generation==1)
      if fixture.declaration then
        local plain=registry.computer(fixture.declaration)
        assert(plain.status=='running',plain.diagnostic and plain.diagnostic.message)
        assert(plain.run_id==fixture.expected.declaration.run_id and plain.run_generation==1
          and plain.active==fixture.active_alias and plain.active.source==declaration_source)
        assert(plain.state.boots==1 and plain.state.samples==2 and plain.state.once==1
          and plain.state.order=='ab' and plain.state.periods>=3)
        assert(plain.state.envelope.run_id==plain.run_id and plain.state.envelope.payload[3]==3)
        local immediate,timed=0,0
        for _,entry in ipairs(plain.logs) do
          if entry.text=='declaration-immediate' then immediate=immediate+1 end
          if entry.text=='declaration-one-shot' then timed=timed+1 end
        end
        assert(immediate==1 and timed==1,'declaration effect replayed')
        printed=0; for _,entry in ipairs(plain.logs) do if entry.text=='Lua 5.2\tfalse\tnil\t3' then printed=printed+1 end end
        assert(printed==1 and plain.state.raw_data.ready==false)
        log('TC_COLD_DECLARATION_OK immediate=1 timer=1 boots=1 order=ab exact-active-source')
        if fixture.collision then
          local old=registry.computer(fixture.collision)
          assert(old.status=='faulted' and old.diagnostic.code=='E_PROGRAM' and old.state.kept and not old.state.unsafe)
          assert(old.active.source==fixture.collision_source and old.saved_source==fixture.collision_source)
          log('TC_COLD_RESERVED_SOURCE_RETAINED no-load-fault synchronized-reconstruction-only')
        end
      end
      scalar_graph(registry.get(),{})
      fixture.phase='done'
      log('TC_COLD_OK retained-source no-startup-replay once-only FIFO same-tick-ledger data-only')
    end
  end
end
return M
