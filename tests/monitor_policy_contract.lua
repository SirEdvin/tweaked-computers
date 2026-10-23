-- Internal provider contracts; public optional-argument wiring is a separate lane.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local limits=require('scripts.runtime.limits')
local principal=require('scripts.runtime.principal')
local defs=require('scripts.device-definitions')
local M={}
local function nop() end
function M.setting(name,value)
  local ledger=registry.get().ledger; local spent=ledger.total
  settings.global[name]={value=value}
  script.get_event_handler(defines.events.on_runtime_mod_setting_changed){setting=name,setting_type='runtime-global',tick=game.tick}
  assert(registry.get().ledger==ledger and ledger.total==spent,'setting change renewed work')
end
local function refused(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
end
function M.geometry()
  local m=model.new(1,1)
  for _,scale in ipairs({0.4,0.75,1.1,5.5,6.25}) do
    model.scale(m,1,1,nop,scale); assert(m.scale==scale)
  end
  local cells,revision,scale=m.cells,m.revision,m.scale
  for _,bad in ipairs({0,-1,math.huge,-math.huge,0/0,1e-300}) do
    refused('E_RANGE',function() model.scale(m,1,1,nop,bad) end)
    assert(m.cells==cells and m.revision==revision and m.scale==scale)
  end
  refused('E_CAPACITY',function() model.scale(m,6,6,nop,0.1) end)
  assert(m.cells==cells and m.revision==revision and m.scale==scale)
  local width,height=limits.monitor_width_tiles,limits.monitor_height_tiles
  for _,direction in ipairs({0,4,8,12}) do for w=1,6 do for h=1,6 do
    limits.monitor_width_tiles=w; limits.monitor_height_tiles=h
    local rotated=direction==4 or direction==12
    local worldw,worldh=rotated and h or w,rotated and w or h
    local tiles={}
    for y=1,worldh do for x=1,worldw do
      tiles[#tiles+1]={id=x..'/'..y,position={x=x,y=y},direction=direction,surface_index=1,force_index=1}
    end end
    local groups=monitor.partition(tiles)
    assert(#groups==1 and groups[1].width_tiles==w and groups[1].height_tiles==h)
  end end end
  limits.monitor_width_tiles=width; limits.monitor_height_tiles=height
  log('TC_CONTRACT monitor-policy-positive-scale-and-configured-cardinal-rectangles')
end
function M.build(c)
  local tiles={}; local previous=c
  for i=1,7 do
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.monitor.entity_name,position={(i-1)*3,4},force='player'})
    local tile=assert(lifecycle.build(body)); lifecycle.power_entity(tile).energy=100000; tile.powered=true
    for _,wire in ipairs({'red','green'}) do
      assert(lifecycle.connector(previous,'network',wire).connect_to(lifecycle.connector(tile,'network',wire)))
    end
    tiles[i]=tile.id; previous=tile
  end
  for i=1,2 do
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.monitor.entity_name,position={29+i,4},force='player'})
    local tile=assert(lifecycle.build(body)); lifecycle.power_entity(tile).energy=100000; tile.powered=true
    tiles.wall=tiles.wall or tile.id
  end
  return tiles
end
function M.decrease(tiles)
  local tile=registry.record(tiles.wall); local g=assert(monitor.resolve(tile)); assert(g.width_tiles==2)
  model.calls.write(g.model,nop,'KEEP'); local cells,revision=g.model.cells,g.model.revision
  M.setting('tc-monitor-width-tiles',1); M.setting('tc-monitor-height-tiles',1)
  monitor.reconcile(game.tick,nop)
  assert(monitor.resolve(tile)==g and g.model.cells==cells and g.model.revision==revision and g.model.cells[1][1]==75)
  assert(monitor.inspect(tile,game.tick,nop).width_tiles==2)
  M.setting('tc-monitor-width-tiles',6); M.setting('tc-monitor-height-tiles',6)
  log('TC_CONTRACT monitor-policy-axis-decrease-preserves-accepted-identity-and-cells')
end
function M.select(c,tiles)
  local p=principal.program(c); local refs={}
  for _,id in ipairs(tiles) do refs[#refs+1]={name=assert(monitor.resolve(registry.record(id))).id,wire='red'} end
  local many={}
  for i=1,5 do for _,wire in ipairs({'green','red'}) do many[#many+1]={name=refs[i].name,wire=wire} end end
  renderer.select(c,game.tick,nop,many,p)
  assert(#c.monitor_sync.members==5)
  for _,ref in ipairs(c.monitor_sync.members) do assert(ref.wire=='red') end
  renderer.select(c,game.tick,nop,{refs[6]},p,'left')
  renderer.select(c,game.tick,nop,{refs[7]},p,'right')
  local left,right,default=c.monitor_sync_groups.left,c.monitor_sync_groups.right,c.monitor_sync
  refused('E_BUSY',function() renderer.select(c,game.tick,nop,{refs[7]},p,'left') end)
  refused('E_ARGUMENT',function() renderer.select(c,game.tick,nop,{refs[6]},p,'') end)
  refused('E_ARGUMENT',function() renderer.select(c,game.tick,nop,{[2]=refs[6]},p,'left') end)
  assert(c.monitor_sync_groups.left==left and c.monitor_sync_groups.right==right and c.monitor_sync==default)
  local cost=0
  renderer.select(c,game.tick,function(n) cost=cost+n end,{refs[6]},p,'left')
  refused('E_BUSY',function()
    renderer.select(c,game.tick,function(n) cost=cost-n; if cost<1 then error({code='E_BUSY'},0) end end,{refs[6]},p,'left')
  end)
  assert(c.monitor_sync_groups.left==left and c.monitor_sync_groups.right==right and c.monitor_sync==default)
  renderer.select(c,game.tick,nop,{},p,'left')
  assert(not c.monitor_sync_groups.left and c.monitor_sync_groups.right==right and c.monitor_sync==default)
  renderer.select(c,game.tick,nop,{refs[6]},p,'left')
  renderer.revoke(c,refs[7].name,'red',p)
  assert(not c.monitor_sync_groups.right and c.monitor_sync_groups.left and c.monitor_sync==default)
  renderer.select(c,game.tick,nop,{refs[7]},p,'right')
  assert(#renderer.status(c,nop,p,'left').members==1 and #renderer.status(c,nop,p).members==5)
  log('TC_CONTRACT monitor-policy-five-members-ten-refs-disjoint-names-atomic-replace-and-selective-revoke')
  return {default=c.monitor_sync,left=c.monitor_sync_groups.left,right=c.monitor_sync_groups.right}
end
function M.check(c,saved)
  assert(c.monitor_sync==saved.default and c.monitor_sync_groups.left==saved.left and c.monitor_sync_groups.right==saved.right)
end
return M
