local ast=require('vendor.phobos.ast_util')
local nodes=require('vendor.phobos.nodes')
local parse=require('vendor.phobos.parser')
local parser_errors=require('vendor.phobos.error_code_util')
local parsing=require('scripts.runtime.parse_admission')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}
local function snapshot(value,seen)
  if type(value)~='table' or seen[value] then return end
  local fields={}; seen[value]=fields
  for key,child in pairs(value) do fields[key]=true; snapshot(key,seen); snapshot(child,seen) end
end
local function growth(value,before,seen)
  if type(value)~='table' or seen[value] then return 0 end
  seen[value]=true
  local fields=before[value]
  local bytes=fields and 0 or 192
  for key,child in pairs(value) do
    bytes=bytes+(fields and fields[key] and 0 or 48)+growth(key,before,seen)+growth(child,before,seen)
  end
  return bytes
end
function M.run()
  local operations={
    {'local',function() return {} end,function(scope) return ast.new_local_def('x',scope) end},
    {'local-reference',function() return {scope={},token={value='x',line=2,column=3}} end,function(input)
      local def,ref=ast.create_local(input.token,input.scope)
      assert(def.refs[1]==ref and ref.reference_def==def and ref.line==2 and ref.column==3)
      return def
    end},
    {'upvalue',function()
      local parent=ast.new_local_def('_ENV',{})
      return {parent=parent,scope={upvals={{name='older'}}}}
    end,function(input)
      local def=ast.create_upval_def(input.parent,input.scope)
      assert(input.parent.child_defs[1]==def and input.scope.upvals[1]==def
        and input.scope.upvals[2].name=='older')
      return def
    end},
    {'resolve',function()
      local main=ast.new_main('@references')
      local def=ast.new_local_def('captured',main); def.whole_block=true; main.locals[1]=def
      return nodes.new_functiondef{source='@references',parent_scope=main}
    end,function(scope)
      local first=ast.resolve_ref_at_end(scope,'captured')
      local second=ast.resolve_ref_at_end(scope,'captured')
      local global=ast.resolve_ref_at_end(scope,'global')
      assert(first.reference_def==second.reference_def and #first.reference_def.refs==2)
      assert(scope.upvals[1].name=='_ENV' and global.node_type=='index' and global.suffix.value=='global')
      return scope
    end},
    {'main',function() return {} end,function() return ast.new_main('@main') end},
  }
  local reserve=memory.reserve
  local account,context,charges
  memory.reserve=function(owner,bytes)
    if charges then charges[#charges+1]={used=account.used+account.reserved,bytes=bytes,work=context.machine.compile} end
    return reserve(owner,bytes)
  end
  local boundaries=0
  local ok,problem=pcall(function()
    for _,case in ipairs(operations) do
      local input=case[2]()
      local before={}; snapshot(input,before)
      account=memory.new(limits.host_memory_bytes,0,'host_memory')
      local owner=memory.owner(account)
      context=admission.context(admission.new(),'ast-reference',0)
      charges={}; parsing.begin(context); parsing.attach(owner)
      local result=case[3](input); parsing.finish()
      local seen={}
      assert(owner.reserved>=growth(result,before,seen)+growth(input,before,seen),
        'parser reference graph grew before admission: '..case[1])
      local recorded=charges; charges=nil
      memory.close(owner,function() end)
      for _,charge in ipairs(recorded) do
        boundaries=boundaries+1
        input=case[2]()
        account=memory.new(charge.used+charge.bytes-1,0,'host_memory'); owner=memory.owner(account)
        context=admission.context(admission.new(),'ast-reference-refusal',0)
        parsing.begin(context); parsing.attach(owner)
        local accepted,e=pcall(case[3],input); parsing.finish()
        assert(not accepted and e.recoverable and e.resource=='host_memory'
          and e.used==charge.used and e.requested==charge.bytes and context.machine.compile==charge.work,
          'parser reference allocation crossed refusal: '..case[1])
        memory.close(owner,function() end)
        assert(account.used==256 and account.reserved==0)
      end
    end
    -- These parser-only inputs deliberately include native syntax rejected later
    -- by the guest language validator, plus recoverable malformed syntax.
    local cases={
      {'local a,b=1,2; local function f(x,...) return a,x,... end; return f(b)',false},
      {'function t:m(x) local a={x,key=x,[x]=x}; f(); f"s"; f{}; return (a.key)..(x).."!" end',false},
      {'::label:: for i=1,2 do if i then break elseif false then f() else g() end end; '
        ..'for k,v in pairs(t) do repeat v=v-1 until v==0 end; while false do end; goto label',false},
      {'local a,b; a,b=b,a; do local c=not false and -1^2 or #{} end',false},
      {'local a, = 1; f(1,); return ("long quoted diagnostic") trailing',true},
      {'::same:: ::same:: function f(...) return function() return ... end end',true},
      {'return {key 1, [2]=3, 4}',true},
      {'function t:(x) end; for x ? do end',true},
      {'return t[[text]]',false},
      {'return (f())..g().."!"; (f())=2',true},
      {'local function f(,) end; function () end; for = do end',true},
      {'local x=1; return function() return function() return x,_G end end',false},
      {'#!parser-memory\nreturn nil,true,false,0x10',false},
    }
    local parser_boundaries=0
    for _,case in ipairs(cases) do
      local before={}; snapshot(parser_errors.codes,before)
      account=memory.new(limits.host_memory_bytes,0,'host_memory'); local owner=memory.owner(account)
      context=admission.context(admission.new(),'parser-graph',0)
      charges={}
      parsing.begin(context); parsing.attach(owner)
      local main,diagnostics=parse(case[1],'@parser-memory'); parsing.finish()
      local recorded=charges; charges=nil
      assert((#diagnostics>0)==case[2],'parser syntax outcome changed')
      local seen={}
      assert(owner.reserved>=growth(main,before,seen)+growth(diagnostics,before,seen),
        'parser output graph exceeds admitted workspace')
      memory.close(owner,function() end)
      assert(account.used==256 and account.reserved==0)
      for _,charge in ipairs(recorded) do
        parser_boundaries=parser_boundaries+1
        account=memory.new(charge.used+charge.bytes-1,0,'host_memory'); owner=memory.owner(account)
        context=admission.context(admission.new(),'parser-graph-refusal',0)
        parsing.begin(context); parsing.attach(owner)
        local accepted,e=pcall(parse,case[1],'@parser-memory'); parsing.finish()
        assert(not accepted and type(e)=='table' and e.recoverable and e.resource=='host_memory'
          and e.used==charge.used and e.requested==charge.bytes and context.machine.compile==charge.work,
          'parser allocation crossed refusal: '..case[1])
        memory.close(owner,function() end)
        assert(account.used==256 and account.reserved==0)
      end
      -- Every aborted parse must clear its roots before the next unrelated request.
      parsing.begin(admission.context(admission.new(),'parser-recovery',0))
      local recovered,errors=parse('return 42','@after-refusal')
      parsing.finish()
      assert(#errors==0 and recovered.body.first.exp_list[1].value==42)
    end
    log('TC_PARSER_MEMORY reference_cases='..#operations..' boundaries='..boundaries
      ..' syntax_cases='..#cases..' parser_boundaries='..parser_boundaries)
  end)
  parsing.finish(); memory.reserve=reserve
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
  log('TC_CONTRACT parser-reference-graphs-admission-and-syntax-preservation')
end
return M
