-- Native cold proof of the private lifetime ledger, not universal sandbox quota.
local memory=require('scripts.runtime.memory')
local ownership=require('scripts.runtime.ownership')
local compiler=require('scripts.runtime.compiler')
local errors=require('scripts.runtime.errors')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local function graph()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local live={value='kept'}; live.self=live
  local dead={}; dead.self=dead
  local tuple={n=1,'kept'}
  local checkpoint={memory_owner=owner.id,frame={locals={live,live},slots={},tuples={tuple}},result=tuple,
    owned={[live]={keys={'self','value'}},[dead]={keys={'self'}}},owned_order={live,dead},
    symbols={},symbols_order={},intern={},bindings={},bindings_order={}}
  for _,item in ipairs({{live,192+48*2},{dead,192+48},{'kept',#'kept'+32},{'orphan',#'orphan'+32},{tuple,64+16}}) do
    memory.acquire(owner,item[1],item[2])
  end
  memory.configure(account,1)
  ownership.begin(checkpoint,{locals=2,slots=1})
  return {checkpoint=checkpoint,owner=owner,live=live,dead=dead,tuple=tuple,actions=0}
end
local function refusal(fn,account,requested)
  local used,reserved=account.used,account.reserved
  local ok,problem=pcall(fn)
  assert(not ok and errors.resource_diagnostic(problem),'untrusted/non-resource refusal')
  assert(problem.code=='E_CAPACITY' and problem.recoverable and problem.setting=='tc-runtime-memory-bytes')
  assert(problem.used==used+reserved and problem.requested==requested and problem.limit==account.limit)
  assert(account.used==used and account.reserved==reserved,'refusal mutated the lifetime ledger')
end
function M.run()
  local account=memory.new(1000000,256)
  local baseline=account.used
  local program,shell=memory.owner(account),memory.owner(account)
  local cyclic={}; cyclic.self=cyclic
  local text=string.rep('x',100)
  memory.acquire(program,cyclic,240); memory.acquire(program,text,#text+32)
  local first=account.used
  memory.acquire(program,cyclic,240); memory.acquire(program,text,#text+32)
  assert(account.used==first and program.count==2,'same-owner aliases were charged twice')
  memory.acquire(shell,cyclic,240); memory.acquire(shell,text,#text+32)
  local shared=account.used
  assert(shared-first==256,'shared payload was charged twice instead of ownership links')
  memory.configure(account,shared+15)
  memory.reserve(program,8)
  refusal(function() memory.reserve(shell,8) end,account,8)
  assert(program.reserved==8 and shell.reserved==0,'lanes obtained independent allowances')
  memory.unreserve(program)
  refusal(function() memory.resize(program,cyclic,256) end,account,16)
  assert(account.values[cyclic].bytes==240)
  memory.configure(account,account.used+16)
  memory.reserve(program,16)
  local charged=account.used+account.reserved
  memory.resize(program,cyclic,256)
  assert(account.used+account.reserved==charged and program.reserved==0,'reserved storage was charged twice')
  memory.configure(account,1)
  assert(account.used>account.limit and account.values[cyclic].bytes==256,'decrease destroyed accepted data')
  memory.resize(program,cyclic,240)
  assert(account.used==shared,'non-growing recovery failed while over limit')
  memory.release(program,cyclic); memory.release(program,text)
  assert(account.values[cyclic] and account.values[text],'releasing one lane freed another lane payload')
  assert(not memory.release(program,cyclic),'double release succeeded')
  local marker={}
  local ran,problem=pcall(memory.close,program,function() error(marker,0) end)
  assert(not ran and problem==marker and not program.closing,'unpaid close changed owner state')
  memory.close(program,function() end); memory.close(shell,function() end)
  assert(account.used==baseline and account.reserved==0 and next(account.values)==nil and next(account.owners)==nil)
  memory.configure(account,1000000); program=memory.owner(account)
  local a,b,c={},{},{}
  for _,value in ipairs({a,b,c}) do memory.acquire(program,value,192) end
  memory.release(program,b)
  assert(program.head.value==a and program.head.next.value==c and program.tail.previous==program.head)
  memory.acquire(program,b,192)
  memory.release(program,c); memory.release(program,a); memory.release(program,b)
  assert(program.head==nil and program.tail==nil and program.count==0 and next(program.values)==nil)
  memory.close(program,function() end)
  assert(account.used==baseline,'middle/head/tail reclamation retained tombstones')
  log('TC_CONTRACT memory-shared-lanes-alias-cycle-peaks-decrease-and-release')
  local reference=graph()
  ownership.advance(reference.checkpoint,function(n) reference.actions=reference.actions+n end,reference.owner)
  local heap=reference.owner
  assert(heap.count==3 and heap.values[reference.live] and heap.values['kept'] and heap.values[reference.tuple])
  assert(not heap.values[reference.dead] and not heap.values['orphan'],'collector retained unreachable lifetime charges')
  local required=reference.actions
  reference.checkpoint.frame.locals={}; reference.checkpoint.frame.tuples={}; reference.checkpoint.result=nil
  ownership.begin(reference.checkpoint,{locals=0,slots=0}); ownership.advance(reference.checkpoint,function() end,reference.owner)
  assert(heap.count==0 and next(heap.account.values)==nil,'dead roots retained ledger payloads')
  memory.close(heap,function() end)
  local sweep=graph(); sweep.required=required
  log('TC_CONTRACT memory-ledger-follows-actual-ownership-roots-and-tuples')
  local account_binding=memory.new(1000000,256)
  local bound,other=memory.owner(account_binding),memory.owner(account_binding)
  local ledger=admission.new(); local ctx=admission.context(ledger,'memory-binding',0); ctx.memory_owner=bound
  local plan,diagnostic=compiler.compile('function start() local n=0; while n<300000 do n=n+1 end end',ctx)
  assert(plan,diagnostic and diagnostic.message)
  local checkpoint={}
  local ran,problem,control=compiler.run(plan,'start',{}, {},ctx,checkpoint)
  assert(not ran and control=='wait' and checkpoint.memory_owner==bound.id,problem and problem.message)
  local stack,seen={checkpoint},{}
  while #stack>0 do
    local value=table.remove(stack)
    assert(value~=bound and value~=account_binding,'checkpoint captured mutable cross-lane accounting')
    if not seen[value] then
      seen[value]=true
      for key,child in pairs(value) do
        if type(key)=='table' then stack[#stack+1]=key end
        if type(child)=='table' then stack[#stack+1]=child end
      end
    end
  end
  local frame,pc=checkpoint.frame,checkpoint.frame.pc
  ctx=admission.context(ledger,'memory-binding',1); ctx.memory_owner=other
  ran,problem=compiler.run(plan,'start',{}, {},ctx,checkpoint)
  assert(not ran and problem.code=='E_UNSUPPORTED' and checkpoint.frame==frame and frame.pc==pc)
  ctx=admission.context(ledger,'memory-binding',2)
  ran,problem=compiler.run(plan,'start',{}, {},ctx,checkpoint)
  assert(not ran and problem.code=='E_UNSUPPORTED' and frame.pc==pc,'missing memory owner silently rebound a checkpoint')
  for tick=3,100 do
    ctx=admission.context(ledger,'memory-binding',tick); ctx.memory_owner=bound
    ran,problem,control=compiler.run(plan,'start',{}, {},ctx,checkpoint)
    assert(ran or control=='wait',problem and problem.message)
    if ran then break end
  end
  assert(ran,'bound owner did not resume its continuation')
  memory.close(bound,function() end); memory.close(other,function() end)
  ctx=admission.context(ledger,'memory-binding',101); ctx.memory_owner=bound
  ran,problem=compiler.run(plan,'start',{}, {},ctx,{})
  assert(not ran and problem.code=='E_UNSUPPORTED','closed owner started a new continuation')
  local closing=memory.owner(account_binding); local credit=1; local stop={}
  assert(not pcall(memory.close,closing,function(n) if credit==0 then error(stop,0) end; credit=credit-n end))
  assert(closing.closing and not closing.closed)
  ctx=admission.context(ledger,'memory-binding',102); ctx.memory_owner=closing
  ran,problem=compiler.run(plan,'start',{}, {},ctx,{})
  assert(not ran and problem.code=='E_UNSUPPORTED','closing owner started a continuation')
  memory.close(closing,function() end)
  log('TC_CONTRACT continuation-retains-owner-id-not-shared-account-graph')

  account=memory.new(1000000,256); program=memory.owner(account); shell=memory.owner(account)
  for i=1,17 do memory.acquire(program,{value=i},192) end
  local survivor={value='other lane'}; memory.acquire(shell,survivor,192)
  memory.reserve(program,64)
  memory.configure(account,1)
  local growth=memory.new(4096,256)
  storage.tc_memory_fixture={phase='growing',account=account,program=program,shell=shell,survivor=survivor,
    ledger=admission.new(),actions=0,required=program.count+2,initial_count=program.count,growth=growth,growth_base=growth.used,
    growth_owner=memory.owner(growth),accepted=0,sweep=sweep}
end
function M.on_load()
  local f=storage.tc_memory_fixture
  if f.phase=='frozen' then
    assert(f.account.used==f.used and f.account.reserved==f.reserved and f.program.head==f.head)
    assert(f.ledger.total==f.spent and f.actions==2 and f.program.closing and not f.program.closed)
    assert(f.sweep.checkpoint.collection.phase=='memory' and f.sweep.checkpoint.collection.memory_cursor==f.sweep.cursor)
    assert(f.sweep.owner.account.used==f.sweep.used and f.sweep.actions==f.sweep.frozen_actions)
    loaded=true; log('TC_MEMORY_ON_LOAD_UNCHANGED')
  end
end
local function step(f,tick,credits)
  local ctx=admission.context(f.ledger,'memory-cleanup',tick)
  if credits then assert(admission.reserve(ctx,'work',limits.callback_work-credits)) end
  local guard=sandbox.new(ctx,{})
  local ok,problem=pcall(memory.close,f.program,function(n)
    guard.spend(n); f.actions=f.actions+n
  end)
  assert(ok or guard.work_suspended(),problem and type(problem)=='table' and problem.message or tostring(problem))
  return ok
end
local function step_gc(f,tick,freeze)
  local sweep=f.sweep; local checkpoint=sweep.checkpoint
  local ctx=admission.context(f.ledger,'memory-gc',tick); local guard=sandbox.new(ctx,{})
  local ok,problem=pcall(ownership.advance,checkpoint,function(n)
    guard.spend(n); sweep.actions=sweep.actions+n
    if freeze and checkpoint.collection.phase=='memory' and checkpoint.collection.memory_cursor.value==sweep.dead then
      assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
    end
  end,sweep.owner)
  assert(ok or guard.work_suspended(),type(problem)=='table' and problem.message or tostring(problem))
  return ok
end
function M.on_tick(event)
  local f=storage.tc_memory_fixture
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if f.phase=='growing' then
    f.first_tick=f.first_tick or event.tick
    local object={value=event.tick}; local before=f.growth.used
    local ok,problem=pcall(memory.acquire,f.growth_owner,object,192)
    if ok then
      f.accepted=f.accepted+1; assert(f.accepted<100,'cross-tick retention was reset as throughput')
    else
      assert(errors.resource_diagnostic(problem) and f.growth.used==before and not f.growth_owner.values[object])
      assert(f.accepted>1 and event.tick>f.first_tick)
      memory.close(f.growth_owner,function() end)
      assert(f.growth.used==f.growth_base and next(f.growth.values)==nil,'growth owner leaked bookkeeping')
      f.growth=nil; f.growth_owner=nil; f.phase='armed'
      log('TC_CONTRACT memory-cross-tick-growth-refusal-and-complete-teardown')
    end
    return
  end
  if f.phase=='armed' then
    assert(not step(f,event.tick,2) and f.actions==2 and f.program.count==f.initial_count-1)
    assert(not step_gc(f,event.tick,true) and not f.sweep.owner.values[f.sweep.dead])
    f.sweep.cursor=f.sweep.checkpoint.collection.memory_cursor
    f.sweep.used=f.sweep.owner.account.used; f.sweep.frozen_actions=f.sweep.actions
    f.phase='frozen'; f.tick=event.tick; f.head=f.program.head; f.used=f.account.used
    f.reserved=f.account.reserved; f.spent=f.ledger.total
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  else
    if loaded then
      assert(not step(f,f.tick) and f.actions==2 and f.account.used==f.used and f.program.head==f.head,
        'same-tick cold retry renewed cleanup credits')
      assert(not step_gc(f,f.tick) and f.sweep.actions==f.sweep.frozen_actions
        and f.sweep.checkpoint.collection.memory_cursor==f.sweep.cursor,'same-tick retry advanced the memory sweep')
      loaded=false
    end
    assert(step(f,event.tick) and f.actions==f.required and f.program.closed)
    assert(step_gc(f,event.tick) and f.sweep.actions==f.sweep.required and f.sweep.owner.count==3)
    assert(f.account.reserved==0 and f.account.values[f.survivor] and f.shell.count==1,
      'closing one lane released the other lane or lost reservations')
    memory.close(f.shell,function() end)
    memory.close(f.sweep.owner,function() end)
    assert(next(f.account.owners)==nil and next(f.account.values)==nil)
    f.phase='done'; log('TC_CONTRACT memory-owner-teardown-paid-cold-exact-progress'); log('TC_COLD_OK')
  end
end
return M
