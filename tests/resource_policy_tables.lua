-- Original chart prerequisites on the one durable block backend.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local body=[[
  local a={false,computer.tuple()}
  assert(a[1]==false and a[2]==11 and a[3]==nil and a[4]==13)
  local b={tag='old',[1]='first',tag='new',other=(computer.tuple())}
  assert(b.tag=='new' and b.other==11)
  local alias=b
  local i=1
  b[i],i,b.tag=computer.mark(1),2,computer.mark(2)
  assert(i==2 and alias[1]==1 and alias.tag==2)
  b.tag,b.tag=3,4; assert(b.tag==3)
  local total=0
  for _,v in ipairs({2,3,5}) do
    for _,x in pairs({a=v,b=1}) do total=total+x end
  end
  assert(total==13)
  local n=0
  for k,v in pairs({[false]=4,[true]=6}) do
    assert(type(k)=='boolean'); n=n+v
  end
  assert(n==10)
  for _,v in ipairs({false,7}) do if v==7 then break end; assert(v==false) end
  local row=string.rep('x',5)..'/'..string.char(65)..12
  assert(row=='xxxxx/A12')
  local n=0
  for _,v in ipairs({1,2,3}) do
    while n<v*100000 do n=n+1 end
    alias[v]=n
  end
  assert(alias[1]==100000 and alias[2]==200000 and alias[3]==300000)
  computer.finished()
]]
local function services(f,g)
  return {computer={
    tuple=function() return 11,nil,13 end,
    mark=function(v) local result=g.prepare_result(v); f.marks[#f.marks+1]=v; return result end,
    finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end,
  }}
end
local function step(f,tick)
  local ctx=admission.context(f.ledger,'tables',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',nil,function(g) return services(f,g) end,ctx,f.checkpoint)
end
function M.run()
  local ledger,checkpoint=admission.new(),{}
  local plan=assert(compiler.compile('function start() computer.finished() end'))
  local ctx=admission.context(ledger,'compile-tail',0); ctx.machine.compile=limits.compile_work
  local effects=0
  local services={computer={finished=function() effects=effects+1 end}}
  local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
  assert(not ok and not e and control=='wait' and effects==0 and checkpoint.version==nil)
  assert(ctx.machine.compile==limits.compile_work)
  ok,e,control=compiler.run(plan,'start',nil,services,admission.context(ledger,'compile-tail',1),checkpoint)
  assert(ok and effects==1,e and e.message)
  for _,descriptor in ipairs({false,true}) do
    local source=descriptor and 'return {api_version=1,handlers={start=function() '..body..' end}}' or 'function start() '..body..' end'
    local plan,e=compiler.compile(source); assert(plan,e and e.message)
    local account=memory.new(4000000,256)
    local f={plan=plan,ledger=admission.new(),checkpoint={},owner=memory.owner(account),marks={},finished=0}
    for tick=1,300 do
      local ok,problem,control=step(f,tick)
      assert(ok or control=='wait',problem and problem.message)
      if ok then
        assert(tick>1 and f.finished==1 and #f.marks==2 and f.marks[1]==1 and f.marks[2]==2)
        memory.close(f.owner,function() end); assert(account.used==512)
        break
      end
      assert(tick<300,'table prerequisites made no progress')
    end
  end
  local source='function start() local a={}; for _,v in ipairs({1,2,3}) do local n=0; while n<200000 do n=n+1 end; a[v]=n end; assert(a[1]==200000 and a[2]==200000 and a[3]==200000); computer.finished() end'
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  local account=memory.new(4000000,256)
  storage.tc_tables={phase='arm',plan=plan,ledger=admission.new(),checkpoint={},owner=memory.owner(account),marks={},finished=0}
end
function M.on_load()
  local f=storage.tc_tables
  if f.phase=='frozen' then
    assert(f.checkpoint.frame==f.frame and f.checkpoint.frame.pc==f.pc and f.finished==0 and f.ledger.total==f.spent)
    loaded=true; log('TC_TABLES_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_tables
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; f.phase='resume' end
  local ok,problem,control=step(f,event.tick)
  assert(ok or control=='wait',problem and problem.message)
  if f.phase=='arm' then
    assert(not ok and control=='wait' and f.finished==0)
    f.frame=f.checkpoint.frame; f.pc=f.frame.pc; f.spent=f.ledger.total; f.frozen_tick=event.tick
    f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-f.frozen_tick<300,'cold table continuation deadline')
  if ok then
    assert(f.finished==1); f.phase='done'
    log('TC_CONTRACT durable-constructors-indexed-assignment-concat-nested-iteration-cold'); log('TC_COLD_OK')
  end
end
return M
