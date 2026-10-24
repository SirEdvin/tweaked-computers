-- Private return-cache capacity belongs to the frame, not only its string members.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local M={}
function M.run()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'tuple-envelope',0); ctx.memory_owner=owner
  local plan,e=compiler.compile('function start() local a,b,c=computer.probe(); assert(a==11 and b==nil and c==13) end',ctx)
  assert(plan,e and e.message)
  local checkpoint,effects,before,frame_before={},0,0,0; local refuse=true
  local function services(g)
    return {computer={probe=function()
      before=account.used; frame_before=owner.values[checkpoint].record.bytes
      if refuse then memory.configure(account,before+63) end
      local a,b,c=g.prepare_result(11,nil,13)
      if not refuse then
        assert(account.used==before+64 and owner.values[checkpoint].record.bytes==frame_before+64,
          'prepared tuple capacity did not enter the frame envelope')
      end
      effects=effects+1; return a,b,c
    end}}
  end
  local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
  assert(not ok and control=='resource' and e.recoverable and effects==0 and account.used==before
    and owner.values[checkpoint].record.bytes==frame_before,
    'prepared tuple envelope did not refuse atomically before effect (effects='..effects..', code='..tostring(e and e.code)..')')
  refuse=false; memory.configure(account,1000000)
  ctx=admission.context(ledger,'tuple-envelope',1); ctx.memory_owner=owner
  ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
  assert(ok and effects==1,e and e.message)
  memory.close(owner,function() end); assert(next(account.values)==nil and account.reserved==0)
  log('TC_CONTRACT prepared-tuple-envelope-one-byte-deficit-refuses-before-effect-and-retries-once')
  for _,damage in ipairs({'entry','control-ledger','capacity-ledger','missing','old-abi'}) do
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,'tuple-invalid',0); ctx.memory_owner=owner
    local plan,e=compiler.compile('function start() while true do end; computer.finished() end',ctx); assert(plan,e and e.message)
    local checkpoint={}; local ok,e,control=compiler.run(plan,'start',nil,{},ctx,checkpoint)
    assert(not ok and control=='wait',e and e.message)
    local key=assert(next(checkpoint.tuple_capacities))
    if damage=='entry' then checkpoint.tuple_capacities[key]=-1
    elseif damage=='control-ledger' then checkpoint.tuple_control=3
    elseif damage=='capacity-ledger' then checkpoint.tuple_capacities[key]=5; checkpoint.tuple_control=6
    elseif damage=='missing' then checkpoint.tuple_capacities[key]=nil
    else checkpoint.version=2 end
    ctx=admission.context(ledger,'tuple-invalid',1); ctx.memory_owner=owner
    ok,e=compiler.run(plan,'start',nil,{},ctx,checkpoint)
    assert(not ok and e.code=='E_UNSUPPORTED','damaged private tuple state executed or was repaired')
    if damage=='entry' then assert(checkpoint.tuple_capacities[key]==-1)
    elseif damage=='control-ledger' then assert(checkpoint.tuple_control==3)
    elseif damage=='capacity-ledger' then assert(checkpoint.tuple_capacities[key]==5 and checkpoint.tuple_control==6)
    elseif damage=='missing' then assert(checkpoint.tuple_capacities[key]==nil)
    else assert(checkpoint.version==2) end
    memory.close(owner,function() end)
  end
  log('TC_CONTRACT malformed-tuple-entry-and-prior-private-ABI-refused-and-retained')

  local body=[[for i=1,2 do
    local a,b,c=computer.probe(); assert(a==11 and b==nil and c==13)
    local n=0; while n<100000 do n=n+1 end
  end; computer.finished()]]
  for _,source in ipairs({'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,'tuple-reuse',0); ctx.memory_owner=owner
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local checkpoint,effects,finished={},0,0
    local function services(g)
      return {computer={probe=function()
        local a,b,c=g.prepare_result(11,nil,13); effects=effects+1; return a,b,c
      end,finished=function() g.prepare_empty_result(); finished=finished+1 end}}
    end
    local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    assert(not ok and control=='wait' and effects==1 and finished==0,e and e.message)
    local used=account.used; memory.configure(account,1)
    for tick=1,100 do
      ctx=admission.context(ledger,'tuple-reuse',tick); ctx.memory_owner=owner
      ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
      assert(ok or control=='wait',e and e.message)
      assert(account.used<=used,'accepted tuple workspace grew after a limit decrease')
      if ok then break end
    end
    assert(ok and effects==2 and finished==1,'accepted tuple capacity was not reused after lowering')
    memory.close(owner,function() end); assert(next(account.values)==nil and account.reserved==0)
  end
  log('TC_CONTRACT nil-containing-tuple-capacity-reused-across-slices-after-one-byte-decrease')

  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'shell-return-envelope',0); ctx.memory_owner=owner
  local source='local n=0; while n<100000 do n=n+1 end; return 11,nil,13'
  local plan,e=compiler.compile(source,ctx,'shell'); assert(plan,e and e.message)
  local values={version=1,root=1,nodes={{kind='table',entries={}}}}
  local output={}; local shell={values=values,output=function(text) output[#output+1]=text end}
  local checkpoint={}
  local ok,e,control=compiler.run(plan,'command',nil,{},ctx,checkpoint,shell)
  assert(not ok and control=='wait' and #output==0,e and e.message)
  local used=account.used; memory.configure(account,used+63)
  local tick=0
  repeat
    tick=tick+1; ctx=admission.context(ledger,'shell-return-envelope',tick); ctx.memory_owner=owner
    ok,e,control=compiler.run(plan,'command',nil,{},ctx,checkpoint,shell)
    assert(tick<100 and (control=='wait' or control=='resource'),e and e.message)
  until control=='resource'
  assert(e.recoverable and account.used==used and #output==0 and checkpoint.result==nil and shell.values==values,
    'unadmitted Console return was printed or committed')
  memory.configure(account,1000000)
  ctx=admission.context(ledger,'shell-return-envelope',tick+1); ctx.memory_owner=owner
  ok,e=compiler.run(plan,'command',nil,{},ctx,checkpoint,shell)
  assert(ok and #output==1 and output[1]:find('11',1,true) and output[1]:find('13',1,true),e and e.message)
  assert(checkpoint.result.n==3 and checkpoint.result[2]==nil and checkpoint.value_graph)
  memory.close(owner,function() end); assert(next(account.values)==nil and account.reserved==0)
  log('TC_CONTRACT Console-return-tuple-refuses-before-print-and-retries-with-nil-arity')
end
return M
