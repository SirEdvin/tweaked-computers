-- Shared host-only physical tuning. Directions use Factorio 2.0's 16 positions.
local M = {}
M.order={'computer','kv','monitor','logic','configurator','recipe_searcher','factoriopedia_interface','production_statistics','dashboard'}
M.devices={
  computer={name='tc-computer',width=1,roles={'network'},icon='arithmetic-combinator',
    ingredients={{'iron-plate',10},{'copper-plate',5},{'electronic-circuit',10},{'advanced-circuit',2}}},
  kv={name='tc-kv',width=1,roles={'network'},icon='steel-chest',
    ingredients={{'iron-plate',8},{'electronic-circuit',5},{'advanced-circuit',2}}},
  monitor={name='tc-monitor',width=1,roles={'network'},icon='display-panel',
    ingredients={{'iron-plate',4},{'copper-plate',2},{'electronic-circuit',5}}},
  logic={name='tc-logic',width=3,roles={'input','network','output'},icon='decider-combinator',
    ingredients={{'iron-plate',6},{'electronic-circuit',8}}},
  configurator={name='tc-configurator',width=2,roles={'network','targets'},icon='constant-combinator',
    ingredients={{'iron-plate',8},{'electronic-circuit',8},{'advanced-circuit',2}}},
  recipe_searcher={name='tc-recipe-searcher',width=1,roles={'network'},icon='lab',
    technology='tc-recipe-searcher',ingredients={{'steel-plate',10},{'advanced-circuit',5},{'processing-unit',2}}},
  factoriopedia_interface={name='tc-factoriopedia-interface',width=1,roles={'network'},icon='lab',
    technology='tc-recipe-searcher',ingredients={{'steel-plate',10},{'advanced-circuit',5},{'processing-unit',2}}},
  production_statistics={name='tc-production-statistics',width=1,roles={'network'},icon='lab',
    technology='tc-recipe-searcher',ingredients={{'iron-plate',8},{'electronic-circuit',5},{'advanced-circuit',2}}},
  dashboard={name='tc-dashboard',width=1,roles={'network'},icon='display-panel',
    ingredients={{'iron-plate',4},{'copper-plate',2},{'electronic-circuit',5}}}
}
M.by_name={}
for kind,def in pairs(M.devices) do
  def.technology=def.technology or 'tc-circuit-computers'
  -- Keep the alpha EEI names loadable. Items keep their names; new placements
  -- use a different native prototype, never a same-name type substitution.
  def.entity_name=def.name..'-shell'; def.power_name=def.name..'-power'
  M.by_name[def.name]=kind; M.by_name[def.entity_name]=kind
end
M.role_order={'input','network','output','targets'}
M.colors={input={1,0.6,0.2},network={0.25,0.8,1},output={0.55,1,0.25},targets={0.75,0.4,1}}
M.pad_box={{-0.22,-0.22},{0.22,0.22}}
function M.transform(x,y,direction)
  if direction==0 then return x,y end
  if direction==4 then return -y,x end
  if direction==8 then return -x,-y end
  if direction==12 then return y,-x end
  error('cardinal direction required',0)
end
function M.offset(kind,index,direction)
  local def=assert(M.devices[kind]); local x=index-(def.width+1)/2
  return M.transform(x,0,direction)
end
function M.pad_name(kind,role) return M.devices[kind].name..'-'..role..'-socket' end
function M.port_role(name)
  if type(name)~='string' then return nil end
  local legacy=name:match('^tc%-port%-(%a+)$')
  if legacy then return legacy end
  for _,kind in ipairs(M.order) do
    for _,role in ipairs(M.devices[kind].roles) do
      if role~='network' and name==M.pad_name(kind,role) then return role end
    end
  end
end
function M.power_kind(name)
  for _,kind in ipairs(M.order) do if name==M.devices[kind].power_name then return kind end end
end
-- Contact centers in tile units, relative to the body; RD2 consumes this same
-- metadata. Each role's studs sit toward its north face, not its selection center.
function M.contact(kind,role,color,direction)
  local def=assert(M.devices[kind]); local index
  for i,r in ipairs(def.roles) do if r==role then index=i end end
  assert(index and (color=='red' or color=='green'),'invalid device contact')
  return M.transform(index-(def.width+1)/2+(color=='red' and -0.07 or 0.07),kind=='monitor' and -0.48 or -0.1,direction)
end
function M.points(kind,role,pad)
  local out={}
  for _,d in ipairs({0,4,8,12}) do
    local point={wire={},shadow={}}
    for _,c in ipairs({'red','green'}) do
      local x,y=M.contact(kind,role,c,d)
      if pad then
        local index; for i,r in ipairs(M.devices[kind].roles) do if r==role then index=i end end
        local px,py=M.offset(kind,index,d); x=x-px; y=y-py
      end
      point.wire[c]={x,y}; point.shadow[c]={x+0.15,y+0.1}
    end
    out[#out+1]=point
  end
  return out
end
function M.cardinal(direction) return direction==0 or direction==4 or direction==8 or direction==12 end
return M
