-- Production-owner budget/fairness fixture. Prepared probe frames are trusted
-- setup, not a claim that guests can allocate a full frame in one callback.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local lifecycle=require('scripts.lifecycle')
local network=require('scripts.network')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local renderer=require('scripts.rendering')
local native=require('tests.monitor_buffer_engine').native
local M={}; local loaded=false
local function f() return storage.tc_budget_live end
local function nop() end
local source=[[function start(e) computer.setState('beats',0); computer.setState('notifications',0); computer.every(1,'beat'); computer.every(7,'notify') end

function beat(e) computer.setState('beats',computer.getState('beats')+1) end

function notify(e) computer.setState('notifications',computer.getState('notifications')+1) end]]
local function fuel(x)
  for _,id in ipairs(x.nodes) do
    local r=assert(registry.record(id)); assert(not r.children.power)
  end
end
local function render(tick,spend)
  local x=f(); if not x or x.phase~='running' then return end
  if not x.cleanup_queued and registry.get().monitors then
    spend(8); renderer.retire(registry.get().monitors,{cells={},panel=x.cleanup_object}); x.cleanup_queued=true
  end
  if registry.get().scheduler.render_reserved_work>60000 then
    local profiler=helpers.create_profiler(); local work=0
    for _,path in ipairs(x.paths) do
      assert(network.validate_witness(registry.computer(x.computer),'red',path,function(n) spend(n); work=work+n end))
    end
    native.publish(x,tick,spend)
    profiler.stop(); log({'','TC_BUDGET_PUBLISH_CPU ',profiler})
    x.proof_work=work; x.last_publish_work=work+native.work(x)
    for _,row in ipairs(x.frames) do row.front,row.back=row.back,row.front end
  end
end
scheduler.register_phase('render','00-budget-probe',render)
scheduler.register_phase('render','zz-budget-demand',function(tick,spend)
  local x=f()
  if x and x.phase=='running' then scheduler.request_render_work(registry.get(),tick,160000,spend) end
end)
function M.run()
  local x={case=2,nodes={},paths={},boosts=0,baseline=0,steps=0,max_maintenance=0,max_host=0,phase='setup'}
  storage.tc_budget_live=x
  x.cleanup_object=rendering.draw_sprite{surface=1,sprite='tc-monitor-fill',target={0,0},visible=false}
  native.start(x)
  while not native.stage(x,'front',true,nop) do end
  while not native.stage(x,'back',false,nop) do end
  for i=1,limits.network_nodes do
    local y=math.floor((i-1)/16); local col=(i-1)%16
    if y%2==1 then col=15-col end
    local kind=i==1 and 'computer' or 'monitor'
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,
      position={24-col*3,24-y*3},force='player'})
    local r=assert(lifecycle.build(body)); x.nodes[i]=r.id
    if i>1 then assert(lifecycle.connector(registry.record(x.nodes[i-1]),'network','red').connect_to(lifecycle.connector(r,'network','red'))) end
  end
  x.computer=x.nodes[1]; fuel(x)
  for _,id in ipairs(x.nodes) do registry.record(id).powered=true end
  local c=registry.computer(x.computer)
  local _,parents=network.discover(c,'red',nop)
  for i=#x.nodes-3,#x.nodes do x.paths[#x.paths+1]=network.witness(c,registry.record(x.nodes[i]),parents,nop) end
  assert(#x.paths[4]==256)
  assert(runtime.save(c.id,source,c.saved_revision))
  assert(runtime.activate(c.id,game.tick))
  scheduler.request_render_work(registry.get(),game.tick,160000,nop)
  x.phase='running'
end
function M.on_load() loaded=true end
function M.on_configuration_changed() error('configuration change is not this fixture phase') end
function M.on_tick(event)
  local x=f(); if not x or x.phase=='done' then return end
  local root=registry.get()
  if x.phase=='frozen' then
    if not loaded then return end
    local saved=x.saved; local s=root.scheduler; local p=root.monitors.job.partition
    assert(p==saved.partition and p.ordered==saved.ordered and p.item==saved.item)
    assert(p.sort_index==saved.sort_index and p.sort_cursor==saved.sort_cursor and p.cursor==saved.cursor)
    assert(s.maintenance_tick==saved.tick and s.maintenance_spent==saved.spent and s.render_reserved_work==saved.reserved)
    assert(s.last_render_boost_tick==saved.last_boost and registry.computer(x.computer).state.beats==saved.beats)
    local old=scheduler.maintenance(root,saved.tick,true)
    assert(not scheduler.try_maintenance(function() old(1) end))
    assert(not scheduler.try_maintenance(function() scheduler.request_render_work(root,saved.tick,0,old) end))
    assert(s.render_demand_work==160000 and s.maintenance_spent==saved.spent and s.render_reserved_work==saved.reserved)
    log('TC_BUDGET_COLD_RETAINED'); x.phase='running'; loaded=false; x.resumed=true
  end
  fuel(x) -- Trusted refill outside the measured scheduler; no factory-grid claim.
  local previous_sequence=x.sequence
  local profiler=helpers.create_profiler()
  scheduler.tick(event.tick)
  profiler.stop()
  if x.sequence~=previous_sequence then native.visibility(x,true,false) end -- Observer outside scheduler CPU sample.
  local s=root.scheduler; local c=registry.computer(x.computer)
  assert(c.status=='running',serpent.line(c.diagnostic))
  assert(s.maintenance_spent<=limits.maintenance_work_per_tick and root.ledger.total<=limits.host_work_per_tick)
  local monitors=root.monitors; local p=monitors and monitors.presentation
  if p and p.demand_version==1 then
    local count=0
    for key,lane in pairs(p.work) do assert(lane==p.lanes[key] and lane.key==key); count=count+1 end
    assert(count<=#monitors.order,'singleton demand grew beyond physical groups')
    local rec=registry.record(x.nodes[2]); local g=monitors.groups[monitors.membership[rec.id]]
    if g then
      local lane=assert(p.lanes[g.id]); local existed=p.work[lane.key]~=nil
      for _=1,32 do registry.monitor_changed(rec,false) end
      local after=0; for _ in pairs(p.work) do after=after+1 end
      assert(after==count+(existed and 0 or 1) and p.work[lane.key]==lane,'burst notifications duplicated demand')
      x.demand_witness=true
    end
  end
  local spent,reserved,seq=s.maintenance_spent,s.render_reserved_work,x.sequence
  scheduler.tick(event.tick)
  assert(s.maintenance_spent==spent and s.render_reserved_work==reserved and x.sequence==seq,'same-tick scheduler replay')
  x.steps=x.steps+1; assert(x.steps<300,'budget scenario failed forward-progress deadline')
  x.max_maintenance=math.max(x.max_maintenance,spent); x.max_host=math.max(x.max_host,root.ledger.total)
  if reserved>60000 then
    assert(not x.previous_boost or event.tick-x.previous_boost>=2,'consecutive boosted reservations')
    x.previous_boost=event.tick; x.boosts=x.boosts+1
  else x.baseline=x.baseline+1 end
  if x.steps%20==0 or reserved>60000 and x.boosts%20==0 then
    log({'','TC_BUDGET_SCHEDULER_CPU step=',x.steps,' reserved=',reserved,' ',profiler})
  end
  local p=root.monitors and root.monitors.job and root.monitors.job.partition
  if not x.saved and p and p.stage=='sort' and p.item then
    scheduler.maintenance(root,event.tick,true)(limits.maintenance_work_per_tick-s.maintenance_spent)
    x.saved={partition=p,ordered=p.ordered,item=p.item,sort_index=p.sort_index,sort_cursor=p.sort_cursor,cursor=p.cursor,
      tick=event.tick,spent=s.maintenance_spent,reserved=reserved,last_boost=s.last_render_boost_tick,beats=c.state.beats}
    x.phase='frozen'; loaded=false
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.resumed and not root.monitors.job and #root.monitors.order==255 then
    assert(c.state.beats>=20 and c.state.notifications>=1 and x.boosts>=3 and x.baseline>=3 and x.sequence>=3)
    assert(x.cleanup_queued and not x.cleanup_object.valid,'retirement made no progress')
    assert(x.demand_witness); log('TC_BUDGET_DEMAND_DEDUP_OK')
    assert(x.proof_work==20296 and x.last_publish_work==147384)
    log('TC_BUDGET_FAIR_OK steps='..x.steps..' boosts='..x.boosts..' baseline='..x.baseline..
      ' beats='..c.state.beats..' notifications='..c.state.notifications..' publications='..x.sequence..' groups='..#root.monitors.order..
      ' max_maintenance='..x.max_maintenance..' max_host='..x.max_host)
    x.phase='done'; log('TC_COLD_OK')
  end
end
return M
