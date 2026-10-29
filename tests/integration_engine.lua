-- Exact-archive production-context integration; GUI/player input uses explicit doubles.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local kv=require('scripts.services.kv')
local logic=require('scripts.services.logic')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local editor=require('scripts.ui.editor')
local interaction=require('scripts.ui.interaction')
local players=require('tests.editor_contract')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local art=require('scripts.device-art')
local sources={factoriopedia=require('examples.factoriopedia-program'),recipe_searcher=require('examples.recipe-searcher-program'),factory=require('examples.factory-controller'),observer=require('examples.shared-telemetry'),
  logic=require('examples.logic-controller'),kv=require('examples.kv-program'),monitor=require('examples.monitor-program'),
  peripheral=require('examples.peripheral-program'),configurator=require('examples.configurator-program'),sections=require('examples.configurator-sections'),inventory=require('tests.api_inventory')}
local contract_programs=require('examples.planning-programs')
for _,program in ipairs(contract_programs) do sources[program.name]=program.source end
local M={}; local loaded=false
local function f() return storage.tc13 end
local function nop() end
local function report(name) log('TC_INTEGRATION '..name) end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local rec=assert(lifecycle.build(body)); lifecycle.power_entity(rec).energy=defs.devices[kind].watts/30; return rec
end
local function connect(a,b,color,ar,br)
  assert(lifecycle.connector(a,ar or 'network',color).connect_to(lifecycle.connector(b,br or 'network',color)))
end
local function wire(entity,rec,color,role)
  assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(rec,role,color)))
end
local function submit(c,source,index,save_only,action)
  local p=players.player(index or 7101,c.body); local real=game; local tick=game.tick
  local ok,e=pcall(function()
    game={tick=tick,get_player=function(i) if i==p.index then return p end end,connected_players={p}}
    assert(editor.open(p,c.id)); local frame=p.gui.screen[editor.frame_name]
    frame.content.editor.source.text=source
    editor.on_text{player_index=p.index,element=frame.content.editor.source,tick=tick}
    editor.on_click{player_index=p.index,element=frame.content.editor.actions.save,tick=tick}
    assert(c.saved_source==source,'actual Save must consume draft text')
    if not save_only then
      editor.on_click{player_index=p.index,element=frame.content.editor.actions.activate,tick=tick}
      assert(c.status=='running' and c.active.source==source,serpent.line(c.candidate_diagnostic))
    end
    editor.on_click{player_index=p.index,element=frame.title.close,tick=tick}
  end)
  game=real; if not ok then error(e,0) end
end
function M.run()
  assert(script.get_event_handler('tc-interact')==interaction.on_input,'production Ctrl-click must use the shared router')
  assert(script.get_event_handler(defines.events.on_gui_opened)==interaction.on_opened,'native open must only suppress implementation dialogs')
  storage.tc13={phase='boot',start=game.tick,samples={},groups=0}
  local s=game.surfaces[1]; local tiles={}
  for y=-16,16 do for x=-16,24 do tiles[#tiles+1]={name='landfill',position={x,y}} end end
  s.set_tiles(tiles)
  for _,e in ipairs(s.find_entities_filtered{area={{-16,-16},{24,16}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local c=build('computer',0,0); local db=build('kv',3,0); local io=build('logic',6,0); local cfg=build('configurator',3,3)
  connect(c,db,'red'); connect(db,io,'red'); connect(db,cfg,'red')
  local searcher=build('recipe_searcher',6,3); connect(cfg,searcher,'red')
  local encyclopedia=build('factoriopedia_interface',9,3); connect(searcher,encyclopedia,'red')
  local statistics=build('production_statistics',12,3); connect(encyclopedia,statistics,'red')
  local dashboard=build('dashboard',15,3); connect(statistics,dashboard,'red')
  local tiles0={}; for y=4,5 do for x=0,1 do tiles0[#tiles0+1]=build('monitor',x,y).id end end
  connect(db,registry.record(tiles0[1]),'red')
  local observer=build('computer',0,-3); local private=build('kv',-3,-3)
  connect(observer,db,'red'); connect(observer,private,'green')
  f().c=c.id; f().db=db.id; f().io=io.id; f().cfg=cfg.id; f().observer=observer.id; f().private=private.id; f().tiles=tiles0
  local stock=assert(s.create_entity{name='steel-chest',position={8,-3},force='player'})
  stock.insert{name='iron-plate',count=5}; stock.get_or_create_control_behavior().read_contents=true
  wire(stock,io,'red','input'); f().stock=stock
  f().supply=assert(s.create_entity{name='steel-chest',position={10,0},force='player'})
  f().supply.insert{name='iron-plate',count=200}
  f().destination=assert(s.create_entity{name='steel-chest',position={10,2},force='player'})
  f().inserter=assert(s.create_entity{name='inserter',position={10,1},direction=defines.direction.north,force='player'})
  wire(f().inserter,io,'green','output'); wire(f().inserter,cfg,'green','targets')
  f().constant=assert(s.create_entity{name='constant-combinator',position={5,5},force='player'})
  wire(f().constant,cfg,'green','targets')
  f().power=assert(s.create_entity{name='electric-energy-interface',position={6,8},force='player'})
  f().power.power_production=100000000; f().power.power_usage=0
  for _,p in ipairs({{-4,3},{6,4},{14,4},{-5,-7}}) do s.create_entity{name='substation',position=p,force='player'} end
  -- Four useful compute neighbours on the same real tick ledger, not nested dispatch loops.
  f().busy={}
  for i=1,4 do local r=build('computer',-8+i*2,-8); f().busy[i]=r.id end
  report('production-native-wiring-and-powered-factory-armed')
end
local function snapshot()
  local c=registry.computer(f().c); local g=monitor.resolve(registry.record(f().tiles[1])); local root=registry.get()
  return {c=c,state=c.state,active=c.active,run=c.run_id,starts=c.state.starts,queue=c.queue,timers=c.timers,subscriptions=c.subscriptions,
    database=registry.record(f().db).database,model=g.model,render=g.render,revision=g.model.revision,
    ledger=root.ledger,total=root.ledger.total,tick=root.ledger.tick,maintenance=root.scheduler.maintenance_spent,
    enabled=c.state.enabled,config=f().inserter.get_control_behavior().circuit_condition.constant,art=c.status_art}
end
local function unchanged()
  local a,b=f().snapshot,snapshot()
  for _,key in ipairs({'c','state','active','run','starts','queue','timers','subscriptions','database','model','render','revision','ledger','total','tick','maintenance','enabled','config','art'}) do assert(a[key]==b[key],'cold changed '..key) end
end
function M.on_load() loaded=true; if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED') end end
function M.on_configuration_changed() unchanged(); f().upgraded=true end
local function touch()
  local g=assert(monitor.resolve(registry.record(f().tiles[1])))
  local p={valid=true,index=7103,force=game.forces.player,surface=game.surfaces[1],cursor_stack={valid_for_read=false},can_reach_entity=function() return true end,print=nop}
  local cw,ch,ox,oy=model.geometry(g); local x,y=model.world(g,ox+cw/2,oy+ch/2)
  assert(monitor.activate_for_player({input_name='tc-interact',tick=game.tick,cursor_position={x=x,y=y}},p))
  -- Engine has no client player; forward this admitted job through the real
  -- authority/deduplication delivery with the same explicit table-backed player.
  local state=registry.get().monitors; local job=state.touches[#state.touches]
  assert(monitor.deliver(job,g,registry.computer(f().c),game.tick,nop,p)); state.touches={}
end
local busy_source=[[function start(e) computer.every(10,'work') end

function work(e) local sum=0; for i=1,128 do sum=sum+i end; computer.setState('sum',sum); computer.setState('tick',e.tick) end]]
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false; x.phase='resumed'; x.since=event.tick
  else loaded=false end
  assert(event.tick-x.start<2400,'integrated scenario deadline '..x.phase)
  scheduler.tick(event.tick)
  local c=registry.computer(x.c); local io=registry.record(x.io); local db=registry.record(x.db); local observer=registry.computer(x.observer)
  for _,id in ipairs(x.busy) do local b=registry.computer(id); assert(b.status~='faulted',serpent.line(b.diagnostic)) end
  if x.phase~='boot' and x.phase~='observer' and x.phase~='examples' and x.phase~='expiry' then
    assert(c.status=='running',serpent.line(c.diagnostic)); assert(observer.status=='running',serpent.line(observer.diagnostic))
  end
  if x.phase=='boot' and event.tick-x.start>=3 then
    for _,id in ipairs(registry.get().order) do local r=registry.record(id); assert(r.status_art and r.status_art.object.valid) end
    assert(c.status_art.name=='tc-status-computer-north-off-0')
    submit(c,sources.factory); x.phase='observer'; x.since=event.tick
  elseif x.phase=='observer' and event.tick>x.since then
    submit(observer,sources.observer,7102); x.phase='busy'; x.since=event.tick; x.busy_index=1
  elseif x.phase=='busy' then
    local id=x.busy[x.busy_index]
    if id then submit(registry.computer(id),busy_source,7200+x.busy_index); x.busy_index=x.busy_index+1
    else x.phase='transfer'; x.since=event.tick end
  elseif x.phase=='transfer' then
    assert(event.tick-x.since<300,'factory transfer deadline')
    if x.destination.get_item_count('iron-plate')>=2 and observer.state.shared_status=='FILLING' then
      local cb=x.inserter.get_control_behavior(); assert(cb.circuit_enable_disable and cb.circuit_condition.first_signal.name=='signal-A')
      assert(c.state.starts==1 and db.database.entries['stock:iron'].deadline>event.tick)
      assert(observer.state.shared_count=='5' and observer.state.private_status=='absent')
      assert(registry.record(x.private).database.entries.observer.value=='private' and db.database.entries.observer.value==observer.id)
      local g=monitor.resolve(registry.record(x.tiles[1])); assert(#g.members==4 and g.model.cells[1][1]==73)
      assert(g.render and g.render.presented_revision==g.model.revision,'merged model not presented')
      assert(c.status_art.name:find('blinking',1,true))
      log('TC_MEASURE '..serpent.line{first_factory_and_shared_observation_tick=event.tick,boot_origin=x.start,active_computers=6,display_cells=#g.model.cells})
      report('saved-factory-source-native-config-inserter-transfer-shared-and-independent-db-world-render')
      x.stock.insert{name='iron-plate',count=115}; x.phase='high'; x.since=event.tick
    end
  elseif x.phase=='high' then
    if #logic.inspect_output(io,nop)==0 then log('TC_MEASURE stock_input_to_output_ticks='..(event.tick-x.since)); x.phase='settle'; x.since=event.tick end
    assert(event.tick-x.since<180,'high stock reaction deadline')
  elseif x.phase=='settle' and event.tick-x.since>=90 then
    x.count=x.destination.get_item_count('iron-plate'); x.phase='cessation'; x.since=event.tick
  elseif x.phase=='cessation' and event.tick-x.since>=60 then
    assert(x.destination.get_item_count('iron-plate')==x.count,'native inserter did not stop')
    report('real-tick-stock-threshold-and-settled-item-cessation')
    x.stock.remove_item{name='iron-plate',count=115}; x.phase='low'; x.since=event.tick
  elseif x.phase=='low' and logic.inspect_output(io,nop)[1] then
    touch(); x.phase='touch'; x.since=event.tick
  elseif x.phase=='touch' and c.state.enabled==false and #logic.inspect_output(io,nop)==0 then
    log('TC_MEASURE mock_touch_to_output_ticks='..(event.tick-x.since))
    report('table-backed-world-touch-production-handler-disables-output')
    -- Native player changes must not be overwritten by cold startup replay.
    local cb=x.inserter.get_control_behavior(); cb.circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=7}
    x.phase='render-wait'; x.since=event.tick
  elseif x.phase=='render-wait' then
    local g=monitor.resolve(registry.record(x.tiles[1]))
    if g.render and g.render.presented_revision==g.model.revision then
      for _,id in ipairs(x.busy) do assert(registry.computer(id).state.sum==8256) end
      x.snapshot=snapshot(); x.phase='frozen'
      x.inserter.disabled_by_script=true
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
  elseif x.phase=='resumed' and event.tick-x.since>=75 then
    assert(c.state.enabled==false and c.state.starts==1 and c.run_id==x.snapshot.run)
    assert(x.inserter.get_control_behavior().circuit_condition.constant==7,'startup configuration replayed')
    report('cold-source-state-queue-display-aliases-spent-credits-and-no-startup-replay')
    touch(); x.phase='save-edit'; x.since=event.tick
  elseif x.phase=='save-edit' and c.state.enabled and logic.inspect_output(io,nop)[1] then
    x.old_run=c.run_id; x.old_active=c.active
    x.edited_source=assert(sources.factory:gsub('count < 100','count < 3'))
    submit(c,x.edited_source,7101,true)
    assert(c.active==x.old_active and c.run_id==x.old_run and c.saved_source~=c.active.source)
    x.phase='saved-old'; x.since=event.tick
  elseif x.phase=='saved-old' and event.tick-x.since>=65 then
    assert(c.active==x.old_active and c.run_id==x.old_run and logic.inspect_output(io,nop)[1].count==1)
    submit(c,x.edited_source,nil,false,'apply'); x.phase='applied'; x.since=event.tick
  elseif x.phase=='applied' and event.tick-x.since>=65 then
    assert(c.active.source==x.edited_source and c.run_id~=x.old_run and #logic.inspect_output(io,nop)==0 and c.state.enabled)
    report('edited-threshold-save-keeps-old-factory-apply-uses-saved-revision')
    runtime.stop(c.id); x.phase='expiry'; x.since=event.tick
    assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
  elseif x.phase=='expiry' and event.tick-x.since>=250 then
    assert(kv.methods.get(nil,db,'red',event.tick,nop,'observer')==observer.id)
    assert(kv.methods.type(nil,db,'red',event.tick,nop,'stock:iron')=='none')
    assert(observer.state.shared_status=='expired' and observer.state.private_status=='absent')
    report('stopped-controller-output-cleanup-and-shared-whole-key-expiry')
    runtime.stop(observer.id); for _,id in ipairs(x.busy) do runtime.stop(id) end
    x.phase='examples'; x.example_names={'logic','kv','monitor','peripheral','configurator','sections','recipe_searcher','factoriopedia','inventory'}; x.example_index=1; x.since=event.tick
    for _,program in ipairs(contract_programs) do x.example_names[#x.example_names+1]=program.name end
  elseif x.phase=='examples' then
    if event.tick-x.since==1 then
      local key=x.example_names[x.example_index]
      if key then submit(c,sources[key]) else
        assert(c.state.api_inventory,'full guest API inventory did not execute')
        assert(c.state.factoriopedia_example,'Factoriopedia example did not complete')
        assert(c.state.recipe_count and c.state.fluid_recipe_count,'Recipe Searcher example did not complete')
        report('all-shipped-and-contract-documents-saved-activated-and-started')
        local maximum,maintenance=0,0
        for _,sample in ipairs(x.samples) do maximum=math.max(maximum,sample.total); maintenance=math.max(maintenance,sample.maintenance) end
        log('TC_MEASURE '..serpent.line{actual_tick_samples=#x.samples,peak_guest_work=maximum,peak_maintenance=maintenance})
        local victim=registry.computer(x.busy[1]); local object=victim.status_art and victim.status_art.object
        assert(object and object.valid); assert(victim.body.die()); assert(not object.valid and not registry.record(victim.id))
        report('native-art-object-destruction-cleanup')
        x.phase='done'; if x.upgraded then log('TC_UPGRADE_OK') else log('TC_COLD_OK') end; return
      end
    elseif event.tick-x.since>=4 then
      assert(c.status=='running',x.example_names[x.example_index]..' '..serpent.line(c.diagnostic))
      report('shipped-example '..x.example_names[x.example_index]); runtime.stop(c.id)
      x.example_index=x.example_index+1; x.since=event.tick
    end
  end
  if c.status=='running' then
    local root=registry.get(); assert(root.ledger.total<=limits.host_work_per_tick-limits.maintenance_work_per_tick)
    x.samples[#x.samples+1]={tick=event.tick,total=root.ledger.total,maintenance=root.scheduler.maintenance_spent}
  end
end
return M
