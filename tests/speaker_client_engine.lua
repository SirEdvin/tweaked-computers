-- Exact-package real-client scene: authoritative schedule, not audibility proof.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local M={}; local loaded=false
local function f() return storage.speaker_client end
local function native_configuration(body)
  local cb=body.get_control_behavior(); local condition=cb.circuit_condition
  condition.fulfilled=nil -- Live observation, not configuration.
  return serpent.line{condition=condition,parameters=cb.circuit_parameters,alerts=body.alert_parameters}
end
local source=[[function start(event)
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  computer.setState('operation','')
  computer.setState('submissions',0)
  computer.every(1,'play')
end
function play(event)
  local operation=computer.getState('operation')
  if operation=='' then return end
  local count=0
  if operation=='detached' then
    local ok,e=pcall(peripheral.call,computer.getState('speaker_name'),'red','playNote','piano',0,0)
    assert(not ok and e.code=='E_UNREACHABLE'); computer.setState('detach_verified',true)
  elseif operation=='unpowered' then
    local s=peripheral.find('speaker','red'); assert(s.getLimits().speaker_notes_per_tick==8)
    local ok,e=pcall(s.playNote,'piano',0,0)
    assert(not ok and e.code=='E_UNPOWERED'); computer.setState('power_verified',true)
  else
    local s=peripheral.find('speaker','red'); assert(s)
    computer.setState('speaker_name',peripheral.getName(s)); count=1
    if operation=='effect' then assert(s.playSound('utility/wire_connect_pole',1))
    elseif operation=='zero' then assert(s.playNote('piano',0,0))
    elseif operation=='quiet' then assert(s.playNote('piano',0.25,0))
    elseif operation=='chord' then assert(s.playNote('piano',0.5,0)); assert(s.playNote('piano',0.5,4)); count=2
    else assert(operation=='note'); assert(s.playNote('piano',1,0)) end
  end
  computer.setState('submissions',computer.getState('submissions')+count)
  computer.setState('operation','')
end]]
local function state(key,value)
  local c=registry.record(f().computer)
  local guard=sandbox.new(admission.context(admission.new(),'speaker-scene-controller',game.tick),{})
  runtime.services(c,game.tick,guard).computer.setState(key,value)
end
function M.run()
  storage.speaker_client={phase='boot',joined={},requests={},start=game.tick}
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local s=game.surfaces[1]; s.always_day=true
  s.request_to_generate_chunks({0,0},2); s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities_filtered{area={{-20,-20},{20,20}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end; s.set_tiles(tiles)
  local other=game.create_surface('speaker-other',{width=64,height=64}); other.always_day=true
  game.create_force('speaker-listener')
  for _,force in ipairs({game.forces.player,game.forces['speaker-listener']}) do force.chart(s,{{-32,-32},{32,32}}) end
  local b=assert(s.create_entity{name='programmable-speaker',position={4,0},force='player'})
  local cbody=assert(s.create_entity{name=defs.devices.computer.entity_name,position={-2,0},force='player'})
  lifecycle.on_built{entity=cbody}; local c=assert(registry.by_entity(cbody))
  assert(cbody.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(b.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
  local p=assert(s.create_entity{name='electric-energy-interface',position={0,-8},force='player'})
  p.power_production=1000000000; p.power_usage=0; p.electric_buffer_size=1000000000; p.energy=1000000000
  assert(s.create_entity{name='substation',position={4,-6},force='player'})
  local parameters=b.parameters; parameters.playback_mode='global'; parameters.playback_volume=.65
  parameters.allow_polyphony=true; parameters.volume_controlled_by_signal=true; parameters.volume_signal_id={type='virtual',name='signal-B'}; b.parameters=parameters
  local cb=b.get_or_create_control_behavior()
  cb.circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=100}
  local piano
  for i,instrument in ipairs(b.prototype.instruments) do if instrument.name=='piano' then piano=i-1 end end
  assert(piano and cb.circuit_condition.first_signal.name=='signal-A' and cb.circuit_condition.constant==100)
  cb.circuit_parameters={signal_value_is_pitch=false,stop_playing_sounds=false,instrument_id=piano,note_id=0}
  f().parameters=serpent.line(b.parameters); f().configuration=native_configuration(b); f().body=b; f().computer=c.id
  rendering.draw_text{text='POSITIONAL API / NATIVE SPEAKER',surface=s,target={4,2},alignment='center',color={1,1,1},scale=.7}
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
local function snapshot()
  local x=f(); local c=registry.record(x.computer); local r=registry.by_entity(x.body)
  local peers={}; for _,p in pairs(game.connected_players) do peers[#peers+1]={index=p.index,force=p.force.name,surface=p.surface.name,position=p.position} end
  table.sort(peers,function(a,b) return a.index<b.index end)
  return {tick=game.tick,phase=x.phase,peers=peers,computer=c.id,speaker=r and r.id,
    starts=c.state.starts,submissions=c.state.submissions,requests=x.requests,stage=x.stage,
    audio=registry.get().speaker_audio,late_join=x.late_join or false,detach_verified=c.state.detach_verified or false,
    power_verified=c.state.power_verified or false,native_circuit_tick=x.native_circuit_tick,
    configuration_unchanged=x.configuration==native_configuration(x.body),parameters_unchanged=x.parameters==serpent.line(x.body.parameters)}
end
local function publish()
  local text=helpers.table_to_json(snapshot())
  helpers.write_file('speaker-server-state.json',text,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('speaker-client-state.json',text,false,p.index) end
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index); local x=f()
  p.set_controller{type=defines.controllers.god}; p.teleport({0,0},game.surfaces[1]); p.zoom=1
  p.force.chart(game.surfaces[1],{{-32,-32},{32,32}})
  x.joined[p.index]=true
  if x.phase=='finished' then
    assert(registry.record(x.computer).state.starts==1)
    x.late_join=true; log('TC_SPEAKER_LATE_JOIN_NO_REPLAY')
  end
end
function M.on_load() loaded=true end
function M.on_configuration_changed() error('unexpected native scene configuration change') end
function M.on_tick(event)
  local x=f(); local c=registry.record(x.computer)
  if loaded then
    loaded=false
    if x.phase=='finished' then assert(c.state.starts==1); log('TC_SPEAKER_CLIENT_LOAD_NO_REPLAY') end
  end
  if not x.booted then x.booted=true; log('TC_SPEAKER_SCENE_BOOTED') end
  if x.phase=='boot' and #game.connected_players==2 and c.state.starts==1 then
    x.phase='playing'; x.start=event.tick; log('TC_SPEAKER_AUDIO_BEGIN')
  end
  if x.phase=='playing' then
    local elapsed=event.tick-x.start; local stage=math.floor(elapsed/1200); local within=elapsed%1200
    if stage<=3 then
      x.stage=stage
      if within==0 then
        local peer=game.get_player(2); assert(peer)
        peer.force=stage==1 and game.forces['speaker-listener'] or game.forces.player
        peer.teleport(stage==2 and {800,800} or {0,0},stage==3 and game.surfaces['speaker-other'] or game.surfaces[1])
        peer.force.chart(game.surfaces[1],{{-32,-32},{32,32}})
      end
      local operations={[180]='note',[360]='effect',[540]='zero',[720]='quiet',[900]='chord'}
      local operation=operations[within]
      if operation then
        local peer=game.get_player(2)
        assert(peer.force.is_chunk_charted(game.surfaces[1],{0,0}))
        assert(x.body.parameters.playback_mode=='global' and x.parameters==serpent.line(x.body.parameters))
        assert(x.configuration==native_configuration(x.body) and x.body.get_control_behavior().circuit_condition.fulfilled==false)
        state('operation',operation)
        local request={tick=event.tick,stage=stage,operation=operation,peer_force=peer.force.name,peer_surface=peer.surface.name,peer_position=peer.position}
        x.requests[#x.requests+1]=request; log('TC_SPEAKER_AUDIO_REQUEST '..helpers.table_to_json(request))
      end
    elseif stage==4 and within==0 then
      assert(c.state.submissions==24 and x.parameters==serpent.line(x.body.parameters))
      local constant=assert(x.body.surface.create_entity{name='constant-combinator',position={8,0},force='player'})
      local cb=constant.get_or_create_control_behavior(); for i=cb.sections_count,1,-1 do cb.remove_section(i) end
      local section=cb.add_section()
      section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=101})
      section.set_slot(2,{value={type='virtual',name='signal-B',quality='normal'},min=100})
      cb.enabled=true
      assert(constant.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(x.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
      x.constant=constant; x.native_circuit_tick=event.tick
      log('TC_SPEAKER_NATIVE_CIRCUIT_ON '..event.tick)
    elseif stage==4 and within==30 then
      assert(x.body.get_control_behavior().circuit_condition.fulfilled==true)
      log('TC_SPEAKER_NATIVE_CONDITION_FULFILLED '..event.tick)
    elseif stage==4 and within==120 then
      x.constant.get_control_behavior().enabled=false
      assert(c.state.submissions==24 and x.parameters==serpent.line(x.body.parameters))
      log('TC_SPEAKER_NATIVE_CIRCUIT_OFF '..event.tick)
    elseif stage==4 and within==150 then
      assert(x.body.get_control_behavior().circuit_condition.fulfilled==false)
      log('TC_SPEAKER_NATIVE_CONDITION_CLEARED '..event.tick)
    elseif stage==4 and within==180 then
      assert(c.body.get_wire_connector(defines.wire_connector_id.circuit_red,false).disconnect_from(x.body.get_wire_connector(defines.wire_connector_id.circuit_red,false)))
      state('operation','detached'); log('TC_SPEAKER_DETACHED_REFUSAL '..event.tick)
    elseif stage==4 and within==240 then
      assert(c.body.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(x.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
      x.restore_energy=x.body.energy; x.body.energy=0; assert(x.body.energy==0)
      state('operation','unpowered'); log('TC_SPEAKER_UNPOWERED_REFUSAL '..event.tick)
    elseif stage>=4 and elapsed>=5160 then
      assert(c.state.submissions==24,'four stages each submit 1+1+1+1+2 samples')
      assert(x.parameters==serpent.line(x.body.parameters))
      x.phase='finished'; x.finished_tick=event.tick
      assert(x.native_circuit_tick and not x.constant.get_control_behavior().enabled)
      assert(x.configuration==native_configuration(x.body))
      assert(c.state.detach_verified and c.state.power_verified)
      publish(); game.server_save('tc-speaker-client-snapshot'); log('TC_SPEAKER_CLIENT_READY')
    end
  end
  scheduler.tick(event.tick)
  if x.restore_energy then x.body.energy=x.restore_energy; x.restore_energy=nil end
  assert(c.status=='running',serpent.line(c.diagnostic))
  if event.tick%30==0 then publish() end
end
return M
