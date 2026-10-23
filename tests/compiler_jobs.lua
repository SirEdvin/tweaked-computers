local compiler=require('scripts.runtime.compiler')
local machine=require('scripts.runtime.compiler-machine')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local parsing=require('scripts.runtime.parse_admission')
local parse=require('vendor.phobos.parser')
local continuation=require('scripts.runtime.continuation')
local M={}
-- This fixture isolates compiler work; shared host-memory ownership is a separate gate.
local function test_workspace() end
local function plain_copy(root)
  local copies,queue={},{}
  local function copy(value)
    local kind=type(value)
    assert(kind~='function' and kind~='thread' and kind~='userdata','compiler cursor retained executable/native value')
    if kind~='table' then return value end
    assert(getmetatable(value)==nil,'compiler cursor retained metatable')
    if not copies[value] then copies[value]={}; queue[#queue+1]=value end
    return copies[value]
  end
  local result=copy(root); local head=1
  while queue[head] do
    local value=queue[head]; head=head+1
    for key,child in pairs(value) do copies[value][copy(key)]=copy(child) end
  end
  return result
end
local function generated(a)
  if type(a)=='string' then return string.format('%q',a) end
  if type(a)~='table' then return tostring(a) end
  local keys={}; for key in pairs(a) do keys[#keys+1]=key end
  table.sort(keys,function(x,y) return tostring(x)<tostring(y) end)
  local out={}; for _,key in ipairs(keys) do out[#out+1]='['..generated(key)..']='..generated(a[key]) end
  return '{'..table.concat(out,',')..'}'
end
function M.drive(source,mode,cold,allowance)
  local ledger=admission.new(); local job=compiler.new_job(source,mode)
  local trace={}
  for tick=1,10000 do
    local context=admission.context(ledger,'compiler',tick)
    if allowance then assert(admission.reserve(context,'compile',limits.compile_work-allowance)) end
    local before=context.machine.compile
    local result,problem,status=compiler.advance(job,context,test_workspace)
    trace[#trace+1]={work=context.machine.compile-before,steps=job.steps}
    if result or problem then return result,problem,trace,job end
    assert(status=='wait')
    local paid,steps=ledger.total,job.steps
    assert(select(3,compiler.advance(job,context,test_workspace))=='wait' and ledger.total==paid and job.steps==steps)
    if cold then job=plain_copy(job) end
  end
  error('compiler cursor did not complete')
end
function M.run()
  local missing,missing_error=compiler.advance(compiler.new_job('function start() end'),admission.context(admission.new(),'missing-owner',1))
  assert(not missing and missing_error.code=='E_UNSUPPORTED')
  for _,source in ipairs({
    'function start() local n=0; for i=1,4 do n=n+i end; computer.log(tostring(n)) end',
    'function start(...) local function f(a,...) return a,... end; local t={f(1,nil,3)}; pcall(f,t) end',
    'return {api_version=1,handlers={start=function() local s=[=[line\ntext]=]; if s then return s end end}}',
  }) do
    local result,e=M.drive(source,nil,true,8192); assert(result,e and e.message)
    parsing.begin(nil)
    local main,diagnostics=parse(source,'@computer'); assert(#diagnostics==0)
    local expected=continuation.lower(main,function(_,message) error(message) end,function() return 1,1 end)
    parsing.finish()
    -- Positions are tested through native execution; compare structural inventories here.
    local actual=compiler.reconstruct(result,function() end)()
    local reference=assert(load(expected,'@compiler-reference','t',{}))()
    assert(#actual.blocks==#reference.blocks and actual.locals==reference.locals and actual.slots==reference.slots)
    assert(actual.entries.start==reference.entries.start)
  end
  local source='function start() local n=0;\n'..string.rep('n=n+1; -- source padding\n',900)..'end'
  assert(#source>16384)
  local warm,e,a=M.drive(source,nil,false,100000); assert(warm,e and e.message)
  local cold,ce,b=M.drive(source,nil,true,100000); assert(cold,ce and ce.message)
  assert(#a>1 and #a==#b and warm.nodes>4096)
  for i=1,#a do assert(a[i].work==b[i].work and a[i].steps==b[i].steps,'cache/copy changed paid progress') end
  assert(generated(warm.artifact)==generated(cold.artifact))
  local declarations={}; for i=1,80 do declarations[i]='function handler'..i..'() end' end
  local many,problem=M.drive(table.concat(declarations,'\n'),nil,false,100000); assert(many,problem and problem.message)
  local count=0; for _ in pairs(many.handlers) do count=count+1 end; assert(count==80)
  for _,invalid in ipairs({'function start() game.print(1) end','function start() local = end','function start() end; start()'}) do
    local result,problem=M.drive(invalid,nil,true,8192)
    assert(not result and problem and problem.code=='E_PROGRAM')
  end
  local shell,location=M.drive('  game','shell',true,8192)
  assert(not shell and location.code=='E_PROGRAM' and location.line==1 and location.column==3)
  local deep,depth_error=M.drive('function start() local n='..string.rep('not ',100)..'true end',nil,true,100000)
  assert(deep,depth_error and depth_error.message)
  local executable,problem=M.drive('function start() local n=0; for i=1,40 do n=n+i end; computer.finished(n) end')
  assert(executable,problem and problem.message)
  local old_cache=limits.compiler_cache_bytes
  local traces={}
  for run,cache_bytes in ipairs({old_cache,1}) do
    limits.compiler_cache_bytes=cache_bytes
    local charges,effects={},0
    local context=admission.context(admission.new(),'reconstruction',1)
    local factory=compiler.reconstruct(executable,function(cost)
      assert(admission.reserve(context,'compile',cost),'fixture native work allowance exhausted')
      charges[#charges+1]=cost
    end)
    local ok,e=continuation.run(executable.source,factory,'start',{},function(guard)
      return {computer={finished=function(value) guard.prepare_empty_result(); assert(value==40*41/2); effects=effects+1 end}}
    end,context,{})
    assert(ok and effects==1,e and e.message)
    traces[run]=table.concat(charges,',')
  end
  limits.compiler_cache_bytes=old_cache
  assert(traces[1]==traces[2],'native cache changed reconstruction charge sequence')
  log('TC_CONTRACT durable-phobos-token-parser-validation-emission-large-source-cache-independent')
end
M.generated=generated
M.plain_copy=plain_copy
return M
