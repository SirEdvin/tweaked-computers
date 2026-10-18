-- Exact native physical-shell checks, not graphical hover/rendering evidence.
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local graph=require('scripts.network')
local wires=require('scripts.physical-wires')
local blueprints=require('scripts.blueprints')
local M={}; local loaded=false
local function nop() end
local function f() return storage.rd1 end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function wire(a,b,color)
  local id=defines.wire_connector_id['circuit_'..color]
  assert(a.get_wire_connector(id,true).connect_to(b.get_wire_connector(id,true),false))
end
local function signal(entity,name,count)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  cb.add_section().set_slot(1,{value={type='virtual',name=name,quality='normal'},min=count}); cb.enabled=true
end
local function value(rec,role,color,name)
  local network=lifecycle.endpoint(rec,role).get_circuit_network(defines.wire_connector_id['circuit_'..color])
  return network and network.get_signal{type='virtual',name=name,quality='normal'} or 0
end
function M.run()
  storage.rd1={groups=0,ids={},rows={},phase='signals',start=game.tick}
  local s=game.surfaces[1]
  for row,d in ipairs({0,4,8,12}) do
    local records={}; f().rows[#f().rows+1]=records
    for col,kind in ipairs(defs.order) do
      local def=defs.devices[kind]
      local b=assert(s.create_entity{name=def.entity_name,position={col*5,row*12},direction=d,force='player'})
      lifecycle.on_built{entity=b}; local rec=assert(registry.by_entity(b)); records[kind]=rec.id
      assert(rec.layout_version==2 and lifecycle.endpoint(rec,'network')==b and not rec.children.network)
      assert(b.type=='constant-combinator' and not b.operable and b.rotatable)
      assert(b.localised_name[1]=='entity-name.'..def.name)
      assert(b.get_control_behavior().sections_count==0 and not b.get_control_behavior().enabled)
      local box=b.selection_box; local horizontal=d==0 or d==8
      assert(box.right_bottom.x-box.left_top.x==(horizontal and def.width or 1))
      assert(box.right_bottom.y-box.left_top.y==(horizontal and 1 or def.width))
      local count=0
      for role,part in pairs(rec.children) do
        count=count+1; assert(registry.by_entity(part)==rec and not part.minable and not part.destructible and not part.operable)
        if role=='power' then
          assert(not part.prototype.selectable_in_game and part.prototype.has_flag('not-blueprintable'))
          assert(part.prototype.has_flag('not-deconstructable') and not part.prototype.mineable_properties.minable)
        else
          assert(part.name==defs.pad_name(kind,role) and part.localised_name[1]=='entity-name.'..part.name)
          local index; for i,r in ipairs(def.roles) do if r==role then index=i end end
          local x,y=defs.offset(kind,index,d)
          assert(part.position.x==b.position.x+x and part.position.y==b.position.y+y)
          assert(part.prototype.has_flag('not-deconstructable'))
        end
      end
      assert(count==#def.roles)
      for _,role in ipairs(def.roles) do for _,color in ipairs({'red','green'}) do assert(lifecycle.connector(rec,role,color)) end end
      local p=lifecycle.power_entity(rec); p.energy=def.watts/30; lifecycle.sample_power(rec,game.tick,nop)
      f().ids[#f().ids+1]=rec.id
      -- Body is the real mark/cancel target; helper state never substitutes for it.
      assert(b.order_deconstruction('player') and b.to_be_deconstructed('player')); b.cancel_deconstruction('player')
      assert(not b.to_be_deconstructed('player'))
    end
    local c=registry.record(records.computer); local m=registry.record(records.monitor); local l=registry.record(records.logic)
    for _,color in ipairs({'red','green'}) do
      wire(c.body,m.body,color); wire(m.body,l.body,color)
      local members=graph.discover(c,color,nop); local seen={}; for _,rec in ipairs(members) do seen[rec.id]=true end
      assert(seen[m.id] and seen[l.id],'direct shell discovery failed')
    end
    local source=assert(s.create_entity{name='constant-combinator',position={12,row*12-4},force='player'})
    signal(source,'signal-B',11); wire(source,c.body,'red'); wire(source,c.body,'green')
    local input=assert(s.create_entity{name='constant-combinator',position={20,row*12-4},force='player'})
    signal(input,'signal-A',7); wire(input,l.children.input,'red'); signal(l.children.output,'signal-C',13)
    local sink=assert(s.create_entity{name='constant-combinator',position={23,row*12-4},force='player'})
    wire(l.children.output,sink,'red')
    local cfg=registry.record(records.configurator)
    wire(source,cfg.body,'red')
    local target=assert(s.create_entity{name='constant-combinator',position={28,row*12-4},force='player'})
    signal(target,'signal-D',17); wire(target,cfg.children.targets,'red')
  end
  report('twenty-four-native-shells-cardinal-footprints-private-power-device-metadata-and-body-mark-cancel')
  report('direct-red-green-computer-monitor-logic-discovery')
  -- Refuse partial placement; only staged native objects are rolled back.
  local staged; local attempts=0; local before=#registry.get().order
  local fake={valid=true,unit_number=-1,name=defs.devices.logic.entity_name,type='constant-combinator',direction=0,
    position={x=100,y=100},force=game.forces.player,quality=prototypes.quality.normal,
    surface={find_entities_filtered=function() return {} end,create_entity=function(spec)
      attempts=attempts+1; if attempts==2 then return nil end
      staged=assert(s.create_entity(spec)); return staged
    end}}
  assert(not lifecycle.build(fake)); assert(staged and not staged.valid and #registry.get().order==before)
  report('partial-native-part-allocation-rolls-back-without-identity-or-orphan')
  local shell=registry.record(f().rows[1].computer).body
  signal(shell,'signal-Z',99) -- Explicit hostile native-paste setup, not guest access.
  blueprints.on_pasted{destination=shell,source=fake}
  assert(shell.get_control_behavior().sections_count==0 and not shell.get_control_behavior().enabled)
  local power_rec=registry.record(f().rows[1].kv); local retained_power=power_rec.children.power
  power_rec.children.power=nil
  assert(lifecycle.power_entity(power_rec)==nil and not lifecycle.has_power(power_rec),'missing private power fell back to the shell')
  power_rec.children.power=retained_power
  -- A later refused wire restores an earlier tentative edge, preserving originals.
  local a=registry.record(f().rows[1].kv).body
  local b=assert(s.create_entity{name='constant-combinator',position={40,0},force='player'})
  local dead=assert(s.create_entity{name='constant-combinator',position={42,0},force='player'})
  local target=dead.get_wire_connector(defines.wire_connector_id.circuit_red,true); dead.destroy()
  local cid=defines.wire_connector_id.circuit_red
  assert(not pcall(wires.apply,{{cid=cid,target=b.get_wire_connector(cid,true),origin=defines.wire_origin.player},
    {cid=cid,target=target,origin=defines.wire_origin.player}},a))
  assert(a.get_wire_connector(cid,true).connection_count==0 and b.get_wire_connector(cid,true).connection_count==0)
  report('wire-handoff-refusal-removes-only-tentative-connections')
  log('TC_CONTRACT_TOTAL '..f().groups)
end
function M.on_load() loaded=true end
function M.on_configuration_changed() end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    for _,id in ipairs(x.ids) do local rec=registry.record(id)
      assert(rec.layout_version==2 and not rec.powered and lifecycle.connector(rec,'network','red'))
    end
    x.phase='done'; log('TC_COLD_OK native-shell-passive-outage-reload'); return
  end
  loaded=false
  local elapsed=event.tick-x.start
  if elapsed==1 then
    for _,id in ipairs(x.ids) do
      local rec=registry.record(id); local def=defs.devices[rec.kind]; local p=lifecycle.power_entity(rec)
      assert(math.abs(p.energy-def.watts/60)<0.02,'private power draw mismatch '..rec.kind..' '..p.energy)
    end
    log('TC_RD1_NATIVE_PRIVATE_DRAIN_OK all-six-wattages')
  elseif elapsed>=3 and x.phase=='signals' then
    for _,row in ipairs(x.rows) do
      local l=registry.record(row.logic); local m=registry.record(row.monitor)
      for _,color in ipairs({'red','green'}) do
        assert(value(m,'network',color,'signal-B')==11 and value(m,'network',color,'signal-A')==0)
        assert(value(m,'network',color,'signal-C')==0,'network shell generated or leaked signals')
      end
      assert(value(l,'input','red','signal-A')==7 and value(l,'input','red','signal-B')==0)
      assert(value(l,'output','red','signal-C')==13 and value(l,'output','red','signal-B')==0)
      local cfg=registry.record(row.configurator)
      assert(value(cfg,'network','red','signal-B')==11 and value(cfg,'network','red','signal-D')==0)
      assert(value(cfg,'targets','red','signal-D')==17 and value(cfg,'targets','red','signal-B')==0)
    end
    x.phase='outage'; log('TC_RD1_NATIVE_PASSIVE_ISOLATION_OK all-cardinal red-green')
  elseif elapsed>=8 and x.phase=='outage' then
    for _,id in ipairs(x.ids) do local rec=registry.record(id)
      lifecycle.sample_power(rec,event.tick,nop); assert(not rec.powered)
      assert(lifecycle.connector(rec,'network','red'),'outage removed passive network')
      if rec.kind=='logic' then assert(rec.children.output.get_control_behavior().sections_count==0) end
    end
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
