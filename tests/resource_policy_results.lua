-- Trusted result storage is admitted before publication, not after an effect.
local sandbox=require('scripts.runtime.sandbox')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local kv=require('scripts.services.kv')
require('scripts.services.logic')
local M={}
runtime.register_services('registration-result-fixture',function(rec,tick,g)
  local f=storage.tc_scalar_results
  if f and rec.id==f.native_id then
    local prepare=g.prepare_result
    g.prepare_result=function(value,...)
      local result=table.pack(prepare(value,...))
      if type(value)=='string' and value:find('/timer-',1,true) then
        f.timer_preparations=f.timer_preparations+1
        if f.phase=='native' and f.timer_preparations==2 then
          f.periodic_id=value
          assert(not pcall(g.suspend)) -- Test-only pause at prepaid effect/caller boundary.
        end
      end
      return table.unpack(result,1,result.n)
    end
  end
  return {}
end)
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
local function scalar_result(kind,value,available,refuse)
  local ctx=admission.context(admission.new(),'prepared-scalar-result',0)
  ctx.machine.work=limits.callback_work-available
  local g=sandbox.new(ctx,{})
  local checkpoint,entered={},0
  local function copy(tuple)
    local result={n=tuple.n}; for i=1,tuple.n do result[i]=tuple[i] end; return result
  end
  g.call_checkpoint(checkpoint,{
    encode=function(tuple) assert(entered==0,'result encoding ran after the effect'); return copy(tuple) end,
    decode=copy,
    prepare=function(tuple)
      assert(entered==0,'result storage was prepared after the effect')
      if refuse then error('test-only scalar result-storage refusal',0) end
      local called={n=tuple.n+1,true}; for i=1,tuple.n do called[i+1]=tuple[i] end
      return {called=called,values=copy(tuple)}
    end,
  })
  local fn=g.service(function()
    if kind=='empty' then g.prepare_empty_result() else g.prepare_boolean_result() end
    entered=entered+1
    if kind=='boolean' then return value end
  end)
  local result=table.pack(pcall(g.call,fn))
  if result[1] then
    assert(entered==1 and result.n==(kind=='empty' and 1 or 2))
    assert(result[2]==value and checkpoint.call_result==checkpoint.service_result)
    assert(checkpoint.prepared.called==checkpoint.call_result)
    assert(checkpoint.prepared.values.n==result.n-1 and checkpoint.prepared.values[1]==value)
  else assert(entered==0,'scalar result refusal happened after publication') end
  return result[1],ctx.machine.work-(limits.callback_work-available)
end
local function direct_effect(kind,available,refuse)
  local ctx=admission.context(admission.new(),'direct-effect-result',0)
  local printed=0
  local g=sandbox.new(ctx,{}, {output=function() printed=printed+1 end})
  g.initialize()
  local table_effect=kind=='insert' or kind=='remove' or kind=='sort'
  local value=g.new(table_effect and 2 or 0,function() return table_effect and {2,1} or {} end)
  local fn=table_effect and g.get(g.global('table'),kind) or g.global(kind)
  local function unchanged()
    return printed==0 and value.key==nil and (not table_effect or #value==2 and value[1]==2 and value[2]==1)
  end
  local checkpoint={}
  local function tuple(v)
    local result={n=v.n}; for i=1,v.n do result[i]=v[i] end; return result
  end
  g.call_checkpoint(checkpoint,{
    encode=function(v) assert(unchanged(),'direct result encoded after mutation: '..kind); return tuple(v) end,
    decode=tuple,prepare=function(v)
      assert(unchanged(),'direct result prepared after mutation: '..kind)
      if refuse then error('test-only direct result storage refusal',0) end
      local called={n=v.n+1,true}; for i=1,v.n do called[i+1]=v[i] end
      return {called=called,values=tuple(v)}
    end,
  })
  ctx.machine.work=limits.callback_work-available
  local result
  if kind=='print' then result=table.pack(pcall(g.call,fn,'text'))
  elseif kind=='insert' then result=table.pack(pcall(g.call,fn,value,1,3))
  elseif kind=='remove' then result=table.pack(pcall(g.call,fn,value,1))
  elseif kind=='sort' then result=table.pack(pcall(g.call,fn,value))
  else result=table.pack(pcall(g.call,fn,value,'key',false)) end
  if result[1] then
    assert(kind=='print' and printed==1 and result.n==1
      or kind=='rawset' and value.key==false and result.n==2 and result[2]==value
      or kind=='insert' and #value==3 and value[1]==3 and value[2]==2 and value[3]==1 and result.n==1
      or kind=='remove' and #value==1 and value[1]==1 and result.n==2 and result[2]==2
      or kind=='sort' and #value==2 and value[1]==1 and value[2]==2 and result.n==1)
    assert(checkpoint.call_result==checkpoint.prepared.called)
  else assert(unchanged(),'direct effect preceded return admission: '..kind) end
  return result[1],ctx.machine.work-(limits.callback_work-available)
end
function M.run()
  for _,kind in ipairs({'print','rawset','insert','remove','sort'}) do
    local ok,cost=direct_effect(kind,limits.callback_work); assert(ok)
    for available=0,cost-1 do assert(not direct_effect(kind,available)) end
    assert(not direct_effect(kind,limits.callback_work,true))
  end
  log('TC_CONTRACT direct-print-rawset-and-table-mutators-admit-durable-returns-before-effect')
  for _,case in ipairs({{'empty'},{'boolean',false},{'boolean',true}}) do
    local ok,cost=scalar_result(case[1],case[2],limits.callback_work)
    assert(ok)
    for available=0,cost-1 do assert(not scalar_result(case[1],case[2],available)) end
    assert(not scalar_result(case[1],case[2],limits.callback_work,true))
  end
  log('TC_CONTRACT prepaid-empty-and-both-boolean-results-before-effect')
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
    assert(not pcall(g.prepare_empty_result),'failed provider leaked its private service frame')
  end
  for _,kind in ipairs({'empty','boolean'}) do
    for _,wrong_width in ipairs({false,true}) do
      local g=sandbox.new(admission.context(admission.new(),'bad-scalar-provider',0),{})
      local calls=0
      local bad=g.service(function()
        if kind=='empty' then g.prepare_empty_result() else g.prepare_boolean_result() end
        calls=calls+1
        if wrong_width then return true,false end
        if kind=='empty' then return false end
        return 'not a boolean'
      end)
      local ran,problem=pcall(g.call,bad)
      assert(not ran and calls==1 and g.diagnostic(problem).code=='E_ENGINE','scalar provider contract failure became suspension')
      assert(not pcall(g.prepare_empty_result),'failed scalar provider leaked its private service frame')
    end
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
  for _,case in ipairs({{'empty'},{'boolean',false},{'boolean',true}}) do
    local body=case[1]=='empty' and 'assert(select("#",computer.probe())==0); computer.finished()' or
      'assert(computer.probe()=='..tostring(case[2])..'); computer.finished()'
    for _,source in ipairs({'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}) do
      local ledger,checkpoint=admission.new(),{}
      local ctx=admission.context(ledger,'durable-scalar-result',0)
      local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
      local entered,finished=0,0
      local function services(g)
        return {computer={probe=function()
          if case[1]=='empty' then g.prepare_empty_result() else g.prepare_boolean_result() end
          entered=entered+1
          assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
          assert(not pcall(g.spend,1)) -- Trusted fixture poisons after the effect, then supplies its real result.
          if case[1]=='boolean' then return case[2] end
        end,finished=function() finished=finished+1 end}}
      end
      local ran,diagnostic,control=compiler.run(plan,'start',{},services,ctx,checkpoint)
      assert(not ran and control=='wait' and entered==1 and finished==0,diagnostic and diagnostic.message)
      assert(checkpoint.frame.pending.service_result==checkpoint.frame.pending.prepared.called)
      assert(checkpoint.frame.pending.call_result==nil,'fixture did not stop between service and caller delivery')
      for tick=1,20 do
        ctx=admission.context(ledger,'durable-scalar-result',tick)
        ran,diagnostic,control=compiler.run(plan,'start',{},services,ctx,checkpoint)
        assert(ran or control=='wait',diagnostic and diagnostic.message)
        if ran then break end
      end
      assert(ran and entered==1 and finished==1,'scalar effect/result was replayed or changed arity')
    end
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
  local function computer_method(name) return g.get(g.global('computer'),name) end
  for _,case in ipairs({{'setState',{'before','new'}},{'deleteState',{'before'},true},
    {'deleteState',{'absent'},false},{'setLabel',{'new label'}},{'log',{'new log'}}}) do
    g.call(computer_method('setState'),'before','old')
    if case[1]=='log' then
      for _=1,limits.console_entries do runtime.log(computer,'retained',game.tick) end
    end
    local before={label=computer.label,state=computer.state.before,bytes=computer.state_bytes,
      nodes=computer.state_nodes,entries=computer.state_entries,size=computer.state_sizes.before,
      logs=#computer.logs,log_bytes=computer.log_bytes,first_log=computer.logs[1],truncated=computer.log_truncated}
    local empty,prepare=g.prepare_empty_result,g.prepare_result
    local marker={}
    g.prepare_empty_result=function() error(marker,0) end
    g.prepare_result=function() error(marker,0) end
    local ran,problem=pcall(g.call,computer_method(case[1]),table.unpack(case[2]))
    assert(not ran and problem==marker,'computer mutator skipped return admission')
    assert(computer.label==before.label and computer.state.before==before.state and computer.state_bytes==before.bytes)
    assert(computer.state_nodes==before.nodes and computer.state_entries==before.entries and computer.state_sizes.before==before.size)
    assert(#computer.logs==before.logs and computer.log_bytes==before.log_bytes and computer.logs[1]==before.first_log
      and computer.log_truncated==before.truncated,'refused log evicted accepted history')
    g.prepare_empty_result,g.prepare_result=empty,prepare
    local result=table.pack(g.call(computer_method(case[1]),table.unpack(case[2])))
    assert(result.n==(case[1]=='deleteState' and 1 or 0) and result[1]==case[3],'computer result arity changed')
  end
  log('TC_CONTRACT computer-state-label-log-results-admitted-before-publication')
  local io=build('logic',6)
  assert(lifecycle.connector(computer,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  computer.active={source='function noop() end',revision=1,api_version=1,compiler_version=limits.compiler_version,
    storage_version=limits.storage_version,handlers={noop=true}}
  g=sandbox.new(admission.context(admission.new(),computer.id,game.tick),function(guard) return runtime.services(computer,game.tick,guard) end)
  g.initialize()
  local logic_handle=g.call(g.get(g.global('peripheral'),'wrap'),io.id,'red')
  local function same(current,old)
    for k,v in pairs(old) do assert(current[k]==v,'refused registration changed retained entry') end
    for k,v in pairs(current) do assert(old[k]==v,'refused registration published a new entry') end
  end
  local function shallow(value) local out={}; for k,v in pairs(value) do out[k]=v end; return out end
  for _,kind in ipairs({'on','after','every','off','off-absent','cancelTimer','cancelTimer-queued','cancelTimer-absent',
                        'logic-subscribe','logic-unsubscribe','logic-unsubscribe-absent'}) do
    computer.subscriptions={}; computer.timers={}; computer.queue={}; computer.queue_bytes=0
    local args,method,expected,created
    if kind=='on' then args={'modem_message','noop'}; method=computer_method('on'); created='subscriptions'
    elseif kind=='after' or kind=='every' then args={1000,'noop',{retained='payload'}}; method=computer_method(kind); created='timers'
    elseif kind=='logic-subscribe' then args={{input='red'},'noop'}; method=g.get(logic_handle,'subscribe'); created='subscriptions'
    elseif kind:sub(1,11)=='cancelTimer' then
      local id=kind=='cancelTimer-absent' and computer.run_id..'/timer-missing' or g.call(computer_method('after'),1000,'noop')
      if kind~='cancelTimer-absent' then
        assert(runtime.enqueue(computer,'noop',{name='timer'},game.tick,nil,{timer_id=id}))
        if kind=='cancelTimer-queued' then computer.timers[id]=nil end
      end
      args={id}; method=computer_method('cancelTimer'); expected=kind~='cancelTimer-absent'
    elseif kind:sub(1,5)=='logic' then
      local id=kind=='logic-unsubscribe-absent' and computer.run_id..'/sub-missing' or
        g.call(g.get(logic_handle,'subscribe'),g.snapshot({input='red'}),'noop')
      if kind~='logic-unsubscribe-absent' then assert(runtime.enqueue(computer,'noop',{name='signal_changed',subscription_id=id},game.tick)) end
      args={id}; method=g.get(logic_handle,'unsubscribe'); expected=kind~='logic-unsubscribe-absent'
    else
      args={kind=='off-absent' and computer.run_id..'/sub-missing' or g.call(computer_method('on'),'modem_message','noop')}
      method=computer_method('off'); expected=kind~='off-absent'
    end
    assert(runtime.enqueue(computer,'noop',{name='unrelated'},game.tick))
    local peer=computer.queue[#computer.queue]
    local before={subscriptions=shallow(computer.subscriptions),timers=shallow(computer.timers),queue=shallow(computer.queue),
      queue_identity=computer.queue,bytes=computer.queue_bytes,sequence=registry.get().next_sequence}
    local prepare,marker=g.prepare_result,{}
    g.prepare_result=function() error(marker,0) end
    for i,v in ipairs(args) do if type(v)=='table' then args[i]=g.snapshot(v) end end
    local ran,problem=pcall(g.call,method,table.unpack(args))
    assert(not ran and problem==marker,'registration skipped result admission: '..kind)
    same(computer.subscriptions,before.subscriptions); same(computer.timers,before.timers); same(computer.queue,before.queue)
    assert(computer.queue==before.queue_identity and computer.queue_bytes==before.bytes and registry.get().next_sequence==before.sequence)
    g.prepare_result=prepare
    local result=table.pack(g.call(method,table.unpack(args)))
    assert(result.n==1 and (created and type(result[1])=='string' or not created and result[1]==expected))
    if created then assert(computer[created][result[1]] and registry.get().next_sequence==before.sequence+1)
    else assert(registry.get().next_sequence==before.sequence) end
    assert(computer.queue[#computer.queue]==peer,'cancellation removed an unrelated accepted event')
    if kind=='cancelTimer' or kind=='cancelTimer-queued' or kind=='logic-unsubscribe' then assert(#computer.queue==1) end
  end
  computer.subscriptions={}; computer.timers={}; computer.queue={}; computer.queue_bytes=0
  log('TC_CONTRACT registration-and-cancellation-result-refusal-preserves-identities-maps-and-queue')
  local sequence=registry.get().next_sequence
  for _,name in ipairs({'on','after','every'}) do
    registry.get().next_sequence=9007199254740989
    local fn=computer_method(name); local args=name=='on' and {'modem_message','noop'} or {1000,'noop'}
    local prefix=computer.run_id..(name=='on' and '/sub-' or '/timer-')
    assert(g.call(fn,table.unpack(args))==prefix..'9007199254740989')
    assert(g.call(fn,table.unpack(args))==prefix..'9007199254740990')
    local ran,problem=pcall(g.call,fn,table.unpack(args))
    assert(not ran and problem.code=='E_CAPACITY' and registry.get().next_sequence==9007199254740991)
    computer.subscriptions={}; computer.timers={}
  end
  registry.get().next_sequence=sequence
  log('TC_CONTRACT exact-registration-identities-and-safe-sequence-exhaustion')
  storage.tc_scalar_results={phase='native',cases={},native_id=computer.id,logic_id=io.id,timer_preparations=0}
  local source=[[function start()
    local io=assert(peripheral.find('logic_handler','red'))
    local subscription=computer.on('modem_message','noop')
    local signal=io.subscribe({input='red'},'noop')
    local once=computer.after(1000,'noop',{value=1})
    local recurring=computer.every(1000,'noop',{value=2})
    computer.setState('periodic',recurring)
    assert(computer.cancelTimer(once) and not computer.cancelTimer(once))
    assert(computer.cancelTimer(recurring) and not computer.cancelTimer(recurring))
    assert(computer.off(subscription) and not computer.off(subscription))
    assert(io.unsubscribe(signal) and not io.unsubscribe(signal))
    computer.setState('registration_done',true)
  end
  function noop() error('timer or unchanged signal delivered unexpectedly') end]]
  assert(runtime.save(computer.id,source,computer.saved_revision)); assert(runtime.activate(computer.id,game.tick))
end
local loaded=false
function M.on_load()
  local f=storage.tc_scalar_results
  if f.phase=='frozen' then
    local c=registry.computer(f.native_id)
    assert(c.run_id==f.native_run and registry.get().next_sequence==f.native_sequence and c.state.periodic==nil)
    assert(c.invocation.checkpoint.frame.pending.service_result[2]==f.periodic_id)
    for _,case in ipairs(f.cases) do
      assert(case.entered==1 and case.finished==0 and case.checkpoint.frame.pc==case.pc)
      assert(case.ledger.total==case.spent and case.checkpoint.frame.pending.call_result==nil)
      assert(case.checkpoint.frame.pending.service_result==case.checkpoint.frame.pending.prepared.called)
    end
    loaded=true; log('TC_SCALAR_RESULTS_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_scalar_results
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if f.phase=='native' or f.phase=='native-resume' then
    local c=registry.computer(f.native_id); local io=registry.record(f.logic_id)
    assert(event.tick<500,'scheduled registration result timed out')
    lifecycle.power_entity(c).energy=1000000; c.powered=true
    lifecycle.power_entity(io).energy=1000000; io.powered=true
    scheduler.tick(event.tick)
    assert(c.status=='running' and not c.diagnostic and not c.resource_refusal,serpent.line(c.diagnostic or c.resource_refusal))
    if f.phase=='native-resume' then
      if c.invocation then return end
      assert(c.state.registration_done and c.state.periodic==f.periodic_id and f.timer_preparations==2)
      assert(c.run_id==f.native_run and registry.get().next_sequence==f.native_sequence)
      assert(next(c.timers)==nil and next(c.subscriptions)==nil and #c.queue==0)
      runtime.stop(c.id); f.phase='done'
      log('TC_CONTRACT scheduled-registration-results-cold-exactly-once-and-cancellation')
      log('TC_COLD_OK'); return
    end
    if not f.periodic_id then return end
    local pending=assert(c.invocation.checkpoint.frame.pending)
    assert(pending.call_result==nil and pending.service_result==pending.prepared.called and pending.service_result[2]==f.periodic_id)
    local timers,subs=0,0
    for _ in pairs(c.timers) do timers=timers+1 end
    for _ in pairs(c.subscriptions) do subs=subs+1 end
    assert(timers==2 and subs==2 and c.timers[f.periodic_id].interval==1000 and c.state.periodic==nil)
    f.native_sequence=registry.get().next_sequence; f.native_run=c.run_id; f.phase='armed'
  end
  if f.phase=='armed' then
    for _,value in ipairs({'empty','false','true'}) do
      for _,declaration in ipairs({false,true}) do
        local body=value=='empty' and 'assert(select("#",computer.probe())==0); computer.finished()' or
          'assert(computer.probe()=='..value..'); computer.finished()'
        f.cases[#f.cases+1]={value=value,source=declaration and 'function start() '..body..' end' or
          'return {api_version=1,handlers={start=function() '..body..' end}}',
          ledger=admission.new(),checkpoint={},entered=0,finished=0}
      end
    end
  end
  for _,case in ipairs(f.cases) do
    local ctx=admission.context(case.ledger,'cold-scalar-result',event.tick)
    local plan,e=compiler.compile(case.source,ctx); assert(plan,e and e.message)
    local function services(g)
      return {computer={probe=function()
        if case.value=='empty' then g.prepare_empty_result() else g.prepare_boolean_result() end
        case.entered=case.entered+1
        assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
        assert(not pcall(g.spend,1))
        if case.value~='empty' then return case.value=='true' end
      end,finished=function() case.finished=case.finished+1 end}}
    end
    local ok,diagnostic,control=compiler.run(plan,'start',{},services,ctx,case.checkpoint)
    if f.phase=='armed' then
      assert(not ok and control=='wait' and case.entered==1 and case.finished==0,diagnostic and diagnostic.message)
      local pending=case.checkpoint.frame.pending
      assert(pending and pending.call_result==nil and pending.service_result==pending.prepared.called)
      case.pc=case.checkpoint.frame.pc; case.spent=case.ledger.total
    else
      assert(ok and case.entered==1 and case.finished==1,diagnostic and diagnostic.message)
    end
  end
  if f.phase=='armed' then
    f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  else
    f.phase='native-resume'; log('TC_CONTRACT scalar-results-cold-between-effect-and-caller-delivery')
  end
end
return M
