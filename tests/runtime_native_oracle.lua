-- Finite pinned-engine observations; no watchdog-dependent cases.
local M = {}
M.cases = {
  {name='next-arity',source=[[local t={a=false}; local k,v=next(t); return select('#',next({})),k,v,select('#',next(t,k))]]},
  {name='unpack-arity',source=[[local t={[1]=false,[160]=7}; local p=table.pack(unpack(t,1,160)); return p.n,p[1],p[2],p[160],select('#',unpack(t,2,1))]]},
  {name='protected-arity',source=[[local f=function(...) return ... end; local a=table.pack(pcall(f,false,nil,3,nil)); local b=table.pack(xpcall(f,function() end,false,nil)); local c=table.pack(xpcall(function() error(false) end,function(e) return e,nil,3 end)); return a.n,a[1],a[2],a[3],a[4],a[5],b.n,b[1],b[2],b[3],c.n,c[1],c[2] ]]},
  {name='table-mutation-arity',source=[[local t={1,2}; local a=select('#',table.insert(t,3)); local b=select('#',table.sort(t)); local c=table.pack(table.remove(t)); return a,b,c.n,c[1],select('#',table.remove({})),select('#',table.remove({1},2))]]},
  {name='string-arity',source=[[return select('#',string.byte('',1,0)),select('#',string.find('abc','z',1,true)),select('#',string.find('abc','b',1,true)),string.char('65',0),string.sub('abc',-2)]]},
  {name='required-inputs',source=[[local a=pcall(type); local b=pcall(tonumber); local c=pcall(string.sub,'abc'); local d=pcall(rawget,{}); local e=pcall(rawset,{},1); local f=pcall(rawlen); local g=pcall(rawequal,nil); return a,b,c,d,e,f,g,type(nil)]]},
  {name='native-coercion',source=[[return math.abs('-2'),math.log(1,nil),string.len(123),string.sub(123,2),string.rep(7,3,0),table.concat({1,2},3),tonumber('ff',16),tonumber({})]]},
  {name='nonfinite-temporaries',source=[[local a=math.sqrt(-1); local b=math.exp(10000); local c=1/0; return a~=a,b>1e300,c>1e300,math.log(0)<-1e300]]},
  {name='sparse-sequence',source=[[local t={[1]='a',[3]='c',[1025]=false}; local n=#t; local raw=rawlen(t); table.insert(t,'x'); local removed=table.pack(table.remove(t)); return n,raw,removed.n,removed[1],t[3],t[1025] ]]},
  {name='temporary-growth',source=[[local t={}; for i=1,2048 do rawset(t,i,i) end; local s=string.rep('a',32768); local a=table.pack(string.byte(s,1,160)); return #t,t[2048],#s,a.n,a[160] ]]},
  {name='native-recursion',source=[[local function f(n) if n==0 then return 0 end; return 1+f(n-1) end; return f(64)]]},
  {name='sort-failure',source=[[local t={4,3,2,1}; local calls=0; local ok=pcall(table.sort,t,function(a,b) calls=calls+1; if calls==3 then error('finite comparator failure') end; return a<b end); return ok,calls,t[1],t[2],t[3],t[4] ]]},
  {name='reference-key-aliases',source=[[local t={}; local key={}; rawset(t,key,t); rawset(t,'self',t); return rawequal(rawget(t,key),t),rawequal(t.self,t),select('#',rawget(t,nil)),select('#',rawget(t,0/0))]]},
  {name='native-index-rules',source=[[local t={1}; local a=pcall(rawset,t,nil,2); local b=pcall(rawset,t,0/0,2); return a,b,t[1],string.sub('abcdef',-100,-100),string.byte('abc','2'),select('#',select(4,1,2))]]}
}

local function values(fn)
  local packed=table.pack(fn())
  local result={n=packed.n,values={}}
  for i=1,packed.n do
    local value=packed[i]
    local kind=type(value)
    assert(kind=='nil' or kind=='boolean' or kind=='number' or kind=='string','oracle must return primitive observations')
    result.values[i]={kind=kind,value=value}
  end
  return result
end

-- The candidate can reuse the same sources and exact nil-bearing observations.
function M.observe(build)
  local observations={}
  for _,case in ipairs(M.cases) do
    local fn=assert(build(case.source,case.name))
    observations[case.name]=values(fn)
  end
  return observations
end

function M.scope_probe()
  local meta=getmetatable('')
  local original=meta.__index
  local approved={sub=string.sub,len=string.len}
  local function scoped(index,fn,...)
    local previous=meta.__index
    meta.__index=index
    local result=table.pack(pcall(fn,...))
    meta.__index=previous
    if not result[1] then error(result[2],0) end
    return table.unpack(result,2,result.n)
  end
  local sentinel={}
  local ok,problem=pcall(function()
    scoped(approved,function()
      assert(('abc')['sub']==string.sub)
      for _,name in ipairs({'dump','match','gsub','pack','unpack'}) do assert(('abc')[name]==nil,name) end
      scoped(original,function()
        assert(('abc').match==string.match)
        local a,b=('abc'):find('b'); assert(a==2 and b==2)
        scoped(approved,function() assert(('abc').match==nil) end)
        assert(('abc').match==string.match)
      end)
      assert(('abc').match==nil)
      table.sort({2,1},function(a,b) assert(('abc').match==nil); return a<b end)
      local caught,transformed=xpcall(function() error(false,0) end,function(e)
        assert(('abc').match==nil and e==false); return 'caught'
      end)
      assert(not caught and transformed=='caught')
      local failed,e=pcall(function() scoped(original,function() error(sentinel,0) end) end)
      assert(not failed and e==sentinel and ('abc').match==nil)
      error(sentinel,0)
    end)
  end)
  assert(not ok and problem==sentinel and meta.__index==original,'native scope was not restored')
  return {nested=true,comparator=true,message_handler=true,host_error=true,outer_error=true,restored=true}
end

function M.run()
  local observations=M.observe(function(source,name) return load(source,'@native-oracle-'..name,'t',_ENV) end)
  local scope=M.scope_probe()
  local count=0
  for _,case in ipairs(M.cases) do
    count=count+1
    log('TC_CONTRACT native-oracle-'..case.name)
  end
  log('TC_CONTRACT native-oracle-string-scopes')
  log('TC_CONTRACT_TOTAL '..(count+1))
  helpers.write_file('trusted-native-oracle.json',helpers.table_to_json({engine=script.active_mods.base,cases=observations,scope=scope}),false)
end
return M
