local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local continuation=require('scripts.runtime.continuation')
local memory=require('scripts.runtime.memory')
local M={}
local function inventories()
  local reserve,lower,cache,host,work=memory.reserve,continuation.lower,limits.compiler_cache_bytes,limits.host_memory_bytes,limits.compile_work
  local recording,requests,context,owner,lowered=false,nil,nil,nil,false
  memory.reserve=function(target,bytes)
    owner=target
    if recording then requests[#requests+1]={used=target.account.used+target.account.reserved,bytes=bytes,work=context.machine.compile} end
    return reserve(target,bytes)
  end
  continuation.lower=function(...)
    recording=false; lowered=true
    return lower(...)
  end
  local ok,problem=pcall(function()
    local boundaries=0
    for _,case in ipairs({
      {'function inventory() end',false,{384,48,48}},
      {'return {api_version=1,handlers={inventory=function() end}}',false,{384,96,96,192,48}},
      {'true','shell',{192}},
    }) do
      limits.compiler_cache_bytes=1
      requests={}; recording,lowered=true,false
      context=admission.context(admission.new(),'validation-inventory',0)
      local plan,e=compiler.prepare(case[1],context,case[2] or nil)
      recording=false
      assert(plan and lowered,e and e.message)
      local observed=requests
      for i,bytes in ipairs(case[3]) do
        local step=observed[#observed-#case[3]+i]
        assert(step.bytes==bytes,'validation inventory graph lacks preallocation')
        boundaries=boundaries+1
        for _,short_work in ipairs({false,true}) do
          limits.compiler_cache_bytes=cache
          assert(compiler.prepare(case[1],admission.context(admission.new(),'inventory-warmup',0),case[2] or nil))
          limits.host_memory_bytes=step.used+step.bytes-1
          limits.compile_work=short_work and step.work-1 or work
          local expected,paid
          for attempt=1,2 do
            if attempt==2 then limits.compiler_cache_bytes=1 end
            lowered=false; context=admission.context(admission.new(),'inventory-refusal',0)
            local denied,reason=compiler.prepare(case[1],context,case[2] or nil)
            assert(not denied and reason.recoverable and reason.resource==(short_work and 'compile_work' or 'host_memory'))
            assert(not lowered and owner.closed and owner.reserved==0,'refused validation entered lowering or retained its owner')
            if expected then
              for _,field in ipairs({'code','resource','setting','used','requested','limit'}) do
                assert(reason[field]==expected[field],'inventory refusal changed with cache warmth: '..field)
              end
              assert(context.machine.compile==paid,'inventory refusal changed paid work')
            else expected,paid=reason,context.machine.compile end
          end
          limits.host_memory_bytes,limits.compile_work=host,work
        end
      end
    end
    log('TC_VALIDATION_MEMORY inventory_boundaries='..boundaries..' warm-cold-competing-work-verified')
  end)
  memory.reserve,continuation.lower=reserve,lower
  limits.compiler_cache_bytes,limits.host_memory_bytes,limits.compile_work=cache,host,work
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
end
function M.run()
  local stringify,lower,cache=tostring,continuation.lower,limits.compiler_cache_bytes
  local validating,booleans=false,0
  tostring=function(value)
    if validating and type(value)=='boolean' then booleans=booleans+1 end
    return stringify(value)
  end
  continuation.lower=function(...)
    validating=false
    return lower(...)
  end
  limits.compiler_cache_bytes=1
  local ok,problem=pcall(function()
    local body=[[local a,b=true,false
      local t={a,b,[a]=b,value=a}
      local function nested(x,...) return not x,#t,-1,... end
      function t.update(x) return x end
      local direct; function direct(x) return x end
      t.value,a=nested(a,b),b
      if a and b or a then t.value=true elseif b then t.value=false else t.value=nil end
      while a do a=false; break end
      repeat b=true until b
      for i=1,2,1 do t[i]=i+1 end
      for k,v in pairs(t) do t[k]=v end
      do local s='a'..'b'; t.value=s end
      return t,a==b,a~=b,a<b,a>b,a<=b,a>=b,1-2,2*3,4/2,4%3,2^3
    ]]
    for i,source in ipairs({'function validation_only() '..body..' end',
      'return {api_version=1,handlers={validation_only=function() '..body..' end}}',body}) do
      validating,booleans=true,0
      local plan,e=compiler.prepare(source,admission.context(admission.new(),'validation-memory-'..i,0),i==3 and 'shell' or nil)
      assert(not validating,'validation fixture did not reach lowering')
      assert(plan,e and e.message)
      assert(booleans==0,'validation-only traversal still constructs discarded scalar source')
    end
  end)
  validating=false
  tostring,continuation.lower,limits.compiler_cache_bytes=stringify,lower,cache
  assert(ok,type(problem)=='table' and problem.message or stringify(problem))
  log('TC_CONTRACT validation-only-traversal-does-not-format-discarded-scalars')
  inventories()
end
return M
