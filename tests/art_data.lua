-- Compare shipped art metadata to actual native contacts; no graphical claims.
local art=require('__tweaked-computers__.assets.sprites')
local defs=require('__tweaked-computers__.scripts.device-definitions')
require('__tweaked-computers__.assets.engine-data')
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local contacts,statuses=0,0
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]; local device=art.devices[kind]
  local shell=data.raw['constant-combinator'][def.entity_name]
  assert(shell.tile_width==def.width and shell.tile_height==1)
  assert(equal(shell.circuit_wire_connection_points,defs.points(kind,'network',false)))
  local item=data.raw['item-with-tags'][def.name] or data.raw.item[def.name]
  assert(item.icon==device.icon and item.icon_size==64 and shell.icon==device.icon)
  for i,direction in ipairs({'north','east','south','west'}) do
    local image=device[direction]; local d=(i-1)*4
    assert(equal(shell.sprites[direction].layers,{image.shadow,image.body}))
    assert(image.body.scale==0.5 and equal(image.body.shift,{0,0}))
    assert(image.body.width==(def.width==1 and 160 or 320) and image.body.height==image.body.width)
    for index,role in ipairs(def.roles) do
      local entry=image.roles[role]; local x,y=defs.offset(kind,index,d)
      assert(equal(entry.center,{x,y}) and equal(entry.color,defs.colors[role]))
      if role~='network' then
        local pad=data.raw['constant-combinator'][defs.pad_name(kind,role)]
        assert(equal(pad.circuit_wire_connection_points,defs.points(kind,role,true)))
        assert(equal(pad.selection_box,defs.pad_box))
      end
      for _,color in ipairs({'red','green'}) do
        local cx,cy=defs.contact(kind,role,color,d)
        assert(equal(entry.contacts[color],{cx,cy}),'artwork/native contact drift')
        if kind=='monitor' then assert(math.max(math.abs(cx),math.abs(cy))==0.48) end
        contacts=contacts+1
      end
    end
    for _,state in ipairs({'off','unpowered','powered','fault','blinking'}) do
      for frame=0,(state=='blinking' and 3 or 0) do
        local sprite=assert(data.raw.sprite['tc-status-'..kind..'-'..direction..'-'..state..'-'..frame])
        assert(sprite.filename==image.states[state].filename and sprite.x==frame*image.body.width)
        assert(sprite.width==image.body.width and sprite.scale==0.5 and equal(sprite.shift,{0,0}))
        statuses=statuses+1
      end
    end
  end
end
assert(contacts==88 and statuses==256)
for _,name in ipairs({'tc-circuit-computers','tc-recipe-searcher'}) do
  local technology=data.raw.technology[name]
  assert(technology.icon==art.technologies[name].icon and technology.icon_size==256)
end
log('TC_RD2_ART_DATA_OK contacts='..contacts..' status_frames='..statuses)
