-- Native provider/cursor contracts. Shared guest Data/result admission is a separate integration gate.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local logic=require('scripts.services.logic')
local recipes=require('scripts.services.recipe-searcher')
local peripheral=require('scripts.services.peripheral')
local network=require('scripts.network')
local contracts=require('tests.recipe_searcher_contract')
local work=require('scripts.services.inventory-work')
local M={}; local loaded=false; local pause={}
local function f() return storage.tc_inventory end
local function nop() end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local r=assert(lifecycle.build(body)); lifecycle.power_entity(r).energy=100000; r.powered=true; return r
end
local function conn(r,color,role) return assert(lifecycle.connector(r,role or 'network',color)) end
local function connect(a,b,color) assert(conn(a,color).connect_to(conn(b,color),false)) end
local function set(entity,n,negative)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=cb.add_section(); local entries={}
  for i=1,n do entries[i]={index=i,value={type='virtual',name=string.format('tc-inventory-%04d',i),quality='normal'},min=negative and -i or i} end
  section.filters=entries; assert(#section.filters==n); cb.enabled=true
end
local function slice(fn,budget)
  local left=budget or 4096
  local ok,result=pcall(fn,function(n) if n>left then error(pause,0) end; left=left-n end)
  if not ok then assert(result==pause,type(result)=='table' and serpent.line(result) or tostring(result)) end
  return ok,result
end
local function signals(values,n,negative)
  assert(#values==n,'native signal prefix: '..#values..' expected '..n)
  for i,e in ipairs(values) do
    assert(e.signal.name==string.format('tc-inventory-%04d',i) and e.signal.type=='virtual' and e.signal.quality=='normal')
    assert(e.count==(negative and -i or i))
  end
end
function M.run()
  registry.initialize(); storage.tc_inventory={phase='armed',redjob={},greenjob={},recipejob={},graphjob={},ticks=0}
  local c=build('computer',0,0); c.status='running'; c.run_id=c.id..'/inventory'
  local io=build('logic',3,0); connect(c,io,'red'); connect(c,io,'green')
  f().c=c.id; f().io=io.id
  local surface=game.surfaces[1]
  for _,color in ipairs({'red','green'}) do
    local native=assert(surface.create_entity{name='constant-combinator',position={color=='red' and 0 or 3,-3},force='player'})
    assert(native.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(conn(io,color,'input')))
    set(native,1100,color=='green'); f()[color]=native
  end
  local chain={c.id}; local last=c
  for i=1,300 do local r=build('recipe_searcher',i*3,12); connect(last,r,'red'); chain[#chain+1]=r.id; last=r end
  connect(last,c,'red'); f().chain=chain
  local bank={}
  for i=150,1,-1 do bank[#bank+1]={signal={type='virtual',name=string.format('tc-inventory-%04d',i)},count=-i} end
  logic.output(c,io,'red',game.tick,nop,bank)
  signals(io.output_bank,150,true)
  assert(#io.children.output.get_control_behavior().get_section(1).filters==150)
  local old=io.output_bank; bank[1].count=2147483648
  local ok,e=pcall(logic.output,c,io,'red',game.tick,nop,bank)
  assert(not ok and e.code=='E_RANGE' and io.output_bank==old)
  local long={{signal={type='virtual',name='tc-inventory-'..string.rep('long-name-',12)},count=-7}}
  assert(logic.canonical(long,nop)[1].count==-7)
  contracts.run(c,io)
  local accepted,problem=pcall(work.job,{continuation_enabled=true},'fixture')
  assert(not accepted and problem.code=='E_UNSUPPORTED','missing private job contract did not fail closed')
  log('TC_CONTRACT native-150-output-atomic-invalid-count-and-long-name')
  log('TC_CONTRACT_TOTAL 1')
end
function M.on_load()
  loaded=f().phase=='frozen'
  if loaded then
    assert(f().redjob.cursor>1 and not f().redjob.sort.done)
    assert(f().recipejob.cursor>1 and #f().recipejob.result>0)
    assert(f().scanjob.key and not f().scanjob.scanned)
    assert(f().graphjob.graph.cursor>1 and f().graphjob.graph.cursor<=#f().graphjob.graph.queue)
    log('TC_COLD_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local c=registry.record(x.c); local io=registry.record(x.io)
  lifecycle.power_entity(c).energy=100000; lifecycle.power_entity(io).energy=100000
  if x.phase=='boundaries' then
    if event.tick<x.due then return end
    local sizes={64,65,150}; signals(logic.read(io,'red',nop),sizes[x.boundary],false)
    x.boundary=x.boundary+1
    if sizes[x.boundary] then set(x.red,sizes[x.boundary]); x.due=event.tick+3; return end
    local entries={{index=1,value={type='recipe',name='iron-plate',quality='normal'},min=-9},
      {index=2,value={type='item',name='iron-plate',quality='normal'},min=7}}
    if script.active_mods.quality then entries[3]={index=3,value={type='item',name='iron-plate',quality='uncommon'},min=-3} end
    x.red.get_control_behavior().get_section(1).filters=entries
    x.phase='identities'; x.due=event.tick+3; return
  elseif x.phase=='identities' then
    if event.tick<x.due then return end
    local result=logic.read(io,'red',nop); local seen={}
    for _,e in ipairs(result) do seen[e.signal.type..'/'..e.signal.quality]=e.count end
    assert(#result==(script.active_mods.quality and 3 or 2) and seen['recipe/normal']==-9 and seen['item/normal']==7)
    if script.active_mods.quality then assert(seen['item/uncommon']==-3) end
    c.powered=false; peripheral.check_outputs(event.tick,nop); assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
    log('TC_INVENTORY complete-1100-both-colors-51-recipes-600-products-300-cycle-cold-cursors-native-boundaries-identities')
    x.phase='done'; log('TC_COLD_OK'); return
  end
  if x.phase=='frozen' then
    if not loaded then return end
    loaded=false; x.phase='resume'
  end
  x.ticks=x.ticks+1; assert(x.ticks<1000,'inventory preparation did not finish')
  if x.phase=='armed' and event.tick<5 then return end
  if not x.red_done then
    local ok,result=slice(function(spend) return logic.read(io,'red',spend,x.redjob) end)
    if ok then signals(result,1100,false); x.red_done=true end
  end
  if not x.green_done then
    local ok,result=slice(function(spend) return logic.read(io,'green',spend,x.greenjob) end)
    if ok then signals(result,1100,true); x.green_done=true end
  end
  if not x.recipe_done then
    local ok,result=slice(function(spend) return recipes.find(c,spend,x.recipejob,'item','tc-rs-single51') end,1024)
    if ok then
      assert(#result==51)
      for i,r in ipairs(result) do assert(r.name==string.format('tc-rs-single-%02d',i) and #r.products==1 and #r.ingredients==1 and r.category=='tc-rs-primary' and not r.enabled) end
      x.recipe_done=true
    end
  end
  if x.phase=='armed' and x.recipejob.cursor and x.recipejob.cursor>1 then
    assert(not x.red_done and not x.recipe_done)
    x.scanjob={}
    local done=slice(function(spend) return recipes.find(c,spend,x.scanjob,'item','tc-rs-fiftyone','tc-rs-primary') end,128)
    assert(not done and x.scanjob.key and not x.scanjob.scanned)
    done=slice(function(spend) return peripheral.inventory(c,'red',spend,x.graphjob) end,128)
    assert(not done and x.graphjob.graph.cursor>1)
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if x.scanjob and not x.scan_done then
    local ok,result=slice(function(spend) return recipes.find(c,spend,x.scanjob,'item','tc-rs-fiftyone','tc-rs-primary') end,1024)
    if ok then assert(#result==49 and result[1].name=='tc-rs-51-03' and result[49].name=='tc-rs-51-51'); x.scan_done=true end
  end
  if x.phase~='armed' and not x.graph_done then
    local ok,result=slice(function(spend) return peripheral.inventory(c,'red',spend,x.graphjob) end,10000)
    if ok then
      local n=0; for _ in pairs(result) do n=n+1 end; assert(n==301)
      local green=peripheral.inventory(c,'green',nop); n=0; for _ in pairs(green) do n=n+1 end; assert(n==1 and green[io.id])
      local _,path=peripheral.authority(c,x.chain[150],'red',nop)
      assert(network.validate_witness(c,'red',path,nop))
      assert(conn(registry.record(path[1]),'red').disconnect_from(conn(registry.record(path[2]),'red')))
      assert(not network.validate_witness(c,'red',path,nop))
      assert(peripheral.authority(c,x.chain[150],'red',nop),'cycle alternate path lost')
      x.graph_done=true
    end
  end
  if x.red_done and x.green_done and x.recipe_done and x.graph_done and x.scan_done then
    for _,n in ipairs({64,65,150}) do
      local entries={}; for i=1,n do entries[i]={signal={type='virtual',name=string.format('tc-inventory-%04d',i)},count=-i} end
      signals(logic.canonical(entries,nop),n,true)
      logic.output(c,io,'green',event.tick,nop,entries); signals(io.output_bank,n,true)
    end
    local more=recipes.find(c,nop,{},'item','tc-rs-large'); assert(#more==1 and #more[1].products==600)
    local metadata=recipes.find(c,nop,{},'item','tc-rs-complex')[1]
    assert(#metadata.products==3 and #metadata.ingredients==2 and #metadata.additional_categories==2)
    assert(metadata.products[1].amount_min and metadata.products[1].probability)
    local recipe={{signal={type='recipe',name='iron-plate'},count=-3}}
    assert(logic.canonical(recipe,nop)[1].signal.type=='recipe')
    if script.active_mods.quality then
      local q=logic.canonical({{signal={type='item',name='iron-plate',quality='uncommon'},count=-4}},nop)
      assert(q[1].signal.quality=='uncommon' and q[1].count==-4)
    end
    x.phase='boundaries'; x.boundary=1; x.due=event.tick+3; set(x.red,64)
  end
end
return M
