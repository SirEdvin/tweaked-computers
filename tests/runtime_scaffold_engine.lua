-- Run-scoped host scaffolding: reused across callbacks, invisible to guests and admission.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local environment=require('scripts.runtime.environment')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local network=require('scripts.network')
require('scripts.services.peripheral')
require('scripts.services.kv')
local M={}
-- One call of each reviewed computer method; 'kv' is the unclassified peripheral control.
local probe=[[
local function call(m,w)
  if m=='getID' then computer.getID()
  elseif m=='getLabel' then computer.getLabel()
  elseif m=='setLabel' then computer.setLabel('probe')
  elseif m=='getTick' then computer.getTick()
  elseif m=='getLimits' then computer.getLimits()
  elseif m=='getState' then computer.getState('missing')
  elseif m=='setState' then computer.setState('k',1)
  elseif m=='deleteState' then computer.deleteState('absent')
  elseif m=='log' then computer.log('probe')
  elseif m=='on' then computer.on('peripheral_attach','noop')
  elseif m=='off' then computer.off(computer.on('peripheral_detach','noop'))
  elseif m=='after' then computer.after(1000,'noop')
  elseif m=='every' then computer.every(1000,'noop')
  elseif m=='cancelTimer' then computer.cancelTimer(computer.after(1000,'noop'))
  elseif m=='kv' then w.get('x')
  else error('unknown probe') end
end
function start() end
function noop() end
function probe(e)
  if e.first then call(e.method) end
  local w=peripheral.wrap(e.target,'red')
  if not e.first then call(e.method,w) end
  computer.setState('type',peripheral.getType(e.target,'red'))
end
]]
local function build(kind,x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
  return assert(lifecycle.build(body))
end
local source=[[
function start() computer.every(1,'beat') end
function beat()
  computer.setState('found',peripheral.find('kv_database','red')~=nil)
  computer.setState('beats',(computer.getState('beats') or 0)+1)
  print('beat',computer.getState('beats'))
end
]]
function M.run()
  registry.initialize()
  local c=build('computer',0); local db=build('kv',4)
  local red=lifecycle.connector(c,'network','red'); local target=lifecycle.connector(db,'network','red')
  assert(red.connect_to(target))
  local builds=0; local new=environment.new
  environment.new=function(context,...) if context==nil then builds=builds+1 end; return new(context,...) end
  -- Guest-program loads target the protected globals proxy; syntax checks use a plain {}.
  local loads=0; local native_load=load
  load=function(text,name,mode,env) if getmetatable(env)==false then loads=loads+1 end; return native_load(text,name,mode,env) end
  local validations=0; local compile=compiler.compile
  compiler.compile=function(...) validations=validations+1; return compile(...) end
  -- Count network walks that guest calls cause, not background reconciliation.
  local discoveries,inside=0,false; local discover,run_program=network.discover,compiler.run
  network.discover=function(...) if inside then discoveries=discoveries+1 end; return discover(...) end
  compiler.run=function(...) inside=true; local r=table.pack(run_program(...)); inside=false; return table.unpack(r,1,r.n) end
  local ok,problem=pcall(function()
    runtime.save(c.id,source,0); local activated,why=runtime.activate(c.id,1); assert(activated,serpent.line(why))
    local root=registry.get(); local charges={}; local compiles={}
    for t=1,6 do
      scheduler.tick(t)
      if c.last_dispatch_tick==t then compiles[#compiles+1]=root.ledger.machines[c.id].compile end
      if c.last_dispatch_tick==t and (c.state.beats or 0)>0 then charges[#charges+1]=root.ledger.total end
    end
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.state.beats>=4 and builds==1,'scaffolding was rebuilt: '..builds)
    assert(loads==1,'warm callbacks reloaded the program: '..loads)
    -- Activation and the first callback validate; warm later callbacks use the scaffold's result.
    assert(validations==2,'warm callbacks validated the source again: '..validations)
    -- The run pays compilation once, on its first callback, and records that in saved state.
    assert(compiles[1]>0 and c.compile_paid==c.run_id,'first callback did not pay compilation')
    for i=2,#compiles do assert(compiles[i]==0,'later callback paid compilation again: '..serpent.line(compiles)) end
    -- Declaration documents allow no guest globals or top-level locals; each successful
    -- warm callback proves its exports and execution state were constructed fresh.
    assert(c.state.found==true and not c.diagnostic,'reused scaffolding broke a callback')
    -- The first beat reads no prior 'beats' value; later identical beats must charge equally.
    for i=3,#charges do assert(charges[i]==charges[2],'warm callback charged differently: '..serpent.line(charges)) end
    log('TC_CONTRACT reused-scaffolding-fresh-guest-state-equal-charges')

    -- Authority and topology are re-proved per callback, not cached by the scaffolding.
    assert(red.disconnect_from(target))
    scheduler.tick(7); assert(c.last_dispatch_tick==7 and c.state.found==false,'removed wire still reachable')
    assert(red.connect_to(target))
    scheduler.tick(8); assert(c.last_dispatch_tick==8 and c.state.found==true,'restored wire not reachable')
    assert(builds==1)
    log('TC_CONTRACT reused-scaffolding-rechecks-authority-and-topology')

    -- Cold (owner=nil) and warm (owner=c) runs admit and refuse identically.
    local function run(owner,allowance)
      local host=limits.host_work_per_tick
      if allowance then limits.host_work_per_tick=limits.maintenance_work_per_tick+allowance end
      local ledger=admission.new(); local ctx=admission.context(ledger,c.id,100)
      local passed,diagnostic=compiler.run(c.active,'beat',{name='timer'},
        function(guard,frame) return runtime.services(c,frame or 100,guard) end,ctx,false,nil,owner)
      limits.host_work_per_tick=host
      return passed,diagnostic and diagnostic.code,ledger.total
    end
    -- A peer without the process caches (late join, reload) sees the same saved record.
    -- A copy with equal saved fields misses the scaffold, so it builds and loads cold.
    local function peer() local copy={}; for k,v in pairs(c) do copy[k]=v end; return copy end
    local before=loads
    local validated=validations
    local warm_ok,_,full=run(c); assert(validations==validated,'warm paid callback validated its source')
    local cold_ok,_,cold=run(peer()); assert(validations==validated+1,'cold peer did not validate exactly once')
    assert(warm_ok and cold_ok and full==cold,'warm/cold full charge differs: '..full..'/'..cold)
    assert(loads==before+1,'warm run reloaded or cold run reused a loaded program')
    local unpaid_ok,_,unpaid=run(nil)
    assert(unpaid_ok and unpaid>full,'a callback without a paid run skipped compilation')
    for _,allowance in ipairs({1,6,7,full-1,full}) do
      local a,ac,at=run(c,allowance); local b,bc,bt=run(peer(),allowance)
      assert(a==b and ac==bc and at==bt,'warm/cold refusal differs at allowance '..allowance)
    end
    log('TC_CONTRACT reused-scaffolding-warm-cold-equal-admission-and-refusal')

    -- A new run never reuses the previous run's scaffolding or compilation payment.
    local mark,built=loads,builds; validated=validations
    runtime.stop(c.id); activated,why=runtime.activate(c.id,9); assert(activated,serpent.line(why))
    scheduler.tick(9); assert(root.ledger.machines[c.id].compile>0,'new run skipped compilation')
    for t=10,11 do scheduler.tick(t) end
    assert(builds==built+1 and c.status=='running','new run reused old scaffolding')
    assert(loads==mark+1,'new run did not load its program exactly once: '..(loads-mark))
    assert(validations==validated+2,'new run did not validate at activation and first callback only')
    -- A changed source is a new run: a stale handler set would fault the retained-export check.
    runtime.stop(c.id); runtime.save(c.id,source..'function extra() end\n',c.saved_revision); validated=validations
    activated,why=runtime.activate(c.id,12); assert(activated,serpent.line(why))
    for t=12,14 do scheduler.tick(t) end
    assert(validations==validated+2 and c.status=='running' and c.active.handlers.extra,'changed source reused an old validation')
    log('TC_CONTRACT reused-scaffolding-ends-with-its-run')

    -- Other sources and Console commands fill the shared cache; a running program does not validate again.
    scheduler.tick(15); local total,beats=root.ledger.total,c.state.beats; validated=validations
    for i=1,limits.active_computers+1 do assert(compile('function start() local n='..i..' end')) end
    scheduler.tick(16)
    assert(validations==validated,'shared cache eviction caused a new validation')
    assert(c.last_dispatch_tick==16 and c.state.beats==beats+1 and root.ledger.total==total and c.status=='running',
      'callback after shared cache eviction changed effects or charges')
    log('TC_CONTRACT reused-validation-survives-shared-cache-eviction')

    -- Reviewed computer methods keep the callback-local proofs: one network walk, equal charges.
    runtime.stop(c.id); runtime.save(c.id,probe,c.saved_revision)
    local T=20
    local function probed(method,first)
      runtime.stop(c.id); T=T+1
      activated,why=runtime.activate(c.id,T); assert(activated,serpent.line(why)); scheduler.tick(T)
      T=T+1; assert(runtime.enqueue(c,'probe',{name='probe',method=method,first=first,target=db.id},T))
      discoveries=0; scheduler.tick(T)
      assert(c.last_dispatch_tick==T and c.status=='running' and c.state.type=='kv_database',
        method..': '..serpent.line(c.diagnostic))
      return discoveries,root.ledger.machines[c.id].work
    end
    for _,method in ipairs({'getID','getLabel','setLabel','getTick','getLimits','getState','setState','deleteState','log',
      'on','off','after','every','cancelTimer'}) do
      local before,before_work=probed(method,true); local between,between_work=probed(method,false)
      assert(before==1 and between==1,method..' discarded the callback proofs: '..before..'/'..between)
      assert(before_work==between_work,method..' charged differently by call order: '..before_work..'/'..between_work)
    end
    assert(probed('kv',false)==2,'unclassified peripheral method kept the callback proofs')
    runtime.stop(c.id)
    log('TC_CONTRACT computer-methods-keep-callback-proofs')
  end)
  environment.new=new; load=native_load; compiler.compile=compile; network.discover=discover; compiler.run=run_program
  assert(ok,problem)
  log('TC_CONTRACT_TOTAL 6')
end
return M
