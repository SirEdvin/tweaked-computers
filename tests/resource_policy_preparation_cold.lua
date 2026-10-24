-- A paid collector phase must not repeatedly repay full validation before progress.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local function step(f,tick,credits)
  local ctx=admission.context(f.ledger,'preparation',tick); ctx.memory_owner=f.owner
  if credits then assert(admission.reserve(ctx,'work',limits.callback_work-credits)) end
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={started=function() g.prepare_empty_result(); f.started=f.started+1 end,
      finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end}}
  end,ctx,f.checkpoint)
end
function M.run()
  local source=[[function start()
    computer.started()
    local root=table.pack('root'); rawset(root,'self',root); local tail=root
    for i=1,128 do local child=table.pack(i); rawset(tail,'next',child); tail=child end
    local n=0; while n<300 do n=n+1 end
    assert(rawequal(root,rawget(root,'self'))); computer.finished()
  end]]
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'preparation',0); ctx.memory_owner=owner
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  storage.tc_preparation={phase='scan',plan=plan,checkpoint={},ledger=ledger,owner=owner,account=account,
    started=0,finished=0,slices=0}
  game.speed=100
end
local function unchanged(f)
  local c=f.checkpoint; local gc=c.collection
  assert(c.preparation=='collect' and c.validation==nil and gc==f.collection and gc.phase==f.gc_phase
    and gc.head==f.head and gc.cursor==f.cursor and c.frame.pc==f.pc and c.wait_tick==f.tick)
  assert(f.ledger.total==f.spent and f.ledger.machines.preparation.work==f.work
    and f.account.used==f.used and f.account.reserved==f.reserved and f.started==1 and f.finished==0
    and f.root.self==f.root and f.root.next==f.first_child and f.owner.values[f.root])
end
function M.on_load()
  local f=storage.tc_preparation
  if f.phase=='frozen' then unchanged(f); loaded=true; log('TC_PREPARATION_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_preparation
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then
    unchanged(f)
    local ok,e,control=step(f,f.tick)
    assert(not ok and control=='wait',e and e.message); unchanged(f)
    loaded=false; f.phase='resume'
  end
  if f.checkpoint.wait_tick==event.tick then
    local ok,e,control=step(f,event.tick)
    assert(not ok and control=='wait',e and e.message); return
  end
  f.slices=f.slices+1; assert(f.slices<2000,'preparation did not make paid progress')
  local ok,e,control=step(f,event.tick,1024)
  assert(ok or control=='wait',e and e.message)
  if not f.root then
    for value in pairs(f.checkpoint.owned) do if value.self==value then f.root=value; break end end
  end
  if f.phase=='scan' and f.started==1 and f.root and f.root.next and f.checkpoint.preparation=='collect' then
    local c=f.checkpoint; local gc=c.collection
    assert(gc and c.validation==nil and f.finished==0)
    f.collection=gc; f.gc_phase=gc.phase; f.head=gc.head; f.cursor=gc.cursor
    f.pc=c.frame.pc; f.tick=event.tick; f.spent=f.ledger.total; f.work=f.ledger.machines.preparation.work
    f.used=f.account.used; f.reserved=f.account.reserved; f.phase='frozen'
    f.first_child=f.root.next
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if ok then
    assert(f.phase=='resume' and f.started==1 and f.finished==1,'collector cold boundary or effect continuity missing')
    local node,count=f.root.next,0
    while node do count=count+1; assert(node[1]==count and count<=128); node=node.next end
    assert(count==128 and f.root.self==f.root,'cold preparation lost or replayed the accepted graph prefix')
    memory.close(f.owner,function() end)
    assert(next(f.account.values)==nil and next(f.account.owners)==nil and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT paid-collector-phase-cold-progress-under-1024-credits')
    log('TC_COLD_OK')
  end
end
return M
