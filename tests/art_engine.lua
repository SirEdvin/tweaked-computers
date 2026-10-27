-- Actual packaged native render-object selection, not client/GPU rendering.
local assets=require('assets.engine-contract')
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local art=require('scripts.device-art')
local M={}
local function nop() end
function M.run()
  assets.run()
  registry.initialize()
  local records={}; local cases=0
  for row,kind in ipairs(defs.order) do
    for col,direction in ipairs({0,4,8,12}) do
      local entity=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,
        position={col*7,row*7},direction=direction,force='player'})
      local rec=assert(lifecycle.build(entity)); records[#records+1]=rec
    end
  end
  local function check(state,tick,frame)
    for _,rec in ipairs(records) do
      rec.powered=state~='unpowered'; rec.status=state=='blinking' and 'running' or 'stopped'
      rec.physical_error=state=='fault' and 'fixture fault' or nil
    end
    art.tick(tick,nop)
    for _,rec in ipairs(records) do
      local direction=({'north','east','south','west'})[rec.body.direction/4+1]
      local effective=state
      if state=='powered' and rec.kind=='computer' then effective='off' end
      if state=='off' and rec.kind~='computer' then effective='powered' end
      if state=='blinking' and rec.kind~='computer' then effective='powered' end
      local expected='tc-status-'..rec.kind..'-'..direction..'-'..effective..'-'..(effective=='blinking' and frame or 0)
      assert(rec.status_art and rec.status_art.name==expected)
      assert(rec.status_art.object.valid and rec.status_art.object.sprite==expected)
      cases=cases+1
      -- No unchanged-status recreation; body and native connector ownership stay.
      local before=rec.status_art.object
      art.tick(tick,nop)
      assert(rec.status_art.object==before and registry.by_entity(rec.body)==rec)
    end
  end
  check('off',0,0); check('unpowered',0,0); check('powered',0,0); check('fault',0,0)
  for frame=0,3 do check('blinking',frame*10,frame) end
  for _,rec in ipairs(records) do
    local old=rec.status_art.object
    local parts={rec.body}; for _,child in pairs(rec.children) do parts[#parts+1]=child end
    assert(registry.remove(rec.id,'art fixture done') and not old.valid)
    for _,entity in ipairs(parts) do if entity.valid then entity.destroy() end end
  end
  assert(cases==224 and #registry.get().order==0)
  log('TC_RD2_STATUS_SELECTION_OK cases='..cases..' twenty-eight-native-shells-and-cleanup')
  -- assets.run emitted its own single-group total; do not invent a second total.
end
return M
