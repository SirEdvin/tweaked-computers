-- Focused model contract; native engine executes this, not a Lua host substitute.
local model=require('scripts.dashboard-model')
local limits=require('scripts.runtime.limits')
local data=require('scripts.runtime.data')
local snapshots=require('scripts.lifecycle-data')
local M={}
local function spend() end
local function refused(code,fn,...)
  local ok,e=pcall(fn,...); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e)..' expected '..code)
end
local function tab(text) return {title='Overview',content={type='column',id='root',children={
  {type='label',id='status',text=text or 'Ready'},{type='button',id='ack',text='Acknowledge'}}}} end
function M.run()
  local shared={value='same'}; local input={first=shared,second=shared}
  local copy_charges,measure_charges={},{}
  local copy,stats=data.copy(input,function(n) copy_charges[#copy_charges+1]=n end)
  local measured=data.measure(input,function(n) measure_charges[#measure_charges+1]=n end)
  assert(copy.first~=copy.second and copy.first~=shared and model.equal(copy_charges,measure_charges))
  assert(stats.bytes==measured.bytes and stats.nodes==measured.nodes)
  local cycle={}; cycle.self=cycle
  refused('E_ARGUMENT',data.measure,cycle,spend)
  refused('E_ARGUMENT',data.measure,{[2]='sparse'},spend)
  local r={dashboard=model.new()}
  model.set_tab(r,1,{title='Empty',content={type='row',id='empty',children={}}},spend)
  assert(#r.dashboard.tabs['1'].definition.content.children==0)
  for slot=1,6 do model.set_tab(r,slot,tab(),spend) end
  assert(r.dashboard.tabs['6'].definition.content.children[2].enabled==true)
  local before=r.dashboard
  refused('E_RANGE',model.set_tab,r,7,tab(),spend); assert(r.dashboard==before)
  local duplicate=tab(); duplicate.content.children[2].id='status'
  refused('E_ARGUMENT',model.set_tab,r,1,duplicate,spend); assert(r.dashboard==before)
  local unknown=tab(); unknown.extra=true
  refused('E_ARGUMENT',model.set_tab,r,1,unknown,spend); assert(r.dashboard==before)
  model.set_tab(r,1,tab(),spend); assert(r.dashboard==before,'identical definition replaced identity')
  model.set_leaf(r,1,'status','Changed',false,spend)
  assert(r.dashboard.tabs['1'].generation==before.tabs['1'].generation)
  assert(before.tabs['1'].definition.content.children[1].text=='Ready')
  model.set_leaf(r,1,'ack',false,true,spend)
  assert(not model.widget(r.dashboard.tabs['1'],'ack').enabled)
  refused('E_ARGUMENT',model.set_leaf,r,1,'status',true,true,spend)
  refused('E_NOT_FOUND',model.set_leaf,r,1,'missing','x',false,spend)
  before=r.dashboard
  local requested=tab(string.rep('x',500))
  local candidate=model.replace(before,'1',model.definition(requested,spend),spend)
  local bytes=model.usage(candidate,spend)
  local ceiling=limits.state_bytes
  limits.state_bytes=bytes-1
  local ok,e=pcall(model.set_tab,r,1,requested,spend)
  limits.state_bytes=ceiling
  assert(not ok and e.code=='E_CAPACITY' and r.dashboard==before,'one-byte-short mutation')
  local copied=data.copy(before.tabs['1'].definition,spend); copied.title='caller mutation'
  assert(before.tabs['1'].definition.title=='Overview')
  limits.state_bytes=1
  local grandfathered,problem=pcall(function()
    model.set_leaf(r,1,'status','Changed',false,spend)
    model.set_leaf(r,1,'status','',false,spend)
    assert(model.equal(model.import(r.dashboard,spend),r.dashboard))
  end)
  limits.state_bytes=ceiling
  assert(grandfathered,serpent.line(problem))
  local target={kind='dashboard',dashboard=model.new()}
  model.set_tab(target,1,tab(string.rep('x',4000)),spend)
  model.set_tab(target,2,tab('small'),spend)
  local previous=target.dashboard
  local bytes=model.usage(previous,spend)
  limits.state_bytes=bytes-1
  local copied,copy_error=pcall(snapshots.apply_settings,target,{version=1,kind='dashboard',dashboard={version=1,tabs={['2']=tab(string.rep('y',3500))}}})
  limits.state_bytes=ceiling
  assert(copied,serpent.line(copy_error))
  assert(not target.dashboard.tabs['1'] and model.usage(target.dashboard,spend)<bytes,'fitting whole settings replacement was not admitted atomically')
  local committed=target.dashboard
  refused('E_ARGUMENT',snapshots.apply_settings,target,{version=1,kind='dashboard',dashboard={version=1,tabs={
    ['1']=tab('staged'),['2']={title='Invalid',content={type='unsupported',id='bad'}}}}})
  assert(target.dashboard==committed,'invalid later settings tab published a prefix')
  local chart={title='Charts',content={type='column',id='root',children={
    {type='line',id='line',series={'a','b'},capacity=3},
    {type='stacked_bars',id='bars',phases={'work','wait'}}}}}
  if not model.charts then
    refused('E_UNSUPPORTED',model.set_tab,r,1,chart,spend)
    model.set_tab(r,1,chart,spend,true)
    assert(r.dashboard.tabs['1'].charts.line.length==3)
  else
    local boundary={dashboard=model.new()}
    local series={}; for i=1,model.charts.colors.get_max_series() do series[i]='series'..i end
    local definition={title='Boundary',content={type='line',id='line',series=series,capacity=2}}
    model.set_tab(boundary,1,definition,spend)
    series[#series+1]='excess'
    refused('E_RANGE',model.set_tab,boundary,1,definition,spend)
    definition.content.series={'same','same'}
    refused('E_ARGUMENT',model.set_tab,boundary,1,definition,spend)
    definition.content.series={'one'}; definition.content.capacity=1
    refused('E_RANGE',model.set_tab,boundary,1,definition,spend)
    definition.content.capacity=2; definition.content.format='numeric-bars'
    refused('E_RANGE',model.set_tab,boundary,1,definition,spend)
    model.set_tab(boundary,1,{title='Bars',content={type='stacked_bars',id='bars',phases={'work'}}},spend)
    local bars={}; for i=1,model.bar_entries do bars[i]={work=0} end
    model.bars(boundary,1,'bars',bars,spend)
    local accepted=boundary.dashboard
    bars[#bars+1]={work=0}; refused('E_RANGE',model.bars,boundary,1,'bars',bars,spend)
    assert(boundary.dashboard==accepted)
    assert((900/32-2-.1*(model.bar_entries+1))/model.bar_entries>0)
    assert((900/32-2-.1*(model.bar_entries+2))/(model.bar_entries+1)<=0)
    model.set_tab(r,1,chart,spend)
    for i=1,5 do model.append(r,1,'line',{a=i,b=2*i},spend) end
    local ring=r.dashboard.tabs['1'].charts.line
    assert(ring.index==2 and ring.sum.a==12 and ring.counts.a==3 and ring.data[3].a==3 and ring.data[1].a==4 and ring.data[2].a==5)
    local actual=data.measure(r.dashboard,spend)
    local reserved_bytes,reserved_nodes=model.usage(r.dashboard,spend)
    assert(actual.bytes==reserved_bytes and actual.nodes==reserved_nodes,'full ring reservation differs from retained graph')
    model.set_tab(r,1,chart,spend); assert(r.dashboard.tabs['1'].charts.line==ring)
    model.bars(r,1,'bars',{{work=1,wait=2}},spend)
    local beforebars=r.dashboard
    refused('E_RANGE',model.bars,r,1,'bars',{{work=-1,wait=2}},spend); assert(r.dashboard==beforebars)
    refused('E_ARGUMENT',model.append,r,1,'line',{a=1,b=2,extra=3},spend)
    refused('E_RANGE',model.append,r,1,'line',{a=1},spend)
    refused('E_RANGE',model.append,r,1,'line',{a=1e308,b=1e308},spend)
    assert(ring.index==2 and ring.sum.a==12,'grid overflow changed retained samples')
    refused('E_RANGE',model.bars,r,1,'bars',{{work=1e308,wait=0}},spend)
    model.clear(r,1,'line',spend); ring=r.dashboard.tabs['1'].charts.line
    refused('E_RANGE',model.append,r,1,'line',{a=1e308,b=-1e308},spend)
    assert(ring.index==0 and #ring.data==0,'cross-series overflow changed empty ring')
    model.append(r,1,'line',{a=1e308,b=1e308},spend)
    local index,sum=ring.index,ring.sum.a
    refused('E_RANGE',model.append,r,1,'line',{a=1e308,b=1e308},spend)
    assert(ring.index==index and ring.sum.a==sum,'refused append changed ring')
    local changed=data.copy(chart,spend); changed.content.children[1].format='time'
    model.set_tab(r,1,changed,spend); assert(r.dashboard.tabs['1'].charts.line==ring)
    changed.content.children[1].capacity=4; model.set_tab(r,1,changed,spend)
    assert(r.dashboard.tabs['1'].charts.line~=ring and #r.dashboard.tabs['1'].charts.line.data==0)
    model.clear(r,1,'bars',spend); assert(#r.dashboard.tabs['1'].charts.bars==0)
  end
  log('TC_DASHBOARD_CONTRACT base-shapes-atomicity-reservation-charts')
end
return M
