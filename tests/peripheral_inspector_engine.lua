-- Combined real-wire fixture, also reused by the native client scene.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local defs=require('scripts.device-definitions')
local kv=require('scripts.services.kv')
local logic=require('scripts.services.logic')
local configurator=require('scripts.services.configurator')
local targets=require('scripts.configuration.targets')
local monitor=require('scripts.services.monitor')
local model=require('scripts.ui.peripheral-inspector-model')
local contracts=require('tests.peripheral_inspector_contract')
local M={}; local loaded=false
local function nop() end
local function state() return storage.tc_inspector_test end
local function rec(kind) return registry.record(state().ids[kind]) end
local function wire(entity,target,role,color)
  assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(target,role,color)))
end
local function emit(entity,color,count)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=cb.add_section()
  section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=count})
  if color=='red' then
    section.set_slot(2,{value={type='item',name='iron-plate',quality='normal'},min=2147483647})
    section.set_slot(3,{value={type='recipe',name='iron-plate',quality='normal'},min=-2147483648})
    if script.active_mods.quality then section.set_slot(4,{value={type='item',name='iron-plate',quality='uncommon'},min=4}) end
  end
  cb.enabled=true
end
function M.setup()
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},2); surface.force_generate_chunk_requests(); surface.always_day=true
  for _,e in ipairs(surface.find_entities_filtered{area={{-20,-20},{24,20}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-20,20 do for x=-20,24 do tiles[#tiles+1]={name='landfill',position={x,y}} end end; surface.set_tiles(tiles)
  storage.tc_inspector_test={ids={},start=game.tick,phase='boot',groups=0}
  local function build(kind,x,y)
    local r=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
    state().ids[kind]=r.id; return r
  end
  local c=build('computer',-4,0)
  local db=build('kv',-1,0); local io=build('logic',2,0); local cfg=build('configurator',6,0)
  build('recipe_searcher',-4,3)
  local members={}
  for y=3,4 do for x=-1,0 do members[#members+1]=build('monitor',x,y).id end end
  state().tiles=members
  for _,r in ipairs({db,io,cfg,rec('recipe_searcher'),rec('monitor')}) do
    assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(r,'network','red')))
  end
  surface.create_entity{name='substation',position={4,5},force='player'}
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={8,6},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  local a=assert(surface.create_entity{name='constant-combinator',position={2,-3},force='player'})
  local b=assert(surface.create_entity{name='constant-combinator',position={4,-3},force='player'})
  emit(a,'red',11); emit(b,'green',-7)
  wire(a,io,'input','red'); wire(b,io,'input','green'); wire(b,io,'output','red'); state().source=a
  local target=assert(surface.create_entity{name='inserter',position={7,3},force='player'})
  local relay=assert(surface.create_entity{name='small-electric-pole',position={5,3},force='player'})
  wire(target,cfg,'targets','red'); wire(target,cfg,'targets','green'); wire(relay,cfg,'targets','green')
  state().target=target
  local source='return {api_version=1,handlers={start=function(e) computer.setState("starts",(computer.getState("starts") or 0)+1); local io=peripheral.find("logic_handler","red"); assert(io); io.setOutput({{signal={type="virtual",name="signal-A",quality="normal"},count=5}}); computer.every(30,"beat") end,beat=function(e) computer.setState("beats",(computer.getState("beats") or 0)+1) end}}'
  runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  kv.methods.set(nil,db,nil,game.tick,nop,'','')
  kv.methods.set(nil,db,nil,game.tick,nop,'binary\0\255','\0\255\\"\n[img=item/iron-plate]')
  kv.methods.set(nil,db,nil,game.tick,nop,'long',string.rep('0123456789abcdef',512))
  kv.methods.hset(nil,db,nil,game.tick,nop,'hash','field\0','value\255','','')
  state().database=db.database
end
function M.run() contracts.run(); M.setup() end
local function report(name) state().groups=state().groups+1; log('TC_INSPECTOR '..name) end
local function verify(tick)
  local d=kv.inspect(rec('kv'),tick,nop)
  assert(#d.entries==4 and rec('kv').database==state().database)
  local cost=0
  local a=logic.inspect(rec('logic'),tick,function(n) cost=cost+n end)
  log('TC_INSPECTOR_LOGIC_WORK '..cost)
  local found={}
  for _,entry in ipairs(a.red) do found[entry.signal.type..'/'..entry.signal.quality]=entry.count end
  assert(found['virtual/normal']==11 and found['item/normal']==2147483647 and found['recipe/normal']==-2147483648)
  if script.active_mods.quality then assert(found['item/uncommon']==4) end
  assert(#a.green==1 and a.green[1].count==-7)
  assert(a.connected.red and a.connected.green and #a.output==1 and a.output[1].count==5 and rec('logic').output_owner)
  assert(not rec('logic').logic_sample)
  report('real-wire-separate-inputs-no-subscription-own-bank-excludes-other-emitter')
  local inventory=configurator.inspect(rec('configurator'),tick,nop)
  assert(#inventory.groups==2)
  assert(inventory.groups[1].prototype=='inserter' and inventory.groups[1].total==1 and inventory.groups[1].red==1 and inventory.groups[1].green==1)
  assert(inventory.groups[2].prototype=='small-electric-pole' and inventory.groups[2].total==1 and inventory.groups[2].red==0 and inventory.groups[2].green==1)
  report('real-target-wires-deduplicated-overlap-relay-and-discovery-isolation')
  local cfg=rec('configurator'); local surface=cfg.body.surface
  local fast=assert(surface.create_entity{name='fast-inserter',position={9,3},force='player'})
  wire(fast,cfg,'targets','red'); wire(fast,cfg,'targets','green')
  local next_inventory=configurator.inspect(cfg,tick,nop)
  assert(#next_inventory.groups==3 and next_inventory.groups[1].prototype=='fast-inserter'
    and next_inventory.groups[1].red==1 and next_inventory.groups[1].green==1 and next_inventory.groups[1].total==1)
  local red=lifecycle.connector(cfg,'targets','red'); local green=lifecycle.connector(cfg,'targets','green')
  assert(fast.get_wire_connector(defines.wire_connector_id.circuit_red).disconnect_from(red))
  local green_only=configurator.inspect(cfg,tick,nop)
  assert(green_only.groups[1].red==0 and green_only.groups[1].green==1 and green_only.groups[1].total==1)
  assert(fast.get_wire_connector(defines.wire_connector_id.circuit_green).disconnect_from(green))
  assert(#configurator.inspect(cfg,tick,nop).groups==2)
  fast.destroy()
  local observed=false; local enumerate=targets.inventory
  targets.inventory=function(r,color,spend)
    if color=='green' then observed=true; error('fixture refuses green after complete red inventory') end
    return enumerate(r,color,spend)
  end
  local ok=pcall(configurator.inspect,cfg,tick,nop)
  targets.inventory=enumerate
  assert(not ok and observed and #inventory.groups==2,'refusal must not modify a prior complete inventory')
  report('real-distinct-prototypes-color-removal-and-private-refusal')
  local first=monitor.inspect(registry.record(state().tiles[1]),tick,nop)
  local last=monitor.inspect(rec('monitor'),tick,nop)
  assert(first.name==last.name and first.width_tiles==2 and first.height_tiles==2 and first.tiles==4)
  assert(first.columns==last.columns and first.rows==last.rows)
  local g=monitor.resolve(rec('monitor')); local revision=g.model.revision
  assert(model.read(rec('monitor'),tick,nop).name==g.id and g.model.revision==revision)
  report('logical-nonanchor-name-and-coherent-tile-cell-geometry-no-revision-change')
  for _,id in pairs(state().ids) do
    local r=registry.record(id); local cb=r.body.get_control_behavior()
    assert(r.body.operable==(r.kind~='computer') and not cb.enabled and cb.sections_count==0)
  end
  report('all-bodies-openability-independent-of-electrical-passivity')
end
function M.on_load() loaded=true end
function M.on_configuration_changed() state().upgraded=true end
function M.on_tick(event)
  local s=state()
  if s.phase=='done' then return end
  if s.phase=='frozen' then
    if not loaded then return end
    assert(rec('kv').database==s.database)
    assert(registry.get().scheduler.maintenance_spent==s.spent and registry.get().scheduler.maintenance_tick==s.maintenance_tick)
    assert(rec('computer').state.starts==s.starts and rec('computer').run_id==s.run)
    assert(monitor.resolve(rec('monitor')).model.revision==s.revision)
    s.phase='done'; log(s.upgraded and 'TC_UPGRADE_OK' or 'TC_COLD_OK'); return
  end
  scheduler.tick(event.tick)
  if event.tick-s.start>=120 then
    verify(event.tick)
    s.starts=rec('computer').state.starts; s.run=rec('computer').run_id
    s.revision=monitor.resolve(rec('monitor')).model.revision
    s.spent=registry.get().scheduler.maintenance_spent; s.maintenance_tick=registry.get().scheduler.maintenance_tick
    loaded=false; s.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
