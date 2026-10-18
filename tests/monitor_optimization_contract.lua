-- Fast paths retain the exact admission prefix and immutable model snapshots.
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local sandbox=require('scripts.runtime.sandbox')
local model=require('scripts.monitor-model')
local M={}
local function nop() end
function M.run()
  local traces={{0},{1,0,3,5,0,8},{128,16,512,4,32}}
  local comparisons=0
  for _,trace in ipairs(traces) do
    trace.total=0; for _,cost in ipairs(trace) do trace.total=trace.total+cost end
    for room=0,trace.total+1 do for _,shared in ipairs({false,true}) do
      local function context()
        local ctx=admission.context(admission.new(),'trace',7)
        if shared then ctx.ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick-room
        else ctx.machine.work=limits.callback_work-room; ctx.ledger.total=ctx.machine.work end
        return ctx
      end
      local slow,fast=context(),context(); local expected=true
      for _,cost in ipairs(trace) do if not admission.reserve(slow,'work',cost) then expected=false; break end end
      assert(admission.replay_work(fast,trace)==expected)
      assert(slow.machine.work==fast.machine.work and slow.ledger.total==fast.ledger.total,'work replay changed accepted prefix')
      comparisons=comparisons+1
    end end
  end
  local ctx=admission.context(admission.new(),'poison',8)
  local g=sandbox.new(ctx,{}); ctx.machine.work=limits.callback_work
  assert(not pcall(g.replay_work,{1,total=1}))
  assert(not pcall(g.check),'cached work refusal was catchable')
  assert(ctx.machine.work==limits.callback_work and ctx.ledger.total==0)
  log('TC_WORK_REPLAY_OK comparisons='..comparisons..' exact-prefix shared-ceiling poison')

  local m=model.new(6,6); model.scale(m,6,6,nop,2)
  local blank=model.capture(m,nop); model.acknowledge(m,blank)
  local cells=m.cells
  local work=0; local function charge(n) work=work+n end
  model.calls.blit(m,charge,string.rep(' ',m.width),string.rep('0',m.width),string.rep('f',m.width))
  assert(work==m.width*12+3,'identical row paid for an unnecessary root copy')
  assert(m.cells==cells and m.cells_shared and m.damage_count==0,'identical blit copied the flat cell root')
  model.calls.setCursorPos(m,nop,1,1); work=0; model.calls.clearLine(m,charge)
  assert(work==m.width*7+2,'identical clearLine paid for an unnecessary root copy')
  assert(m.cells==cells and m.damage_count==0,'identical clearLine copied the flat cell root')
  local refused={}
  local function reject_copy() return function(n) if n==m.width*m.height then error(refused,0) end end end
  local revision=m.revision
  local ok,problem=pcall(model.calls.write,m,reject_copy(),string.rep(' ',m.width-1)..'X')
  assert(not ok and problem==refused,'copy reservation was not refused')
  assert(m.cells==cells and m.cells_shared and m.damage_count==0 and m.revision==revision and m.x==1)
  assert(cells[m.width][1]==32,'refused copy changed the frozen image')
  model.calls.setCursorPos(m,nop,m.width,1); model.calls.write(m,nop,'X')
  assert(m.cells~=cells and cells[m.width][1]==32 and m.cells[m.width][1]==88)
  assert(m.damage_count==1 and m.damage[m.width])
  local frozen=model.capture(m,nop)
  model.calls.setCursorPos(m,nop,1,1); revision=m.revision; cells=m.cells
  ok,problem=pcall(model.calls.clearLine,m,reject_copy())
  assert(not ok and problem==refused)
  assert(m.cells==cells and m.cells_shared and m.damage_count==1 and m.revision==revision and m.x==1)
  assert(cells[m.width][1]==88,'refused clearLine changed the frozen image')
  model.calls.clearLine(m,nop)
  assert(frozen.cells[m.width][1]==88 and m.cells[m.width][1]==32)
  log('TC_MODEL_NOOP_OK lazy-copy immutable-first-change refused-copy-atomic')
end
return M
