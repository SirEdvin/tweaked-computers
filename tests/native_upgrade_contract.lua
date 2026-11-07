local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
local serial=0
local source=[[
function start(e)
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  computer.after(20,'later',{kept=false})
end
function later(e)
  computer.setState('later',(computer.getState('later') or 0)+1)
end
]]
local function fresh()
  storage.tweaked_computers=nil
  local root=registry.initialize()
  serial=serial+1
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={serial*2,-50},force='player'})
  local rec=registry.register('computer',entity)
  runtime.save(rec.id,source,0); assert(runtime.activate(rec.id,0))
  assert(scheduler.dispatch(rec,0) and rec.state.starts==1)
  assert(runtime.enqueue(rec,'later',{name='test',kept=false},0))
  runtime.save(rec.id,'function start(e) computer.setState("unapplied",true) end',1)
  rec.shell={version=1,id=rec.id..'/shell-test',pending={},pending_bytes=0,
    values={version=1,root=1,nodes={{kind='table',entries={{key='kept',value=false}}}}}}
  rec.active.compiler_version=2
  root.ledger.version=1
  for _,machine in pairs(root.ledger.machines) do
    machine.allocations=37; root.ledger.total=root.ledger.total+37
  end
  return root,rec
end
local function capture(root,rec)
  local timer=next(rec.timers)
  return {active=rec.active,source=rec.active.source,revision=rec.active.revision,saved=rec.saved_source,
    saved_revision=rec.saved_revision,run=rec.run_id,queue=rec.queue,item=rec.queue[1],
    timers=rec.timers,timer=rec.timers[timer],deadline=rec.timers[timer].deadline,
    state=rec.state,shell=rec.shell,graph=rec.shell.values,total=root.ledger.total,
    machine=root.ledger.machines[rec.id],compile=root.ledger.machines[rec.id].compile,
    last_dispatch=rec.last_dispatch_tick}
end
local function unchanged(rec,before)
  assert(rec.active==before.active and rec.active.source==before.source and rec.active.revision==before.revision)
  assert(rec.saved_source==before.saved and rec.saved_revision==before.saved_revision and rec.run_id==before.run)
  assert(rec.queue==before.queue and rec.queue[1]==before.item and rec.timers==before.timers)
  assert(rec.timers[before.timer.id]==before.timer and before.timer.deadline==before.deadline)
  assert(rec.state==before.state and rec.state.starts==1 and rec.state.later==nil and rec.state.unapplied==nil)
  assert(rec.shell==before.shell and rec.shell.values==before.graph and rec.last_dispatch_tick==before.last_dispatch)
end
function M.run()
  local previous=storage.tweaked_computers
  local total=0
  local function group(name,fn) fn(); total=total+1; log('TC_CONTRACT native-upgrade-'..name) end
  local ok,problem=pcall(function()
    group('synchronized-known-source-ledger-and-identities',function()
      local root,rec=fresh(); local before=capture(root,rec)
      registry.initialize()
      assert(rec.active.compiler_version==3 and root.ledger.version==2,'known guarded save did not migrate')
      unchanged(rec,before)
      assert(root.ledger.total>=before.total and root.ledger.machines[rec.id]==before.machine)
      assert(before.machine.allocations==nil and before.machine.work==0 and before.machine.compile>=before.compile)
      assert(scheduler.dispatch(rec,1) and rec.state.later==1 and rec.state.starts==1 and rec.state.unapplied==nil)
    end)
    group('shared-admission-defers-before-timers-or-queue-consumption',function()
      local root,rec=fresh(); local before=capture(root,rec)
      root.ledger.total=admission.host_ceiling(root.ledger,0)
      local spent=root.ledger.total
      registry.initialize()
      assert(rec.active.compiler_version==2 and root.ledger.version==2 and root.runtime_upgrade_pending)
      assert(root.ledger.total==spent); unchanged(rec,before)
      scheduler.tick(0)
      assert(root.ledger.total==spent and rec.active.compiler_version==2); unchanged(rec,before)
      assert(scheduler.dispatch(rec,1))
      assert(rec.active.compiler_version==3 and rec.state.later==1 and rec.state.starts==1)
    end)
    group('malformed-or-unknown-metadata-retains-recovery-data',function()
      for _,change in ipairs({
        function(a) a.compiler_version=99 end,
        function(a) a.generated='computer.setState("injected",true)' end,
        function(a) a.handlers.injected=true end,
        function(a) a.handlers.later=false end,
        function(a) a.source='not valid source' end,
        function(a) a.revision=-1 end,
        function(a) setmetatable(a.handlers,{}) end
      }) do
        local root,rec=fresh(); change(rec.active)
        local before=capture(root,rec)
        registry.initialize()
        assert(rec.status=='faulted' and rec.diagnostic.code=='E_UNSUPPORTED')
        unchanged(rec,before)
        assert(not scheduler.dispatch(rec,1) and rec.state.injected==nil)
      end
    end)
    group('unknown-ledger-preserves-clock-credits-and-accepted-data',function()
      for _,change in ipairs({
        function(ledger) ledger.version=99 end,
        function(ledger) ledger.total=-1 end,
        function(ledger) ledger.machines[next(ledger.machines)].allocations=-1 end
      }) do
        local root,rec=fresh(); change(root.ledger)
        local before=capture(root,rec); local ledger=root.ledger
        local version,tick,spent=ledger.version,ledger.tick,ledger.total
        registry.initialize(); scheduler.tick(1)
        assert(root.ledger==ledger and ledger.version==version and ledger.tick==tick and ledger.total==spent)
        assert(root.scheduling_diagnostic and root.scheduling_diagnostic.code=='E_UNSUPPORTED')
        unchanged(rec,before)
      end
    end)
  end)
  storage.tweaked_computers=previous
  assert(ok,problem)
  log('TC_CONTRACT_TOTAL '..total)
  return total
end
return M
