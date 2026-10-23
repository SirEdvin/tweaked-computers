-- Cold checkpoints for private service jobs and library comparator continuations.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local M={}; local loaded=false
local sources={
[=[function start()
  local ok,a,b,c=pcall(computer.job)
  assert(ok and a==false and b==nil and c==9)
  assert(select('#',computer.job())==3)
  computer.finished()
end]=],
[=[function start()
  local values={8,4,7,1,6,2,5,3}; local alias=values
  local calls=0
  table.sort(values,function(a,b)
    calls=calls+1
    if calls==1 then
      computer.prefix()
      local n=0; while n<300000 do n=n+1 end
    end
    return a<b
  end)
  assert(rawequal(values,alias) and calls>1)
  assert(table.concat(values,',')=='1,2,3,4,5,6,7,8')
  assert(string.format('%s:%04d:%%:%q',false,7,'a\n')=='false:0007:%:"a\\\n"')
  local result=table.pack(table.unpack({false,2,3},1,5))
  assert(result.n==5 and result[1]==false and result[4]==nil and result[5]==nil)
  local mixed={false,2,3}; mixed.tag=mixed
  assert(select('#',table.insert(mixed,2,nil))==0 and mixed[1]==false and mixed[3]==2 and mixed[4]==3)
  assert(table.remove(mixed,1)==false and mixed[1]==nil and mixed[2]==2 and mixed[3]==3)
  assert(mixed.tag==mixed)
  assert(string.char(65,0,66)== 'A\0B')
  assert(string.byte('ABC',-1)==67 and select('#',string.byte('ABC',4))==0)
  assert(string.sub('ABCDE',-3,-1)=='CDE' and string.reverse('abc')=='cba')
  assert(string.lower('ABcd')=='abcd' and string.upper('abCD')=='ABCD')
  assert(string.rep('x',3,':')=='x:x:x' and string.rep('',3,':')=='::')
  local first,last=string.find('aaaab','aab',1,true)
  assert(first==3 and last==5 and string.find('a','b',1,true)==nil)
  local empty={[0]=false}
  assert(select('#',table.remove(empty,0))==1 and empty[0]==nil)
  local untouched={3,2,1}
  local ok=pcall(table.sort,untouched,function() untouched.side=true; error('comparison') end)
  assert(not ok and untouched[1]==3 and untouched[2]==2 and untouched[3]==1 and untouched.side)
  local function recurse(n) if n==0 then return 7 end; return recurse(n-1) end
  assert(recurse(40)==7)
  local attempts=0
  local outer,ok,problem=pcall(xpcall,function() error(false) end,function(e)
    attempts=attempts+1
    if attempts<40 then error(e) end
    return 'caught'
  end)
  assert(outer and not ok and problem=='caught' and attempts==40)
  computer.finished()
end]=],
}
local function create(source)
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  return {plan=plan,ledger=admission.new(),checkpoint={},effects=0,prefix=0,finished=0,starts=0}
end
local function step(f,tick)
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={
      job=function()
        local j=g.job('test',function() return {phase='start',index=0} end)
        if j.phase=='start' then
          g.spend(1); f.starts=f.starts+1; j.phase='work'
        end
        if j.phase=='work' then
          g.spend(1); j.index=j.index+1
          if j.index<3 then g.suspend() end
          j.phase='prepare'
        end
        if j.phase=='prepare' then
          g.prepare_result(false,nil,9); j.phase='commit'; g.suspend()
        end
        local a,b,c=g.prepare_result(false,nil,9)
        g.spend(1); f.effects=f.effects+1
        return a,b,c
      end,
      prefix=function() g.prepare_empty_result(); f.prefix=f.prefix+1 end,
      finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end,
    }}
  end,admission.context(f.ledger,'language',tick),f.checkpoint)
end
function M.run()
  storage.tc_language={phase='arm',cases={create(sources[1]),create(sources[2])}}
end
function M.on_load()
  local state=storage.tc_language
  if state.phase=='frozen' then
    for _,f in ipairs(state.cases) do
      assert(f.ledger.total==f.spent and f.checkpoint.frame==f.frame and f.finished==0)
    end
    loaded=true; log('TC_LANGUAGE_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local state=storage.tc_language
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; state.phase='resume' end
  local done=true
  for _,f in ipairs(state.cases) do
    if not f.done then
      local ok,e,control=step(f,event.tick)
      assert(ok or control=='wait',e and (e.message..' at '..tostring(e.line)..':'..tostring(e.column)))
      if ok then assert(f.finished==1); f.done=true else done=false end
      if state.phase=='arm' then
        assert(not ok); f.spent=f.ledger.total; f.frame=f.checkpoint.frame
      end
    end
  end
  if state.phase=='arm' then
    local pending=state.cases[1].checkpoint.frame.pending
    if not pending or pending.result_kind~='tuple' then return end
    assert(state.cases[1].starts==1 and state.cases[1].effects==0 and state.cases[2].prefix==1)
    assert(pending.prepared and pending.prepared.values.n==3 and pending.jobs.test.phase=='commit')
    state.phase='frozen'; state.tick=event.tick
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-state.tick<300,'language continuation deadline')
  if done then
    assert(state.cases[1].starts==2 and state.cases[1].effects==2 and state.cases[2].prefix==1)
    state.phase='done'; log('TC_CONTRACT durable-private-jobs-library-comparators-and-protection'); log('TC_COLD_OK')
  end
end
return M
