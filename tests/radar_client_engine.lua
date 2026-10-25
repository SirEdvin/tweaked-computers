-- Native visible radar scene and real-peer authoritative readback.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local radar=require('scripts.radar')
local defs=require('scripts.device-definitions')
local sender_source=require('examples.modem-sender')
local receiver_source=require('examples.modem-receiver')
local M={}; local loaded=false
local function f() return storage.radar_client end
local function build(kind,x,y,surface)
  surface=surface or game.surfaces[1]
  local name=kind=='radar' and 'radar' or kind=='advanced' and 'tc-interplanetary-radar' or defs.devices[kind].entity_name
  local body=assert(surface.create_entity{name=name,position={x,y},force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function connect(a,b,color)
  local function endpoint(r) return r.body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true) end
  assert(endpoint(a).can_wire_reach(endpoint(b)),'visible scene must use native wire reach')
  assert(endpoint(a).connect_to(endpoint(b)))
end
local function supply(surface,x,y)
  local e=assert(surface.create_entity{name='electric-energy-interface',position={x,y},force='player'})
  e.power_production=1000000000; e.power_usage=0; e.electric_buffer_size=1000000000; e.energy=1000000000
  if not surface.platform then
    for _,p in ipairs({{x-9,y},{x+5,y}}) do assert(surface.create_entity{name='substation',position=p,force='player'}) end
  end
end
function M.run()
  storage.radar_client={phase='boot',start=game.tick,joined={}}
  local s=game.surfaces[1]; s.always_day=true
  s.request_to_generate_chunks({8,0},2); s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities_filtered{area={{-24,-24},{48,24}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for x=-24,48 do for y=-24,24 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  s.set_tiles(tiles)
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local c=build('computer',-8,0); local r=build('radar',-2,0)
  local d=build('computer',32,0); local receiver=build('radar',26,0)
  connect(c,r,'red'); connect(c,r,'green'); connect(d,receiver,'red'); connect(d,receiver,'green')
  f().sender=c.id; f().radar=r.id; f().receiver=d.id; f().remote=receiver.id
  supply(s,0,-8); supply(s,30,-8)
  rendering.draw_text{text='NATIVE RADAR / SHARED MODEM',surface=s,target={-2,3},alignment='center',color={1,1,1},scale=.7}
  assert(runtime.save(d.id,receiver_source,0)); assert(runtime.activate(d.id,game.tick))
  assert(runtime.save(c.id,sender_source,0)); assert(runtime.activate(c.id,game.tick))
  if script.active_mods['space-age'] then
    assert(s.can_place_entity{name='tc-interplanetary-radar',position={7,0},force='player'})
    local advanced=build('advanced',7,0); f().advanced=advanced.id
    connect(r,advanced,'red'); connect(r,advanced,'green')
    rendering.draw_text{text='INTERPLANETARY / 5 x 5',surface=s,target={7,3.5},alignment='center',color={.6,1,1},scale=.7}
    local force=game.forces.player
    local tech=force.technologies['tc-interplanetary-radar']
    for _,prerequisite in pairs(tech.prerequisites) do prerequisite.researched=true end
    assert(not tech.researched and not force.recipes['tc-interplanetary-radar'].enabled)
    force.add_research(tech); force.research_progress=499/500
    local lab=assert(s.create_entity{name='lab',position={12,-6},force='player'})
    lab.disabled_by_script=true -- Exercise native research only after a real client joins.
    for _,pack in ipairs(tech.research_unit_ingredients) do lab.insert{name=pack.name,count=2} end
    f().lab=lab
    local assembler=assert(s.create_entity{name='assembling-machine-3',position={12,6},force='player'})
    f().assembler=assembler
    supply(s,20,1)
    local platform=assert(force.create_space_platform{name='Radar visible platform',planet='nauvis',starter_pack='space-platform-starter-pack'})
    assert(platform.apply_starter_pack())
    local floor={}; for x=-16,22 do for y=-16,20 do floor[#floor+1]={name='space-platform-foundation',position={x,y}} end end
    platform.surface.set_tiles(floor)
    local pc=build('computer',8,10,platform.surface); local pr=build('advanced',15,10,platform.surface)
    connect(pc,pr,'red'); connect(pc,pr,'green'); supply(platform.surface,12,17)
    assert(platform.surface.can_place_entity{name='tc-interplanetary-radar',position={-8,10},force='player'})
    f().platform=platform; f().platform_radar=pr.id; f().platform_computer=pc.id
  end
end
local function snapshot()
  local x=f(); local c,d=registry.record(x.sender),registry.record(x.receiver)
  local peers={}; for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end; table.sort(peers)
  local channels={}
  for _,id in ipairs({x.radar,x.remote,x.advanced,x.platform_radar}) do
    local values={}; for ch in pairs(registry.record(id).modem.channels) do values[#values+1]=ch end; table.sort(values)
    channels[#channels+1]={id=id,channels=values}
  end
  return {tick=game.tick,phase=x.phase,peers=peers,sender=c.id,receiver=d.id,channels=channels,
    sent=c.state.sent,received=d.state.received,last_message=d.state.last_message,last_reply=c.state.last_reply,
    sender_starts=c.state.starts,receiver_starts=d.state.starts,
    sender_event_sequence=c.state.last_sequence,receiver_event_sequence=d.state.last_sequence,
    transport=registry.get().modem_transport,sequence=registry.get().next_sequence,
    late_join=x.late_join,crafted=x.crafted or false,researched=x.researched or false,advanced=x.advanced}
end
local function publish()
  local text=helpers.table_to_json(snapshot())
  helpers.write_file('radar-server-state.json',text,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('radar-client-state.json',text,false,p.index) end
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index); local x=f()
  p.set_controller{type=defines.controllers.god}; p.teleport({2,1},game.surfaces[1]); p.zoom=1.5
  if p.index==2 and x.platform then p.teleport({10,11},x.platform.surface) end
  p.game_view_settings.show_entity_info=true
  p.insert{name='radar',count=5}; p.set_quick_bar_slot(1,1,'radar')
  if x.advanced then p.insert{name='tc-interplanetary-radar',count=5}; p.set_quick_bar_slot(1,2,'tc-interplanetary-radar') end
  if x.lab and not x.researched then x.lab.disabled_by_script=false end
  if x.phase=='ready' then x.late_join=true; assert(registry.record(x.radar).modem.channels[201]); log('TC_RADAR_LATE_JOIN_RETAINED') end
  x.joined[p.index]=true
end
function M.on_load()
  loaded=true
  if f().phase=='ready' then
    assert(registry.record(f().radar).modem.channels[201] and registry.record(f().remote).modem.channels[200])
    assert(registry.record(f().sender).state.starts==1 and registry.record(f().receiver).state.starts==1)
    log('TC_RADAR_CLIENT_ON_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('unexpected native scene configuration change') end
function M.on_tick(event)
  local x=f(); loaded=false -- Joining reconstructs local code, never authoritative state.
  if not x.booted then x.booted=true; log('TC_RADAR_SCENE_BOOTED') end
  scheduler.tick(event.tick)
  local c,d=registry.record(x.sender),registry.record(x.receiver)
  assert(c.status=='running',serpent.line(c.diagnostic)); assert(d.status=='running',serpent.line(d.diagnostic))
  if x.advanced and not x.crafted then
    local force=game.forces.player; local tech=force.technologies['tc-interplanetary-radar']
    if tech.researched and not x.researched then
      assert(force.recipes['tc-interplanetary-radar'].enabled)
      x.researched=true
      x.assembler.set_recipe('tc-interplanetary-radar')
      assert(x.assembler.get_recipe().name=='tc-interplanetary-radar')
      for _,ingredient in ipairs(force.recipes['tc-interplanetary-radar'].ingredients) do x.assembler.insert{name=ingredient.name,count=ingredient.amount} end
      log('TC_RADAR_NATIVE_RESEARCH_COMPLETED accelerated-final-unit')
    end
    if x.researched and x.assembler.get_inventory(defines.inventory.crafter_output).get_item_count('tc-interplanetary-radar')==1 then
      x.crafted=true; log('TC_RADAR_NATIVE_CRAFT_COMPLETED')
    end
  end
  if x.phase=='boot' and c.state.last_reply and d.state.received and (not x.advanced or x.crafted) then
    x.phase='ready'; game.server_save('tc-radar-client-snapshot'); log('TC_RADAR_CLIENT_READY')
  end
  if event.tick%30==0 then publish() end
  if #game.connected_players==2 and x.late_join and x.phase=='ready' and not x.multiplayer_done then
    x.multiplayer_done=true; publish(); log('TC_RADAR_MULTIPLAYER_OK')
  end
end
return M
