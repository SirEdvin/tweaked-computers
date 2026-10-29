-- One compact packaged native lifecycle fixture; GUI/player routes are labelled doubles.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local snapshots=require('scripts.lifecycle-data')
local blueprints=require('scripts.blueprints')
local kv=require('scripts.services.kv')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local logic=require('scripts.services.logic')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor-model')
local undo=require('scripts.computer-undo')
local compiler=require('scripts.runtime.compiler')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc12 end
local function group(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function build(kind,x,y,surface)
  local b=assert((surface or game.surfaces[1]).create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=b}; local r=assert(registry.by_entity(b)); lifecycle.power_entity(r).energy=defs.devices[kind].watts/30; r.powered=true
  assert(r.body.minable_flag,'new '..kind..' must be mineable')
  return r
end
local function mine(rec)
  local inv=game.create_inventory(1); inv[1].set_stack{name=defs.devices[rec.kind].name,count=1,quality=rec.body.quality}
  lifecycle.on_removed{entity=rec.body,buffer=inv,tick=game.tick}; rec.body.destroy(); return inv
end
local function replace(inv,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[defs.by_name[inv[1].name]].entity_name,position={x,y},force='player',quality=inv[1].quality})
  lifecycle.on_built{entity=body,consumed_items=inv}; return assert(registry.by_entity(body))
end
local function monitor_stacks()
  local inv=game.create_inventory(8)
  assert(prototypes.item['tc-monitor'].stack_size==50 and prototypes.item['tc-monitor'].type=='item-with-tags')
  for _,kind in ipairs(defs.order) do
    assert(prototypes.item[defs.devices[kind].name].stack_size==((kind=='computer' or kind=='kv' or kind=='dashboard') and 1 or 50))
  end
  assert(inv.insert{name='tc-monitor',count=50}==50 and inv[1].count==50 and not inv[2].valid_for_read)
  assert(inv.insert{name='tc-monitor',count=1}==1 and inv[1].count==50 and inv[2].count==1)
  inv.clear()
  inv[1].set_stack{name='tc-monitor',count=3}; inv[1].tags={fixture='A'}; inv[1].label='retained label'
  assert(inv.insert(inv[1])==3 and inv[1].count==6,'identical tagged monitors failed native merge')
  inv[2].set_stack(inv[1]); inv[2].count=2; inv[2].tags={fixture='B'}
  inv[3].set_stack(inv[1]); inv[3].count=2; inv[3].label='different label'
  local target=game.create_inventory(1); target[1].set_stack(inv[1])
  assert(target.insert(inv[2])==0 and target.insert(inv[3])==0,'unlike tags/labels silently merged')
  if script.active_mods.quality then
    inv[4].set_stack{name='tc-monitor',count=2,quality='uncommon'}
    inv[4].tags=inv[1].tags; inv[4].label=inv[1].label
    assert(target.insert(inv[4])==0 and inv[4].quality.name=='uncommon','unlike qualities silently merged')
  end
  target.destroy(); inv.destroy()
  group('monitor-native-50-plus-one-tag-label-quality-compatibility')
  -- Real stacks/entities, but explicitly simulated consumption: handlers do
  -- not own the engine's item decrement. Native robot mining is checked below.
  local source=game.create_inventory(1); source[1].set_stack{name='tc-monitor',count=50}
  local rec=replace(source,32,-12); source[1].count=source[1].count-1
  assert(source[1].count==49 and rec.body.valid)
  local mined=mine(rec)
  assert(mined[1].count==1 and source[1].count+mined[1].count==50 and mined[1].tags.tc_monitor)
  local settings=mined[1].tags.tc_monitor; settings.scale=2; settings.fg=3; settings.bg=4; settings.blink=true
  settings.palette[1]={0.1,0.2,0.3}
  -- Count writes cannot manufacture extra data-bearing items; construct this
  -- separate three-item settings fixture before assigning its native tags.
  mined[1].clear(); mined[1].set_stack{name='tc-monitor',count=3}
  mined[1].tags={tc_monitor=settings}; mined[1].label='settings retained'
  local restored=replace(mined,32,-12); mined[1].count=2
  assert(restored.monitor_settings.scale==2 and restored.monitor_settings.fg==3 and restored.monitor_settings.bg==4)
  assert(restored.monitor_settings.blink and restored.monitor_settings.palette[1][2]==0.2)
  assert(mined[1].count==2 and mined[1].label=='settings retained',serpent.line{count=mined[1].count,label=mined[1].label})
  assert(lifecycle.remove(restored.id,'fixture',true))
  -- Malformed data refunds one into real cargo, preserving the larger source.
  local surface=game.surfaces[1]
  for _,field in ipairs({'stack','consumed_items'}) do
    local robot=assert(surface.create_entity{name='construction-robot',position={36,-12},force='player'})
    local body=assert(surface.create_entity{name=defs.devices.monitor.entity_name,position={32,-12},force='player'})
    mined[1].clear(); mined[1].set_stack{name='tc-monitor',count=3,quality=script.active_mods.quality and 'uncommon' or 'normal'}
    mined[1].tags={tc_monitor={version=99}}; mined[1].label='settings retained'
    local event={entity=body,robot=robot}
    event[field]=field=='stack' and mined[1] or mined
    lifecycle.on_built(event)
    local cargo=robot.get_inventory(defines.inventory.robot_cargo)
    assert(not body.valid and cargo[1].name=='tc-monitor' and cargo[1].count==1)
    assert(mined[1].count==3 and cargo[1].tags.tc_monitor.version==99 and cargo[1].label==mined[1].label)
    assert(cargo[1].quality.name==mined[1].quality.name)
    robot.destroy()
  end
  source.destroy(); mined.destroy()
  group('monitor-multi-item-placement-mining-and-single-item-refund-both-event-shapes')
end
local source="return {api_version=1,handlers={start=function(e) computer.setState('boots',(computer.getState('boots') or 0)+1); computer.after(600,'wake') end,wake=function(e) computer.setState('wakes',1) end}}"
local saved='-- saved but not applied\n'..source
local function fixture_state(rec)
  -- Exactly the public state capacity, independently admitted by the importer.
  local state={}; for i=1,4 do state['k'..i]=string.rep(string.char(i),i==4 and 16264 or 16384) end
  -- 16 + four (key 2 + metadata 16 + string header 8) + content 65416 = 65536.
  local c=snapshots.import_computer{version=1,saved_source=rec.saved_source,saved_revision=rec.saved_revision,state=state}
  for _,k in ipairs({'state','state_bytes','state_nodes','state_entries','state_sizes','state_node_sizes'}) do rec[k]=c[k] end
  assert(rec.state_bytes==limits.state_bytes,'fixture must reach accepted state capacity')
end
local function undo_contract(legacy,case)
  local real_game=game
  local player={index=9999,force=game.forces.player,print=nop}
  game=setmetatable({get_player=function(index) if index==player.index then return player end; return real_game.get_player(index) end},{__index=function(_,key) return real_game[key] end})
  local ok,failure=pcall(function()
  local surface=game.surfaces[1]
  local overlap=assert(surface.create_entity{name=defs.devices.computer.entity_name,position={-24,4},force=player.force})
  local staged_ghost=assert(surface.create_entity{name='entity-ghost',inner_name=overlap.name,position=overlap.position,force=player.force},'restoration ghost must be stageable before rollback')
  assert(overlap.valid and staged_ghost.valid); overlap.destroy(); assert(staged_ghost.valid); staged_ghost.destroy()
  local source_rec=build('computer',-20,0)
  source_rec.saved_source=string.rep('s',limits.source_bytes); source_rec.saved_revision=3; source_rec.label='undo label'
  source_rec.active={source=string.rep('a',limits.source_bytes),revision=2,api_version=1,compiler_version=1,storage_version=1,handlers={start=true}}
  fixture_state(source_rec)
  local payload={version=1,tick=game.tick,operation='fixture-undo',player=player.index,force=player.force.index,
    surface=surface.index,name=source_rec.body.name,quality='normal',position={x=-19.5,y=.5},snapshot=snapshots.computer_snapshot(source_rec,false)}
  lifecycle.remove(source_rec.id,'fixture',true)
  local ghost=assert(surface.create_entity{name='entity-ghost',inner_name=payload.name,position=payload.position,force=player.force,tags={tc_computer_undo=payload,tc_computer=legacy,tc_computer_seen='private history marker'}})
  local event={entity=ghost,player_index=player.index,tick=game.tick}
  undo.on_ghost(event)
  undo.on_applied{player_index=player.index,tick=game.tick,actions={{type='removed-entity',surface_index=surface.index,target={name=payload.name,position=payload.position},tags={tc_computer_undo=payload}}}}
  assert(ghost.tags.tc_computer_ghost==ghost.unit_number and ghost.tags.tc_settings.computer.saved_source==payload.snapshot.saved_source)
  local inv=game.create_inventory(1); inv[1].set_stack{name='blueprint',count=1}
  local bp=inv[1]; local mapping=bp.create_blueprint{surface=surface,force=player.force,area={{-21,-1},{-18,2}}}
  assert(blueprints.prepare(bp,mapping))
  local entities=bp.get_blueprint_entities(); assert(#entities==1)
  assert(entities[1].tags.tc_computer_undo==nil and entities[1].tags.tc_computer_ghost==nil and entities[1].tags.tc_computer==nil and entities[1].tags.tc_computer_seen==nil)
  assert(entities[1].tags.tc_settings.computer.saved_source==payload.snapshot.saved_source and entities[1].tags.tc_settings.computer.state==nil)
  local original=ghost.tags
  for _,bad in ipairs({'malformed undo',{snapshot='malformed snapshot'},{snapshot={version=99}}}) do
    ghost.tags={tc_computer_undo=bad}
    mapping=bp.create_blueprint{surface=surface,force=player.force,area={{-21,-1},{-18,2}}}
    assert(not pcall(blueprints.prepare,bp,mapping) and #(bp.get_blueprint_entities() or {})==0,'malformed recovery copy published blank or leaked undo data')
  end
  ghost.tags=original
  local tags=ghost.tags
  local robot=surface.create_entity{name='construction-robot',position={-14,0},force=player.force}
  local material=game.create_inventory(1); material[1].set_stack{name='tc-computer',count=1}; material[1].tags={tc_computer=legacy}
  for _,operation in ipairs({'ordinary','blueprint'}) do
    local copy=assert(surface.create_entity{name=payload.name,position={-26,0},force=player.force})
    lifecycle.on_built{entity=copy,robot=robot,consumed_items=material,tags=operation=='blueprint' and {tc_settings=snapshots.settings(source_rec)} or nil}
    local r=assert(registry.by_entity(copy)); assert(r.status=='stopped' and not r.active and not r.run_id and next(r.state)==nil)
    assert(r.saved_source==(operation=='blueprint' and payload.snapshot.saved_source or '') and r.label==(operation=='blueprint' and payload.snapshot.label or nil))
    lifecycle.remove(r.id,'fixture',true)
  end
  local unrelated=assert(surface.create_entity{name=payload.name,position={-14,0},force=player.force})
  lifecycle.on_built{entity=unrelated,robot=robot,consumed_items=material,tags=tags}
  assert(not unrelated.valid and ghost.valid and robot.get_inventory(defines.inventory.robot_cargo).get_item_count('tc-computer')==1)
  local refusals=1
  for _,bad in ipairs({'malformed undo payload',{version=99},
    {version=1,tick=payload.tick,operation=payload.operation,player=payload.player,force=payload.force,surface=payload.surface,name=payload.name,quality=payload.quality,position=payload.position,snapshot={version=99}}}) do
    tags=ghost.tags; tags.tc_computer_undo=bad; ghost.destroy()
    local failed=assert(surface.create_entity{name=payload.name,position=payload.position,force=player.force})
    lifecycle.on_built{entity=failed,robot=robot,consumed_items=material,tags=tags}
    assert(not failed.valid,'malformed restoration published a body'); refusals=refusals+1
    local retained=surface.find_entities_filtered{type='entity-ghost',position=payload.position,force=player.force}
    assert(#retained==1 and retained[1].tags.tc_computer_undo~=nil,'refusal discarded the recoverable ghost payload')
    ghost=retained[1]; local repaired=ghost.tags; repaired.tc_computer_undo=payload; ghost.tags=repaired
  end
  local scope=game.create_surface('tc12-undo-scope-'..case); scope.request_to_generate_chunks({0,0},1); scope.force_generate_chunk_requests()
  local scoped={}; for key,value in pairs(payload) do scoped[key]=value end; scoped.surface=scope.index
  local expired=assert(scope.create_entity{name='entity-ghost',inner_name=payload.name,position=payload.position,force=player.force,tags={tc_computer_undo=scoped}})
  undo.on_ghost{entity=expired,player_index=player.index,tick=game.tick}
  undo.on_applied{player_index=player.index,tick=game.tick,actions={{type='removed-entity',surface_index=scope.index,target={name=payload.name,position=payload.position},tags={tc_computer_undo=scoped}}}}
  f().expired_scopes=f().expired_scopes or {}
  f().expired_scopes[#f().expired_scopes+1]={surface=scope,name=scope.name,index=scope.index,unit=expired.unit_number,tags=expired.tags}
  game.delete_surface(scope)
  local foreign=game.forces['tc12-undo-foreign'] or game.create_force('tc12-undo-foreign')
  ghost.force=foreign; tags=ghost.tags; ghost.destroy()
  local changed=assert(surface.create_entity{name=payload.name,position=payload.position,force=foreign})
  lifecycle.on_built{entity=changed,robot=robot,consumed_items=material,tags=tags}; refusals=refusals+1
  assert(not changed.valid and not registry.by_entity(changed))
  ghost=assert(surface.find_entities_filtered{position=payload.position,type='entity-ghost',ghost_name=payload.name}[1])
  assert(ghost.force==foreign and ghost.tags.tc_computer_undo.snapshot.state.k1==payload.snapshot.state.k1)
  ghost.force=player.force
  for _,failure in ipairs({'current-capacity','partial-placement'}) do
    tags=ghost.tags; ghost.destroy()
    local failed=assert(surface.create_entity{name=payload.name,position=payload.position,force=player.force})
    local state_limit,normalize,staged_power=limits.state_bytes,lifecycle.normalize_power
    if failure=='current-capacity' then limits.state_bytes=limits.state_bytes-1
    else lifecycle.normalize_power=function(rec)
      staged_power=rec.children.power; assert(staged_power.valid)
      error({code='E_ENGINE',message='injected physical allocation refusal'},0)
    end end
    local accepted,reason=pcall(lifecycle.on_built,{entity=failed,robot=robot,consumed_items=material,tags=tags})
    limits.state_bytes=state_limit; lifecycle.normalize_power=normalize; assert(accepted,reason)
    assert(not failed.valid and (not staged_power or not staged_power.valid),'refused restoration published partial placement'); refusals=refusals+1
    local retained=surface.find_entities_filtered{type='entity-ghost',position=payload.position,force=player.force}
    assert(#retained==1 and retained[1].tags.tc_computer_undo.snapshot.state.k1==payload.snapshot.state.k1)
    ghost=retained[1]
  end
  tags=ghost.tags; ghost.destroy()
  local forged={tc_computer_ghost=tags.tc_computer_ghost,tc_computer_undo={}}
  for key,value in pairs(payload) do forged.tc_computer_undo[key]=value end
  forged.tc_computer_undo.position={x=-13.5,y=.5}
  local replacement=assert(surface.create_entity{name=payload.name,position={-14,0},force=player.force})
  lifecycle.on_built{entity=replacement,robot=robot,consumed_items=material,tags=forged}
  assert(not replacement.valid and #surface.find_entities_filtered{type='entity-ghost',position={-13.5,.5}}==0,'forged scope stole original ghost authority'); refusals=refusals+1
  local body=assert(surface.create_entity{name=payload.name,position=payload.position,force=player.force})
  local compile=compiler.compile; compiler.compile=function() error('undo restoration must not compile source') end
  local accepted,reason=pcall(lifecycle.on_built,{entity=body,robot=robot,consumed_items=material,tags=tags})
  compiler.compile=compile; assert(accepted,reason)
  local restored=assert(registry.by_entity(body)); assert(restored.id~=source_rec.id)
  assert(restored.saved_source==payload.snapshot.saved_source and restored.active.source==payload.snapshot.active.source and restored.state_bytes==limits.state_bytes and restored.label==payload.snapshot.label)
  assert(restored.status=='stopped' and not restored.run_id and not restored.shell and not restored.output_owner and next(restored.queue)==nil and next(restored.timers)==nil and next(restored.subscriptions)==nil)
  restored.saved_source='later edit'; lifecycle.on_built{entity=body,tags=tags}; assert(restored.saved_source=='later edit')
  assert(registry.get().computer_undo.ghosts[tags.tc_computer_ghost]==nil)
  local refunds=robot.get_inventory(defines.inventory.robot_cargo).get_item_count('tc-computer')
  for _,item in ipairs(surface.find_entities_filtered{type='item-entity',area={{-24,-3},{-10,3}}}) do
    assert(item.stack.name=='tc-computer'); refunds=refunds+item.stack.count; item.destroy()
  end
  assert(refunds==refusals and material[1].count==1,'refused material conservation failed')
  lifecycle.remove(restored.id,'fixture',true)
  -- Refuse native ghost allocation before destroying the only owned recovery body.
  ghost=assert(surface.create_entity{name='entity-ghost',inner_name=payload.name,position=payload.position,force=player.force,tags={tc_computer_undo=payload}})
  undo.on_ghost{entity=ghost,player_index=player.index,tick=game.tick}
  undo.on_applied{player_index=player.index,tick=game.tick,actions={{type='removed-entity',surface_index=surface.index,target={name=payload.name,position=payload.position},tags={tc_computer_undo=payload}}}}
  tags=ghost.tags; ghost.destroy()
  local held=assert(surface.create_entity{name=payload.name,position=payload.position,force=player.force})
  local host_game,state_limit=game,limits.state_bytes
  game=setmetatable({surfaces={[surface.index]={create_entity=function() if case=='malformed' then error('injected rollback allocation failure') end; return nil end}}},{__index=function(_,key) return host_game[key] end})
  limits.state_bytes=limits.state_bytes-1
  local refused,reason=pcall(lifecycle.on_built,{entity=held,robot=robot,consumed_items=material,tags=tags})
  game=host_game; limits.state_bytes=state_limit; assert(refused,reason)
  local ownership=registry.get().computer_undo.ghosts[held.unit_number]
  assert(held.valid and not held.minable_flag and not registry.by_entity(held) and ownership.entity==held and ownership.payload.snapshot.state.k1==payload.snapshot.state.k1)
  lifecycle.on_built{entity=held}
  local recovered=assert(registry.by_entity(held)); assert(recovered.state_bytes==limits.state_bytes and recovered.saved_source==payload.snapshot.saved_source and recovered.status=='stopped')
  assert(registry.get().computer_undo.ghosts[held.unit_number]==nil)
  lifecycle.remove(recovered.id,'fixture',true); material.destroy(); robot.destroy(); inv.destroy()
  end)
  game=real_game; assert(ok,failure)
  group('host-event-double-undo-max-source-state-ghost-sanitization-replay-refusal-duplicate-delivery-'..case)
end
local function history_contract()
  local real_game=game; local players={}; local tick=game.tick; local reads=0
  for _,index in ipairs({9001,9002}) do
    local items={undo={},redo={}}; local stack={}
    for _,side in ipairs({'undo','redo'}) do
      local name=side
      stack['get_'..name..'_item_count']=function() reads=reads+1; return #items[name] end
      stack['get_'..name..'_item']=function(i) return items[name][i] end
      stack['set_'..name..'_tag']=function(i,j,key,value) local a=items[name][i][j]; a.tags=a.tags or {}; a.tags[key]=value end
    end
    players[index]={index=index,force=game.forces.player,print=nop,undo_redo_stack=stack,items=items}
  end
  local host={tick=tick,get_player=function(index) return players[index] or real_game.get_player(index) end}
  game=setmetatable(host,{__index=function(_,key) return real_game[key] end})
  local ok,failure=pcall(function()
    local a=build('computer',-38,0); local b=build('computer',-34,0)
    a.state.marker='first player'; b.state.marker='second player'
    local function action(rec) return {type='removed-entity',surface_index=rec.surface_index,target={name=rec.body.name,position=rec.body.position}} end
    local first,second=players[9001],players[9002]
    first.items.undo={{action(a)}}
    undo.capture(a,{name=defines.events.on_player_mined_entity,player_index=first.index})
    undo.capture(b,{name=defines.events.on_player_mined_entity,player_index=second.index})
    table.insert(first.items.undo,1,{action(a)}); second.items.undo={{action(b)}}
    undo.settle()
    assert(first.items.undo[1][1].tags.tc_computer_undo.snapshot.state.marker=='first player')
    assert(second.items.undo[1][1].tags.tc_computer_undo.snapshot.state.marker=='second player')
    assert(not first.items.undo[2][1].tags.tc_computer_undo,'old same-coordinate action was tagged')
    assert(#registry.get().computer_undo.pending==0)
    local before_reads=reads; undo.maintain(tick); undo.maintain(tick+1); assert(reads==before_reads,'settled actions must not poll histories')
    undo.on_marked{entity=b.body,player_index=second.index}
    table.insert(second.items.undo,1,{action(b)}); undo.settle()
    b.state.marker='changed after mark'
    undo.capture(b,{name=defines.events.on_robot_mined_entity})
    assert(second.items.undo[1][1].tags.tc_computer_undo.snapshot.state.marker=='changed after mark')
    local identity,status,state=b.id,b.status,b.state
    undo.on_cancelled{entity=b.body,player_index=second.index}
    assert(b.undo_action==nil and b.id==identity and b.status==status and b.state==state)
    undo.on_marked{entity=a.body,player_index=first.index}; first.items.undo={}; first.items.redo={}; host.tick=tick+1
    undo.settle(); assert(#registry.get().computer_undo.pending==0)
    undo.capture(a,{name=defines.events.on_robot_mined_entity})
    assert(#first.items.undo==0 and #first.items.redo==0,'discarded history manufactured recovery')
    undo.capture(b,{name=defines.events.on_entity_died,player_index=second.index})
    undo.capture(b,{name=defines.events.script_raised_destroy,player_index=second.index})
    assert(#registry.get().computer_undo.pending==0,'non-undo destruction manufactured history')
    -- Applied-event double for undo arriving before deferred native tagging.
    undo.capture(a,{name=defines.events.on_player_mined_entity,player_index=first.index})
    local native=action(a); local surface=a.body.surface; local pos=a.body.position; local name=a.body.name
    lifecycle.remove(a.id,'fixture',true)
    local ghost=assert(surface.create_entity{name='entity-ghost',inner_name=name,position=pos,force=first.force})
    undo.on_ghost{entity=ghost,player_index=first.index,tick=host.tick}
    first.items.redo={{{type='built-entity',surface_index=surface.index,target={name='entity-ghost',position=pos}}}}
    undo.on_applied{player_index=first.index,tick=host.tick,actions={native}}
    local saved=first.items.redo[1][1].tags.tc_computer_undo
    assert(saved.snapshot.state.marker=='first player' and ghost.tags.tc_computer_ghost==ghost.unit_number)
    assert(#registry.get().computer_undo.pending==0)
    local inverse=first.items.redo[1]; local unit=ghost.unit_number
    undo.on_removed{entity=ghost}; ghost.destroy(); first.items.redo={}; first.items.undo={{native}}
    undo.on_applied{player_index=first.index,tick=host.tick,actions=inverse}
    assert(first.items.undo[1][1].tags.tc_computer_undo.operation==saved.operation)
    lifecycle.remove(b.id,'fixture',true)
    assert(registry.get().computer_undo.ghosts[unit]==nil)
  end)
  game=real_game; assert(ok,failure)
  group('history-doubles-interleaved-players-exact-old-action-exclusion-no-polling-mark-time-discard-fast-undo-inverse-transfer')
end
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
script.on_event(defines.events.script_raised_revive,lifecycle.on_built)
script.on_event(defines.events.script_raised_built,lifecycle.on_built)
script.on_event(defines.events.on_pre_surface_deleted,lifecycle.on_surface_removed)
script.on_event(defines.events.on_forces_merging,lifecycle.on_forces_merging)
script.on_event(defines.events.on_robot_mined_entity,function(event)
  local rec=registry.by_entity(event.entity)
  if rec then
    lifecycle.on_removed(event)
    if rec.id==f().robot_id then f().robot_mined=true; log('TC_NATIVE_COMPUTER_ROBOT_MINED') end
    if rec.id==f().robot_monitor then f().monitor_mined=true; log('TC_NATIVE_MONITOR_ROBOT_MINED') end
  end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
  lifecycle.on_built(event)
  local rec=registry.by_entity(event.entity)
  if rec and rec.kind=='monitor' then f().robot_built_monitor=rec.id end
end)
function M.run()
  registry.initialize(); storage.tc12={groups=0,phase='start'}
  monitor_stacks()
  local surface=game.surfaces[1]; local material=game.create_inventory(1)
  material[1].set_stack{name='tc-kv',count=1}; material[1].tags={tc_kv={version=99}}
  local robot=assert(surface.create_entity{name='construction-robot',position={-28,0},force='player'})
  local body=assert(surface.create_entity{name=defs.devices.kv.entity_name,position={-28,0},force='player'})
  lifecycle.on_built{entity=body,robot=robot,consumed_items=material}
  local cargo=robot.get_inventory(defines.inventory.robot_cargo)
  assert(not body.valid and cargo.get_item_count('tc-kv')==1 and cargo[1].tags.tc_kv.version==99 and material[1].count==1)
  material.destroy(); robot.destroy(); group('malformed-kv-material-still-refused-and-original-refunded')
  for _,case in ipairs({{name='valid',payload={version=1,saved_source='legacy forbidden',saved_revision=1,state={secret='not imported'}}},{name='malformed',payload='malformed legacy'},{name='unsupported',payload={version=99}}}) do undo_contract(case.payload,case.name) end
  history_contract()
  local c=build('computer',0,0); runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  assert(scheduler.dispatch(c,game.tick)); assert(c.state.boots==1 and next(c.timers))
  runtime.save(c.id,saved,c.saved_revision); c.label='private literal label'
  fixture_state(c)
  local root=registry.get(); root.player_drafts[1]={documents={[c.id]={source='unsaved recoverable draft',base_source=saved,base_revision=c.saved_revision}},session={id=c.id,token=1}}
  local inv=mine(c)
  assert(inv[1].tags.tc_computer==nil,'computer mining must produce plain hardware')
  assert(root.player_drafts[1].documents[c.id].source=='unsaved recoverable draft')
  local restored=replace(inv,0,0)
  assert(restored.id~=c.id and restored.status=='stopped' and not restored.run_id and next(restored.queue)==nil and next(restored.timers)==nil and next(restored.subscriptions)==nil)
  assert(next(restored.state)==nil and restored.active==nil and restored.saved_source=='' and restored.label==nil)
  assert(not lifecycle.remove(c.id,'stale',true) and restored.body.valid)
  -- The same inert validated snapshot remains available for operation-owned undo.
  snapshots.restore_computer(restored,snapshots.computer_snapshot(c,false),false)
  assert(restored.state_bytes==65536 and restored.active.source==source and restored.saved_source==saved)
  inv.destroy(); f().restored=restored.id
  group('maximum-state-plain-material-item-new-identity-stopped-draft-recovery')
  local player={valid=true,index=7,force=restored.body.force,surface=restored.body.surface,can_reach_entity=function() return true end}
  local session,draft=editor.open(player,restored.id)
  editor.action(player,session.token,'review-active',game.tick)
  editor.action(player,session.token,'copy-active',game.tick)
  assert(draft.source==source and restored.saved_source==saved and restored.status=='stopped')
  editor.close(player.index,session.token)
  local before=restored.state
  for _,bad in ipairs({{version=99}, {version=1,saved_source='',saved_revision=0,state={bad=function() end}},
    {version=1,saved_source='',saved_revision=0,state={bad=0/0}}, {version=1,saved_source='',saved_revision=0,state={bad=setmetatable({},{})}}}) do
    assert(not pcall(snapshots.restore_computer,restored,bad,false)); assert(restored.state==before)
  end
  local cycle={}; cycle.self=cycle
  assert(not pcall(snapshots.import_computer,{version=1,saved_source='',saved_revision=0,state=cycle}))
  restored.schema_version=99; snapshots.initialize_computer(restored)
  assert(not restored.body.minable and restored.state==before and restored.saved_source==saved)
  restored.schema_version=1; snapshots.initialize_computer(restored); assert(restored.body.minable)
  group('malicious-and-unsupported-snapshots-inert-recoverable-without-data-replacement')
  for i,kind in ipairs(defs.order) do
    local r=build(kind,i*4,12)
    local child=lifecycle.endpoint(r,'network')
    for _,dir in ipairs({4,8,12,0}) do local previous=r.body.direction; r.body.direction=dir; local rotated,rotation_error=lifecycle.rotate(r,previous); assert(rotated,type(rotation_error)=='table' and rotation_error.message or tostring(rotation_error)); assert(r.direction==dir and child==lifecycle.endpoint(r,'network') and lifecycle.connector(r,'network','red'),kind..' direction '..dir..' body '..r.body.direction..' retained '..r.direction..' error '..tostring(r.physical_error)) end
    if kind=='computer' then runtime.save(r.id,source,0); r.state.keep='not copied'
    elseif kind=='kv' then kv.methods.set(nil,r,'red',game.tick,nop,'secret','not copied') end
    f()[kind]=r.id
  end
  group('every-family-cardinal-rotation-retains-exact-owned-port-roles')
  local m=registry.record(f().monitor); monitor.reconcile(game.tick,nop)
  local g=assert(monitor.resolve(m)); model.calls.write(g.model,nop,'private screen')
  model.scale(g.model,1,1,nop,2); model.calls.setPaletteColor(g.model,nop,1,0x123456)
  local mi=mine(m); local m2=replace(mi,m.position.x,m.position.y); mi.destroy(); f().monitor=m2.id
  monitor.reconcile(game.tick,nop); local fresh=assert(monitor.resolve(m2))
  assert(fresh.id~=g.id and fresh.model.scale==2 and fresh.model.cells[1][1]==32 and fresh.model.palette[1][1]==0x12/255)
  f().monitor_group=fresh.id; model.calls.write(fresh.model,nop,'COLD')
  group('monitor-mining-preserves-settings-not-obsolete-buffer-or-logical-identity')
  local db=registry.record(f().kv)
  kv.methods.expire(nil,db,'red',game.tick,nop,'secret',1000); f().deadline=db.database.entries.secret.deadline
  local intact=db.database; db.database={version=1,entries={lost={type='string',value='retained',bytes=8}},order={},bytes=0,fields=0,cursor=1}
  kv.initialize(db); assert(not db.body.minable and db.database.entries.lost.value=='retained')
  assert(not pcall(kv.methods.get,nil,db,'red',game.tick,nop,'lost'))
  kv.maintenance(game.tick,nop); assert(db.database.entries.lost.value=='retained')
  db.database=intact; kv.initialize(db)
  -- Source settings copy is deliberately not a state transfer or destructive reset.
  snapshots.apply_settings(restored,snapshots.settings(registry.record(f().computer)))
  assert(restored.state==before and restored.status=='stopped' and restored.saved_source==source)
  group('settings-copy-stops-old-run-preserves-destination-state-excludes-source-state')
  -- Real engine blueprint capture/build/revival. No player/GUI is fabricated.
  local inventory=game.create_inventory(1); inventory[1].set_stack{name='blueprint',count=1}
  local bp=inventory[1]; local surf=game.surfaces[1]
  local a=registry.record(f().computer); local l=registry.record(f().logic)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  assert(lifecycle.connector(db,'network','red').connect_to(lifecycle.connector(l,'network','red')))
  local searcher=registry.record(f().recipe_searcher)
  assert(lifecycle.connector(l,'network','green').connect_to(lifecycle.connector(searcher,'network','green')))
  local statistics=registry.record(f().production_statistics)
  assert(lifecycle.connector(searcher,'network','green').connect_to(lifecycle.connector(statistics,'network','green')))
  local target=assert(surf.create_entity{name='constant-combinator',position={l.position.x+3,9},force='player'})
  assert(lifecycle.connector(l,'output','green').connect_to(target.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
  local mapping=bp.create_blueprint{surface=surf,force='player',area={{2,8},{36,16}}}
  assert(blueprints.prepare(bp,mapping)); assert(bp.blueprint_description:find(blueprints.disclosure,1,true))
  local entities=bp.get_blueprint_entities(); local ports=0
  for _,e in ipairs(entities) do if defs.port_role(e.name) then ports=ports+1 end
    if e.tags and e.tags.tc_settings then assert(not e.tags.tc_settings.state and not e.tags.tc_settings.database) end
  end
  local expected_ports=0; for _,kind in ipairs(defs.order) do expected_ports=expected_ports+#defs.devices[kind].roles-1 end
  assert(ports==expected_ports,'all owned blueprint roles must be represented: '..ports..' / '..expected_ports)
  f().blueprint_inventory=inventory
  group('native-blueprint-source-disclosure-no-state-kv-and-complete-role-wire-graph')
  -- Destruction and surface deletion never delete a replacement by location.
  local srf=game.create_surface('tc12-delete',{width=32,height=32}); local gone=build('computer',0,0,srf); local oldchild=gone.children.power
  local id=gone.id; lifecycle.on_surface_removed{surface_index=srf.index}; game.delete_surface(srf)
  assert(not registry.record(id) and not oldchild.valid)
  group('surface-delete-route-retires-exact-owned-objects-on-init-events-suppressed')
  f().start_tick=game.tick
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function cold_check()
  local x=f(); local r=registry.record(x.robot_id); local saved=x.snapshot; local root=registry.get()
  local items=x.monitor_inventory
  assert(items[1].name=='tc-monitor' and items[1].count==49 and not next(items[1].tags))
  assert(items[2].count==1 and items[2].tags.tc_monitor.scale==2 and items[2].tags.tc_monitor.palette[1][2]==0.2)
  assert(registry.record(x.robot_built_monitor).body.valid)
  assert(r==x.alias and r.state==x.state_alias and r.active==x.active_alias)
  assert(r.saved_source==saved.saved_source and r.active.source==x.expected_active and r.state_bytes==65536 and r.body.unit_number==saved.unit)
  assert(root.ledger.tick==saved.tick and root.ledger.total==saved.total and root.scheduler.maintenance_spent==saved.maintenance)
  local db=registry.record(x.kv); assert(db.database==x.database_alias and db.database.entries.secret.deadline==x.deadline)
  local g=monitor.resolve(registry.record(x.monitor)); assert(g.id==x.monitor_group and g.model==x.monitor_alias and g.model.cells[1][1]==67)
  assert(root.player_drafts[1].documents[x.original_id].source=='unsaved recoverable draft')
end
function M.on_load() loaded=true; if f().phase=='frozen' then cold_check(); log('TC_COLD_ON_LOAD_UNCHANGED') end end
function M.on_configuration_changed()
  cold_check(); snapshots.initialize_existing(); kv.initialize_existing(); f().upgraded=true
  assert(registry.record(f().robot_id).state==f().state_alias)
  log('TC_CONFIGURATION_DATA_RETAINED')
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    cold_check(); loaded=false
    local material=x.monitor_inventory[2]
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.monitor.entity_name,position={4,16},force='player',quality=material.quality})
    lifecycle.on_built{entity=body,stack=material}
    local restored=assert(registry.by_entity(body)); material.clear()
    assert(restored.monitor_settings.scale==2 and restored.monitor_settings.palette[1][2]==0.2)
    assert(x.monitor_inventory[1].count==49 and x.monitor_inventory.get_item_count('tc-monitor')==49)
    log('TC_NATIVE_MINED_MONITOR_COLD_REPLACEMENT_OK settings-retained fresh-count=49')
    if x.upgraded then log('TC_UPGRADE_OK lifecycle-data-source-state-deadline-monitor-drafts')
    else log('TC_COLD_OK lifecycle-data-source-state-deadline-monitor-drafts') end
    x.phase='done'; return
  end
  loaded=false
  assert(event.tick<x.start_tick+1800,'compact lifecycle scenario deadline exceeded')
  if x.phase=='start' then
    for _,scope in ipairs(x.expired_scopes) do
      if game.surfaces[scope.index] or registry.get().computer_undo.ghosts[scope.unit] then return end
    end
    for _,scope in ipairs(x.expired_scopes) do
      assert(not scope.surface.valid)
      local fresh=game.create_surface(scope.name); fresh.request_to_generate_chunks({0,0},1); fresh.force_generate_chunk_requests()
      scope.tags.tc_computer_undo.surface=fresh.index
      local pos=scope.tags.tc_computer_undo.position
      local wrong=assert(fresh.create_entity{name=defs.devices.computer.entity_name,position=pos,force='player'})
      local material=game.create_inventory(1); material[1].set_stack{name='tc-computer',count=1}
      lifecycle.on_built{entity=wrong,tags=scope.tags,consumed_items=material}; assert(not wrong.valid)
      local drops=fresh.find_entities_filtered{type='item-entity'}; assert(#drops==1 and drops[1].stack.name=='tc-computer' and drops[1].stack.count==1 and material[1].count==1)
      material.destroy()
      local replacement=build('computer',pos.x,pos.y,fresh); assert(replacement.saved_source=='' and next(replacement.state)==nil)
      replacement.saved_source='later ordinary placement'; lifecycle.on_built{entity=replacement.body,tags=scope.tags}
      assert(replacement.saved_source=='later ordinary placement' and replacement.body.valid)
      game.delete_surface(fresh)
    end
    log('TC_NATIVE_UNDO_DELETED_RECREATED_SURFACES_OK '..#x.expired_scopes); x.expired_scopes=nil
    -- Genuine on_tick clone events, all registered families, including native area helper clones.
    x.clones={}
    for _,kind in ipairs(defs.order) do
      local r=registry.record(x[kind]); local b=assert(r.body.clone{position={r.body.position.x,32},surface=r.body.surface,force=r.body.force})
      local clone=assert(registry.by_entity(b),'real clone event must register every body family')
      assert(clone.id~=r.id and not clone.output_owner)
      if kind=='computer' then assert(clone.saved_source==source and clone.status=='stopped' and not clone.active and next(clone.state)==nil and next(clone.timers)==nil)
      elseif kind=='kv' then assert(next(clone.database.entries)==nil) end
      x.clones[#x.clones+1]=clone.id
      if kind=='production_statistics' then
        local helper=lifecycle.power_entity(clone); local id=clone.id
        local native=clone.body.force.get_item_production_statistics(clone.body.surface)
        local before=serpent.line(native.input_quality_counts)
        local inventory=mine(clone)
        assert(inventory.get_item_count('tc-production-statistics')==1 and not helper.valid and not registry.record(id))
        assert(serpent.line(native.input_quality_counts)==before,'mining statistics reset native counters')
        local rebuilt=replace(inventory,clone.position.x,clone.position.y); inventory.destroy()
        assert(rebuilt.id~=id and not rebuilt.statistics and not rebuilt.history)
        assert(lifecycle.remove(rebuilt.id,'fixture',true))
        log('TC_STAT_NATIVE_MINING one-drop-helper-cleanup-no-history-reset')
      end
    end
    local surf=game.surfaces[1]
    surf.clone_area{source_area={{2,8},{24,16}},destination_area={{2,48},{24,56}},clone_entities=true,clone_tiles=true,clone_decoratives=false,clear_destination_entities=false,expand_map=true}
    while registry.get().pending_clone_ports and #registry.get().pending_clone_ports>0 do blueprints.reconcile_clones(event.tick,nop) end
    local ports=surf.find_entities_filtered{area={{2,48},{24,56}},name={'tc-logic-input-socket','tc-logic-output-socket','tc-configurator-targets-socket'}}
    assert(#ports==3,'area clone left duplicate/orphan ports: '..#ports)
    for _,p in ipairs(ports) do assert(registry.by_entity(p),'area clone helper unowned') end
    log('TC_NATIVE_ALL_FAMILY_CLONES_OK area-helper-ownership')
    -- Blueprint ghosts are native; engine preserves endpoint wires through rotation.
    local bp=x.blueprint_inventory[1]
    -- The ninth body's rotated footprint extends beyond the old cleared edge.
    local tiles={}; for y=16,50 do for xx=64,96 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
    game.surfaces[1].set_tiles(tiles)
    for _,entity in ipairs(game.surfaces[1].find_entities_filtered{area={{64,16},{96,50}},type={'tree','simple-entity'}}) do entity.destroy() end
    local ghosts=bp.build_blueprint{surface=game.surfaces[1],force='player',position={80,32},direction=defines.direction.east,raise_built=true,skip_fog_of_war=false,build_mode=defines.build_mode.forced}
    assert(#ghosts>0)

    x.revived={}
    for _,ghost in ipairs(ghosts) do
      if ghost.valid and defs.by_name[ghost.ghost_name] then
        local name=ghost.ghost_name; local _,b=ghost.revive{raise_revive=true}; assert(b,'native blueprint body revive refused '..name)
        local r=assert(registry.by_entity(b)); x.revived[r.kind]=r.id
        if r.kind=='computer' then assert(r.saved_source==source and r.status=='stopped' and next(r.state)==nil)
        elseif r.kind=='kv' then assert(next(r.database.entries)==nil) end
      elseif ghost.valid and not defs.port_role(ghost.ghost_name) then assert(select(2,ghost.revive{raise_revive=true})) end
    end
    local bc=registry.record(x.revived.computer); local bd=registry.record(x.revived.kv); local bl=registry.record(x.revived.logic)
    local bs=assert(registry.record(x.revived.recipe_searcher))
    assert(lifecycle.connector(bs,'network','green').connection_count==2,'blueprint lost Recipe Searcher wires')
    local statistics=assert(registry.record(x.revived.production_statistics))
    assert(lifecycle.connector(statistics,'network','green').connection_count==1 and not statistics.history)
    assert(bc and bd and bl)
    local red=lifecycle.connector(bc,'network','red')

    assert(red.connection_count==1 and lifecycle.connector(bd,'network','red').connection_count==2,'blueprint lost NETWORK wire roles')
    assert(lifecycle.connector(bl,'output','green').connection_count==1,'blueprint lost external OUTPUT wire')
    assert(lifecycle.connector(bl,'input','red').connection_count==0 and not bl.output_owner)
    log('TC_NATIVE_BLUEPRINT_ROTATED_REVIVAL_WIRES_OK')
    -- Native force/surface movement reconciles owned ports, retaining data but stopping authority.
    local moving=registry.record(x.restored); local srf=game.create_surface('tc12-move',{width=32,height=32})
    local crossbody=assert(moving.body.clone{position={0,0},surface=srf,force='player'})
    local cross=assert(registry.by_entity(crossbody)); assert(cross.saved_source==source and next(cross.state)==nil and cross.status=='stopped')
    local force=game.create_force('tc12-moved'); moving.body.force=force
    lifecycle.reconcile(event.tick,nop)
    assert(moving.body.surface==lifecycle.endpoint(moving,'network').surface and lifecycle.endpoint(moving,'network').force==force and moving.state_bytes==65536)
    assert(lifecycle.connector(moving,'network','red'))
    x.moving=moving.id; x.cross=cross.id; x.cross_surface=srf.index
    game.merge_forces(force,'player'); x.phase='force_wait'
  elseif x.phase=='force_wait' then
    lifecycle.reconcile(event.tick,nop)
    local moving=registry.record(x.moving)
    if moving.body.force.index~=game.forces.player.index then return end
    assert(moving.force_index==game.forces.player.index and moving.state_bytes==65536)
    local cross=registry.record(x.cross); x.cross_child=lifecycle.endpoint(cross,'network')
    game.delete_surface(x.cross_surface); x.phase='surface_wait'
  elseif x.phase=='surface_wait' then
    if game.surfaces[x.cross_surface] then return end
    assert(not registry.record(x.cross) and not x.cross_child.valid)
    log('TC_NATIVE_FORCE_SURFACE_MERGE_OK')
    local writer=build('computer',40,0); local output=build('logic',44,0)
    assert(lifecycle.connector(writer,'network','red').connect_to(lifecycle.connector(output,'network','red')))
    lifecycle.sample_power(writer,event.tick,nop); lifecycle.sample_power(output,event.tick,nop)
    local program="return {api_version=1,handlers={start=function(e) local l=peripheral.find('logic_handler','red'); assert(l); l.setOutput({{signal={type='virtual',name='signal-A'},count=9}}) end}}"
    runtime.save(writer.id,program,0); assert(runtime.activate(writer.id,event.tick)); assert(scheduler.dispatch(writer,event.tick))
    assert(output.output_owner and output.output_owner.computer_id==writer.id,'native output writer missing')
    local child=lifecycle.endpoint(writer,'network'); writer.active.compiler_version=99
    assert(writer.body.die()); assert(not registry.record(writer.id) and not child.valid and not output.output_owner and output.children.output.get_control_behavior().sections_count==0)
    log('TC_NATIVE_DESTRUCTION_OUTPUT_CLEANUP_OK malformed-source-independent')
    -- Maximum accepted source+state item, mined by an actual construction robot.
    local r=registry.record(x.computer)
    lifecycle.power_entity(r).energy=defs.devices.computer.watts/30; lifecycle.sample_power(r,event.tick,nop)
    x.expected_active=source..string.rep(' ',limits.source_bytes-#source)
    runtime.save(r.id,x.expected_active,r.saved_revision); assert(runtime.activate(r.id,event.tick))
    assert(scheduler.dispatch(r,event.tick)); fixture_state(r)
    runtime.save(r.id,saved..string.rep(' ',limits.source_bytes-#saved),r.saved_revision)
    assert(#r.saved_source==limits.source_bytes)
    x.robot_id=r.id; x.original_id=x.original_id or next(registry.get().player_drafts[1].documents)
    local surf=r.body.surface
    x.roboport=assert(surf.create_entity{name='roboport',position={8,18},force='player'})
    x.roboport.energy=100000000; x.roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=1}
    x.chest=assert(surf.create_entity{name='storage-chest',position={13,18},force='player'})
    x.pole=assert(surf.create_entity{name='substation',position={8,23},force='player'})
    x.generator=assert(surf.create_entity{name='electric-energy-interface',position={12,23},force='player'})
    x.generator.power_production=100000000; x.generator.power_usage=0
    local tile=build('monitor',4,16)
    local settings=snapshots.monitor_snapshot(tile); settings.scale=2; settings.palette[1]={0.1,0.2,0.3}
    snapshots.restore_monitor(tile,settings); x.robot_monitor=tile.id
    local cargo=x.chest.get_inventory(defines.inventory.chest)
    assert(cargo.insert{name='tc-monitor',count=50}==50)
    assert(surf.create_entity{name='entity-ghost',inner_name=defs.devices.monitor.entity_name,position={2,16},force='player'})
    x.robot_snapshot=snapshots.computer_snapshot(r,false)
    assert(r.body.order_deconstruction('player')); x.phase='mining'
  elseif x.phase=='mining' then
    -- Finish the fresh-stack construction first, so the robot cannot choose
    -- the subsequently mined tagged item as its construction material.
    if x.robot_built_monitor and not x.monitor_ordered then
      assert(registry.record(x.robot_monitor).body.order_deconstruction('player')); x.monitor_ordered=true
    end
    if not x.robot_mined or not x.monitor_mined or not x.robot_built_monitor then return end
    local inventory=x.chest.get_inventory(defines.inventory.chest); local stack=inventory.find_item_stack('tc-computer')
    if not stack then return end
    if inventory.get_item_count('tc-monitor')~=50 then return end
    local tagged,plain
    for i=1,#inventory do
      local item=inventory[i]
      if item.valid_for_read and item.name=='tc-monitor' then
        if item.tags.tc_monitor then tagged=item else plain=item end
      end
    end
    assert(tagged and plain and tagged.count==1 and plain.count==49,'native robot counts/tags coalesced')
    assert(tagged.tags.tc_monitor.scale==2 and tagged.tags.tc_monitor.palette[1][2]==0.2)
    x.monitor_inventory=game.create_inventory(2)
    assert(x.monitor_inventory[1].transfer_stack(plain) and x.monitor_inventory[2].transfer_stack(tagged))
    log('TC_NATIVE_MONITOR_ROBOT_COUNTS_OK fresh=49 built=1 mined-tagged=1')
    assert(inventory.get_item_count('tc-computer')==1 and stack.tags.tc_computer==nil)
    local r=replace({[1]=stack},4,12)
    assert(next(r.state)==nil and r.saved_source=='' and r.active==nil and r.status=='stopped')
    snapshots.restore_computer(r,x.robot_snapshot,false)
    assert(r.state_bytes==65536 and r.status=='stopped' and r.active.source==x.expected_active and next(r.timers)==nil)
    x.robot_id=r.id; x.alias=r; x.state_alias=r.state; x.active_alias=r.active
    stack.clear(); x.generator.power_production=0
    for _,id in ipairs(registry.get().order) do local rec=registry.record(id); lifecycle.power_entity(rec).power_usage=0 end
    x.database_alias=registry.record(x.kv).database
    local g=monitor.resolve(registry.record(x.monitor)); x.monitor_alias=g.model
    local root=registry.get(); root.scheduler.maintenance_spent=limits.maintenance_work_per_tick
    x.snapshot={saved_source=r.saved_source,unit=r.body.unit_number,tick=root.ledger.tick,total=root.ledger.total,maintenance=root.scheduler.maintenance_spent}
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
