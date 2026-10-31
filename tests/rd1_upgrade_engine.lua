-- Same fixture is injected into an untouched alpha checkout, then read by the
-- candidate in a new process. Only the test mod version triggers configuration.
local registry=require('scripts.registry')
local defs=require('scripts.device-definitions')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local data=require('scripts.runtime.data')
local kv=require('scripts.services.kv')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local snapshots=require('scripts.lifecycle-data')
local blueprints=require('scripts.blueprints')
local M={}; local loaded=false
local function nop() end
local function f() return storage.rd1_upgrade end
local function endpoint(rec,role) return rec.layout_version==2 and role=='network' and rec.body or rec.children[role] end
local function connect(a,ar,b,br,color)
  local cid=defines.wire_connector_id['circuit_'..color]
  assert(endpoint(a,ar).get_wire_connector(cid,true).connect_to(endpoint(b,br).get_wire_connector(cid,true),false))
end
local program="function start(e) computer.setState('boots',(computer.getState('boots') or 0)+1); computer.every(1000,'timer'); local l=peripheral.find('logic_handler','red'); assert(l); l.setOutput({{signal={type='virtual',name='signal-C'},count=13}}) end\n\nfunction timer(e) computer.setState('timers',(computer.getState('timers') or 0)+1) end"
function M.run()
  assert(not defs.devices.computer.entity_name,'old fixture must run on the pinned alpha source')
  storage.rd1_upgrade={phase='old',records={},parts={},order={},start=game.tick}
  local s=game.surfaces[1]; local x=f()
  for i,kind in ipairs(defs.order) do
    x.order[i]=kind
    local body=assert(s.create_entity{name=defs.devices[kind].name,position={i*3,0},force='player'})
    lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body)); x.records[kind]=rec
    body.energy=defs.devices[kind].watts/30; rec.powered=true
    x.parts[#x.parts+1]=body
    for _,part in pairs(rec.children) do x.parts[#x.parts+1]=part end
  end
  for _,color in ipairs({'red','green'}) do
    for i=2,#defs.order do connect(x.records[defs.order[i-1]],'network',x.records[defs.order[i]],'network',color) end
  end
  local input=assert(s.create_entity{name='constant-combinator',position={12,-3},force='player'})
  local cb=input.get_or_create_control_behavior(); cb.add_section().set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=7}); cb.enabled=true
  x.input=input
  local cid=defines.wire_connector_id.circuit_red
  assert(input.get_wire_connector(cid,true).connect_to(x.records.logic.children.input.get_wire_connector(cid,true)))
  x.sink=assert(s.create_entity{name='constant-combinator',position={15,-3},force='player'})
  assert(x.records.logic.children.output.get_wire_connector(cid,true).connect_to(x.sink.get_wire_connector(cid,true)))
  -- Retain an unsupported vanilla network cable too, without granting traversal.
  assert(input.get_wire_connector(cid,true).connect_to(x.records.kv.children.network.get_wire_connector(cid,true)))
  -- The immutable alpha cannot compile declarations: seed data, never an active run.
  local c=x.records.computer
  runtime.save(c.id,program,0)
  local value,stats=data.copy(1,nop)
  c.state.boots=value; c.state_sizes.boots=stats.bytes+#'boots'+16
  c.state_entries=1; c.state_bytes=c.state_bytes+c.state_sizes.boots
  c.state_nodes=c.state_nodes+stats.nodes; c.state_node_sizes.boots=stats.nodes
  local io=x.records.logic
  io.output_bank={{signal={type='virtual',name='signal-C',quality='normal'},count=13}}
  local output=io.children.output.get_or_create_control_behavior()
  output.add_section().set_slot(1,{value={type='virtual',name='signal-C',quality='normal'},min=13}); output.enabled=true
  kv.methods.set(nil,x.records.kv,'red',game.tick,nop,'secret','retained string')
  kv.methods.hset(nil,x.records.kv,'red',game.tick,nop,'hash','field','retained hash')
  kv.methods.expire(nil,x.records.kv,'red',game.tick,nop,'secret',6000)
  monitor.reconcile(game.tick,nop); x.group=assert(monitor.resolve(x.records.monitor)); model.calls.write(x.group.model,nop,'KEEP')
  local c=x.records.computer
  registry.get().player_drafts[1]={documents={[c.id]={source='dirty retained draft',base_source=program,base_revision=c.saved_revision}},session={id=c.id,unit=c.body.unit_number,token=7}}
  x.inventory=game.create_inventory(2); x.inventory[1].set_stack{name='blueprint',count=1}
  local bp=x.inventory[1]; local mapping=bp.create_blueprint{surface=s,force='player',area={{0,-5},{20,3}}}
  assert(blueprints.prepare(bp,mapping))
  x.records.kv.body.order_deconstruction('player')
  x.inventory[2].set_stack{name='tc-computer',count=1}; x.inventory[2].tags={tc_computer=snapshots.computer_snapshot(c,false)}
  x.state=c.state; x.active=c.active; x.timers=c.timers; x.queue=c.queue; x.run=c.run_id; x.generation=c.generation
  x.database=x.records.kv.database; x.deadline=x.database.entries.secret.deadline; x.screen=x.group.model
  x.bank=x.records.logic.output_bank; x.owner=x.records.logic.output_owner
  -- A malformed retained part must refuse conversion without deleting its owner.
  x.refused=x.records.configurator; x.missing=x.refused.children.targets; x.refused.children.targets=nil
  -- Deliberate host-only oversized native output tests refusal AFTER allocation.
  local extra=assert(s.create_entity{name=defs.devices.logic.name,position={24,0},force='player'})
  lifecycle.on_built{entity=extra}; x.staged_refused=assert(registry.by_entity(extra))
  local extra_cb=x.staged_refused.children.output.get_or_create_control_behavior()
  extra_cb.add_section().set_slot(513,{value={type='virtual',name='signal-A',quality='normal'},min=1})
  assert(extra_cb.get_section(1).filters_count>512)
  assert(x.staged_refused.children.output.get_wire_connector(cid,true).connect_to(x.sink.get_wire_connector(cid,true),false))
  extra.power_usage=0
  for _,rec in pairs(x.records) do rec.body.power_usage=0 end
  log('TC_CONTRACT genuine-alpha-stopped-host-data-kv-screen-wires-blueprint-tagged-item')
  log('TC_CONTRACT_TOTAL 1')
end
local function retained(loading)
  local x=f(); local c=x.records.computer
  assert(registry.record(c.id)==c and c.state==x.state and c.active==x.active and c.timers==x.timers and c.queue==x.queue)
  assert(c.run_id==x.run and c.generation==x.generation and c.state.boots==1 and not c.state.timers and c.saved_source==program)
  assert(c.status=='stopped' and not c.active and not c.run_id and next(c.timers)==nil and next(c.queue)==nil)
  assert(c.state_nodes==1+c.state_node_sizes.boots and c.state_node_sizes.boots==1)
  assert(c.state_entries==1 and c.state_bytes==16+c.state_sizes.boots)
  assert(x.records.kv.database==x.database and x.database.entries.secret.value=='retained string')
  assert(x.database.entries.hash.fields.field=='retained hash' and x.database.entries.secret.deadline==x.deadline)
  local monitors=registry.get().monitors
  local group=loading and monitors.groups[monitors.membership[x.records.monitor.id]] or monitor.resolve(x.records.monitor)
  assert(group==x.group and x.group.model==x.screen and x.screen.cells[1][1]==75)
  local io=x.records.logic
  assert(io.output_owner==x.owner)
  if not x.upgraded then assert(io.output_bank==x.bank) end
  assert(io.children.output.get_control_behavior().get_section(1).get_slot(1).min==13)
  assert(registry.get().player_drafts[1].documents[c.id].source=='dirty retained draft')
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then retained(true); log('TC_RD1_OLD_ON_LOAD_UNCHANGED') end
end
function M.on_configuration_changed()
  local x=f(); x.upgraded=true; retained()
  for _,kind in ipairs({'computer','kv','monitor','logic'}) do
    local rec=x.records[kind]; assert(rec.layout_version==2 and rec.body.name==defs.devices[kind].entity_name)
    assert(registry.by_entity(rec.body)==rec and lifecycle.available(rec) and not rec.children.power)
    for _,role in ipairs(defs.devices[kind].roles) do for _,color in ipairs({'red','green'}) do
      assert(lifecycle.connector(rec,role,color),'migrated role unavailable')
    end end
  end
  assert(x.group.body==x.records.monitor.body,'monitor anchor retained an invalid body')
  assert(x.records.kv.body.to_be_deconstructed('player'),'native removal order lost')
  assert(registry.get().player_drafts[1].session==nil,'stale editor session was not invalidated')
  assert(x.refused.layout_version~=2 and x.refused.body.valid and x.refused.migration_error)
  assert(x.refused.children.network.valid and x.missing.valid,'refusal deleted retained parts')
  local refused=x.staged_refused; local old_output=refused.children.output
  assert(refused.body.valid and refused.layout_version~=2 and refused.migration_error)
  assert(old_output.valid and old_output.get_wire_connector(defines.wire_connector_id.circuit_red,true).real_connection_count==1)
  local surface=refused.body.surface
  assert(#surface.find_entities_filtered{area=refused.body.bounding_box,name=defs.devices.logic.entity_name}==0,'failed stage left a shell')
  assert(#surface.find_entities_filtered{area=refused.body.bounding_box,name=defs.devices.logic.power_name}==0,'failed stage left private power')
  local section=old_output.get_control_behavior().get_section(1); section.filters={}
  section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=1})
  assert(lifecycle.upgrade(refused) and not old_output.valid)
  assert(not refused.children.power and lifecycle.available(refused))
  x.refused.children.targets=x.missing
  assert(lifecycle.upgrade(x.refused)); retained()
  for _,part in ipairs(x.parts) do assert(not part.valid,'old physical object survived successful upgrade') end
  -- Preserve every edge from the old world's graph, not newly added families.
  for _,color in ipairs({'red','green'}) do
    for i=2,#x.order do
      local a=x.records[x.order[i-1]]; local b=x.records[x.order[i]]; local c=lifecycle.connector(a,'network',color); local found=false
      for _,connection in ipairs(c.real_connections) do if connection.target==lifecycle.connector(b,'network',color) then found=true end end
      assert(found,'upgrade lost exact role/color edge')
    end
  end
  assert(lifecycle.connector(x.records.kv,'network','red').real_connection_count==3,'unsupported cable was lost')
  assert(lifecycle.connector(x.records.logic,'input','red').real_connection_count==1)
  assert(lifecycle.connector(x.records.logic,'output','red').real_connection_count==1)
  local out=x.records.logic.children.output.get_control_behavior()
  assert(out.enabled and out.get_section(1).get_slot(1).min==13,'output section lost during replacement')
  for _,rec in pairs(x.records) do assert(not rec.children.power and lifecycle.available(rec)) end
  x.upgraded=true; x.phase='verify'; x.tick=game.tick
  log('TC_RD1_UPGRADE_DATA_WIRES_REFUSAL_OK stopped-host-setup logical-aliases-and-old-endpoints-retired')
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='old' then
    loaded=false
    if event.tick<x.start+3 then return end
    retained(); x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if x.phase=='frozen' and loaded and not x.upgraded then
    retained(); log('TC_COLD_OK genuine-alpha-ordinary-load'); x.phase='done'; return
  end
  if x.phase=='verify' then
    retained()
    -- Old alpha blueprint: native rotated ghosts, including generic helper tags.
    local surface=game.surfaces[1]; local tiles={}
    for y=0,40 do for xx=25,55 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
    surface.set_tiles(tiles)
    for _,entity in ipairs(surface.find_entities_filtered{area={{25,0},{55,40}},type={'tree','simple-entity'}}) do entity.destroy() end
    local ghosts=x.inventory[1].build_blueprint{surface=game.surfaces[1],force='player',position={40,20},direction=defines.direction.east,
      raise_built=true,build_mode=defines.build_mode.forced}
    local revived={}
    for _,ghost in ipairs(ghosts) do
      if ghost.valid and defs.by_name[ghost.ghost_name] then
        local kind=defs.by_name[ghost.ghost_name]; local pos=ghost.position
        local _,body=ghost.revive{raise_revive=true}
        -- Raised conversion may retire the old EEI before revive returns it.
        for _,id in ipairs(registry.get().order) do local rec=registry.record(id)
          if rec.kind==kind and rec.body.valid and rec.body.position.x==pos.x and rec.body.position.y==pos.y then revived[kind]=rec end
        end
        assert(revived[kind] and not ghost.valid,'old blueprint body revival failed '..kind..' at '..pos.x..','..pos.y)
      elseif ghost.valid and not defs.port_role(ghost.ghost_name) then assert(select(2,ghost.revive{raise_revive=true})) end
    end
    for _,kind in ipairs(x.order) do assert(revived[kind] and revived[kind].layout_version==2,'old blueprint not converted '..kind) end
    local c=revived.computer; local db=revived.kv; local l=revived.logic
    assert(c.saved_source==program and c.status=='stopped' and next(c.state)==nil and next(db.database.entries)==nil)
    assert(lifecycle.connector(c,'network','red').real_connection_count==1)
    assert(lifecycle.connector(db,'network','red').real_connection_count==3)
    assert(lifecycle.connector(l,'output','red').real_connection_count==1)
    local stack=x.inventory[2]
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={30,0},force='player'})
    lifecycle.on_built{entity=body,consumed_items={[1]=stack}}
    local item=assert(registry.by_entity(body)); assert(item.saved_source=='' and next(item.state)==nil and item.status=='stopped' and not item.run_id and not item.active)
    assert(next(item.timers)==nil and next(item.queue)==nil,'legacy computer item resumed an obsolete run')
    assert(x.inventory[2].tags.tc_computer.saved_source==program,'fixture must retain a genuine old computer-item payload')
    retained(); x.phase='done'; log('TC_UPGRADE_OK alpha-save-exact-data-wires-refusal-old-rotated-blueprint-tagged-item-no-start-replay')
  end
end
return M
