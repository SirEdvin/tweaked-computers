-- Owned service/library continuations plus paid private-graph collection across cold load.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local ownership=require('scripts.runtime.ownership')
local memory=require('scripts.runtime.memory')
local sandbox=require('scripts.runtime.sandbox')
local M={}; local loaded=false
local function counted(f) return function(n) f.actions=(f.actions or 0)+n end end
local function graph()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local guest,cell,fn,symbol,binding,facade={},{},{},{},{},{}
  guest.self=guest; cell.value=guest
  local pending={result_kind='tuple'}
  local frame={locals={},slots={},tuples={},cells={},pending=pending}
  local c={memory_owner=owner.id,frame=frame,root=frame,exports={},
    owned={[guest]={keys={'self'}},[cell]={keys={'value'}}},owned_order={guest,cell},
    functions={[fn]={cells={cell}}},functions_order={fn},
    symbols={[symbol]='math.abs'},symbols_order={symbol},intern={['math.abs']=symbol},
    bindings={[binding]={name='device',method='read',facade=facade},[facade]={name='device'}},bindings_order={binding,facade}}
  local ctx=admission.context(admission.new(),'graph',0); ctx.memory_owner=owner
  local guard=sandbox.new(ctx,{},nil,c); guard.call_checkpoint(pending)
  memory.acquire_all(owner,{{guest,240},{cell,240},{fn,736},{symbol,304},{binding,736},{facade,736}})
  local job=guard.job('saved',function()
    local j={}; j.self=j; j[fn]=symbol; j[binding]=guest
    return j
  end)
  pending.service_args={n=2,cell,'argument-only'}
  pending.prepared={called={n=2,true,'prepared-only'},values={n=1,'prepared-only'}}
  frame.library={name='table.sort',line=1,column=1,job={alias=job},result={n=1,'library-only'}}
  local dead={}
  memory.acquire_all(owner,{{pending,512},{pending.jobs,240},{pending.service_args,96},
    {pending.prepared,288},{pending.prepared.called,96},{pending.prepared.values,80},
    {frame.library,432},{frame.library.job,240},{frame.library.result,80},
    {'argument-only',45},{'prepared-only',45},{'library-only',44},{dead,192}})
  memory.configure(account,1)
  ownership.begin(c,{locals=1,slots=0})
  return {checkpoint=c,owner=owner,account=account,job=job,guest=guest,cell=cell,fn=fn,symbol=symbol,
    binding=binding,facade=facade,dead=dead,actions=0}
end
local function live(f)
  local c,o=f.checkpoint,f.owner
  for _,v in ipairs({f.job,f.guest,f.cell,f.fn,f.symbol,f.binding,f.facade,c.frame.pending,
    c.frame.pending.jobs,c.frame.pending.service_args,c.frame.pending.prepared,c.frame.pending.prepared.called,
    c.frame.pending.prepared.values,c.frame.library,c.frame.library.job,c.frame.library.result,
    'argument-only','prepared-only','library-only'}) do
    assert(o.values[v],'live private edge lost its ledger record')
  end
  assert(c.owned[f.guest] and c.owned[f.cell] and c.functions[f.fn] and c.symbols[f.symbol]
    and c.bindings[f.binding] and c.bindings[f.facade],'private token edge was treated as an empty record')
  assert(not o.values[f.dead] and f.job.self==f.job and f.job[f.binding]==f.guest)
end
local function clear(f)
  f.checkpoint.frame.pending=nil; f.checkpoint.frame.library=nil
  ownership.begin(f.checkpoint,{locals=1,slots=0})
  ownership.advance(f.checkpoint,counted(f),f.owner)
  assert(f.owner.count==0 and next(f.account.values)==nil,'cancelled private graphs retained charges')
  memory.close(f.owner,counted(f)); assert(f.account.used==512 and f.account.reserved==0)
end
local sources={
[[function start()
  local value={answer=7}
  local ok,a,b,c=pcall(computer.hold,value)
  assert(ok and a==false and b==nil and c==7)
  local n=0; while n<300000 do n=n+1 end
  computer.finished()
end]],
[[function start()
  local values={{x=3},{x=1},{x=2}}
  table.sort(values,function(a,b) computer.hold(a); return a.x<b.x end)
  assert(values[1].x==1 and values[2].x==2 and values[3].x==3)
  local n=0; while n<300000 do n=n+1 end
  computer.finished()
end]]}
local function create(source)
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  return {plan=plan,ledger=admission.new(),checkpoint={},account=account,owner=owner,effects=0,finished=0}
end
local function step(f,tick)
  local ctx=admission.context(f.ledger,'private-owned',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={hold=function(value)
      local j=g.job('owned',function() local j={value=value,phase='prepare'}; j.self=j; return j end)
      assert(f.owner.values[j] and f.owner.values[value],'service entered with an unowned job or argument')
      f.job=j
      local a,b,c=g.prepare_result(false,nil,value.answer or value.x)
      if j.phase=='prepare' then
        g.spend(1); j.phase='commit'; f.ready=true; g.suspend()
      end
      g.spend(1); f.effects=f.effects+1
      return a,b,c
    end,finished=function()
      assert(not f.owner.values[f.job],'completed service job survived later collection')
      if f.library then assert(not f.owner.values[f.library],'completed library job survived collection') end
      g.prepare_empty_result(); f.finished=f.finished+1
    end}}
  end,ctx,f.checkpoint)
end
function M.run()
  local reference=graph()
  ownership.advance(reference.checkpoint,counted(reference),reference.owner); live(reference)
  local required=reference.actions
  clear(reference)
  -- Every shorter allowance must leave the same paid traversal and no early sweep.
  for cut=0,required-1 do
    local f=graph(); local stop={}; local paid=0
    local ok,e=pcall(ownership.advance,f.checkpoint,function(n)
      if paid+n>cut then error(stop,0) end
      paid=paid+n
    end,f.owner)
    assert(not ok and e==stop and paid==cut)
    ownership.advance(f.checkpoint,counted(f),f.owner)
    assert(paid+f.actions==required,'private collection repaid or skipped a step')
    live(f); clear(f)
  end
  for _,damage in ipairs({'native','metatable','tuple','result-kind','jobs'}) do
    local f=graph(); local pending=f.checkpoint.frame.pending
    if damage=='native' then f.job.bad=function() end
    elseif damage=='metatable' then f.job.bad=setmetatable({},{})
    elseif damage=='tuple' then pending.service_args.n=-1
    elseif damage=='result-kind' then pending.result_kind='foreign'
    else pending.jobs=false end
    local used=f.account.used
    local ok,e=pcall(ownership.advance,f.checkpoint,counted(f),f.owner)
    assert(not ok and type(e)=='table' and e.code=='E_UNSUPPORTED')
    assert(f.account.used==used and f.owner.values[f.dead],'malformed graph was swept or changed accounting')
    memory.close(f.owner,counted(f))
  end
  log('TC_CONTRACT private-graph-token-aliases-paid-prefixes-validation-lowering-and-reclamation')
  local cursor=graph(); local stop={}; local paid=0
  local ok,e=pcall(ownership.advance,cursor.checkpoint,function(n)
    if cursor.checkpoint.collection.records[cursor.job] then error(stop,0) end
    paid=paid+n
  end,cursor.owner)
  assert(not ok and e==stop); cursor.actions=paid; cursor.required=required
  storage.tc_private_ownership={phase='arm',cursor=cursor,cases={create(sources[1]),create(sources[2])}}
end
local function unchanged(state)
  for _,f in ipairs(state.cases) do
    assert(f.checkpoint.frame==f.frame and f.ledger.total==f.spent and f.account.used==f.used
      and f.owner.values[f.job] and f.job.phase=='commit' and f.effects==0 and f.finished==0)
    local p=f.frame.pending
    assert(p.jobs.owned==f.job and p.prepared.values.n==3 and p.service_args and p.result_kind=='tuple')
  end
  assert(state.cursor.checkpoint.collection.head==state.head and state.cursor.account.used==state.used)
end
function M.on_load()
  local state=storage.tc_private_ownership
  if state.phase=='frozen' then unchanged(state); loaded=true; log('TC_PRIVATE_OWNERSHIP_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local state=storage.tc_private_ownership
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  if loaded then
    unchanged(state)
    local f=state.cursor
    ownership.advance(f.checkpoint,counted(f),f.owner)
    assert(f.actions==f.required,'cold private cursor repaid a prefix'); live(f); clear(f)
    loaded=false; state.phase='resume'
  end
  local ready,done=true,true
  for _,f in ipairs(state.cases) do
    if not f.done and not (state.phase=='arm' and f.ready) then
      local ok,e,control=step(f,event.tick)
      assert(ok or control=='wait',e and e.message)
      if ok then assert(f.finished==1); f.done=true end
    end
    ready=ready and f.ready; done=done and f.done
  end
  if state.phase=='arm' and ready then
    for _,f in ipairs(state.cases) do
      f.frame=f.checkpoint.frame; f.spent=f.ledger.total; f.used=f.account.used
      local frame=f.frame
      while frame do
        if frame.library then f.library=frame.library.job; assert(f.owner.values[f.library]) end
        frame=frame.parent
      end
    end
    assert(state.cases[2].library,'comparator did not suspend inside a library frame')
    state.head=state.cursor.checkpoint.collection.head; state.used=state.cursor.account.used
    state.phase='frozen'; state.tick=event.tick; unchanged(state)
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if state.phase=='resume' then assert(event.tick-state.tick<300,'owned private continuation deadline') end
  if done then
    assert(state.cases[1].effects==1 and state.cases[2].effects>1)
    for _,f in ipairs(state.cases) do
      memory.close(f.owner,counted(f))
      assert(f.account.used==512 and f.account.reserved==0 and next(f.account.values)==nil)
    end
    state.phase='done'; log('TC_CONTRACT owned-private-service-library-cold-completion-and-release'); log('TC_COLD_OK')
  end
end
return M
