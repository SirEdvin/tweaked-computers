-- Install into an immutable pre-Dashboard same-engine save; keep old identities/state.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_dashboard_upgrade end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y or 0},force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function capture()
  local x=f(); local c=registry.record(x.c); local db=registry.record(x.db)
  local recipes,research={},{}
  for name,recipe in pairs(game.forces.player.recipes) do recipes[name]=recipe.enabled end
  for name,technology in pairs(game.forces.player.technologies) do research[name]=technology.researched end
  return {c=c,db=db,state=c.state,active=c.active,source=c.saved_source,boots=c.state.boots,
    computer_unit=c.body.unit_number,database_unit=db.body.unit_number,
    red=lifecycle.connector(c,'network','red').connection_count,green=lifecycle.connector(c,'network','green').connection_count,
    recipes=recipes,research=research}
end
local function unchanged()
  local a=f().before; local b=capture()
  for _,key in ipairs({'c','db','state','active','source','boots','computer_unit','database_unit','red','green'}) do assert(a[key]==b[key],'Dashboard installation changed '..key) end
  for name,value in pairs(a.recipes) do assert(b.recipes[name]==value,'installation changed old recipe '..name) end
  for name,value in pairs(a.research) do assert(b.research[name]==value,'installation changed old research '..name) end
end
function M.run()
  assert(not defs.devices.dashboard,'immutable baseline must predate Dashboard')
  storage.tc_dashboard_upgrade={phase='boot'}
  local x=f(); local c=build('computer',0); local db=build('kv',3)
  x.c=c.id; x.db=db.id
  for _,wire in ipairs({'red','green'}) do assert(lifecycle.connector(c,'network',wire).connect_to(lifecycle.connector(db,'network',wire))) end
  local power=assert(game.surfaces[1].create_entity{name='electric-energy-interface',position={6,6},force='player'})
  power.power_production=100000000; power.power_usage=0
  assert(game.surfaces[1].create_entity{name='substation',position={3,3},force='player'})
  game.forces.player.technologies['tc-circuit-computers'].researched=true; lifecycle.unlocks()
  game.create_force('tc-dashboard-upgrade-unresearched')
  local source=[[return {api_version=1,handlers={start=function() computer.setState('boots',(computer.getState('boots') or 0)+1) end}}]]
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load() loaded=true end
function M.on_configuration_changed()
  unchanged(); local x=f(); local fresh=game.forces['tc-dashboard-upgrade-unresearched']
  assert(game.forces.player.recipes['tc-dashboard'].enabled)
  if x.phase=='frozen' then
    assert(not fresh.technologies['tc-circuit-computers'].researched and not fresh.recipes['tc-dashboard'].enabled)
    x.phase='installed'
  elseif x.phase=='waiting-later' then
    assert(fresh.technologies['tc-circuit-computers'].researched and fresh.recipes['tc-dashboard'].enabled)
    x.phase='later'
  else error('unexpected Dashboard installation phase '..x.phase) end
end
function M.on_tick(event)
  local x=f()
  if x.phase=='frozen' or x.phase=='done' then return end
  if x.phase=='waiting-later' then
    if loaded then unchanged(); loaded=false; log('TC_UPGRADE_ORDINARY_OK') end
    return
  end
  scheduler.tick(event.tick)
  local c=registry.record(x.c); assert(c.status=='running',serpent.line(c.diagnostic))
  if x.phase=='boot' and c.state.boots then
    assert(c.state.boots==1); x.before=capture(); x.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='installed' then
    unchanged()
    if not x.probe then
      local panel=build('dashboard',6); local probe=build('computer',9)
      x.panel=panel.id; x.probe=probe.id
      assert(lifecycle.connector(probe,'network','red').connect_to(lifecycle.connector(panel,'network','red')))
      local source=[[return {api_version=1,handlers={start=function()
        local p=peripheral.find('dashboard','red'); assert(p)
        p.setTab(1,{title='Installed',content={type='label',id='status',text='Ready'}})
        computer.setState('configured',true)
      end}}]]
      assert(runtime.save(probe.id,source,0)); assert(runtime.activate(probe.id,event.tick)); return
    end
    local probe=registry.record(x.probe); assert(probe.status=='running',serpent.line(probe.diagnostic))
    if not probe.state.configured then return end
    assert(registry.record(x.panel).dashboard.tabs['1'].definition.content.text=='Ready')
    local fresh=game.forces['tc-dashboard-upgrade-unresearched']
    fresh.technologies['tc-circuit-computers'].researched=true; fresh.recipes['tc-dashboard'].enabled=false
    x.phase='waiting-later'; game.server_save('tc-dashboard-installed'); log('TC_UPGRADE_OK')
  elseif x.phase=='later' then
    unchanged(); x.phase='done'; log('TC_DASHBOARD_LATER_RECONCILIATION_OK')
  end
end
return M
