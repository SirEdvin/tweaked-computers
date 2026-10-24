-- Native recipe results and plain Data beyond the retired total-node ceiling.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local data=require('scripts.runtime.data')
local defs=require('scripts.device-definitions')
local sandbox=require('scripts.runtime.sandbox')
local memory=require('scripts.runtime.memory')
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
require('scripts.services.recipe-searcher')
local M={}; local loaded=false
local source=[[function start()
  local searcher=peripheral.find('recipe_searcher','red'); assert(searcher)
  local recipes=searcher.findRecipes('item','tc-rs-large')
  assert(#recipes==1 and #recipes[1].products==600)
  local wide=searcher.findRecipes('item','tc-rs-wide')
  assert(#wide==1 and #wide[1].products==1100)
  for i,p in ipairs(wide[1].products) do
    assert(p.name=='tc-rs-wide' and (i==1 and p.amount==1 or i>1 and p.amount_max==i) and p.probability==i/2000,
      'wide product '..i..' max='..tostring(p.amount_max)..' probability='..tostring(p.probability))
  end
  computer.setState('queried',true)
end
function wide(event)
  local cyclic={}; cyclic.self=cyclic
  for _,bad in ipairs({cyclic,{[2]=true},{fn=function() end}}) do
    local ok,e=pcall(computer.setState,'invalid',bad)
    assert(not ok and e.code=='E_ARGUMENT' and computer.getState('invalid')==nil)
  end
  local deep=true; for i=1,17 do deep={deep} end
  local ok,e=pcall(computer.setState,'invalid',deep)
  assert(not ok and e.code=='E_LIMIT' and computer.getState('invalid')==nil)
  assert(#event.data==600 and event.data[600][7]==true)
  computer.setState('kept',event.data)
  event.data[600][7]=false
  assert(computer.getState('kept')[600][7]==true)
  computer.after(1,'checked',computer.getState('kept'))
end
function checked(event)
  assert(event.payload[600][7]==true)
  computer.setState('timer_checked',true)
end
function width(event)
  local a=event.array
  assert(#a==1100 and a[1100]==true and event.map['k1100']==false)
  a[1101]=false
  a[1102],a[1103]=true,false
  local count=0; for i,v in ipairs(a) do count=count+1 end
  assert(count==1103)
  table.insert(a,true); assert(table.remove(a)==true and #a==1103)
  local x,y,z=table.unpack(a,1101,1103); assert(x==false and y==true and z==false)
  computer.setState('width',a)
  a[1100]=false
  assert(computer.getState('width')[1100]==true)
  table.sort(a,function(x,y) return x==false and y==true end)
  assert(a[1]==false and a[3]==false and a[4]==true and a[1103]==true)
  computer.setState('width_checked',true)
end
function recover()
  local value=computer.getState('kept')
  assert(#value==600 and value[600][7]==true)
  assert(computer.getState('queried') and computer.getState('timer_checked'))
  assert(computer.getState('width_checked') and computer.getState('width')[1103]==false)
  assert(computer.deleteState('width'))
  assert(computer.deleteState('kept'))
  computer.setState('recovered',true)
end]]
local function admission_checks()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new()
  local checkpoint={owned={},owned_order={},symbols={},bindings={},functions={}}
  local pending={}; local input={}
  for i=1,1100 do input[i]=string.rep('x',100) end
  local cursor_resizes=0
  local function guard(tick)
    local ctx=admission.context(ledger,'data-copy-admission',tick); ctx.memory_owner=owner
    local g=sandbox.new(ctx,{},nil,checkpoint); g.call_checkpoint(pending,{})
    local resize=g.job_resize
    g.job_resize=function(...)
      resize(...); cursor_resizes=cursor_resizes+1
    end
    return g
  end
  local used,count=account.used,owner.count
  memory.configure(account,used)
  local g=guard(0); local ok,e=pcall(g.snapshot,input,'copy')
  assert(not ok and errors.resource_diagnostic(e) and not pending.jobs)
  assert(account.used==used and owner.count==count and account.reserved==0 and input[1100]==input[1])
  memory.configure(account,1000000)
  local result,waited
  for tick=1,10 do
    g=guard(tick); ok,result=pcall(g.snapshot,input,'copy')
    if ok then break end
    assert(g.work_suspended(),'copy failed instead of suspending: '..serpent.line(result)); waited=true
    local job=pending.jobs.copy; assert(job.bytes>0 and not job.done and owner.values[job.source])
  end
  assert(ok and waited and #result==1100 and result~=input and result[1100]==input[1])
  assert(cursor_resizes==1,'scalar copies must reuse the admitted traversal frame')
  assert(owner.values[result] and owner.values[input[1]] and account.used<=account.limit)
  g=guard(11)
  local shared={true}; local alias=g.snapshot({left=shared,right=shared},'alias')
  assert(alias.left~=alias.right and alias.left~=shared and alias.left[1]==true and alias.right[1]==true)
  assert(cursor_resizes==4,'each nested copy must admit its traversal frame')
  used=account.used; count=#checkpoint.owned[result].keys
  memory.configure(account,used)
  g=guard(12); ok,e=pcall(g.assignment_one,result,1101,true)
  assert(not ok and errors.resource_diagnostic(e) and result[1101]==nil)
  assert(account.used==used and #checkpoint.owned[result].keys==count and account.reserved==0)
  memory.configure(account,used+48)
  g=guard(13); ok,e=pcall(g.assignment_check,2,{{result,1101},{result,1102}},{true,true})
  assert(not ok and errors.resource_diagnostic(e) and result[1101]==nil and result[1102]==nil)
  assert(account.used==used and #checkpoint.owned[result].keys==count and account.reserved==0)
  memory.configure(account,1000000)
  g=guard(14); g.assignment_one(result,1101,true); result[1101]=true
  assert(#checkpoint.owned[result].keys==count+1 and account.used>used)
  g=guard(15); g.assignment_one(result,1101,nil); result[1101]=nil
  assert(#checkpoint.owned[result].keys==count and account.used==used)
  memory.close(owner,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil and account.reserved==0)
  log('TC_CONTRACT snapshot-cursor-and-wide-growth-memory-refusal-suspension-and-release')
end
function M.run(boundary)
  admission_checks()
  registry.initialize()
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    local rec,e=lifecycle.build(body); assert(rec,serpent.line(e))
    lifecycle.power_entity(rec).energy=1000000; rec.powered=true
    return rec
  end
  local rec=build('computer',0); local searcher=build('recipe_searcher',3)
  assert(lifecycle.connector(rec,'network','red').connect_to(lifecycle.connector(searcher,'network','red'),false))
  assert(runtime.save(rec.id,source,rec.saved_revision)); assert(runtime.activate(rec.id,game.tick))
  local value={}; for i=1,600 do value[i]={true,false,true,false,true,false,true} end
  local copied,stats=data.copy(value,function() end)
  assert(stats.nodes>4096 and stats.bytes<65536 and copied~=value and copied[600]~=value[600])
  local fits,capacity=pcall(data.copy,value,function() end,stats.bytes-1)
  assert(not fits and capacity.code=='E_CAPACITY' and value[600][7]==true)
  for _,invalid in ipairs({{[2]=1},{[1100]=true},{[9007199254740992]=true},{bad=math.huge}}) do
    local ok,e=pcall(data.copy,invalid,function() end); assert(not ok and e.code=='E_ARGUMENT')
  end
  local cyclic={}; cyclic.self=cyclic
  local ok,e=pcall(data.copy,cyclic,function() end); assert(not ok and e.code=='E_ARGUMENT')
  assert(runtime.enqueue(rec,'wide',{name='fixture',data=value},game.tick))
  value[600][7]=false
  local wide={name='fixture',array={},map={}}
  for i=1,1100 do wide.array[i]=true; wide.map['k'..i]=false end
  local copy,wide_stats=data.copy(wide,function() end)
  assert(#copy.array==1100 and copy.map.k1100==false and copy.array~=wide.array and copy.map~=wide.map)
  local fits,problem=pcall(data.copy,wide,function() end,wide_stats.bytes-1)
  assert(not fits and problem.code=='E_CAPACITY')
  storage.tc_data_policy={id=rec.id,searcher=searcher.id,phase='run',boundary=boundary or 'state',started=game.tick,run_id=rec.run_id,width_event=wide}
end
function M.on_load()
  local f=storage.tc_data_policy
  if f.phase=='frozen' then
    local rec=registry.record(f.id)
    assert(rec.state==f.state and rec.state_bytes==f.bytes and rec.state_nodes==f.nodes and rec.run_id==f.run_id)
    if f.boundary=='copy' then
      local job=rec.invocation.checkpoint.frame.pending.jobs['result-data-2']
      assert(job==f.copy_job and not job.done and job.bytes==f.copied_bytes and #job.stack==f.depth)
      assert(#job.source[1].products==1100)
      assert(job.stack[f.depth].key==f.key and rec.invocation.memory_owner.values[job.source])
      assert(not rec.state.queried)
    else assert(rec.state_nodes>4096 and rec.state.kept[600][7]==true and rec.state.width[1103]==false) end
    assert(registry.get().ledger.tick==f.tick and registry.get().ledger.total==f.work)
    loaded=true; log('TC_DATA_POLICY_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_data_policy
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  local rec=registry.record(f.id)
  assert(event.tick-f.started<300,'wide-data fixture deadline: '..serpent.line{
    queried=rec.state.queried,timer_checked=rec.state.timer_checked,handler=rec.invocation and rec.invocation.item.handler,
    pc=rec.invocation and rec.invocation.checkpoint and rec.invocation.checkpoint.frame and rec.invocation.checkpoint.frame.pc})
  for _,id in ipairs({f.id,f.searcher}) do
    local device=registry.record(id); lifecycle.power_entity(device).energy=1000000; device.powered=true
  end
  if loaded then
    loaded=false; f.resumed=true; f.phase=f.boundary=='copy' and 'run' or 'recover'
    if f.phase=='recover' then assert(runtime.enqueue(rec,'recover',{name='fixture'},event.tick)) end
  end
  if f.width_event and rec.state.timer_checked and #rec.queue==0 then
    assert(runtime.enqueue(rec,'width',f.width_event,event.tick))
    f.width_event.array[1100]=false; f.width_event.map.k1100=true; f.width_event=nil
  end
  scheduler.tick(event.tick)
  assert(rec.status=='running' and not rec.diagnostic,serpent.line(rec.diagnostic))
  if f.boundary=='copy' and not f.resumed and rec.invocation then
    local pending=rec.invocation.checkpoint.frame.pending
    local job=pending and pending.jobs and pending.jobs['result-data-2']
    if job and not job.done and job.bytes>0 and job.source[1] and job.source[1].products and #job.source[1].products==1100 then
      assert(rec.invocation.item.handler=='start' and not rec.state.queried)
      f.copy_job=job; f.copied_bytes=job.bytes; f.depth=#job.stack; f.key=job.stack[f.depth].key
      f.state=rec.state; f.bytes=rec.state_bytes; f.nodes=rec.state_nodes; f.phase='frozen'
      f.tick=registry.get().ledger.tick; f.work=registry.get().ledger.total
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
  end
  if rec.invocation or #rec.queue>0 then return end
  if f.phase=='run' then
    if not rec.state.timer_checked or not rec.state.width_checked then return end
    assert(rec.state.queried and rec.state.kept[600][7]==true and rec.state_nodes>4096)
    if f.boundary=='copy' then
      assert(f.resumed,'no cold boundary inside the result copy')
      f.copy_job=nil; f.phase='recover'
      assert(runtime.enqueue(rec,'recover',{name='fixture'},event.tick)); return
    end
    f.state=rec.state; f.bytes=rec.state_bytes; f.nodes=rec.state_nodes; f.phase='frozen'
    f.tick=registry.get().ledger.tick; f.work=registry.get().ledger.total
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  else
    assert(f.phase=='recover' and rec.state.recovered and rec.state.kept==nil and rec.state_nodes<4096)
    assert(runtime.stop(rec.id))
    f.phase='done'; log('TC_CONTRACT large-recipe-state-event-timer-wide-tables-and-cold-data'); log('TC_COLD_OK')
  end
end
return M
