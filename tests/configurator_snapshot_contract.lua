-- Snapshot normalization already detaches native data; do not copy it again.
local adapters=require('scripts.configuration.adapters')
local sections=require('scripts.configuration.sections')
local data=require('scripts.runtime.data')
local validation=require('scripts.configuration.validation')
local limits=require('scripts.runtime.limits')
local M={}
local function nop() end
local function observation(fn,value,ceiling)
  local charges={}
  local ok,result,stats=pcall(fn,value,function(n) charges[#charges+1]=n end,ceiling)
  if not ok then return {ok=false,result=result,charges=charges} end
  return {ok=true,stats=stats or result,charges=charges}
end
local function sizing()
  assert(type(data.measure)=='function','Data sizing requires a non-copying traversal')
  local alias={child='shared'}
  local cases={false,true,0,'',string.rep('x',300),{}, {a=alias,b=alias},{{1,false},{2,true}},
    {[1]=true,[3]=false},{[1]=true,a=false},setmetatable({},{}),{bad=function() end},0/0}
  local cycle={}; cycle.self=cycle; cases[#cases+1]=cycle
  local deep={}; local cursor=deep
  for _=1,limits.data_depth+1 do cursor.child={}; cursor=cursor.child end
  cases[#cases+1]=deep
  for _,value in ipairs(cases) do
    local baseline=observation(data.copy,value,limits.host_memory_bytes)
    local measured=observation(data.measure,value,limits.host_memory_bytes)
    assert(validation.equal(baseline,measured),'Data sizing changed validation, accounting or failure order')
    if baseline.ok then
      for _,ceiling in ipairs({baseline.stats.bytes,baseline.stats.bytes-1}) do
        assert(validation.equal(observation(data.copy,value,ceiling),observation(data.measure,value,ceiling)),
          'Data sizing changed exact capacity boundary')
      end
    end
  end
  local notices={}
  for _,fn in ipairs({data.copy,data.measure}) do
    local called
    local ok,e=pcall(fn,{value='payload'},nop,1,function(bytes) called=bytes end)
    assert(not ok and e.code=='E_CAPACITY' and called)
    notices[#notices+1]=called
  end
  assert(notices[1]==notices[2])
  assert(validation.equal(observation(data.copy,nil),observation(data.measure,nil)))
  local source={a=alias,b=alias}
  local copy=data.copy(source,nop,limits.host_memory_bytes)
  assert(copy~=source and copy.a~=alias and copy.b~=alias and copy.a~=copy.b)
  copy.a.child='changed'; assert(copy.b.child=='shared' and alias.child=='shared')
end
local function detached_reads()
  local reads=0
  local parameters={conditions={{constant=3}},outputs={{signal={type='virtual',name='signal-A'}}}}
  local cb=setmetatable({}, {__index=function(_,key)
    if key=='object_name' then return 'LuaDeciderCombinatorControlBehavior' end
    if key=='parameters' then reads=reads+1; return parameters end
    if key=='disabled' then return false end
  end})
  local item={id='snapshot-host-double',entity={get_control_behavior=function() return cb end}}
  local first=adapters.snapshot(item,nop)
  assert(reads==1,'native configuration field fetched more than once per snapshot')
  assert(first.values.parameters.conditions[1].constant==3 and first.observations.disabled==false)
  first.values.parameters.conditions[1].constant=99
  assert(parameters.conditions[1].constant==3,'normalized snapshot aliases native input')
  assert(adapters.snapshot(item,nop).values.parameters.conditions[1].constant==3)
  local copy=data.copy
  data.copy=function() error('detached configuration snapshot copied a second time') end
  local ok,problem=pcall(function()
    assert(adapters.snapshot(item,nop).values.parameters.conditions[1].constant==3)
    assert(select('#',adapters.snapshot(item,nop))==1)
    local caps=adapters.capabilities(item,nop)
    caps.settings.parameters.fields.conditions.items.fields.constant.min=0
    assert(adapters.capabilities(item,nop).settings.parameters.fields.conditions.items.fields.constant.min<0)
    assert(select('#',adapters.capabilities(item,nop))==1)
    local empty={id='empty-section-host-double',entity={type='constant-combinator',get_control_behavior=function() end}}
    assert(#sections.get(empty,nop)==0)
    assert(select('#',sections.get(empty,nop))==1)
  end)
  data.copy=copy
  assert(ok,problem)
end
function M.run(report)
  detached_reads()
  sizing()
  local name='configurator-single-native-read-detached-results-and-copy-free-sizing'
  if report then report(name) else log('TC_CONTRACT '..name) end
end
return M
