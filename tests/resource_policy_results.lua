-- Trusted result storage is admitted before publication, not after an effect.
local sandbox=require('scripts.runtime.sandbox')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local kv=require('scripts.services.kv')
local M={}
local function direct(available,refuse)
  local ctx=admission.context(admission.new(),'prepared-result',0)
  ctx.machine.work=limits.callback_work-available
  local guard=sandbox.new(ctx,{})
  local checkpoint,entered={},0
  local function copy(value)
    local out={n=value.n}; for i=1,value.n do out[i]=value[i] end; return out
  end
  guard.call_checkpoint(checkpoint,{
    encode=copy,decode=copy,
    prepare=function(value)
      if refuse then error('test-only result-storage refusal',0) end
      local called={n=value.n+1,true}; for i=1,value.n do called[i+1]=value[i] end
      return {called=called,values=copy(value)}
    end,
  })
  local fn=guard.service(function()
    local a,b,c=guard.prepare_result(false,nil,'tail')
    entered=entered+1
    return a,b,c
  end)
  local result=table.pack(pcall(guard.call,fn))
  if result[1] then
    assert(result.n==4 and result[2]==false and result[3]==nil and result[4]=='tail')
    assert(entered==1 and checkpoint.call_result==checkpoint.service_result)
    assert(checkpoint.prepared.called==checkpoint.call_result and checkpoint.prepared.values.n==3)
  else assert(entered==0,'result admission failed after the effect') end
  return result[1],ctx.machine.work-(limits.callback_work-available)
end
function M.run()
  local ok,cost=direct(limits.callback_work)
  assert(ok)
  for available=0,cost-1 do assert(not direct(available),'short allowance admitted an unpaid result') end
  assert(not direct(limits.callback_work,true),'storage refusal reached publication')
  for _,wrong_width in ipairs({false,true}) do
    local g=sandbox.new(admission.context(admission.new(),'bad-prepared-provider',0),{})
    local calls=0
    local bad=g.service(function()
      g.prepare_result(true); calls=calls+1
      if wrong_width then return end
      return false
    end)
    local ran,problem=pcall(g.call,bad)
    assert(not ran and calls==1 and g.diagnostic(problem).code=='E_ENGINE','provider contract failure became retryable pressure')
  end
  local body=[[local a,b,c=computer.probe(); assert(a==false and b==nil and c=='tail'); computer.finished()]]
  for _,source in ipairs({'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local ledger=admission.new()
    local ctx=admission.context(ledger,'durable-prepared-result',0)
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local checkpoint,entered,finished={},0,0
    local function services(g)
      return {computer={
        probe=function()
          local a,b,c=g.prepare_result(false,nil,'tail')
          entered=entered+1
          assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
          return a,b,c
        end,
        finished=function() finished=finished+1 end,
      }}
    end
    local ran,diagnostic,control=compiler.run(plan,'start',{},services,ctx,checkpoint)
    assert(not ran and control=='wait' and diagnostic==nil and entered==1 and finished==0)
    for tick=1,20 do
      ctx=admission.context(ledger,'durable-prepared-result',tick)
      ran,diagnostic,control=compiler.run(plan,'start',{},services,ctx,checkpoint)
      assert(ran or control=='wait',diagnostic and diagnostic.message)
      if ran then break end
    end
    assert(ran and entered==1 and finished==1,'prepared result lost, changed arity or replayed its effect')
  end
  log('TC_CONTRACT prepaid-service-result-before-effect-and-exact-resume')
  local function nop() end
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    local rec=assert(lifecycle.build(body))
    lifecycle.power_entity(rec).energy=defs.devices[kind].watts/30; rec.powered=true
    return rec
  end
  registry.initialize()
  local computer,db=build('computer',0),build('kv',3)
  computer.status='running'; computer.run_id=computer.id..'/result-admission'
  assert(lifecycle.connector(computer,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  local ctx=admission.context(admission.new(),computer.id,game.tick)
  local g=sandbox.new(ctx,function(guard) return runtime.services(computer,game.tick,guard) end)
  g.initialize()
  local handle=g.call(g.get(g.global('peripheral'),'wrap'),db.id,'red')
  local prepare=g.prepare_result
  for _,case in ipairs({{'set',{'k','new'},'OK'},{'hset',{'h','f','new'},0},{'hdel',{'h','f'},1},
    {'del',{'k'},1},{'expire',{'k',30},1},{'persist',{'k'},1}}) do
    kv.methods.set(nil,db,'red',game.tick,nop,'k','old')
    kv.methods.hset(nil,db,'red',game.tick,nop,'h','f','old')
    kv.methods.expire(nil,db,'red',game.tick,nop,'k',1)
    local before=db.database; local marker={}
    g.prepare_result=function() assert(db.database==before); error(marker,0) end
    local ran,problem=pcall(g.call,g.get(handle,case[1]),table.unpack(case[2]))
    assert(not ran and problem==marker and db.database==before,'native KV published before result admission')
    g.prepare_result=prepare
    assert(g.call(g.get(handle,case[1]),table.unpack(case[2]))==case[3])
    assert(db.database~=before,'accepted native KV mutation did not publish')
  end
  log('TC_CONTRACT native-KV-result-refusal-preserves-original-before-every-mutator')
end
return M
