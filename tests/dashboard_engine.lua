-- Packaged physical/model/guest/cold contracts. No claim of native player input.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local scheduler=require('scripts.scheduler')
local model=require('scripts.dashboard-model')
local data=require('scripts.runtime.data')
local limits=require('scripts.runtime.limits')
local snapshot=require('scripts.lifecycle-data')
local contracts=require('tests.dashboard_contract')
local gui_contracts=require('tests.dashboard_gui_contract')
local event_contracts=require('tests.dashboard_events_contract')
local render_contracts=require('tests.dashboard_render_contract')
local M={}; local resumed=false
local function f() return storage.tc_dashboard_fixture end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body)); assert(body.minable_flag); return rec
end
local function guest(c,body)
  local ctx=runtime.context(c,game.tick)
  local plan,e=compiler.compile('function start() '..body..' end',ctx)
  assert(plan,serpent.line(e))
  local ok,problem=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(problem))
end
local idle=[[function start() end

function clicked(e) computer.setState('clicks',(computer.getState('clicks') or 0)+1); computer.setState('last',e) end]]
function M.run()
  contracts.run()
  gui_contracts.run()
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},2); surface.force_generate_chunk_requests()
  local tiles={}; for y=-10,10 do for x=-10,20 do tiles[#tiles+1]={name='landfill',position={x,y}} end end; surface.set_tiles(tiles)
  local panel=build('dashboard',3,0); local c=build('computer',0,0); local second=build('computer',0,3)
  local third=build('computer',3,3)
  for _,wire in ipairs({'red','green'}) do
    assert(lifecycle.connector(c,'network',wire).connect_to(lifecycle.connector(panel,'network',wire)))
    assert(lifecycle.connector(second,'network',wire).connect_to(lifecycle.connector(panel,'network',wire)))
    assert(lifecycle.connector(third,'network',wire).connect_to(lifecycle.connector(panel,'network',wire)))
  end
  for _,direction in ipairs({4,8,12,0}) do
    local previous=panel.body.direction; panel.body.direction=direction
    lifecycle.on_rotated{entity=panel.body,previous_direction=previous}
    assert(panel.direction==direction and panel.body.direction==direction)
    for _,wire in ipairs({'red','green'}) do assert(lifecycle.connector(panel,'network',wire).real_connection_count==3) end
  end
  local empty=build('dashboard',12,-3)
  local power=assert(surface.create_entity{name='electric-energy-interface',position={9,0},force='player'})
  power.power_production=100000000; power.power_usage=0
  assert(surface.create_entity{name='substation',position={6,0},force='player'})
  assert(prototypes.item['tc-dashboard'].type=='item-with-tags' and prototypes.item['tc-dashboard'].stack_size==1)
  assert(prototypes.entity['tc-dashboard-shell'].tile_width==1 and prototypes.entity['tc-dashboard-shell'].tile_height==1)
  local force=game.create_force('tc-dashboard-researched'); force.technologies['tc-circuit-computers'].researched=true
  lifecycle.unlocks(); assert(force.recipes['tc-dashboard'].enabled)
  for _,r in ipairs({c,second,third}) do assert(runtime.save(r.id,idle,0)); assert(runtime.activate(r.id,game.tick)) end
  storage.tc_dashboard_fixture={phase='power',start=game.tick,panel=panel.id,computer=c.id,second=second.id,third=third.id,empty=empty.id}
  log('TC_DASHBOARD physical-powered-network-research-item')
end
function M.on_load() resumed=f().phase=='frozen' end
function M.on_configuration_changed() error('unexpected dashboard configuration change') end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local panel=registry.record(x.panel); local c=registry.record(x.computer); local second=registry.record(x.second)
  if x.empty then
    local empty=assert(registry.record(x.empty)); local power_part=empty.children.power
    local inventory=game.create_inventory(4)
    assert(empty.body.mine{inventory=inventory,raise_destroyed=true})
    local drops=0
    for i=1,#inventory do if inventory[i].valid_for_read then
      assert(inventory[i].name=='tc-dashboard' and inventory[i].count==1); drops=drops+1
    end end
    assert(drops==1 and not registry.record(empty.id) and not power_part.valid,
      ('mining result: drops=%d registered=%s helper_valid=%s'):format(drops,tostring(registry.record(empty.id)~=nil),tostring(power_part.valid)))
    inventory.destroy(); x.empty=nil
    log('TC_DASHBOARD cardinal-native-contacts-empty-script-mine-single-drop'); return
  end
  if x.phase=='frozen' then
    if not resumed then return end
    assert(panel.dashboard==x.retained and panel.dashboard.tabs['1'].generation==x.layout)
    assert(c.state.calls==2 and second.state.calls==1 and c.run_id==x.run)
    x.phase='mine'; log('TC_DASHBOARD cold-retained-model-no-startup-replay'); return
  end
  assert(event.tick-x.start<600,'dashboard fixture deadline '..x.phase)
  if x.phase=='events' then
    if event_contracts.tick(c,second,registry.record(x.third),panel,guest,event.tick) then render_contracts.start(); x.phase='render' end
    return
  end
  if x.phase=='render' then
    if render_contracts.tick(panel,event.tick) then x.phase='save' end
    return
  end
  scheduler.tick(event.tick)
  assert(c.status=='running' and second.status=='running',serpent.line(c.diagnostic))
  if not panel.powered or not c.powered or not second.powered then return end
  if x.phase=='power' then
    if #c.queue>0 or #second.queue>0 then return end
    guest(c,[[local p=peripheral.find('dashboard','red'); assert(p)
      assert(peripheral.getType(peripheral.getName(p),'red')=='dashboard')
      assert(select('#',p.getTab(1))==1 and p.getTab(1)==nil)
      assert(select('#',p.setTab(1,{title='Overview',content={type='column',id='root',children={
        {type='label',id='label',text='Ready'},{type='button',id='button',text='Go'}}}}))==0)
      assert(p.getLimits().dashboard_tabs==6)
      local a=p.getTab(1); a.title='Not committed'; assert(p.getTab(1).title=='Overview')
      local sub=p.subscribe('clicked'); assert(type(sub)=='string'); assert(p.unsubscribe(sub)); assert(not p.unsubscribe(sub))
      computer.setState('calls',1)
    ]])
    x.phase='base-contracts'; return
  elseif x.phase=='base-contracts' then
    guest(c,[[local p=peripheral.find('dashboard','red')
      local function bad(code,fn,...)
        local ok,e=pcall(fn,...); assert(not ok and e.code==code)
      end
      bad('E_ARGUMENT',p.getTab); bad('E_ARGUMENT',p.getTab,1,2)
      bad('E_RANGE',p.getTab,'1'); bad('E_RANGE',p.getTab,0); bad('E_RANGE',p.getTab,1.5)
      bad('E_ARGUMENT',p.getLimits,1)
      bad('E_ARGUMENT',p.setTab,1); bad('E_ARGUMENT',p.setTab,1,false)
      bad('E_ARGUMENT',p.setTab,1,{title='Bad',content={type='label',id='x',text='x',color='red'}})
      bad('E_ARGUMENT',p.setTab,1,{title='Bad',content={type='row',id='x',children={{type='label',id='x',text='x'}}}})
      bad('E_ARGUMENT',p.setText,1,'label',false)
      bad('E_ARGUMENT',p.setText,1,'button','')
      bad('E_ARGUMENT',p.setEnabled,1,'button','yes')
      bad('E_ARGUMENT',p.setEnabled,1,'label',false)
      bad('E_NOT_FOUND',p.setText,1,'missing','x')
      assert(select('#',p.setText(1,'label',''))==0)
      assert(select('#',p.setText(1,'label','Ready'))==0)
      assert(select('#',p.setEnabled(1,'button',false))==0)
      assert(select('#',p.setEnabled(1,'button',true))==0)
      local limits=p.getLimits(); limits.dashboard_tabs=1; assert(p.getLimits().dashboard_tabs==6)
      for slot=2,6 do
        assert(select('#',p.setTab(slot,{title='Empty',content={type='row',id='empty',children={}}}))==0)
        assert(#p.getTab(slot).content.children==0)
      end
      assert(select('#',p.removeTab(6))==1); assert(not p.removeTab(6))
      for slot=2,5 do assert(p.removeTab(slot)) end
      assert(select('#',p.getTab(6))==1 and p.getTab(6)==nil)
      local expected={'setTab','getTab','removeTab','setText','setEnabled','subscribe','unsubscribe','getLimits'}
      local names=peripheral.getMethods(peripheral.getName(p),'red'); local found={}
      for _,name in ipairs(names) do found[name]=true end
      for _,name in ipairs(expected) do assert(found[name]) end
      if found.appendSample then assert(found.setBars and found.clearChart and #names==11)
      else assert(not found.setBars and not found.clearChart and #names==8 and p.appendSample==nil) end
    ]])
    log('TC_DASHBOARD real-guest-base-arity-types-empty-six-slots-return-counts-inventory')
    x.phase='second'; return
  elseif x.phase=='second' then
    guest(second,[[local p=peripheral.find('dashboard','green'); assert(p); p.setText(1,'label','Second writer'); computer.setState('calls',1)]])
    assert(model.widget(panel.dashboard.tabs['1'],'label').text=='Second writer')
    x.phase='first'; return
  elseif x.phase=='first' then
    guest(c,[[local p=peripheral.find('dashboard','red'); p.setText(1,'label','First writer again'); p.setEnabled(1,'button',false)
      assert(not p.getTab(1).content.children[2].enabled)
      local ok,e=pcall(p.setTab,7,{title='x',content={type='label',id='x',text='x'}}); assert(not ok and e.code=='E_RANGE')
      assert(p.getTab(1).content.children[1].text=='First writer again')
      computer.setState('calls',2)
    ]])
    local previous=panel.dashboard; local changed=data.copy(previous.tabs['1'].definition)
    changed.content.children[1].text=string.rep('x',500)
    local candidate=model.replace(previous,'1',changed,function() end)
    local bytes=model.usage(candidate,function() end); local ceiling=limits.state_bytes
    limits.state_bytes=bytes-1
    local ok,problem=pcall(guest,c,[[local p=peripheral.find('dashboard','red')
      local ok,e=pcall(p.setText,1,'label',string.rep('x',500)); assert(not ok and e.code=='E_CAPACITY')]])
    limits.state_bytes=ceiling
    assert(ok,serpent.line(problem)); assert(panel.dashboard==previous,'guest one-byte-short publication changed model')
    log('TC_DASHBOARD real-guest-one-byte-short-preserves-model')
    model.set_tab(panel,2,{title='Empty',content={type='column',id='empty',children={}}},function() end)
    limits.state_bytes=128
    local ok,problem=pcall(guest,c,[[local p=peripheral.find('dashboard','red')
      assert(p.getTab(1).content.children[1].text=='First writer again')
      assert(p.getLimits().dashboard_state_bytes==128)
      p.setText(1,'label','First writer again'); p.setEnabled(1,'button',false)
      assert(p.removeTab(2) and p.getTab(2)==nil)]])
    limits.state_bytes=ceiling
    assert(ok,serpent.line(problem))
    log('TC_DASHBOARD real-guest-grandfathered-read-nongrowth-remove')
    event_contracts.start(panel); x.phase='events'; return
  elseif x.phase=='save' then
    if #c.queue>0 then return end
    x.retained=panel.dashboard; x.layout=panel.dashboard.tabs['1'].generation; x.run=c.run_id
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  elseif x.phase=='mine' then
    local source=snapshot.dashboard_snapshot(panel)
    local inventory=game.create_inventory(1); inventory[1].set_stack{name='tc-dashboard',count=1}
    lifecycle.on_removed{entity=panel.body,buffer=inventory,tick=event.tick}; panel.body.destroy()
    assert(inventory[1].count==1 and model.equal(inventory[1].tags.tc_dashboard,source))
    local body=assert(game.surfaces[1].create_entity{name='tc-dashboard-shell',position={12,3},force='player'})
    lifecycle.on_built{entity=body,consumed_items=inventory}; local restored=assert(registry.by_entity(body))
    assert(restored.id~=x.panel and model.equal(restored.dashboard,x.retained))
    assert(restored.dashboard~=x.retained and not restored.subscriptions and not restored.status_art)
    local clone=build('dashboard',15,3); snapshot.apply_settings(clone,snapshot.settings(restored))
    assert(model.equal(clone.dashboard.tabs['1'].definition,restored.dashboard.tabs['1'].definition))
    assert(model.equal(clone.dashboard.tabs['1'].charts,{}))
    local before=restored.dashboard; local ok=pcall(snapshot.restore_dashboard,restored,{version=99,model={}})
    assert(not ok and restored.dashboard==before)
    inventory.destroy(); x.phase='done'; log('TC_DASHBOARD item-new-identity-configuration-only-malformed-atomic')
    log('TC_COLD_OK')
  end
end
return M
