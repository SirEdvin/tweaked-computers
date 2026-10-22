-- Console's logger override must retain the same pre-effect result admission.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local shell=require('scripts.runtime.shell')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
function M.run()
  registry.initialize()
  local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,0},force='player'})
  local rec=registry.register('computer',body)
  rec.shell={version=1,id=rec.id..'/logger-fixture',pending={},pending_bytes=0}
  assert(shell.evaluate(rec,'x=5',0,1,{}))
  local source='computer.log("marker")'; local marker='Shell #7 output: marker'
  local tick=1
  for _,kind in ipairs({'work','capacity'}) do
    rec.logs={}; rec.log_bytes=0
    for i=1,limits.console_entries do
      local text='retained '..i; rec.logs[i]={text=text,tick=0}; rec.log_bytes=rec.log_bytes+#text
    end
    local first,bytes,committed=rec.logs[1],rec.log_bytes,rec.shell.values
    local ctx=runtime.context(rec,tick); local effects,poison=0,true
    local original=runtime.log
    runtime.log=function(record,text,at,spend,prepare)
      if record==rec and text==marker and kind=='capacity' and prepare then
        local paid=prepare
        prepare=function()
          paid()
          errors.refuse('runtime_memory','tc-runtime-memory-bytes',1,1,1,'injected result storage refusal')
        end
      end
      local result=original(record,text,at,spend,prepare)
      if record==rec and text==marker then
        effects=effects+1
        if kind=='work' and poison then
          poison=false
          assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
        end
      end
      return result
    end
    local passed,problem=pcall(function()
      local checkpoint={}
      local ran,diagnostic,control=shell.evaluate(rec,source,tick,7,checkpoint)
      if kind=='capacity' then
        assert(not ran and diagnostic and diagnostic.code=='E_CAPACITY' and control=='resource')
        assert(effects==0 and rec.logs[1]==first and #rec.logs==limits.console_entries
          and rec.log_bytes==bytes and rec.shell.values==committed,'Console result refusal followed publication/eviction')
      else
        assert(not ran and control=='wait' and effects==1,diagnostic and diagnostic.message)
        tick=tick+1; ctx=runtime.context(rec,tick)
        ran,diagnostic,control=shell.evaluate(rec,source,tick,7,checkpoint)
        assert(ran,diagnostic and diagnostic.message or control)
        assert(effects==1,'Console computer.log repeated after guarded result suspension')
        local count=0; for _,entry in ipairs(rec.logs) do if entry.text==marker then count=count+1 end end
        assert(count==1,'Console logger duplicated its retained entry')
      end
    end)
    runtime.log=original
    assert(passed,type(problem)=='table' and problem.message or problem)
    tick=tick+1
  end
  log('TC_CONTRACT console-computer-log-prepares-result-before-eviction-and-resumes-once')
end
return M
