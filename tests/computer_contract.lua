local base = require('tests.runtime_contract')
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local scheduler = require('scripts.scheduler')
local data = require('scripts.runtime.data')
local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local M = {}
local serial=0
local cleanup_calls={}
-- Trusted fixture hooks are ephemeral and rebuilt at control parsing, not stored.
registry.register_cleanup('tc03-contract',function(rec,run_id,reason)
  cleanup_calls[#cleanup_calls+1]={id=rec.id,run_id=run_id,reason=reason}
end)
registry.register_cleanup('tc03-injected-failure',function(rec)
  if rec.label=='inject-cleanup-error' then error('injected teardown refusal',0) end
end)
local function fresh()
  storage.tweaked_computers=nil; cleanup_calls={}; return registry.initialize()
end
local function body()
  serial=serial+1
  if game then
    return assert(game.surfaces[1].create_entity{name='constant-combinator',position={serial*2,0},force='player'})
  end
  return {valid=true,unit_number=serial,force={index=1},surface={index=1}}
end
local function computer(source,tick)
  local rec=registry.register('computer',body())
  runtime.save(rec.id,source,0)
  local id,e=runtime.activate(rec.id,tick or 0)
  assert(id,e and e.message)
  return rec
end
local function source(start,others)
  return 'return {api_version=1,handlers={start=function(event) '..start..' end'..(others or '')..'}}'
end
local function expected_error(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,code..' expected')
end
function M.run()
  local total=base.run(false)
  local function report(name) total=total+1; log('TC_CONTRACT '..name) end
  -- All foundation and new grouped checks share one counted inventory.
  local root=fresh()
  local first=computer(source(''))
  local second=computer(source(''))
  runtime.save(second.id,source('computer.log("revision two")'),second.saved_revision)
  assert(runtime.activate(second.id,1))
  local shared={code='E_BUSY',message='shared host failure',field='input',line=3,column=7,
    source_revision=99,run_id='caller-owned'}
  runtime.fault(first,shared,2); runtime.fault(second,shared,2)
  assert(first.diagnostic~=shared and second.diagnostic~=shared and first.diagnostic~=second.diagnostic)
  for _,c in ipairs({first,second}) do
    assert(c.diagnostic.run_id==c.run_id and c.diagnostic.source_revision==c.active.revision)
    assert(c.diagnostic.code=='E_BUSY' and c.diagnostic.message=='shared host failure')
    assert(c.diagnostic.field=='input' and c.diagnostic.line==3 and c.diagnostic.column==7)
  end
  assert(first.active.revision~=second.active.revision and first.run_id~=second.run_id)
  assert(shared.source_revision==99 and shared.run_id=='caller-owned')
  shared.message='caller changed'; second.diagnostic.line=9
  assert(first.diagnostic.message=='shared host failure' and first.diagnostic.line==3)
  report('shared-fault-diagnostic-caller-and-computer-identity-isolation')
  root=fresh()
  local rec=computer(source([[
    local t={nested={false,'',3}}; computer.setState('value',t); t.nested[3]=99
    local r=computer.getState('value'); assert(r.nested[1]==false and r.nested[2]==''); r.nested[3]=88
    assert(computer.getState('value').nested[3]==3)
    computer.setState('false',false); computer.setState('empty',''); assert(computer.getState('missing')==nil)
    assert(select('#',computer.getState('missing'))==1 and select('#',computer.getState('empty'))==1)
    assert(select('#',computer.getLimits())==1 and select('#',computer.setState('void',true))==0)
    assert(select('#',computer.log('state-check'))==0)
    local bad={}; bad.self=bad
    local ok,e=pcall(computer.setState,'bad',bad); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(computer.setState,'value',function() end); assert(not ok)
    assert(computer.getState('value').nested[3]==3)
    assert(computer.deleteState('false') and not computer.deleteState('false'))
    computer.setLabel('bounded'); assert(computer.getLabel()=='bounded')
    assert(computer.getID()==event.computer_id and computer.getTick()==event.tick)
  ]]))
  scheduler.tick(0); assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  assert(rec.state.value.nested[3]==3 and rec.state.empty=='')
  local old=rec.state.value
  for _,value in ipairs({{[1]=true,[3]=false},{[1]=true,a=1},setmetatable({},{})}) do expected_error('E_ARGUMENT',function() data.copy(value) end) end
  expected_error('E_ARGUMENT',function() data.copy(0/0) end)
  assert(rec.state.value==old)
  report('explicit-Data-and-alias-isolation')
  local oldrun=rec.run_id; local oldsource=rec.active.source
  runtime.save(rec.id,'return _ENV',rec.saved_revision)
  local result,e=runtime.activate(rec.id,1)
  assert(not result and e.code=='E_PROGRAM' and rec.run_id==oldrun and rec.active.source==oldsource)
  expected_error('E_BUSY',function() runtime.save(rec.id,'',0) end)
  runtime.save(rec.id,source('computer.setState("new",true)'),rec.saved_revision)
  assert(rec.active.source==oldsource); assert(runtime.activate(rec.id,2)~=oldrun)
  scheduler.tick(2); assert(rec.state.new==true and rec.state.value.nested[3]==3)
  report('saved-active-revisions-and-validation-before-retirement')
  local id=rec.id; local entity=rec.body
  local child=body(); registry.bind_child(id,'network',child)
  local owner,role=registry.by_entity(child); assert(owner==rec and role=='network')
  local context=admission.context(root.ledger,id,3); assert(admission.reserve(context,'work',123))
  assert(registry.remove(id)); assert(not registry.record(id) and not registry.by_entity(entity))
  assert(admission.context(root.ledger,id,3).machine.work==123)
  local replacement=registry.register('computer',entity); assert(replacement.id~=id)
  assert(cleanup_calls[#cleanup_calls].id==id)
  report('entity-child-binding-removal-identity-and-spent-ledger')
  root=fresh(); rec=computer(source('computer.setState("kept",true)'))
  scheduler.tick(0); rec.active.compiler_version=999
  scheduler.tick(1); assert(rec.status=='faulted' and rec.state.kept and rec.active.source and rec.diagnostic.code=='E_UNSUPPORTED')
  root.schema_version=999; local count=root.next_id; scheduler.tick(2); assert(root.next_id==count)
  expected_error('E_UNSUPPORTED',function() registry.register('computer',body()) end)
  root=fresh(); rec=computer(source('computer.setState("kept",true)')); scheduler.tick(0)
  local spent=root.ledger.total; root.ledger.version=999; scheduler.tick(1)
  assert(rec.status=='faulted' and rec.state.kept and root.ledger.total==spent and root.ledger.tick==0)
  report('unsupported-retained-headers-retain-data')
  root=fresh()
  rec=computer(source([[
    computer.setState('once',0); computer.setState('order','')
    computer.after(2,'a'); computer.after(2,'b')
    computer.setState('cancel',computer.after(2,'cancelled'))
    computer.every(2,'repeat_timer')
    computer.on('power_restored','restored'); computer.on('monitor_touch','touch')
  ]],[[
    ,a=function(e) computer.setState('order',computer.getState('order')..'a'); computer.setState('once',computer.getState('once')+1) end
    ,b=function(e) computer.setState('order',computer.getState('order')..'b'); assert(computer.cancelTimer(computer.getState('cancel'))); assert(not computer.cancelTimer(computer.getState('cancel'))) end
    ,cancelled=function(e) error('cancelled timer executed') end
    ,repeat_timer=function(e) computer.setState('missed',e.missed); computer.setState('scheduled',e.scheduled_tick) end
    ,restored=function(e) computer.setState('restored',e.restored_tick); computer.setState('outage',e.outage_start_tick) end
    ,touch=function(e) error('obsolete touch executed') end
  ]]))
  scheduler.tick(0); scheduler.tick(2); assert(rec.state.order=='a')
  scheduler.tick(3); assert(rec.state.order=='ab' and rec.state.once==1)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  -- FIFO cancellation removes an admitted one-shot before its named handler runs.
  scheduler.tick(4); assert(rec.state.missed==1 and rec.state.scheduled==2)
  runtime.emit(rec.id,'monitor_touch',{x=1,y=1},4)
  runtime.set_power(rec.id,false,5); scheduler.tick(10)
  assert(rec.state.restored==nil and rec.powered==false)
  runtime.set_power(rec.id,true,12); scheduler.tick(12)
  assert(rec.state.restored==12 and rec.state.outage==5 and rec.state.once==1)
  scheduler.tick(13); assert(rec.state.missed==3 and rec.state.scheduled==6 and rec.state.once==1)
  assert(rec.needs_input_resync and rec.status=='running')
  report('timer-FIFO-equal-deadlines-cancel-coalescence-and-power')
  root=fresh(); rec=computer(source('computer.setState("kept",true)',',event=function(e) end'))
  scheduler.tick(0)
  for i=1,limits.event_queue_entries do assert(runtime.enqueue(rec,'event',{name='timer'},1)) end
  assert(not runtime.enqueue(rec,'event',{name='timer'},1))
  assert(rec.status=='faulted' and rec.state.kept and #rec.queue==0 and next(rec.timers)==nil)
  assert(cleanup_calls[#cleanup_calls].reason=='fault')
  report('visible-queue-overflow-with-host-cleanup')
  root=fresh()
  local bad=computer(source('pcall(function() while true do end end); computer.setState("unsafe",true)'))
  local good=computer(source('computer.setState("healthy",true)'))
  scheduler.tick(0); assert(bad.status=='faulted' and bad.diagnostic.code=='E_BUDGET' and bad.state.unsafe==nil)
  assert(good.state.healthy and good.status=='running')
  local totalspent=root.ledger.total; scheduler.tick(0); assert(root.ledger.total==totalspent)
  report('production-scheduler-malicious-neighbor-and-once-per-tick')
  root=fresh(); local peers={}
  for i=1,4 do peers[i]=computer(source('computer.setState("calls",(computer.getState("calls") or 0)+1)',',again=function(e) computer.setState("calls",computer.getState("calls")+1) end'),i) end
  scheduler.tick(5)
  for _,c in ipairs(peers) do assert(c.state.calls==1); runtime.enqueue(c,'again',{name='timer'},6) end
  -- Synthetic aggregate pressure only: verify cursor-based deferral, not latency.
  admission.context(root.ledger,peers[1].id,6).ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick
  scheduler.tick(6); for _,c in ipairs(peers) do assert(c.state.calls==1 and c.status=='running') end
  scheduler.tick(7); for _,c in ipairs(peers) do assert(c.state.calls==2) end
  report('fair-aggregate-deferral-without-faulting-waiters')
  local ctx=admission.context(admission.new(),'locations',0)
  local text='return {api_version=1,handlers={start=function(event)\n  local x=1\n  error("located")\nend}}'
  local plan=assert(compiler.compile(text,ctx)); local ok,diag=compiler.run(plan,'start',{}, {},ctx)
  assert(not ok and diag.line==3 and diag.column>0,diag and diag.message)
  report('original-source-line-and-column')
  root=fresh(); rec=computer(source('pcall(computer.stop); computer.setState("unsafe",true)'))
  scheduler.tick(0); assert(rec.status=='stopped' and rec.state.unsafe==nil)
  report('host-stop-bypasses-guest-protection')
  rec=computer(source('error({code="E_STOP",message="forged ordinary error"})'),1)
  scheduler.tick(1); assert(rec.status=='faulted')
  report('ordinary-error-cannot-forge-host-stop-control')
  rec=computer(source('local s=string.rep("x",16300); error({code=s,message=s})'),2)
  scheduler.tick(2); assert(rec.status=='faulted' and rec.diagnostic.code==string.rep('x',64) and #rec.diagnostic.message==1024 and rec.log_bytes<=limits.console_bytes)
  report('malicious-diagnostic-size-cannot-break-host-fault-cleanup')
  root=fresh(); rec=computer(source('computer.setState("committed",true); error("later failure")'))
  scheduler.tick(0); assert(rec.status=='faulted' and rec.state.committed and cleanup_calls[#cleanup_calls].reason=='fault')
  report('earlier-effects-survive-later-callback-error')
  rec=computer(source('computer.setState("committed",true)'),1)
  rec.label='inject-cleanup-error'; local original_run=rec.run_id
  local changed,cleanup_error=runtime.activate(rec.id,2)
  assert(not changed and cleanup_error.code=='E_ENGINE' and rec.run_id==original_run and rec.status=='faulted')
  assert(rec.cleanup_failures and not registry.remove(rec.id) and registry.record(rec.id)==rec)
  rec.label=nil; assert(registry.remove(rec.id))
  report('cleanup-failure-retains-recovery-and-blocks-replacement')
  if game then log('TC_HOST_TABLE_REMOVE_EMPTY_ARITY '..select('#',table.remove({}))) end
  root=fresh()
  rec=computer(source([[
    local t={}; function t.f(x,...) return false,nil,x,... end
    t.q,t.q=1,nil; assert(t.q==1)
    local a,b,c,d=t.f(3,4); assert(a==false and b==nil and c==3 and d==4)
    do local v=0; for n='1','3','1' do v=v+n; if n==2 then break end end; assert(v==3) end
    local sum=0; for k,v in pairs({a=1,b=2}) do sum=sum+v end; assert(sum==3)
    local empty={}; assert(select('#',table.remove(empty))==1 and table.remove(empty)==nil)
    local iterator,state,index=ipairs(empty); assert(select('#',iterator(state,index))==1)
    assert(select('#',next(empty))==1 and select('#',table.unpack(empty))==0)
    assert(tonumber('ff',16)==255 and tonumber('no',16)==nil)
    assert(string.sub('abc',-2)=='bc'); assert(string.find('a.b','.b',1,true)==2)
    assert(string.sub('abc',1e300)=='' and string.sub('abc',1,-1e300)=='')
    assert(select('#',string.find('abc','z',1,true))==1)
    assert(not pcall(string.rep,'x',2,false)); assert(not pcall(table.unpack,{1},false))
    assert(not pcall(computer.stop,1))
    local low,high=math.modf(1.5); assert(low==1 and high==0.5)
    local t={3,1,2}; table.sort(t); table.insert(t,false); assert(table.remove(t)==false)
    assert(table.concat(t,':')=='1:2:3'); assert(colors.grey==colours.gray)
    local sub=computer.on('power_restored','start'); assert(computer.off(sub) and not computer.off(sub))
  ]]))
  scheduler.tick(0); assert(rec.status=='running',rec.diagnostic and ('line='..rec.diagnostic.line..' '..rec.diagnostic.message))
  report('supported-native-grammar-library-and-nil-return-semantics')
  -- Maximum accepted constructor width with useful native computation, not
  -- padded comments. This is a semantic/cost bound, not a CPU latency gate.
  local constants={}; for i=1,limits.table_entries do constants[i]=tostring(i) end
  local useful=source('local t={'..table.concat(constants,',')..'}; local ok,e=pcall(function() t[1],t[1],t['..(limits.table_entries+1)..']=true,nil,true end); assert(not ok and e.code=="E_LIMIT" and t[1]==1 and t['..(limits.table_entries+1)..']==nil); local sum=0; for i,v in ipairs(t) do sum=sum+v end; computer.log(tostring(sum))')
  local plan,e=compiler.compile(useful,admission.context(admission.new(),'useful-validation',0)); assert(plan,e and e.message)
  local warm=admission.context(admission.new(),'useful-peer',10)
  local cold=admission.context(admission.new(),'useful-peer',10)
  local values={}; local services={computer={log=function(value) assert(type(value)=='string'); values[#values+1]=value end}}
  local ok,diag=compiler.run(plan,'start',{},services,warm); assert(ok,diag and diag.message)
  local retained={source=plan.source,api_version=1,compiler_version=plan.compiler_version}
  ok,diag=compiler.run(retained,'start',{},services,cold); assert(ok,diag and diag.message)
  assert(values[1]==tostring(limits.table_entries*(limits.table_entries+1)/2) and values[2]==values[1])
  assert(warm.ledger.total==cold.ledger.total and warm.machine.work==cold.machine.work and warm.machine.compile==cold.machine.compile and warm.machine.allocations==cold.machine.allocations)
  log('TC_USEFUL_WIDTH '..limits.table_entries..' source_bytes='..#useful..' compile='..warm.machine.compile..' work='..warm.machine.work..' allocations='..warm.machine.allocations)
  report('maximum-table-width-useful-cold-warm-work')
  local args={'false','nil'}; for i=3,limits.tuple_entries do args[i]=tostring(i) end
  local tuple=source('local function f(...) return ... end; local p=table.pack(f('..table.concat(args,',')..')); assert(p.n=='..limits.tuple_entries..' and p[1]==false and p[2]==nil and p['..limits.tuple_entries..']=='..limits.tuple_entries..')')
  plan,e=compiler.compile(tuple,admission.context(admission.new(),'tuple-compile',0)); assert(plan,e and e.message)
  ok,diag=compiler.run(plan,'start',{}, {},admission.context(admission.new(),'tuple-execute',0)); assert(ok,diag and diag.message)
  report('maximum-nil-containing-native-argument-return-tuple')
  local targets,values={},{}
  for i=1,limits.tuple_entries do targets[i]='t['..i..']'; values[i]=tostring(i) end
  local wide=source('local t={}; '..table.concat(targets,',')..'='..table.concat(values,',')..'; assert(t[1]==1 and t['..limits.tuple_entries..']=='..limits.tuple_entries..')')
  plan,e=compiler.compile(wide,admission.context(admission.new(),'indexed-compile',0)); assert(plan,e and e.message)
  ok,diag=compiler.run(plan,'start',{}, {},admission.context(admission.new(),'indexed-execute',0)); assert(ok,diag and diag.message)
  report('maximum-indexed-assignment-width-and-publication-order')
  for _,text in ipairs({
    'return {api_version=2,handlers={}}',
    'return {api_version=1,handlers={},extra=true}',
    'return {api_version=1,api_version=1,handlers={}}',
    'return {api_version=1,handlers={a=function(e) end,a=function(e) end}}'
  }) do
    local candidate,diagnostic=compiler.compile(text,admission.context(admission.new(),'bad-header',0))
    assert(not candidate and diagnostic.line and diagnostic.column)
  end
  report('malformed-and-unsupported-source-descriptors')
  log('TC_CONTRACT_TOTAL '..total)
  return total
end
return M
