-- Real powered/circuit setups for every exact embedded document. GUI input is
-- covered separately by the client fixture; this test never substitutes API mocks.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local kv=require('scripts.services.kv')
local logic=require('scripts.services.logic')
local help=require('scripts.ui.help')
local defs=require('scripts.device-definitions')
local peripheral=require('scripts.services.peripheral')
local dashboard=require('scripts.dashboard-model')
local M={}; local loaded=false
local function build(kind,x,y)
  return assert(lifecycle.build(assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
end
local function connect(a,b,color,ar,br)
  local function socket(r,role)
    if r.native_carrier then return r.body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true) end
    return lifecycle.connector(r,role or 'network',color)
  end
  assert(socket(a,ar).connect_to(socket(b,br),false))
end
local function wire(entity,rec,color,role)
  assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(rec,role,color),false))
end
local function start(c,code)
  runtime.save(c.id,code,c.saved_revision); local ok,e=runtime.activate(c.id,game.tick); assert(ok,serpent.line(e))
end
local function report(name) log('TC_CONTRACT reference-tutorial-'..name) end
local function stock_scene(c,x,combined)
  local s=game.surfaces[1]; local io=build('logic',x+4,0); connect(c,io,'red')
  local stock=assert(s.create_entity{name='steel-chest',position={x+4,-3},force='player'})
  stock.insert{name='iron-plate',count=5}; stock.get_or_create_control_behavior().read_contents=true
  wire(stock,io,'red','input')
  local supply=assert(s.create_entity{name='steel-chest',position={x+8,0},force='player'}); supply.insert{name='iron-plate',count=200}
  local destination=assert(s.create_entity{name='steel-chest',position={x+8,2},force='player'})
  local inserter=assert(s.create_entity{name='inserter',position={x+8,1},direction=defines.direction.north,force='player'})
  wire(inserter,io,'green','output')
  local cb=inserter.get_or_create_control_behavior()
  cb.circuit_enable_disable=true; cb.circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=0}
  local scene={computer=c.id,io=io.id,stock=stock,destination=destination,inserter=inserter}
  if combined then
    local db=build('kv',x,3); local screen=build('monitor',x+2,3); local cfg=build('configurator',x+5,3)
    connect(c,db,'red');connect(c,screen,'red');connect(c,cfg,'red');wire(inserter,cfg,'green','targets')
    cb.circuit_enable_disable=false -- the actual tutorial must configure it
    scene.db=db.id;scene.screen=screen.id;scene.cfg=cfg.id
  end
  return scene
end
function M.run()
  local s=game.surfaces[1];s.request_to_generate_chunks({90,0},7);s.force_generate_chunk_requests();s.always_day=true
  local tiles={};for x=-12,270 do for y=-10,12 do tiles[#tiles+1]={name='landfill',position={x,y}} end end;s.set_tiles(tiles)
  for _,e in ipairs(s.find_entities_filtered{area={{-12,-10},{270,12}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local x={phase='boot',since=game.tick,origin=game.tick,programs={},results={}}
  storage.tc_reference_tutorials=x
  for i,id in ipairs({'starter','speaker','logic','recipe','factory','shared','statistics','dashboard','dashboard_charts'}) do
    local px=(i-1)*30;local c=build('computer',px,0)
    x.programs[#x.programs+1]={id=id,computer=c.id,code=help.tutorials[id].prelude or help.tutorials[id].code}
    assert(s.create_entity{name='substation',position={px+4,4},force='player'})
    local power=assert(s.create_entity{name='electric-energy-interface',position={px+7,7},force='player'})
    power.power_production=100000000;power.power_usage=0
    if id=='speaker' then
      local speaker=assert(lifecycle.build(assert(s.create_entity{name='programmable-speaker',position={px+3,0},force='player'})))
      connect(c,speaker,'red');x.speaker=speaker.id
    elseif id=='recipe' then
      local search=build('recipe_searcher',px+3,0);connect(c,search,'red');x.recipe=search.id
      local encyclopedia=build('factoriopedia_interface',px+9,0);connect(search,encyclopedia,'red')
      local radar=assert(lifecycle.build(assert(s.create_entity{name='radar',position={px+6,0},force='player'})))
      connect(c,radar,'red')
    elseif id=='statistics' then
      local stats=build('production_statistics',px+3,0); connect(c,stats,'red'); x.statistics=stats.id
      x.statistics_computer=c.id
    elseif id=='dashboard' or id=='dashboard_charts' then
      local panel=build('dashboard',px+3,0); connect(c,panel,'red'); x[id]=panel.id
    elseif id=='logic' or id=='factory' then x[id]=stock_scene(c,px,id=='factory')
    elseif id=='shared' then
      local db=build('kv',px+3,0);local independent=build('kv',px+3,-3);local observer=build('computer',px,-3)
      connect(c,db,'red');connect(observer,db,'red');connect(observer,independent,'green')
      x.shared={writer=c.id,observer=observer.id,db=db.id,independent=independent.id}
      x.programs[#x.programs+1]={id='shared-observer',computer=observer.id,code=help.tutorials.shared.code}
    end
  end
  report('documented-native-setups-created')
end
function M.on_load() loaded=true end
local function healthy(c) assert(c.status=='running',serpent.line(c.diagnostic)) end
local function row(screen,y)
  local g=assert(monitor.resolve(registry.record(screen)));local out={}
  for column=1,g.model.width do out[#out+1]=string.char(g.model.cells[(y-1)*g.model.width+column][1]) end
  return table.concat(out)
end
local function inventory(x,tick)
  local topics={};for _,topic in ipairs(help.topics) do topics[topic.id or topic.category]=topic end
  local ledger={}
  local function check(topic,methods)
    local signatures={}
    for _,block in ipairs(topic.blocks) do
      if block.kind=='signature' then signatures[assert(block.text:match('^([%w_]+)%('))]=true end
    end
    local names={}
    for name in pairs(methods) do assert(signatures[name],'undocumented live method '..name);names[#names+1]=name end
    for name in pairs(signatures) do
      local optional=topic.id=='peripheral.dashboard' and not dashboard.charts and (name=='appendSample' or name=='setBars' or name=='clearChart')
      assert(methods[name] or name=='find' or optional,'stale documented method '..name)
    end
    table.sort(names);ledger[topic.title]=names
  end
  -- Host-only read inventory, not a latency/budget benchmark. Real traversal,
  -- identity and method providers are used; no guest effects are invoked.
  local guard={spend=function() end,check=function() end,accept_handle=function() end}
  local c=registry.record(x.factory.computer)
  local namespaces=runtime.services(c,tick,guard)
  -- sandbox.lua installs the fatal stop intrinsic after service composition;
  -- tests.api_inventory additionally exercises it as a compiled guest member.
  namespaces.computer.stop=true
  check(assert(topics.Computer),namespaces.computer)
  check(assert(topics['peripheral.discovery']),namespaces.peripheral)
  local seen={}
  for _,entry in ipairs(x.programs) do
    local rec=registry.record(entry.computer)
    local api=peripheral.services(rec,tick,guard).peripheral
    for _,name in ipairs(api.getNames('red')) do
      local kind=api.getType(name,'red')
      if not seen[kind] then
        local methods={};for _,method in ipairs(api.getMethods(name,'red')) do methods[method]=true end
        check(assert(topics['peripheral.'..kind]),methods);seen[kind]=true
      end
    end
  end
  for _,kind in ipairs({'speaker','modem','monitor','logic_handler','configurator','recipe_searcher','factoriopedia_interface','production_statistics','kv_database','dashboard'}) do assert(seen[kind],kind) end
  helpers.write_file('reference-coverage.json',helpers.table_to_json{topics=help.topics,inventory=ledger},false)
  report('live-discovery-computer-and-ten-service-inventories-match-help')
end
function M.on_tick(event)
  local x=storage.tc_reference_tutorials
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    for _,program in ipairs(x.programs) do assert(registry.record(program.computer).saved_source==program.code) end
    assert(registry.record(x.programs[1].computer).state.samples>=2)
    report('cold-exact-source-and-results-retained');x.phase='done';log('TC_COLD_OK');return
  end
  loaded=false;scheduler.tick(event.tick)
  assert(event.tick-x.origin<1800,'tutorial deadline '..x.phase)
  if x.phase=='boot' and event.tick-x.since>=5 then
    x.next=1;x.phase='start'
  elseif x.phase=='start' then
    local p=x.programs[x.next]
    if p then start(registry.record(p.computer),p.code);x.next=x.next+1
    else x.phase='observe';x.since=event.tick end
  elseif x.phase=='observe' and event.tick-x.since>=150 then
    for _,p in ipairs(x.programs) do healthy(registry.record(p.computer)) end
    local starter=registry.record(x.programs[1].computer)
    assert(starter.state.samples>=3 and starter.logs[1].text=='Initial sample count:\t1');report('starter-immediate-and-recurring-counter')
    local speaker=registry.record(x.programs[2].computer)
    assert(speaker.logs[1].text=='Note submitted:\ttrue');report('speaker-native-note-submission')
    local recipes=registry.record(x.programs[4].computer);local found=false
    for _,entry in ipairs(recipes.logs) do if entry.text=='iron-plate' then found=true end end
    assert(found and recipes.logs[1].text:match('Iron plate smelting recipes:\t[1-9]'));report('recipe-actual-smelting-results')
    for _,id in ipairs({'logic','factory'}) do
      local scene=x[id];local io=registry.record(scene.io)
      local output=logic.inspect_output(io,function() end)
      assert(output[1].signal.name=='signal-A' and output[1].count==1)
      assert(scene.destination.get_item_count('iron-plate')>0,'native inserter must transfer actual items')
      scene.stock.insert{name='iron-plate',count=95}
    end
    assert(row(x.factory.screen,1):find('Iron: 5',1,true) and row(x.factory.screen,2):find('FILLING',1,true))
    assert(registry.record(x.factory.db).database.entries['stock:iron'].fields.count=='5')
    report('logic-and-factory-real-inserter-transfer-monitor-and-kv')
    local observer=registry.record(x.shared.observer)
    assert(observer.state.shared_status=='FILLING' and observer.state.shared_count=='5' and observer.state.private_status=='absent',serpent.line(observer.state))
    assert(registry.record(x.shared.db).database.entries.observer.value==observer.id)
    assert(registry.record(x.shared.independent).database.entries.observer.value=='private')
    assert(observer.logs[1].text=='FILLING / private=private');report('two-computer-shared-and-physically-independent-storage')
    assert(registry.record(x.statistics_computer).state.statistics_example)
    report('statistics-exact-embedded-example')
    assert(dashboard.widget(registry.record(x.dashboard).dashboard.tabs['1'],'status').text=='Ready')
    local panel=registry.record(x.dashboard_charts)
    assert(panel.dashboard.tabs['6'].definition.title=='Panel 6')
    if dashboard.charts then
      local ring=panel.dashboard.tabs['1'].charts.trend
      assert(#ring.data==8 and ring.index==4 and ring.sum.input==68)
    end
    report('dashboard-exact-embedded-programs-and-optional-chart-wrap')
    inventory(x,event.tick)
    x.phase='high';x.since=event.tick
  elseif x.phase=='high' and event.tick-x.since>=120 then
    for _,id in ipairs({'logic','factory'}) do
      assert(#logic.inspect_output(registry.record(x[id].io),function() end)==0)
      x[id].settled=x[id].destination.get_item_count('iron-plate')
    end
    assert(row(x.factory.screen,1):find('Iron: 100',1,true) and row(x.factory.screen,2):find('STOPPED',1,true))
    x.phase='settled';x.since=event.tick
  elseif x.phase=='settled' and event.tick-x.since>=60 then
    for _,id in ipairs({'logic','factory'}) do assert(x[id].destination.get_item_count('iron-plate')==x[id].settled) end
    report('both-thresholds-and-settled-native-inserter-stop')
    for _,p in ipairs(x.programs) do runtime.stop(p.computer) end
    assert(not registry.record(x.factory.io).output_owner)
    x.phase='expiry';x.since=event.tick
  elseif x.phase=='expiry' and event.tick-x.since>=200 then
    assert(kv.methods.type(nil,registry.record(x.factory.db),'red',event.tick,function() end,'stock:iron')=='none')
    assert(row(x.factory.screen,2):find('STOPPED',1,true));report('stop-owned-output-cleanup-display-retention-and-ttl-expiry')
    -- Disconnect the documented service paths, then execute the SAME documents.
    for _,p in ipairs(x.programs) do
      local c=registry.record(p.computer)
      for _,color in ipairs({'red','green'}) do lifecycle.connector(c,'network',color).disconnect_all() end
    end
    x.next=2;x.phase='fail-start'
  elseif x.phase=='fail-start' then
    local p=x.programs[x.next]
    if p then start(registry.record(p.computer),p.code);x.next=x.next+1
    else x.phase='fail-observe';x.since=event.tick end
  elseif x.phase=='fail-observe' and event.tick-x.since>=100 then
    for i=2,#x.programs do
      local c=registry.record(x.programs[i].computer)
      assert(c.status=='faulted' and c.diagnostic,'documented absent path must fault '..x.programs[i].id)
      x.results[x.programs[i].id]={status=c.status,diagnostic=c.diagnostic}
    end
    report('same-documents-absent-wiring-failures-not-synthetic-output')
    helpers.write_file('reference-tutorials.json',helpers.table_to_json{programs=x.programs,failures=x.results,passed=true},false)
    x.phase='frozen';game.server_save('tc03-snapshot');log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
