local defs=require('scripts.device-definitions')
local empty={filename='__core__/graphics/empty.png',width=1,height=1}
local art=require('assets.sprites')
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]
  local icon=art.devices[kind].icon
  local pictures={}
  for _,direction in ipairs({'north','east','south','west'}) do
    local image=art.devices[kind][direction]
    pictures[direction]={layers={table.deepcopy(image.shadow),table.deepcopy(image.body)}}
    -- Status sprites are separate so stopped, powered, faulted and running
    -- devices update without replacing the native body or its wire endpoints.
    for _,state in ipairs({'off','unpowered','powered','fault','blinking'}) do
      local source=image.states[state]
      for frame=0,(source.frame_count or 1)-1 do
        local sprite=table.deepcopy(source)
        sprite.type='sprite'; sprite.name='tc-status-'..kind..'-'..direction..'-'..state..'-'..frame
        sprite.x=frame*sprite.width
        sprite.frame_count=nil; sprite.line_length=nil; sprite.animation_speed=nil
        data:extend{sprite}
      end
    end
  end
  local shell=table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
  shell.name=def.entity_name; shell.icon=icon; shell.icon_size=64
  shell.localised_name={'entity-name.'..def.name}
  shell.localised_description={'entity-description.'..def.name}
  shell.flags={'placeable-neutral','player-creation'}
  shell.minable={mining_time=0.3,result=def.name}; shell.max_health=200
  shell.fast_replaceable_group=nil; shell.next_upgrade=nil; shell.allow_copy_paste=true
  shell.tile_width=def.width; shell.tile_height=1; shell.selection_priority=40
  shell.collision_box={{-def.width/2+0.1,-0.4},{def.width/2-0.1,0.4}}
  shell.selection_box={{-def.width/2,-0.5},{def.width/2,0.5}}
  shell.sprites=pictures; shell.activity_led_sprites=nil; shell.activity_led_light=nil
  shell.activity_led_light_offsets={{0,0},{0,0},{0,0},{0,0}}
  shell.circuit_wire_connection_points=defs.points(kind,'network',false)
  shell.circuit_wire_max_distance=9
  data:extend{shell}
  -- The old named EEI remains loadable for staged upgrade/old blueprints.
  -- A separate, truly nonselectable EEI carries electricity for new shells.
  data:extend{{type='electric-energy-interface',name=def.name,icon=icon,icon_size=64,
    localised_name={'entity-name.'..def.name},localised_description={'entity-description.tc-device'},
    flags={'placeable-neutral','player-creation'},minable={mining_time=0.3,result=def.name},
    placeable_by={item=def.name,count=1},
    max_health=200,corpse='small-remnants',gui_mode='none',allow_copy_paste=true,
    tile_width=def.width,tile_height=1,selection_priority=40,
    collision_box={{-def.width/2+0.1,-0.4},{def.width/2-0.1,0.4}},
    selection_box={{-def.width/2,-0.5},{def.width/2,0.5}},pictures=pictures,
    energy_source={type='electric',usage_priority='secondary-input',buffer_capacity=(def.watts/30)..'J',
      input_flow_limit=(def.watts*2)..'W',output_flow_limit='0W',drain='0W'},
    energy_usage=def.watts..'W',energy_production='0W'},
    {type=(kind=='computer' or kind=='kv' or kind=='monitor') and 'item-with-tags' or 'item',name=def.name,
      icon=icon,icon_size=64,subgroup='circuit-network',order='z[tc]-'..kind,
      place_result=def.entity_name,stack_size=(kind=='computer' or kind=='kv') and 1 or 50},
    {type='recipe',name=def.name,enabled=false,energy_required=2,
      ingredients=(function() local out={}; for _,v in ipairs(def.ingredients) do out[#out+1]={type='item',name=v[1],amount=v[2]} end; return out end)(),
      results={{type='item',name=def.name,amount=1}},auto_recycle=false}}
  local power=table.deepcopy(data.raw['electric-energy-interface'][def.name])
  power.name=def.power_name; power.hidden=true; power.hidden_in_factoriopedia=true
  power.flags={'placeable-off-grid','not-on-map','not-blueprintable','not-deconstructable','not-upgradable','hide-alt-info'}
  power.selectable_in_game=false; power.selection_box={{0,0},{0,0}}
  power.collision_box={{0,0},{0,0}}; power.collision_mask={layers={}}
  power.minable=nil; power.placeable_by=nil; power.corpse=nil; power.dying_explosion=nil
  power.pictures={north=empty,east=empty,south=empty,west=empty}
  data:extend{power}
  for _,role in ipairs(def.roles) do if role~='network' then
    local pad=table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
    pad.name=defs.pad_name(kind,role); pad.localised_name={'entity-name.'..pad.name}
    pad.localised_description={'entity-description.tc-port-'..role}
    pad.flags={'placeable-off-grid','player-creation','not-deconstructable','not-upgradable','hide-alt-info'}
    pad.hidden=true; pad.hidden_in_factoriopedia=true; pad.allow_copy_paste=false
    pad.minable=nil; pad.corpse=nil; pad.dying_explosion=nil
    pad.fast_replaceable_group=nil; pad.next_upgrade=nil; pad.collision_mask={layers={}}
    pad.collision_box={{0,0},{0,0}}; pad.selection_box=table.deepcopy(defs.pad_box)
    pad.selection_priority=60; pad.tile_width=1; pad.tile_height=1
    pad.sprites={north=empty,east=empty,south=empty,west=empty}
    pad.activity_led_sprites=nil; pad.activity_led_light=nil
    pad.activity_led_light_offsets={{0,0},{0,0},{0,0},{0,0}}
    pad.circuit_wire_connection_points=defs.points(kind,role,true); pad.circuit_wire_max_distance=9
    pad.placeable_by={item=pad.name,count=1}
    data:extend{pad,{type='item',name=pad.name,icon='__core__/graphics/empty.png',icon_size=1,
      hidden=true,hidden_in_factoriopedia=true,place_result=pad.name,stack_size=1,auto_recycle=false}}
  end end
end
for _,role in ipairs(defs.role_order) do
  local p=table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
  p.name='tc-port-'..role; p.localised_name={'entity-name.'..p.name}
  p.localised_description={'entity-description.tc-port-'..role}
  p.flags={'placeable-off-grid','player-creation','not-deconstructable','not-upgradable','hide-alt-info'}
  p.hidden=true; p.hidden_in_factoriopedia=true; p.allow_copy_paste=false
  p.minable=nil; p.corpse=nil; p.dying_explosion=nil
  p.fast_replaceable_group=nil; p.next_upgrade=nil; p.collision_mask={layers={}}
  p.collision_box={{0,0},{0,0}}; p.selection_box={{-0.22,-0.22},{0.22,0.22}}
  p.selection_priority=60; p.tile_width=1; p.tile_height=1
  p.sprites={north=empty,east=empty,south=empty,west=empty}
  p.activity_led_sprites=nil; p.activity_led_light=nil
  p.activity_led_light_offsets={{0,0},{0,0},{0,0},{0,0}}
  -- Reset inherited vanilla points; the child's position already encodes its role offset.
  local point={wire={red={-0.07,-0.1},green={0.07,-0.1}},shadow={red={-0.07,0},green={0.07,0}}}
  p.circuit_wire_connection_points={table.deepcopy(point),table.deepcopy(point),table.deepcopy(point),table.deepcopy(point)}
  p.circuit_wire_max_distance=9
  -- Native blueprint wires require a blueprintable/placeable prototype. This
  -- hidden, uncraftable token is never a logical device cost or a mining drop;
  -- the body revives its owned ghost itself without consuming any item.
  p.placeable_by={item=p.name,count=1}
  data:extend{p,{type='item',name=p.name,icon='__core__/graphics/empty.png',icon_size=1,
    hidden=true,hidden_in_factoriopedia=true,place_result=p.name,stack_size=1,auto_recycle=false}}
end
local effects={}
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]
  effects[def.technology]=effects[def.technology] or {}
  local owned=effects[def.technology]; owned[#owned+1]={type='unlock-recipe',recipe=def.name}
end
data:extend{{type='technology',name='tc-circuit-computers',icon='__base__/graphics/technology/circuit-network.png',icon_size=256,
  prerequisites={'circuit-network','advanced-circuit'},effects=effects['tc-circuit-computers'],
  unit={count=100,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1}},time=30},order='a-d-e'},
  {type='technology',name='tc-recipe-searcher',icon=art.devices.recipe_searcher.icon,icon_size=64,
    prerequisites={'tc-circuit-computers','utility-science-pack'},effects=effects['tc-recipe-searcher'],
    unit={count=200,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'utility-science-pack',1}},time=60},order='a-d-f'}}
