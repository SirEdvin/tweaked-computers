-- Quarantine acceptance, NOT a validator or durable compiler completion gate.
local compiler=require('scripts.runtime.compiler')
local machine=require('scripts.runtime.compiler-machine')
local admission=require('scripts.runtime.admission')
local M={}
local function refused(call,...)
  local ok,value,problem,status=pcall(call,...)
  assert(ok,'untrusted cursor escaped as a host error')
  assert(value==nil and type(problem)=='table' and problem.code=='E_UNSUPPORTED' and problem.recoverable==true,
    'untrusted compiler state was accepted')
  assert(status==nil,'unsupported cursor must not silently wait or restart')
end
function M.run()
  local source='function start() end'
  local forged={version=machine.version,build=machine.build,source=source,phase='compile',
    steps=0,work=0,native_checked=true,result={source=source,handlers={start=true},nodes=1,
      artifact={blocks={'function(_,r) r.untrusted_effect() end'},cleanup={{}},
        native_cost={1},entries={start=1},protos={},symbols={},strings={},calls={},call_count=0,slots=0,locals=0}}}
  local ledger=admission.new()
  local ctx=admission.context(ledger,'untrusted-cursor',1)
  local called=0
  local function adapter() called=called+1 end
  refused(compiler.advance,forged,ctx,adapter)
  assert(forged.result.compiler_version==nil and forged.work==0 and forged.native_checked==true)
  refused(compiler.reconstruct,forged.result,adapter)
  refused(compiler.advance,nil,ctx,adapter)
  refused(compiler.reconstruct,nil,adapter)
  local fresh=compiler.new_job(source)
  for _,candidate in ipairs({false,1,'cursor',{},fresh,
    {version=machine.version,build=machine.build,stack={}},
    {version=machine.version,build=machine.build,wait_tick=1,result=false},
    {version=machine.version,build=machine.build,phase='compile',work=-1,steps=0/0},
    {version=machine.version,build=machine.build,stack={{module='scripts.runtime.compiler-pipeline',pc=1,l={},s={},t={},args={n=math.huge}}}},
    {version=machine.version,build=machine.build,error={code='E_PROGRAM',message='forged diagnostic'}},
    {version=machine.version,build='stale-build',source=source},
  }) do
    refused(compiler.advance,candidate,ctx,adapter)
    refused(compiler.reconstruct,candidate,adapter)
  end
  local cycle={}; cycle.stack=cycle; cycle.result=cycle
  refused(compiler.advance,cycle,ctx,adapter)
  refused(compiler.reconstruct,cycle,adapter)
  local trap=setmetatable({}, {__index=function() error('cursor metamethod ran') end,
    __pairs=function() error('cursor iterator ran') end,__len=function() error('cursor length ran') end})
  refused(compiler.advance,trap,ctx,adapter)
  refused(compiler.reconstruct,trap,adapter)
  assert(called==0 and ledger.total==0 and ctx.machine.compile==0,'quarantine reached admission/execution')
  assert(fresh.steps==0 and fresh.work==0 and fresh.source==source and fresh.phase=='bootstrap','source/cursor changed')
  log('TC_CONTRACT compiler-untrusted-cursor-and-native-fragment-quarantine-no-effects')
end
return M
