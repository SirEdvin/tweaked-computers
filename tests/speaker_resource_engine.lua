-- Real wired speaker, native oversized prototypes, scheduler and cold reload.
-- Silent engine submissions prove accepted results, not client audibility.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local radar=require('scripts.radar')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local examples={require('examples.speaker-alarm'),require('examples.speaker-melody'),require('examples.speaker-catalogue')}
local M={}; local loaded=false
local source=[[function start()
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  local speaker=peripheral.find('speaker','red'); assert(speaker)
  local green=peripheral.wrap(peripheral.getName(speaker),'green')
  local instruments=speaker.getInstruments(); assert(#instruments>64)
  for i=2,#instruments do assert(instruments[i-1]<instruments[i]) end
  computer.setState('instruments',#instruments)
  local notes=speaker.getNotes('tc-resource-instrument-001'); assert(#notes==129)
  for i,n in ipairs(notes) do assert(n.name=='note-'..i and n.pitch==i-1) end
  notes[1].name='edited'; assert(speaker.getNotes('tc-resource-instrument-001')[1].name=='note-1')
  local long='tc-resource-long-'..string.rep('x',257)
  assert(speaker.getNotes(long)[1].name==long)
  assert(speaker.playNote(long,0,0))
  assert(speaker.playSound(long,0) and green.playSound(long,0))
  for i=1,9 do assert(speaker.playNote('tc-resource-instrument-001',0,128)) end
  local ok,e=pcall(speaker.playNote,'tc-resource-instrument-001',0,129)
  assert(not ok and e.code=='E_RANGE')
  computer.setState('submissions',12)
  computer.after(1,'page')
end
function page()
  local speaker=peripheral.find('speaker','red'); assert(speaker)
  local count=computer.getState('count') or 0
  local page=speaker.getSounds('tc-resource-sound-',computer.getState('cursor') or '')
  assert(#page.sounds>0 and #page.sounds<=73)
  for i,path in ipairs(page.sounds) do
    assert(path==string.format('tc-resource-sound-%05d',count+i),'missing or repeated native sound')
  end
  count=count+#page.sounds; computer.setState('count',count)
  if page.next then
    assert(page.next==page.sounds[#page.sounds]); computer.setState('cursor',page.next)
    computer.after(1,'page')
  else assert(count==32769); computer.setState('complete',true) end
end]]
local function setting(value)
  settings.global['tc-speaker-sound-page-size']={value=value}
  assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed)){
    setting='tc-speaker-sound-page-size',setting_type='runtime-global',tick=game.tick}
  assert(limits.speaker_sound_page_size==value)
end
function M.run()
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={0,0},force='player'})
  lifecycle.on_built{entity=body}; local computer=assert(registry.by_entity(body))
  local sound=assert(game.surfaces[1].create_entity{name='programmable-speaker',position={6,0},force='player'})
  for _,color in ipairs({'red','green'}) do
    local connector=defines.wire_connector_id['circuit_'..color]
    assert(body.get_wire_connector(connector,true).connect_to(sound.get_wire_connector(connector,true),false))
  end
  for _=1,#registry.get().order+3 do radar.tick(game.tick,function() end) end
  local speaker=assert(registry.by_entity(sound))
  local before=serpent.line{parameters=sound.parameters,alert=sound.alert_parameters,circuit=sound.get_or_create_control_behavior().circuit_parameters}
  setting(73)
  assert(runtime.save(computer.id,source,computer.saved_revision)); assert(runtime.activate(computer.id,game.tick))
  storage.tc_speaker_resource={computer=computer.id,speaker=speaker.id,run=computer.run_id,phase='run',before=before,started=game.tick}
end
function M.on_load()
  local f=storage.tc_speaker_resource
  if f.phase=='frozen' then
    local computer=assert(registry.record(f.computer)); local ledger=registry.get().ledger
    assert(computer.run_id==f.run and computer.state.count==f.count and computer.state.starts==1 and computer.state.submissions==12)
    assert(ledger.tick==f.tick and ledger.total==f.work and limits.speaker_sound_page_size==73)
    loaded=true; log('TC_SPEAKER_RESOURCE_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_speaker_resource
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; f.phase='resume' end
  local computer=assert(registry.record(f.computer)); local speaker=assert(registry.record(f.speaker))
  lifecycle.power_entity(computer).energy=1000000; computer.powered=true
  speaker.body.energy=1000000; speaker.powered=true
  scheduler.tick(event.tick)
  assert(computer.status=='running',serpent.line(computer.diagnostic))
  assert(event.tick-f.started<2400,'native catalogue fixture deadline')
  if computer.invocation then return end
  if f.phase=='examples' then
    local ready=f.example==1 and computer.state.accepted==true
      or f.example==2 and computer.state.step and computer.state.step~=1
      or f.example==3 and computer.state.complete==true
    if not ready then return end
    assert(runtime.stop(computer.id))
    if f.example==3 then
      assert(computer.state.count>=32769)
      assert(f.before==serpent.line{parameters=speaker.body.parameters,alert=speaker.body.alert_parameters,circuit=speaker.body.get_or_create_control_behavior().circuit_parameters})
      f.phase='done'; log('TC_CONTRACT native-speaker-three-maintained-examples'); log('TC_COLD_OK')
    else
      f.example=f.example+1
      assert(runtime.save(computer.id,examples[f.example],computer.saved_revision)); assert(runtime.activate(computer.id,event.tick))
    end
    return
  end
  if f.phase=='run' and (computer.state.count or 0)>=146 then
    local ledger=registry.get().ledger
    f.count=computer.state.count; f.tick=ledger.tick; f.work=ledger.total; f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif computer.state.complete then
    assert(f.phase=='resume' and computer.run_id==f.run and computer.state.starts==1 and computer.state.submissions==12)
    assert(computer.state.count==32769 and computer.state.instruments==prototypes.mod_data['tc-resource-speaker-oracle'].data.instruments)
    assert(f.before==serpent.line{parameters=speaker.body.parameters,alert=speaker.body.alert_parameters,circuit=speaker.body.get_or_create_control_behavior().circuit_parameters})
    assert(runtime.stop(computer.id) and computer.state.complete)
    log('TC_SPEAKER_RESOURCE_RESULT sounds='..computer.state.count..' instruments='..computer.state.instruments..' tick='..event.tick)
    log('TC_CONTRACT native-oversized-speaker-catalogues-sequential-playback-and-cold')
    f.phase='examples'; f.example=1
    assert(runtime.save(computer.id,examples[1],computer.saved_revision)); assert(runtime.activate(computer.id,event.tick))
  end
end
return M
