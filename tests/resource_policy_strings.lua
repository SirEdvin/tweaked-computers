-- Retained strings are separate from allocation throughput and tuple workspace.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local M={}
function M.run()
  local body=[[local text=string.rep('z',128); local alias=text
    local n=0; while n<300000 do n=n+1 end
    assert(rawequal(text,alias)); assert('late-literal'~=''); computer.finished()]]
  for _,source in ipairs({'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,'string-lifetime',0); ctx.memory_owner=owner
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local checkpoint,effects={},0
    local function services(g)
      return {computer={finished=function() g.prepare_empty_result(); effects=effects+1 end}}
    end
    local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    assert(not ok and control=='wait',e and e.message)
    local made=string.rep('z',128)
    assert(owner.values[made] and owner.values['late-literal'] and owner.values[''],
      'standalone string retained without admission')
    assert(account.values[made].owners==1,'string aliases obtained separate lifetime payloads')
    local used,spent=account.used,ledger.total; memory.configure(account,1)
    ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    assert(not ok and control=='wait' and account.used==used and ledger.total==spent and effects==0)
    for tick=1,100 do
      ctx=admission.context(ledger,'string-lifetime',tick); ctx.memory_owner=owner
      ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
      assert(ok or control=='wait',e and e.message)
      assert(account.used<=used and owner.values['late-literal'] and owner.values[''])
      if ok then break end
    end
    assert(ok and effects==1,'literal/result aliases did not survive a lowered allowance')
    memory.close(owner,function() end); assert(next(account.values)==nil and account.reserved==0)
  end
  log('TC_CONTRACT source-literals-and-pure-call-string-results-retain-aliases-after-decrease')
  for _,sizes in ipairs({{200,100},{21000,17000}}) do
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,'prepared-string',0); ctx.memory_owner=owner
    local source='function start() local value,tail=computer.probe(); computer.finished() end'
    if sizes[1]>200 then source=[[function start()
      local ok,e=pcall(computer.probe); assert(not ok and e.recoverable)
      computer.retry()
      local value,tail=computer.probe(); assert(#value==21000 and #tail==17000)
      computer.finished()
    end]] end
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local value,tail=string.rep('v',sizes[1]),string.rep('w',sizes[2])
    local effects,finished,before=0,0,0; local refuse=true
    local function services(g)
      return {computer={probe=function()
        before=account.used
        -- Two-value output grows both the output and control capacities by one slot.
        if refuse then memory.configure(account,before+256+#value+32+256+#tail+32+32-1) end
        local accepted,a,b=pcall(g.prepare_result,value,tail)
        if not accepted then
          assert(account.used==before and not owner.values[value] and not owner.values[tail],
            'prepared tuple refused after partial retained publication')
          assert(a.used==before and a.used+a.requested==a.limit+1,
            'prepared tuple was not refused exactly one byte short: '..serpent.line(a))
          error(a,0)
        end
        effects=effects+1; return a,b
      end,retry=function()
        assert(effects==0 and finished==0 and not owner.values[value] and not owner.values[tail])
        g.prepare_empty_result(); memory.configure(account,1000000); refuse=false
      end,finished=function() g.prepare_empty_result(); finished=finished+1 end}}
    end
    local checkpoint={}
    local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    if sizes[1]==200 then
      assert(not ok and control=='resource' and e.recoverable and effects==0 and finished==0
        and account.used==before and not owner.values[value] and not owner.values[tail],
        'string refusal followed its prepared effect or partially charged the tuple')
      refuse=false; memory.configure(account,1000000)
      ctx=admission.context(ledger,'prepared-string',1); ctx.memory_owner=owner
      ok,e=compiler.run(plan,'start',nil,services,ctx,checkpoint); assert(ok,e and e.message)
    else
      for tick=1,16 do
        if ok then break end
        assert(control=='wait',e and e.message)
        ctx=admission.context(ledger,'prepared-string',tick); ctx.memory_owner=owner
        ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
      end
      assert(ok,e and e.message)
    end
    assert(effects==1 and finished==1 and owner.values[value] and owner.values[tail])
    memory.close(owner,function() end); assert(next(account.values)==nil and account.reserved==0)
  end
  log('TC_CONTRACT prepared-string-result-refuses-one-byte-short-before-effect-and-retries-once')
end
return M
