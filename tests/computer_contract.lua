local base = require('tests.runtime_contract')
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local scheduler = require('scripts.scheduler')
local data = require('scripts.runtime.data')
local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local environment = require('scripts.runtime.environment')
local principal = require('scripts.runtime.principal')
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
  return 'function start(event) '..start..' end '..(others or '')
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
  scheduler.tick(0)
  assert(runtime.enqueue(rec,'start',{name='fixture'},1))
  rec.active.compiler_version=999 -- Invalid retained code is checked when work is due, not by an idle sweep.
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
    function a(e) computer.setState('order',computer.getState('order')..'a'); computer.setState('once',computer.getState('once')+1) end
    function b(e) computer.setState('order',computer.getState('order')..'b'); assert(computer.cancelTimer(computer.getState('cancel'))); assert(not computer.cancelTimer(computer.getState('cancel'))) end
    function cancelled(e) error('cancelled timer executed') end
    function repeat_timer(e) computer.setState('missed',e.missed); computer.setState('scheduled',e.scheduled_tick) end
    function restored(e) computer.setState('restored',e.restored_tick); computer.setState('outage',e.outage_start_tick) end
    function touch(e) computer.setState('touches',(computer.getState('touches') or 0)+1) end
  ]]))
  scheduler.tick(0); scheduler.tick(2); assert(rec.state.order=='a')
  scheduler.tick(3); assert(rec.state.order=='ab' and rec.state.once==1)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  -- FIFO cancellation removes an admitted one-shot before its named handler runs.
  scheduler.tick(4); assert(rec.state.missed==1 and rec.state.scheduled==2)
  runtime.emit(rec.id,'monitor_touch',{x=1,y=1},4)
  rec.powered=false; scheduler.tick(10)
  assert(rec.state.restored==nil and rec.state.touches==1)
  assert(not runtime.emit(rec.id,'power_restored',{},12))
  rec.powered=true; scheduler.tick(12)
  assert(rec.state.restored==nil and rec.state.outage==nil and rec.state.once==1)
  scheduler.tick(13); assert(rec.state.missed==3 and rec.state.scheduled==6 and rec.state.once==1)
  assert(not rec.needs_input_resync and rec.status=='running')
  report('timer-FIFO-equal-deadlines-cancel-coalescence-inert-power-restored')
  root=fresh(); rec=computer(source('computer.setState("kept",true)','function event(e) end'))
  scheduler.tick(0)
  for i=1,limits.event_queue_entries do assert(runtime.enqueue(rec,'event',{name='timer'},1)) end
  assert(not runtime.enqueue(rec,'event',{name='timer'},1))
  assert(rec.status=='faulted' and rec.state.kept and #rec.queue==0 and next(rec.timers)==nil)
  assert(cleanup_calls[#cleanup_calls].reason=='fault')
  report('visible-queue-overflow-with-host-cleanup')
  root=fresh()
  local bad=computer('--'..string.rep('x',8000)..'\n'..source('computer.setState("calls",(computer.getState("calls") or 0)+1)'))
  local good=computer(source('computer.setState("healthy",true)'))
  local pending=bad.queue[1]; local event_tick=pending.event.tick; local queued_bytes=bad.queue_bytes
  admission.context(root.ledger,bad.id,1).ledger.total=admission.host_ceiling(root.ledger,1)-10000
  scheduler.tick(1); assert(bad.status=='running' and not bad.diagnostic and bad.state.calls==nil)
  assert(bad.queue[1]==pending and pending.event.tick==event_tick and bad.queue_bytes==queued_bytes and bad.last_dispatch_tick==nil)
  assert(good.state.healthy and good.status=='running')
  local totalspent=root.ledger.total; scheduler.tick(1); assert(root.ledger.total==totalspent)
  scheduler.tick(2); assert(bad.state.calls==1 and #bad.queue==0 and bad.status=='running')
  scheduler.tick(3); assert(bad.state.calls==1)
  report('production-scheduler-source-deferral-healthy-neighbor-and-once-per-tick')
  root=fresh(); rec=computer(source('computer.setState("unstarted",true)'))
  local compile_limit=limits.compile_work; limits.compile_work=1
  scheduler.tick(1); limits.compile_work=compile_limit
  assert(rec.status=='faulted' and rec.diagnostic.code=='E_BUDGET' and not rec.state.unstarted and #rec.queue==0)
  report('unfit-fresh-source-preparation-fails-without-retry')
  root=fresh(); rec=computer(source('computer.setState("calls",(computer.getState("calls") or 0)+1); computer.setState("payload",string.rep("x",8192)); for i=1,1024 do computer.getState("payload") end'))
  scheduler.tick(1); assert(rec.status=='faulted' and rec.diagnostic.code=='E_BUDGET' and rec.state.calls==1)
  scheduler.tick(2); assert(rec.state.calls==1 and #rec.queue==0)
  report('started-host-refusal-never-replays-completed-effects')
  root=fresh(); local peers={}
  for i=1,4 do peers[i]=computer(source('computer.setState("calls",(computer.getState("calls") or 0)+1)','function again(e) computer.setState("calls",computer.getState("calls")+1) end'),i) end
  scheduler.tick(5)
  for _,c in ipairs(peers) do assert(c.state.calls==1); runtime.enqueue(c,'again',{name='timer'},6) end
  -- Synthetic aggregate pressure only: verify cursor-based deferral, not latency.
  admission.context(root.ledger,peers[1].id,6).ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick
  scheduler.tick(6); for _,c in ipairs(peers) do assert(c.state.calls==1 and c.status=='running') end
  scheduler.tick(7); for _,c in ipairs(peers) do assert(c.state.calls==2) end
  report('fair-aggregate-deferral-without-faulting-waiters')
  local ctx=admission.context(admission.new(),'locations',0)
  local text='function start(event)\n  local x=1\n  error("located")\nend'
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
    local empty={}; assert(select('#',table.remove(empty))==0 and table.remove(empty)==nil)
    local iterator,state,index=ipairs(empty); assert(select('#',iterator(state,index))==1)
    assert(select('#',next(empty))==1 and select('#',table.unpack(empty))==0)
    assert(tonumber('ff',16)==255 and tonumber('no',16)==nil)
    assert(string.sub('abc',-2)=='bc'); assert(string.find('a.b','.b',1,true)==2)
    assert(string.sub('abc',1e300)==]]..string.format('%q',string.sub('abc',1e300))..[[ and string.sub('abc',1,-1e300)==]]..string.format('%q',string.sub('abc',1,-1e300))..[[)
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
  local width=limits.table_entries+1
  local constants={}; for i=1,width do constants[i]=tostring(i) end
  local computation='local t={'..table.concat(constants,',')..'}; local alias=t; t[1],t[1],t['..(width+1)..']=1,2,'..(width+1)..'; assert(alias==t and t['..(width+1)..']=='..(width+1)..'); local sum=0; for i,v in ipairs(t) do sum=sum+v end; '
  local native_sum=assert(load(computation..'return sum','@native-assignment','t',_ENV))()
  local useful=source(computation..'computer.log(tostring(sum))')
  local plan,e=compiler.compile(useful,admission.context(admission.new(),'useful-validation',0)); assert(plan,e and e.message)
  local warm=admission.context(admission.new(),'useful-peer',10)
  local cold=admission.context(admission.new(),'useful-peer',10)
  local values={}; local services={computer={log=function(value) assert(type(value)=='string'); values[#values+1]=value end}}
  local ok,diag=compiler.run(plan,'start',{},services,warm); assert(ok,diag and diag.message)
  local retained={source=plan.source,api_version=1,compiler_version=plan.compiler_version}
  ok,diag=compiler.run(retained,'start',{},services,cold); assert(ok,diag and diag.message)
  assert(values[1]==tostring(native_sum) and values[2]==values[1])
  assert(warm.ledger.total==cold.ledger.total and warm.machine.work==cold.machine.work and warm.machine.compile==cold.machine.compile)
  log('TC_USEFUL_WIDTH '..limits.table_entries..' source_bytes='..#useful..' compile='..warm.machine.compile..' work='..warm.machine.work)
  report('maximum-table-width-useful-cold-warm-work')
  local args={'false','nil'}; for i=3,160 do args[i]=tostring(i) end
  local tuple=source('local function f(...) return ... end; local p=table.pack(f('..table.concat(args,',')..')); assert(p.n==160 and p[1]==false and p[2]==nil and p[160]==160)')
  plan,e=compiler.compile(tuple,admission.context(admission.new(),'tuple-compile',0)); assert(plan,e and e.message)
  ok,diag=compiler.run(plan,'start',{}, {},admission.context(admission.new(),'tuple-execute',0)); assert(ok,diag and diag.message)
  report('maximum-nil-containing-native-argument-return-tuple')
  local targets,values={},{}
  for i=1,160 do targets[i]='t['..i..']'; values[i]=tostring(i) end
  local wide=source('local t={}; '..table.concat(targets,',')..'='..table.concat(values,',')..'; assert(t[1]==1 and t[160]==160)')
  plan,e=compiler.compile(wide,admission.context(admission.new(),'indexed-compile',0)); assert(plan,e and e.message)
  ok,diag=compiler.run(plan,'start',{}, {},admission.context(admission.new(),'indexed-execute',0)); assert(ok,diag and diag.message)
  report('maximum-indexed-assignment-width-and-publication-order')
  for _,text in ipairs({
    'return 2',
    'function start() end; return true',
    'local function private() end',
    'function a(e) end\n\nfunction a(e) end'
  }) do
    local candidate,diagnostic=compiler.compile(text,admission.context(admission.new(),'bad-header',0))
    assert(not candidate and diagnostic.line and diagnostic.column)
  end
  report('malformed-and-unsupported-source-documents')
  root=fresh()
  local plain=[[
local function increment(n) return n+1 end
function start(e)
  if e.name=='start' then
    computer.setState('boots',increment(computer.getState('boots') or 0))
    assert(sample()==1)
    local payload={false,'',3}
    computer.setState('timer',computer.after(2,'sample',payload)); payload[3]=99
    computer.on('peripheral_attach','again')
    computer.log('plain-start')
  else
    e.changed=true
    computer.setState('direct',increment(computer.getState('direct') or 0))
    return false,nil,e
  end
end
function sample(e)
  local n=increment(computer.getState('samples') or 0)
  computer.setState('samples',n)
  if e==nil then computer.setState('immediate',true) else
    assert(e.name=='timer' and e.timer_id==computer.getState('timer'))
    assert(e.payload[1]==false and e.payload[2]=='' and e.payload[3]==3)
    assert(e.computer_id==computer.getID())
    computer.setState('envelope',e)
    e.payload[3]=88
  end
  computer.log('plain-sample-'..tostring(n))
  return n
end
function again(e)
  assert(e.name=='peripheral_attach' and e.payload.value==3)
  local arg={name='ordinary'}
  local a,b,c=start(arg)
  assert(a==false and b==nil and c==arg and arg.changed)
  computer.setState('supplied',e)
end
function monitor_touch(e) error('unregistered event-like export ran') end
function registrations(e)
  local function nested() end
  for _,bad in ipairs({sample,increment,nested,'increment','nested','unknown'}) do
    local ok,problem=pcall(computer.after,1,bad)
    assert(not ok and problem.code=='E_ARGUMENT')
    ok,problem=pcall(computer.every,1,bad)
    assert(not ok and problem.code=='E_ARGUMENT')
    ok,problem=pcall(computer.on,'monitor_touch',bad)
    assert(not ok and problem.code=='E_ARGUMENT')
  end
  computer.setState('registrations_checked',true)
end
]]
  rec=registry.register('computer',body())
  assert(runtime.save(rec.id,plain,0)==1 and rec.active==nil and next(rec.state)==nil)
  plan,e=runtime.validate(rec.id,0); assert(plan,e and e.message)
  assert(plan.handlers.start and plan.handlers.sample and plan.handlers.again and plan.handlers.registrations
    and plan.handlers.monitor_touch and not plan.handlers.increment)
  assert(rec.active==nil and next(rec.state)==nil and #rec.logs==0,'Validate executed source')
  local validated=root.ledger.total
  local run=assert(runtime.activate(rec.id,0,1))
  assert(root.ledger.total>validated and rec.run_generation==1 and #rec.queue==1 and next(rec.state)==nil)
  local keys={source=true,revision=true,api_version=true,compiler_version=true,storage_version=true,handlers=true}
  local fields=0; for k in pairs(rec.active) do assert(keys[k],'active shape expanded'); fields=fields+1 end
  assert(fields==6 and rec.active.source==plain and rec.active.revision==1
    and rec.active.api_version==1 and rec.active.compiler_version==3 and rec.active.storage_version==1)
  assert(not rec.active.handlers.increment and rec.active.handlers.sample==true)
  scheduler.tick(0)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  assert(rec.state.boots==1 and rec.state.samples==1 and rec.state.immediate and #rec.logs==2)
  assert(rec.logs[1].text=='plain-sample-1' and rec.logs[2].text=='plain-start')
  local active,timers,subscriptions=rec.active,rec.timers,rec.subscriptions
  local timer=assert(rec.timers[rec.state.timer]); assert(timer.handler=='sample' and timer.payload[3]==3)
  local spent=root.ledger.total; scheduler.tick(0); assert(root.ledger.total==spent)
  report('plain-save-validate-apply-immediate-call-and-closed-active-shape')
  local payload={payload={value=3},computer_id='forged',run_id='forged',sequence=-1,tick=-1}
  assert(runtime.emit(rec.id,'monitor_touch',{},1) and #rec.queue==0,'exports auto-subscribed')
  assert(runtime.emit(rec.id,'peripheral_attach',payload,1))
  local queued=rec.queue[1].event
  assert(queued~=payload and queued.payload~=payload.payload and queued.computer_id==rec.id
    and queued.run_id==run and queued.tick==1 and queued.sequence>0)
  payload.payload.value=99
  scheduler.tick(1)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  assert(rec.state.direct==1 and rec.state.boots==1 and rec.run_id==run and rec.run_generation==1
    and rec.active==active and rec.timers==timers and rec.subscriptions==subscriptions)
  assert(rec.state.supplied.payload.value==3 and rec.state.supplied.run_id==run)
  -- The run paid compilation on its start callback; later callbacks pay none.
  assert(root.ledger.machines[rec.id].work>0 and root.ledger.machines[rec.id].compile==0)
  report('plain-direct-start-keeps-run-authority-and-copied-event-envelope')
  scheduler.tick(2)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  assert(rec.state.samples==2 and rec.state.envelope.payload[3]==3 and rec.state.envelope.run_id==run
    and rec.state.envelope.scheduled_tick==2 and rec.state.envelope.tick==2 and rec.state.envelope.missed==0)
  assert(rec.timers[rec.state.timer]==nil and rec.logs[#rec.logs].text=='plain-sample-2')
  assert(runtime.enqueue(rec,'registrations',{name='fixture'},3))
  scheduler.tick(3)
  assert(rec.status=='running' and rec.state.registrations_checked,rec.diagnostic and rec.diagnostic.message)
  assert(next(rec.timers)==nil)
  local sub_count=0; for _,sub in pairs(rec.subscriptions) do sub_count=sub_count+1; assert(sub.handler=='again') end
  assert(sub_count==1)
  report('plain-once-timer-and-string-only-private-function-registration-refusal')
  local state,logs,queue=rec.state,rec.logs,rec.queue
  for i,text in ipairs({'function start() sample() end; return 1',
    'function start() end; computer.log("top-level")','function start() sample=1 end'}) do
    local tick=3+i
    runtime.save(rec.id,text,rec.saved_revision)
    local before=root.ledger.total
    local replacement,problem=runtime.activate(rec.id,tick)
    assert(not replacement and problem.code=='E_PROGRAM')
    assert(rec.run_id==run and rec.active==active and rec.state==state and rec.logs==logs
      and rec.queue==queue and rec.timers==timers and rec.subscriptions==subscriptions and rec.status=='running')
    local same=runtime.context(rec,tick); local charged=same.ledger.total
    assert(charged>0 and same.machine.compile>0)
    assert(runtime.context(rec,tick).ledger.total==charged,'failed candidate refreshed credits')
  end
  report('plain-failed-candidate-keeps-active-resources-and-spent-credits')
  runtime.save(rec.id,'local function start() error("private start executed") end\nfunction sample(e) computer.setState("unexpected",true) end',rec.saved_revision)
  local before=runtime.context(rec,7).ledger.total
  assert(runtime.activate(rec.id,7)~=run and root.ledger.total>before)
  assert(not rec.active.handlers.start and rec.active.handlers.sample and #rec.queue==0)
  scheduler.tick(7)
  assert(rec.status=='running' and rec.state.unexpected==nil and rec.state.boots==1 and rec.state.samples==2)
  report('plain-optional-start-does-not-choose-arbitrary-export')
  root=fresh()
  local printing=[[function start()
    print('value',false,nil,3,nil); print(); computer.log('unchanged')
    local ok,e=pcall(print,string.rep('x',16384),'overflow')
    assert(not ok and e.code=='E_LIMIT')
    print('before failure'); error('later failure')
  end]]
  rec=registry.register('computer',body())
  runtime.save(rec.id,printing,0); assert(runtime.validate(rec.id,0))
  assert(#rec.logs==0 and not rec.active)
  assert(runtime.activate(rec.id,0)); scheduler.tick(0)
  assert(rec.status=='faulted' and #rec.logs==5)
  assert(rec.logs[1].text=='value\tfalse\tnil\t3\tnil' and rec.logs[2].text==''
    and rec.logs[3].text=='unchanged' and rec.logs[4].text=='before failure')
  report('saved-print-exact-tabs-empty-no-partial-and-earlier-output-survives')
  -- Observe the existing retention sink at the exact remaining-credit boundary.
  -- Fatal readback is host-only: poisoned guests cannot execute witnesses.
  do
    local kind='work'
    local function setup()
      local target={logs={},log_bytes=0}
      for i=1,limits.console_entries do runtime.log(target,'old-'..i,0) end
      local context=admission.context(admission.new(),'print-retention',0)
      local guard=environment.new(context,function(g)
        return {computer={log=function(text) runtime.log(target,text,0,g.spend) end}}
      end)
      guard.initialize()
      return target,context,guard,guard.globals.print
    end
    local target,context,guard,fn=setup(); local before=context.machine[kind]
    guard.execute(fn,'new',false,nil); local cost=context.machine[kind]-before
    assert(#target.logs==limits.console_entries and target.logs[1].text=='old-2' and target.logs[#target.logs].text=='new\tfalse\tnil')
    target,context,guard,fn=setup()
    context.ledger.total=admission.host_ceiling(context.ledger,0)-cost
    assert(pcall(guard.execute,fn,'new',false,nil) and target.logs[1].text=='old-2')
    target,context,guard,fn=setup()
    local first,bytes=target.logs[1],target.log_bytes
    context.ledger.total=admission.host_ceiling(context.ledger,0)-cost+1
    assert(not pcall(guard.execute,fn,'new',false,nil) and #target.logs==limits.console_entries and target.logs[1]==first and target.log_bytes==bytes)
    assert(guard.diagnostic({}).code=='E_BUDGET')
  end
  report('saved-print-exact-admission-before-retention-eviction')
  local function output_guard()
    fresh()
    local target=computer('function start() end')
    local context=runtime.context(target,1)
    local guard=environment.new(context,function(g) return runtime.services(target,1,g) end)
    guard.initialize()
    return target,context,guard,guard.globals.computer.log,guard.globals.print
  end
  do
    local target,context,guard,write,print_fn=output_guard()
    local available,snapshot=principal.available,guard.snapshot
    local physical,copies=0,0
    principal.available=function(...) physical=physical+1; return available(...) end
    guard.snapshot=function(...) copies=copies+1; return snapshot(...) end
    local ok,problem=pcall(function()
      assert(table.pack(guard.execute(write,'logged')).n==0)
      assert(table.pack(guard.execute(print_fn,'value',false,nil,3,nil)).n==0)
      assert(table.pack(guard.execute(print_fn)).n==0)
      -- Program output is published when the callback ends.
      assert(#target.logs==0); guard.flush_output()
      assert(#target.logs==3 and target.logs[1].text=='logged'
        and target.logs[2].text=='value\tfalse\tnil\t3\tnil' and target.logs[3].text=='')
      assert(physical==0 and copies==0,'local output repeated physical discovery or Data snapshots')
      expected_error('E_ARGUMENT',function() guard.execute(write) end)
      expected_error('E_ARGUMENT',function() guard.execute(write,'extra',false) end)
      for _,value in ipairs({false,3,{}}) do expected_error('E_ARGUMENT',function() guard.execute(write,value) end) end
      assert(#target.logs==3)
      runtime.retire(target,'stopped')
      expected_error('E_NOT_FOUND',function() guard.execute(write,'retired') end)
      expected_error('E_NOT_FOUND',function() guard.execute(print_fn,'retired') end)
      assert(#target.logs==3,'captured output survived owner retirement')
    end)
    principal.available=available; guard.snapshot=snapshot
    assert(ok,problem)
  end
  report('direct-log-and-print-zero-results-no-rediscovery-or-snapshots-and-retirement')
  do
    local target,context,guard,_,print_fn=output_guard()
    context.ledger.total=admission.host_ceiling(context.ledger,1)-1
    local native=tostring; local conversions=0
    tostring=function(value)
      if type(value)=='number' then conversions=conversions+1 end
      return native(value)
    end
    local ok=pcall(guard.execute,print_fn,3)
    tostring=native
    assert(not ok and conversions==0 and #target.logs==0,'number formatting ran before host admission')
    assert(guard.diagnostic({}).code=='E_BUDGET')
  end
  report('direct-print-number-formatting-refused-before-native-conversion')
  do
    local kind='work'
    local function setup()
      local target,context,guard,fn=output_guard()
      for i=1,limits.console_entries do runtime.log(target,'old-'..i,0) end
      return target,context,guard,fn
    end
    local target,context,guard,fn=setup(); local before=context.machine[kind]
    guard.execute(fn,'new'); local cost=context.machine[kind]-before
    for _,short in ipairs({false,true}) do
      target,context,guard,fn=setup()
      local first,bytes,truncated=target.logs[1],target.log_bytes,target.log_truncated
      context.ledger.total=admission.host_ceiling(context.ledger,1)-cost+(short and 1 or 0)
      local ok=pcall(guard.execute,fn,'new')
      assert(ok~=short,'unexpected direct-log boundary')
      if short then
        assert(target.logs[1]==first and target.log_bytes==bytes and target.log_truncated==truncated
          and #target.logs==limits.console_entries,'refused log changed retained history')
        assert(guard.diagnostic({}).code=='E_BUDGET')
        assert(not pcall(guard.execute,fn,'post-fatal') and target.logs[1]==first)
      else guard.flush_output(); assert(target.logs[1].text=='old-2' and target.logs[#target.logs].text=='new') end
    end
  end
  report('direct-log-host-work-before-entry-publication')
  do
    -- Program print: n+1 before conversion, then one bytes+entry charge (eviction once).
    local function setup()
      local target,context,guard,_,fn=output_guard()
      for i=1,limits.console_entries do runtime.log(target,'old-'..i,0) end
      return target,context,guard,fn
    end
    local target,context,guard,fn=setup(); local before=context.machine.work
    guard.execute(fn,'new',7); local cost=context.machine.work-before
    -- 3 (n+1) + #'new\t7'+1 + 4 + 3*entries.
    assert(cost==3+6+4+3*limits.console_entries,'unexpected print charge '..cost)
    local second=context.machine.work; guard.execute(fn,'again'); local repeat_cost=context.machine.work-second
    assert(repeat_cost==2+6+4,'eviction charged twice in one callback: '..repeat_cost)
    for allowance=0,cost do
      target,context,guard,fn=setup()
      local first,bytes=target.logs[1],target.log_bytes
      context.ledger.total=admission.host_ceiling(context.ledger,1)-allowance
      local ok=pcall(guard.execute,fn,'new',7); guard.flush_output()
      assert(ok==(allowance==cost),'unexpected print boundary at '..allowance)
      if ok then assert(target.logs[#target.logs].text=='new\t7' and target.logs[1].text=='old-2')
      else
        assert(target.logs[1]==first and target.log_bytes==bytes and #target.logs==limits.console_entries,'refused print published')
        assert(guard.diagnostic({}).code=='E_BUDGET')
      end
    end
  end
  report('buffered-print-two-charges-eviction-once-and-refusal-publishes-nothing')
  do
    local old_entries,old_bytes=limits.console_entries,limits.console_bytes
    limits.console_entries=8; limits.console_bytes=16
    local ok,problem=pcall(function()
      local function seeded()
        local logs={}; for i=1,8 do logs[i]={text=tostring(i)..'.',tick=i} end
        return {logs=logs,log_bytes=16}
      end
      local target=seeded(); local survivor=target.logs[6]
      local paid=0; runtime.log(target,'1234567890',9,function(n) paid=paid+n end)
      assert(#target.logs==4 and target.logs[1]==survivor and target.logs[1].tick==6
        and target.logs[4].text=='1234567890' and target.log_bytes==16 and target.log_truncated)
      assert(paid<=3*8+4,'retention reservation is not linear')
      for _,short in ipairs({false,true}) do
        target=seeded(); local first=target.logs[1]; local room=paid-(short and 1 or 0)
        local accepted=pcall(runtime.log,target,'1234567890',9,function(n) assert(n<=room); room=room-n end)
        assert(accepted~=short)
        if short then assert(target.logs[1]==first and #target.logs==8 and target.log_bytes==16 and not target.log_truncated) end
      end
      target=seeded(); local actual=target.logs; local writes=0
      target.logs=setmetatable({},{__len=function() return #actual end,__index=actual,
        __newindex=function(_,k,v) writes=writes+1; actual[k]=v end})
      runtime.log(target,'1234567890',9)
      assert(writes<=9 and actual[1].tick==6 and #actual==4,'log eviction moved an entry more than once')
      target={logs={},log_bytes=0}
      for i=1,9 do runtime.log(target,'',i) end
      assert(#target.logs==8 and target.logs[1].tick==2 and target.log_bytes==0 and target.log_truncated)
      local first=target.logs[1]
      expected_error('E_LIMIT',function() runtime.log(target,string.rep('x',17),10) end)
      assert(target.logs[1]==first and target.log_bytes==0 and target.log_truncated)
      limits.console_entries=2
      runtime.log(target,'fit',11)
      assert(#target.logs==2 and target.logs[1].tick==9 and target.logs[2].text=='fit' and target.log_bytes==3)
    end)
    limits.console_entries=old_entries; limits.console_bytes=old_bytes
    assert(ok,problem)
  end
  report('linear-log-prefix-compaction-byte-entry-pressure-and-refusal-atomicity')
  fresh(); rec=computer('function start() local output=print; pcall(computer.stop); output("unsafe") end')
  scheduler.tick(0)
  assert(rec.status=='stopped' and #rec.logs==0)
  report('captured-output-cannot-follow-protected-stop')
  -- Buffered program output: call order, publication before stop/fault entries,
  -- and the same retained Console as immediate appends under entry and byte pressure.
  fresh(); rec=computer('function start() print("a"); computer.log("b"); print("c",1); computer.stop() end')
  scheduler.tick(0)
  assert(rec.status=='stopped' and #rec.logs==3 and rec.logs[1].text=='a' and rec.logs[2].text=='b'
    and rec.logs[3].text=='c\t1' and rec.logs[3].tick==0)
  fresh(); rec=computer('function start() print("x"); computer.log("y"); error("boom") end')
  scheduler.tick(0)
  assert(rec.status=='faulted' and #rec.logs==3 and rec.logs[1].text=='x' and rec.logs[2].text=='y'
    and rec.logs[3].text:find('boom',1,true),'buffered output did not precede the fault entry')
  do
    local old_entries,old_bytes=limits.console_entries,limits.console_bytes
    local ok,problem=pcall(function()
      for _,case in ipairs({
        {entries=4,bytes=16,retained={'1234'},writes={'1234567890','1234567890'}},
        {entries=4,bytes=64,retained={'r1','r2','r3','r4'},writes={'a','b'}},
        {entries=4,bytes=64,retained={'r1'},writes={'a','b','c','d','e','f'}},
        {entries=8,bytes=16,retained={'12345678'},writes={'','abc','defgh'}},
        {entries=8,bytes=64,retained={},writes={}},
      }) do
        limits.console_entries,limits.console_bytes=case.entries,case.bytes
        local target,_,guard,write,print_fn=output_guard()
        local reference={logs={},log_bytes=0}
        for i,text in ipairs(case.retained) do runtime.log(target,text,0); runtime.log(reference,text,0) end
        for i,text in ipairs(case.writes) do
          guard.execute(i%2==0 and write or print_fn,text); runtime.log(reference,text,1)
        end
        guard.flush_output()
        assert(#target.logs==#reference.logs and target.log_bytes==reference.log_bytes
          and (target.log_truncated or false)==(reference.log_truncated or false),'batched Console differs from immediate appends')
        for i,entry in ipairs(reference.logs) do
          assert(target.logs[i].text==entry.text and target.logs[i].tick==entry.tick,'batched Console entry differs')
        end
      end
      -- Deterministic sweep: random retained history, writes and limits.
      local target,_,guard,write,print_fn=output_guard(); local seed=7
      local function rand(k) seed=(seed*1103515245+12345)%2147483648; return seed%k end
      for _=1,300 do
        limits.console_entries,limits.console_bytes=1+rand(6),8+rand(17)
        target.logs,target.log_bytes,target.log_truncated={},0,nil
        local reference={logs={},log_bytes=0}
        for _=1,rand(7) do local text=string.rep('r',rand(9)); runtime.log(target,text,0); runtime.log(reference,text,0) end
        for i=1,rand(9) do
          local text=string.rep('w',rand(9))
          guard.execute(i%2==0 and write or print_fn,text); runtime.log(reference,text,1)
        end
        guard.flush_output()
        assert(#target.logs==#reference.logs and target.log_bytes==reference.log_bytes
          and (target.log_truncated or false)==(reference.log_truncated or false),'swept batch differs from immediate appends')
        for i,entry in ipairs(reference.logs) do
          assert(target.logs[i].text==entry.text and target.logs[i].tick==entry.tick,'swept batch entry differs')
        end
      end
      -- A direct host entry during a callback keeps the buffered entries ahead of it.
      limits.console_entries,limits.console_bytes=old_entries,old_bytes
      local target,_,guard,_,print_fn=output_guard()
      guard.execute(print_fn,'first'); runtime.log(target,'host',1); guard.flush_output()
      assert(#target.logs==2 and target.logs[1].text=='first' and target.logs[2].text=='host')
    end)
    limits.console_entries,limits.console_bytes=old_entries,old_bytes
    assert(ok,problem)
  end
  report('buffered-program-output-order-stop-fault-and-immediate-append-equivalence')
  for _,name in ipairs({'xpcall','unpack','_VERSION'}) do
    root=fresh(); rec=computer('function start() computer.setState("kept",true) end')
    scheduler.tick(0)
    local run,active,state=rec.run_id,rec.active,rec.state
    local collision='local function '..name..'() end\nfunction start() computer.setState("unsafe",true) end'
    runtime.save(rec.id,collision,rec.saved_revision)
    local replacement,problem=runtime.activate(rec.id,1)
    assert(not replacement and problem.code=='E_PROGRAM' and rec.run_id==run and rec.active==active and rec.state==state)
    -- Old representation only, never a retained executable cache.
    active.source=collision
    assert(runtime.enqueue(rec,'start',{name='fixture'},2))
    scheduler.tick(2)
    assert(rec.status=='faulted' and rec.diagnostic.code=='E_PROGRAM' and rec.diagnostic.message:find(name,1,true))
    assert(rec.active==active and active.source==collision and rec.saved_source==collision and rec.state==state and state.kept and not state.unsafe)
    assert(active.api_version==1 and active.compiler_version==3 and active.storage_version==1)
  end
  report('new-reserved-active-source-reconstruction-retains-source-state-and-ABI')
  log('TC_CONTRACT_TOTAL '..total)
  return total
end
return M
