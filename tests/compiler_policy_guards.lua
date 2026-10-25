local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local parsing=require('scripts.runtime.parse_admission')
local tokenize=require('vendor.phobos.tokenize')
local continuation=require('scripts.runtime.continuation')
local memory=require('scripts.runtime.memory')
local ast_memory=require('tests.compiler_ast_memory')
local parser_memory=require('tests.compiler_parser_memory')
local validation_memory=require('tests.compiler_validation_memory')
local proof_memory=require('tests.compiler_proof_memory')
local M={}
local function lexical_memory()
  local payload=string.rep('lexical',24)
  local cases={
    {'"'..payload..'\\n\\x41\\065\\z  \r\nend"','string',payload..'\nAAend'},
    {'[==[\r\n'..payload..'\r\n]x]==]','string',payload..'\n]x'},
    {payload,'ident',payload},
    {'0.'..string.rep('1',80),'number'},
    {'--'..payload,'comment',payload},
    {'--[=['..payload..']=]','comment',payload},
    {string.rep(' ',80)..'\r\n','blank',string.rep(' ',80)..'\n'},
    {'"'..payload,'invalid','"'..payload},
    {'[=['..payload,'invalid','[=['..payload},
    {'"'..payload..'\\q"','invalid','"'..payload..'\\q"'},
    {'"'..payload..'\\x!"','invalid','"'..payload..'\\x!"'},
    {'"'..payload..'\\999"','invalid','"'..payload..'\\999"'},
    {'"'..payload..'\n','invalid','"'..payload},
    {'--[=['..payload,'invalid','--[=['..payload},
    {'1'..string.rep('0',80)..'e+','invalid','1'..string.rep('0',80)..'e+'},
    {'['..string.rep('=',80)..'['..payload..']'..string.rep('=',80)..']','string',payload},
    {'"'..payload..'\\\r\nend"','string',payload..'\nend'},
    {'\239\187\191#'..payload..'\n','blank','\n','#'..payload},
  }
  local reserve,sub,concat=memory.reserve,string.sub,table.concat
  local watching,last,first_copy,copies,joins,account=false,0,nil,0,0,nil
  local reservations,context
  memory.reserve=function(owner,bytes)
    if watching and reservations then
      reservations[#reservations+1]={used=account.used+account.reserved,bytes=bytes,work=context.machine.compile}
    end
    last=bytes; return reserve(owner,bytes)
  end
  string.sub=function(value,first,final)
    if watching and first>0 and final and final-first+1>16 then
      assert(last>=32+final-first+1,'tokenizer payload copied before memory admission')
      first_copy=first_copy or account.used+account.reserved
      copies=copies+1; last=0
    end
    return sub(value,first,final)
  end
  table.concat=function(parts,...)
    if watching then
      local bytes=32; for _,part in ipairs(parts) do bytes=bytes+#part end
      assert(last>=bytes,'tokenizer joined text before memory admission')
      joins=joins+1; last=0
    end
    return concat(parts,...)
  end
  local passed,problem=pcall(function()
    local total_copies,total_joins,total_boundaries=0,0,0
    for _,case in ipairs(cases) do
      local boundary,charges
      for attempt=1,2 do
        account=memory.new(attempt==1 and limits.host_memory_bytes or boundary-1,0,'host_memory')
        local owner=memory.owner(account)
        context=admission.context(admission.new(),'lexical-memory',0)
        parsing.begin(context); parsing.attach(owner)
        reservations=attempt==1 and {} or nil
        watching,last,first_copy,copies,joins=true,0,nil,0,0
        local ok,result=pcall(function()
          local iter,state,index=tokenize(case[1],'@lexical-memory')
          if case[4] then assert(state.shebang_line==case[4]) end
          local next_index,token=iter(state,index)
          assert(next_index and token and token.token_type==case[2])
          if case[3] then assert(token.value==case[3],'tokenizer changed decoded bytes') end
          assert(owner.reserved>=192+5*48,'tokenizer state metadata was not admitted')
        end)
        watching=false; parsing.finish(); memory.close(owner,function() end)
        assert(account.used==256 and account.reserved==0,'lexical refusal leaked temporary ownership')
        if attempt==1 then
          assert(ok,type(result)=='table' and result.message or tostring(result))
          assert(first_copy,'fixture did not exercise input-sized text')
          boundary=first_copy; total_copies=total_copies+copies; total_joins=total_joins+joins
          charges=reservations
        else
          assert(not ok and result.recoverable and result.resource=='host_memory' and copies==0,
            'one-byte-short tokenizer refusal followed payload copying')
        end
      end
      -- Exercise every actual record/part/diagnostic growth boundary, not just text.
      reservations=nil
      for _,charge in ipairs(charges) do
        total_boundaries=total_boundaries+1
        account=memory.new(charge.used+charge.bytes-1,0,'host_memory')
        local owner=memory.owner(account)
        context=admission.context(admission.new(),'lexical-boundary',0)
        parsing.begin(context); parsing.attach(owner)
        local ok,e=pcall(function()
          local iter,state,index=tokenize(case[1],'@lexical-memory'); iter(state,index)
        end)
        parsing.finish()
        assert(not ok and e.recoverable and e.resource=='host_memory'
          and e.used==charge.used and e.requested==charge.bytes
          and context.machine.compile==charge.work,'lexical growth changed refusal order or paid work')
        memory.close(owner,function() end)
        assert(account.used==256 and account.reserved==0)
      end
    end
    assert(total_copies>0 and total_joins>0)
    log('TC_LEXICAL_MEMORY cases='..#cases..' boundaries='..total_boundaries..' copies='..total_copies..' joins='..total_joins)
  end)
  watching=false; parsing.finish()
  memory.reserve,string.sub,table.concat=reserve,sub,concat
  assert(passed,type(problem)=='table' and problem.message or tostring(problem))
  log('TC_CONTRACT tokenizer-payload-admission-before-copy-join-and-one-byte-short-refusal')
end
local function single_frontend()
  local find,cache=string.find,limits.compiler_cache_bytes
  local allocate=parsing.allocate
  local reserve,host,work=memory.reserve,limits.host_memory_bytes,limits.compile_work
  local watched,passes={},0
  string.find=function(value,pattern,...)
    if watched[value] and pattern=='^\239\187\191' then passes=passes+1 end
    return find(value,pattern,...)
  end
  limits.compiler_cache_bytes=1
  local ok,problem=pcall(function()
    for _,case in ipairs({
      {'function one_pass() return true end',false,1},
      {'return {api_version=1,handlers={one_pass=function() return true end}}',false,1},
      {'1+2','shell',1},
      {'local n=1; n=n+1','shell',2},
      {'\239\187\191function one_pass() end',false,1},
      {'#!/usr/bin/lua\nfunction one_pass() end',false,1},
    }) do
      watched={[case[1]]=true,['return '..case[1]]=true}; passes=0
      local plan,e=compiler.prepare(case[1],admission.context(admission.new(),'single-frontend',0),case[2] or nil)
      assert(plan,e and e.message)
      assert(passes==case[3],'compiler duplicated the tokenizer pass')
    end
    local source='"'..string.rep('prefix',20)..'"'
    local first,allocating
    memory.reserve=function(owner,bytes)
      if allocating then first=first or {used=owner.account.used+owner.account.reserved,bytes=bytes} end
      return reserve(owner,bytes)
    end
    parsing.allocate=function(bytes)
      allocating=true; allocate(bytes); allocating=false
    end
    assert(compiler.prepare(source,admission.context(admission.new(),'prefix-fit',0),'shell'))
    memory.reserve,parsing.allocate=reserve,allocate
    assert(first and first.bytes==32+7+#source)
    for _,resource in ipairs({'host_memory','compile_work'}) do
      watched={['return '..source]=true}; passes=0
      limits.host_memory_bytes=resource=='host_memory' and first.used+first.bytes-1 or host
      limits.compile_work=resource=='compile_work' and (#source*2+1)+(#source+8)-1 or work
      local plan,e=compiler.prepare(source,admission.context(admission.new(),'prefix-refused',0),'shell')
      assert(not plan and e.recoverable and e.resource==resource and passes==0,
        'Console prefix entered the parser before admission')
    end
    limits.host_memory_bytes,limits.compile_work=host,work
    watched={}
    for _,name in ipairs({'_ENV','_G','__tc_private'}) do
      for _,source in ipairs({'local '..name..'=1','return t.'..name,
        'return {'..name..'=1}','local function f('..name..') end','::'..name..'::'}) do
        for _,mode in ipairs({false,'shell'}) do
          local plan,e=compiler.prepare(source,admission.context(admission.new(),'identifier-boundary',0),mode or nil)
          assert(not plan and e.message=='forbidden identifier','parser bypassed reserved identifier validation')
          assert(e.line==1 and e.column==assert(find(source,name,1,true)),'identifier position changed')
        end
      end
    end
    for _,source in ipairs({'function broken(','function broken(\n','function broken(\r\n'}) do
      local plan,e=compiler.prepare(source,admission.context(admission.new(),'eof-position',0))
      assert(not plan and e.code=='E_PROGRAM')
      assert(e.line==(source:find('\n',1,true) and 2 or 1))
      assert(e.column==(e.line==2 and 1 or #source+1),'EOF position changed')
    end
    assert(compiler.prepare('function safe() return {["__tc_private"]=1} end',
      admission.context(admission.new(),'quoted-key',0)))
  end)
  string.find,limits.compiler_cache_bytes=find,cache
  memory.reserve,limits.host_memory_bytes,limits.compile_work=reserve,host,work
  parsing.allocate=allocate
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
  log('TC_CONTRACT single-tokenizer-parser-path-reserved-identifiers-and-eof-positions')
end
function M.run()
  proof_memory.run()
  validation_memory.run()
  ast_memory.run()
  parser_memory.run()
  single_frontend()
  lexical_memory()
  -- Durable validation must traverse the language without emitting a discarded backend.
  local format,concat,lower=string.format,table.concat,continuation.lower
  local validating,formats,joins=false,0,0
  string.format=function(pattern,...) if validating and pattern=='%q' then formats=formats+1 end; return format(pattern,...) end
  table.concat=function(...)
    local result=concat(...)
    if validating and result:find('__tc',1,true) then joins=joins+1 end
    return result
  end
  continuation.lower=function(...) validating=false; return lower(...) end
  local checked,problem=pcall(function()
    local body='local t={value="'..string.rep('literal',2000)..'"}; t.value=t.value.."!"; return t.value'
    for i,text in ipairs({'function validate_only() '..body..' end',
      'return {api_version=1,handlers={validate_only=function() '..body..' end}}',body}) do
      validating=true
      local plan,reason=compiler.prepare(text,admission.context(admission.new(),'validation-only-'..i,0),i==3 and 'shell' or nil)
      assert(not validating,'fixture did not reach durable lowering')
      validating=false
      assert(plan,reason and reason.message)
      assert(formats==0 and joins==0,'validation emitted discarded native source')
    end
  end)
  string.format,table.concat,continuation.lower=format,concat,lower
  assert(checked,type(problem)=='table' and problem.message or tostring(problem))
  local reserve=memory.reserve
  local emitting,last_reservation,quoted,joined=false,0,0,0
  memory.reserve=function(owner,bytes) last_reservation=bytes; return reserve(owner,bytes) end
  string.format=function(pattern,value,...)
    if emitting and pattern=='%q' then
      assert(last_reservation>=34+4*#value,'literal quoting allocated before admission')
      quoted=quoted+1; last_reservation=0
    end
    return format(pattern,value,...)
  end
  table.concat=function(values,separator,...)
    if emitting then
      local bytes=32+math.max(0,#values-1)*#(separator or '')
      for _,value in ipairs(values) do bytes=bytes+#tostring(value) end
      assert(last_reservation>=bytes,'generated join allocated before admission')
      joined=joined+1; last_reservation=0
    end
    return concat(values,separator,...)
  end
  continuation.lower=function(...)
    emitting=true
    local generated=lower(...)
    emitting=false
    return generated
  end
  local checked,problem=pcall(function()
    local literal=string.rep('literal',2000)..'\0\1\n\r\\"'
    local body='local text='..format('%q',literal)..'; return text'
    for i,text in ipairs({'function strings_owned() '..body..' end',
      'return {api_version=1,handlers={strings_owned=function() '..body..' end}}',body}) do
      quoted,joined=0,0
      local plan,e=compiler.prepare(text,admission.context(admission.new(),'emission-memory-'..i,0),i==3 and 'shell' or nil)
      assert(plan,e and e.message)
      assert(quoted>0 and joined>0,'fixture did not reach string emission')
    end
  end)
  memory.reserve,string.format,table.concat,continuation.lower=reserve,format,concat,lower
  assert(checked,type(problem)=='table' and problem.message or tostring(problem))
  local invalid={
    'local x=1; function start() end', 'function start() end; function start() end',
    'function computer() end', 'function obj:method() end',
    'return {api_version=1,handlers={},extra=true}',
    'return {api_version=1,api_version=1,handlers={}}',
    'return {api_version=2,handlers={}}', 'return {api_version=1,handlers={start=1}}',
    'return {api_version=1,handlers={["bad-name"]=function() end}}'
  }
  for _,body in ipairs({'return game.tick','local _ENV={}','return __tc_guard',
    'return getmetatable({})','local t={}; return t:method()',
    'escaped=1','return 1e999','goto label; ::label::'}) do
    invalid[#invalid+1]='function start() '..body..' end'
    invalid[#invalid+1]='return {api_version=1,handlers={start=function() '..body..' end}}'
  end
  for i,text in ipairs(invalid) do
    local legacy,expected=compiler.compile(text,admission.context(admission.new(),'invalid-legacy-'..i,0))
    local durable,actual=compiler.prepare(text,admission.context(admission.new(),'invalid-durable-'..i,0))
    assert(not legacy and not durable and actual.code==expected.code and actual.message==expected.message
      and actual.line==expected.line and actual.column==expected.column,'durable validation changed a source diagnostic: '..text)
  end
  for _,text in ipairs({'game.tick','computer=1','return require("x")','local t={}; t:method()'}) do
    local legacy,expected=compiler.compile(text,admission.context(admission.new(),'invalid-shell-legacy',0),'shell')
    local durable,actual=compiler.prepare(text,admission.context(admission.new(),'invalid-shell-durable',0),'shell')
    assert(not legacy and not durable and actual.code==expected.code and actual.message==expected.message
      and actual.line==expected.line and actual.column==expected.column,'durable shell validation changed a source diagnostic')
  end
  for _,key in ipairs({'generated_source_bytes','source_nodes','source_tokens','source_nesting','handler_names'}) do
    assert(limits[key]==nil,'obsolete compiler quota still advertised: '..key)
  end
  local name=string.rep('long_identifier_',16)
  local source='function '..name..'() local '..name..'_value=1; assert('..name..'_value==1) end'
  local plan,e=compiler.compile(source,admission.context(admission.new(),'long-name',1))
  assert(plan and plan.handlers[name],e and e.message)
  local ok,problem=compiler.run(plan,name,{}, {},admission.context(admission.new(),'long-name-run',2))
  assert(ok,problem and problem.message)
  local shell,se=compiler.prepare('local '..name..'=1; return '..name,admission.context(admission.new(),'long-shell',3),'shell')
  assert(shell,se and se.message)
  for _,reserved in ipairs({'_ENV','_G','__tc'..name,'game','load','require'}) do
    local denied,reason=compiler.compile('function '..reserved..'() end',admission.context(admission.new(),reserved,4))
    assert(not denied and reason.code=='E_PROGRAM')
  end
  local ordinary,diagnostic=compiler.compile('function ordinary() if true then return 1 end end',admission.context(admission.new(),'old-depth-unused',5))
  assert(ordinary,diagnostic and diagnostic.message)
  parsing.begin(nil)
  for _=1,limits.host_stack_depth do parsing.push() end
  local accepted,depth_error=pcall(parsing.push)
  parsing.finish()
  assert(not accepted and depth_error.code=='E_CAPACITY' and depth_error.message=='compiler host depth exceeded')
  local deep,deep_error=compiler.compile('function deep() return '..string.rep('not ',limits.host_stack_depth+1)..'true end',admission.context(admission.new(),'real-recursion',6))
  assert(not deep and deep_error.code=='E_CAPACITY')
  assert(compiler.compile('function after_refusal() end',admission.context(admission.new(),'after-depth-refusal',7)))
  local body='local x=0; '..string.rep('x=x+1; ',900)..' assert(x==900)'
  for _,text in ipairs({'function start() '..body..' end',
    'return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local wide,reason=compiler.prepare(text,admission.context(admission.new(),'wide',8))
    assert(wide,reason and reason.message)
    local iter,state,index=tokenize(text,'@quota-regression'); local tokens=0
    while true do
      local token; index,token=iter(state,index)
      if not token or token.token_type=='eof' then break end
      tokens=tokens+1
    end
    assert(tokens>4096 and wide.nodes>4096 and #wide.generated>131072,'fixture did not cross former compiler quotas')
    local ran,problem,status=compiler.run(wide,'start',{}, {},admission.context(admission.new(),'wide-run',9),{})
    assert(ran and status==nil,problem and problem.message or 'wide handler did not complete')
    log('TC_COMPILER_QUOTAS tokens='..tokens..' nodes='..wide.nodes..' generated='..#wide.generated)
  end
  local functions={}
  for i=1,65 do functions[i]='function f'..i..'() end' end
  local exports,reason=compiler.prepare(table.concat(functions,'\n'),admission.context(admission.new(),'exports',10))
  assert(exports and exports.handlers.f65,reason and reason.message)
  log('TC_CONTRACT compiler-long-identifiers-reserved-names-real-host-depth')
end
return M
