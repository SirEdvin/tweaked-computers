-- Durable source functions/cells/protection, not native closure reconstruction.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local body=[[
  local value={n=0}; local alias=value
  value[math.floor]=math; value[math]=math.floor; value.round=math.floor
  value[true],value[false]=math,math.floor
  local x=4
  local function change(a,...)
    local b,c,d=...
    assert(a==false and b==nil and c==7 and d==nil and select('#',...)==3)
    x=x+1
    computer.prefix()
    local function inner()
      local n=0
      while n<300000 do n=n+1 end
      alias.n=n
      return false,nil,value
    end
    local result=table.pack(inner())
    local restored=table.pack(...); local single=table.pack((...)); local expanded={false,...}
    assert(restored.n==3 and restored[1]==nil and restored[2]==7 and restored[3]==nil)
    assert(single.n==1 and single[1]==nil and expanded[1]==false and expanded[3]==7)
    return table.unpack(result,1,result.n)
  end
  local ok,a,b,c=pcall(change,false,nil,7,nil)
  assert(ok and a==false and b==nil and rawequal(c,alias) and alias.n==300000 and x==5)
  assert(value[math.floor]==math and value[math](4.5)==4 and value.round(2.5)==2)
  assert(value[true]==math and value[false](7.5)==7)
  local function pass(...) return ... end
  local passed=table.pack(pass(false,nil,3,nil))
  assert(passed.n==4 and passed[1]==false and passed[2]==nil and passed[3]==3 and passed[4]==nil)
  local function factorial(n) if n==0 then return 1 end; return n*factorial(n-1) end
  assert(factorial(6)==720)
  local fs={}
  for i=1,3 do fs[i]=function() return i end end
  assert(fs[1]()==1 and fs[2]()==2 and fs[3]()==3)
  for _,i in ipairs({4,5,6}) do fs[i]=function() return i end end
  assert(fs[4]()==4 and fs[5]()==5 and fs[6]()==6)
  local err={message='owned'}
  local caught,e=pcall(function() error(err) end)
  assert(caught==false and rawequal(e,err))
  local outer,inner=pcall(function() return pcall(function() error(false) end) end)
  assert(outer and inner==false)
  local ok,a,b,c=pcall(function() return computer.tuple() end)
  assert(ok and a==false and b==nil and c==9)
  assert(select('#',pcall(function() end))==1)
  local safe=pcall(function() computer.writeData({fn=change}) end)
  assert(not safe)
  computer.finished()
]]
local protected_body=[[
  local problem={value=false}; local attempts=0
  local protected,ok,result=pcall(xpcall,function() error(problem) end,function(p)
    attempts=attempts+1
    if attempts==1 then assert(rawequal(p,problem)); error('second') end
    assert(attempts==2 and p=='second'); computer.prefix()
    local function wait()
      local n=0; while n<300000 do n=n+1 end
      return false,7
    end
    return wait()
  end)
  assert(protected and ok==false and result==false and attempts==2)
  local values=table.pack(xpcall(function(a,b,c,d) return a,b,c,d end,error,false,nil,3,nil))
  assert(values.n==5 and values[1] and values[2]==false and values[3]==nil and values[4]==3 and values[5]==nil)
  assert(select('#',xpcall(function() end,error))==1)
  values=table.pack(xpcall(function() error(nil) end,function(p) assert(p==nil) end))
  assert(values.n==2 and values[1]==false and values[2]==nil)
  ok,result=xpcall(function() error(computer) end,function(p) assert(p==computer); return p end)
  assert(not ok and result==computer)
  ok,result=xpcall(function() error(math.floor) end,function(p) assert(p==math.floor); return p end)
  assert(not ok and result==math.floor)
  local function message(p) return p end
  ok,result=xpcall(function() error(message) end,message)
  assert(not ok and result==message)
  assert(not pcall(xpcall,false,message) and not pcall(xpcall,message,nil))
  ok,result=xpcall(error,tostring,'native failure')
  assert(not ok and result=='native failure')
  local outer,inner,value=pcall(xpcall,function() return 9 end,error)
  assert(outer and inner and value==9)
  outer,inner,value=xpcall(pcall,error,function() error(false) end)
  assert(outer and inner==false and value==false)
  values=table.pack(pcall(pcall,pcall,math.floor,9.5))
  assert(values.n==4 and values[1] and values[2] and values[3] and values[4]==9)
  local attempts=0
  outer,ok,result=pcall(xpcall,function() error('first') end,function()
    attempts=attempts+1; error('again')
  end)
  assert(outer and not ok and attempts==32 and result.recoverable and result.resource=='call_depth')
  assert(result.used==attempts and result.limit==attempts and result.setting=='tc-host-stack-depth')
  ok,result=xpcall(error,error,'native re-entry')
  assert(not ok and result.recoverable and result.resource=='call_depth')
  computer.finished()
]]
local function create(source,expect_bridge)
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  local account=memory.new(8000000,256)
  return {plan=plan,ledger=admission.new(),checkpoint={},account=account,owner=memory.owner(account),prefix=0,finished=0,writes=0,expect_bridge=expect_bridge}
end
local function step(f,tick)
  local ctx=admission.context(f.ledger,'functions',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={prefix=function() g.prepare_empty_result(); f.prefix=f.prefix+1 end,
      tuple=function() return false,nil,9 end,
      writeData=function() f.writes=f.writes+1 end,
      finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end}}
  end,ctx,f.checkpoint)
end
function M.run()
  storage.tc_functions={phase='arm',cases={
    create('function start() '..body..' end'),
    create('return {api_version=1,handlers={start=function() '..body..' end}}'),
    create('function start() '..protected_body..' end',true),
    create('return {api_version=1,handlers={start=function() '..protected_body..' end}}',true),
  }}
end
function M.on_load()
  local state=storage.tc_functions
  if state.phase=='frozen' then
    for _,f in ipairs(state.cases) do
      assert(f.checkpoint.frame==f.frame and f.frame.pc==f.pc and f.frame.parent and f.frame.parent.parent)
      assert(f.ledger.total==f.spent and f.prefix==1 and f.finished==0)
      if f.expect_bridge then assert(f.handler_pending.handling and f.handler_pending.handler_depth==2) end
    end
    loaded=true; log('TC_FUNCTIONS_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local state=storage.tc_functions
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; state.phase='resume' end
  local done=true
  for _,f in ipairs(state.cases) do
    if not f.done then
      local ok,e,control=step(f,event.tick)
      assert(ok or control=='wait',e and (e.message..' at '..tostring(e.line)..':'..tostring(e.column)))
      if ok then assert(f.prefix==1 and f.finished==1 and f.writes==0); f.done=true else done=false end
      if state.phase=='arm' then
        assert(not ok and f.prefix==1 and f.checkpoint.frame.parent and f.checkpoint.frame.parent.parent)
        local live={}; local frame=f.checkpoint.frame; local bridge=false
        while frame do
          live[frame]=true; bridge=bridge or frame.bridge~=nil
          if frame.pending and frame.pending.handling then f.handler_pending=frame.pending end
          frame=frame.parent
        end
        assert(not f.expect_bridge or bridge,'nested protected bridge was not frozen')
        if f.expect_bridge then assert(f.handler_pending and f.handler_pending.handler_depth==2) end
        for value in pairs(f.owner.values) do
          if type(value)=='table' and value.parent and value.locals and value.slots then
            assert(live[value],'unwound frame retained its memory charge')
          end
        end
        f.frame=f.checkpoint.frame; f.pc=f.frame.pc; f.spent=f.ledger.total
      end
    end
  end
  if state.phase=='arm' then
    state.phase='frozen'; state.tick=event.tick; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-state.tick<300,'nested function continuation deadline')
  if done then
    for _,f in ipairs(state.cases) do memory.close(f.owner,function() end); assert(f.account.used==512) end
    state.phase='done'; log('TC_CONTRACT durable-nested-calls-cells-recursion-protection-and-cold'); log('TC_COLD_OK')
  end
end
return M
