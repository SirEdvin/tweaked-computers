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
require('scripts.services.peripheral')
require('scripts.services.kv')
local M={}
local function build(kind,x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
  return assert(lifecycle.build(body))
end
local source=[[
function start() computer.every(1,'beat') end
function beat()
  computer.setState('found',peripheral.find('kv_database','red')~=nil)
  computer.setState('beats',(computer.getState('beats') or 0)+1)
end
]]
function M.run()
  registry.initialize()
  local c=build('computer',0); local db=build('kv',4)
  local red=lifecycle.connector(c,'network','red'); local target=lifecycle.connector(db,'network','red')
  assert(red.connect_to(target))
  local builds=0; local new=environment.new
  environment.new=function(context,...) if context==nil then builds=builds+1 end; return new(context,...) end
  local ok,problem=pcall(function()
    runtime.save(c.id,source,0); local activated,why=runtime.activate(c.id,1); assert(activated,serpent.line(why))
    local root=registry.get(); local charges={}
    for t=1,6 do
      scheduler.tick(t)
      if c.last_dispatch_tick==t and (c.state.beats or 0)>0 then charges[#charges+1]=root.ledger.total end
    end
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.state.beats>=4 and builds==1,'scaffolding was rebuilt: '..builds)
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
    local warm_ok,_,full=run(c); local cold_ok,_,cold=run(nil)
    assert(warm_ok and cold_ok and full==cold,'warm/cold full charge differs: '..full..'/'..cold)
    for _,allowance in ipairs({1,6,7,full-1,full}) do
      local a,ac,at=run(c,allowance); local b,bc,bt=run(nil,allowance)
      assert(a==b and ac==bc and at==bt,'warm/cold refusal differs at allowance '..allowance)
    end
    assert(builds==1)
    log('TC_CONTRACT reused-scaffolding-warm-cold-equal-admission-and-refusal')

    -- A new run never reuses the previous run's scaffolding.
    runtime.stop(c.id); activated,why=runtime.activate(c.id,9); assert(activated,serpent.line(why))
    for t=9,11 do scheduler.tick(t) end
    assert(builds==2 and c.status=='running','new run reused old scaffolding')
    log('TC_CONTRACT reused-scaffolding-ends-with-its-run')
  end)
  environment.new=new
  assert(ok,problem)
  log('TC_CONTRACT_TOTAL 4')
end
return M
