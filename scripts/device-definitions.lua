-- Shared host-only physical tuning. Directions use Factorio 2.0's 16 positions.
local M = {}
M.order={'computer','kv','monitor','logic','configurator'}
M.devices={
  computer={name='tc-computer',width=1,watts=60000,roles={'network'},icon='arithmetic-combinator',
    ingredients={{'iron-plate',10},{'copper-plate',5},{'electronic-circuit',10},{'advanced-circuit',2}}},
  kv={name='tc-kv',width=1,watts=30000,roles={'network'},icon='steel-chest',
    ingredients={{'iron-plate',8},{'electronic-circuit',5},{'advanced-circuit',2}}},
  monitor={name='tc-monitor',width=1,watts=15000,roles={'network'},icon='display-panel',
    ingredients={{'iron-plate',4},{'copper-plate',2},{'electronic-circuit',5}}},
  logic={name='tc-logic',width=3,watts=15000,roles={'input','network','output'},icon='decider-combinator',
    ingredients={{'iron-plate',6},{'electronic-circuit',8}}},
  configurator={name='tc-configurator',width=2,watts=30000,roles={'network','targets'},icon='constant-combinator',
    ingredients={{'iron-plate',8},{'electronic-circuit',8},{'advanced-circuit',2}}}
}
M.by_name={}
for kind,def in pairs(M.devices) do M.by_name[def.name]=kind end
M.role_order={'input','network','output','targets'}
M.colors={input={0.25,0.65,1},network={0.75,0.4,1},output={1,0.6,0.2},targets={0.25,1,0.55}}
function M.offset(kind,index,direction)
  local def=assert(M.devices[kind]); local x=index-(def.width+1)/2
  if direction==0 then return x,0 end
  if direction==4 then return 0,x end
  if direction==8 then return -x,0 end
  if direction==12 then return 0,-x end
  error('cardinal direction required',0)
end
function M.cardinal(direction) return direction==0 or direction==4 or direction==8 or direction==12 end
return M
