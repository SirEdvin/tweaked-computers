local environment=require('scripts.runtime.environment')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local oracle=require('tests.runtime_native_oracle')
local M={}
local function same(a,b)
  assert(type(a)==type(b),'oracle type differs')
  if type(a)~='table' then assert(a==b,'oracle value differs'); return end
  for k,v in pairs(a) do same(v,b[k]) end
  for k in pairs(b) do assert(a[k]~=nil,'unexpected oracle field') end
end
function M.run()
  local native_index=getmetatable('').__index
  local function create(services)
    local ctx=admission.context(admission.new(),'native-environment',0)
    local env=environment.new(ctx,services or {})
    env.initialize()
    return env,ctx
  end
  local function execute(env,source)
    return env.execute(assert(load(source,'@computer','t',env.globals)))
  end
  local expected=oracle.observe(function(source,name) return load(source,'@native-oracle-'..name,'t',_ENV) end)
  local observed=oracle.observe(function(source)
    local env=create()
    return function() return execute(env,source) end
  end)
  same(expected,observed)
  log('TC_CONTRACT environment-native-oracles')
  local original={code='E_TEST',message='original host error'}
  local writes=0
  local env,ctx=create({computer={
    inspect=function()
      assert(('abc').match==string.match,'host received guest string scope')
      return {value=false}
    end,
    fail=function() error(original,0) end,
    foreign_error=function() error(function() return 'private host function' end,0) end,
    log=function(text) assert(type(text)=='string'); writes=writes+1 end
  }})
  execute(env,[[
    for _,name in ipairs({'dump','match','gsub','pack','unpack'}) do assert(('abc')[name]==nil) end
    assert(('abc')['sub']==string.sub)
    assert(string.sub('abc',2)=='bc')
    assert(computer.inspect().value==false and ('abc').match==nil)
    local ok,e=pcall(computer.fail); assert(not ok and e.code=='E_TEST'); e.message='changed'
    assert(not pcall(function() pcall(computer.foreign_error) end),'host function escaped in an error')
    assert(('abc').match==nil)
    table.sort({2,1},function(a,b) assert(('abc').match==nil); return a<b end)
    ok,e=xpcall(function() error(false) end,function(v) assert(('abc').match==nil); return v end)
    assert(not ok and e==false)
    local t={}; ok,e=pcall(function() error(t) end); assert(not ok and rawequal(e,t))
    ok,e=xpcall(function() error(computer) end,function(v) assert(v==computer); return 'handle' end)
    assert(not ok and e=='handle')
    assert(not pcall(function() pcall(function() error(computer) end) end))
    local sequence_iterator=ipairs({})
    for _,t in ipairs({math,string,table,computer,peripheral,colors}) do
      assert(not pcall(function() t.changed=true end))
      assert(not pcall(rawget,t,'anything'))
      assert(not pcall(rawset,t,'anything',true))
      assert(not pcall(pairs,t))
      assert(not pcall(sequence_iterator,t,0))
      assert(not pcall(table.insert,t,true))
      assert(not pcall(table.remove,t))
      assert(not pcall(table.sort,t))
    end
    assert(tostring({})=='table' and tostring(function() end)=='guest function')
    assert(tostring(computer)=='API handle' and tostring(unpack)=='table function')
    assert(string.format('%s %s %s',{},computer,false)=='table API handle false')
    assert(not pcall(string.find,'abc','a'))
    assert(not pcall(string.format,'%q',123))
  ]])
  assert(original.message=='original host error' and getmetatable('').__index==native_index)
  log('TC_CONTRACT environment-host-boundary-and-scopes')
  local before=ctx.ledger.total
  execute(env,[[local n=0; for i=1,200000 do n=n+math.abs(-1) end; assert(n==200000)]])
  assert(ctx.ledger.total==before,'pure native work spent host credits')
  log('TC_CONTRACT environment-no-operation-accounting')
  local ok,problem=pcall(execute,env,'local function f()\n error("native failure")\nend\nf()')
  assert(not ok and env.diagnostic(problem).line==2 and env.diagnostic(problem).column==1)
  assert(getmetatable('').__index==native_index)
  log('TC_CONTRACT environment-source-diagnostic')
  for _,body in ipairs({
    'pcall(function() computer.stop() end); computer.log("unsafe")',
    'xpcall(function() computer.stop() end,function() computer.log("unsafe") end); computer.log("unsafe")',
    'pcall(function() xpcall(function() error("ordinary") end,function() computer.stop() end) end); computer.log("unsafe")'
  }) do
    local stopped=create({computer={log=function() writes=writes+1 end}})
    ok,problem=pcall(execute,stopped,body)
    assert(not ok and stopped.stop_requested() and stopped.diagnostic(problem).code=='E_STOP')
    assert(writes==0 and getmetatable('').__index==native_index)
  end
  local refused,credits=create({computer={log=function() writes=writes+1 end}})
  credits.ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick
  ok,problem=pcall(execute,refused,'xpcall(function() computer.log("unsafe") end,function(e) computer.log("unsafe") end)')
  assert(not ok and refused.diagnostic(problem).code=='E_BUDGET' and writes==0)
  assert(getmetatable('').__index==native_index)
  local healthy=create()
  assert(execute(healthy,'return math.abs(-2)')==2)
  log('TC_CONTRACT environment-fatal-controls-and-neighbor')
  local descriptor={kind='test',wire='red'}
  local facade=env.namespace({value=false},'test facade')
  env.bind_value(facade,descriptor)
  assert(env.binding(facade)==descriptor and env.binding({kind='test',wire='red'})==nil)
  assert(healthy.binding(facade)==nil)
  local nested=create({computer={nested=function()
    assert(('abc').match==string.match)
    local ok=pcall(execute,healthy,'assert(("abc").match==nil); error(false)')
    assert(not ok and ('abc').match==string.match)
  end}})
  execute(nested,'computer.nested(); assert(("abc").match==nil)')
  env.close()
  assert(not pcall(env.globals.computer.inspect) and getmetatable('').__index==native_index)
  log('TC_CONTRACT environment-authentic-bindings-nested-scopes-and-retirement')
  local effects=0
  local scalar,boundary=create({computer={effect=function() effects=effects+1; return false,nil,3,'done' end}})
  boundary.ledger.total=admission.host_ceiling(boundary.ledger,0)-1
  local result=table.pack(pcall(scalar.execute,scalar.globals.computer.effect))
  assert(result[1] and result.n==5 and result[2]==false and result[3]==nil and result[4]==3 and result[5]=='done',
    'scalar result charged after an admitted effect')
  assert(effects==1)
  assert(not pcall(scalar.execute,scalar.globals.computer.effect) and effects==1)
  log('TC_CONTRACT environment-scalar-return-without-post-effect-accounting')
  log('TC_CONTRACT_TOTAL 7')
end
return M
