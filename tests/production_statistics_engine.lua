-- Real packaged provider and compiled guest, one bounded case per native tick.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local defs=require('scripts.device-definitions')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local contracts=require('tests.production_statistics_contract')
local shell=require('scripts.runtime.shell')
local program=require('examples.production-statistics-program')
local dashboard=require('examples.production-statistics-monitor')
local monitor=require('scripts.services.monitor')
local M={}; local resumed=false
local windows={'five_seconds','one_minute','ten_minutes','one_hour','ten_hours','fifty_hours','two_hundred_fifty_hours','one_thousand_hours'}
local function f() return storage.tc_stat_fixture end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function build(kind,surface,force,x,y)
  local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force=force})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function wire(a,b,color)
  assert(lifecycle.connector(a,'network',color).connect_to(lifecycle.connector(b,'network',color)))
end
local busy=[[function start() computer.every(1,'pulse') end

function pulse() computer.setState('pulses',(computer.getState('pulses') or 0)+1) end]]
local prefix=[[local s=peripheral.find('production_statistics','red'); assert(s)
local function refused(code,fn,...)
  local ok,e=pcall(fn,...); assert(not ok and type(e)=='table' and e.code==code,code..' expected')
end
]]
local function guest(c,body,document)
  local ctx=runtime.context(c,game.tick)
  local plan,e=compiler.compile(document or 'function start() '..body..' end',ctx)
  assert(plan,serpent.line(e))
  local ok,problem=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(problem))
end
local function stats(s,kind)
  if kind=='item' then return s.body.force.get_item_production_statistics(s.body.surface) end
  if kind=='fluid' then return s.body.force.get_fluid_production_statistics(s.body.surface) end
  return s.body.surface.pollution_statistics
end
local function expected(s,kind,window,key,quality)
  local native=stats(s,kind); local out={tick=game.tick}
  for _,side in ipairs({'input','output'}) do
    local map
    if key then
      map={}
      for i=1,300 do map[i]=native.get_flow_count{name=kind=='item' and {name=key,quality=quality or 'normal'} or key,
        category=side,precision_index=defines.flow_precision_index[window],sample_index=i,count=false} end
    else
      map=native[side..(kind=='item' and '_quality_counts' or '_counts')]
      if window then
        for name,value in pairs(map) do
          if kind=='item' then
            for item in pairs(value) do value[item]=native.get_flow_count{name={name=item,quality=name},category=side,precision_index=defines.flow_precision_index[window],count=false} end
          else map[name]=native.get_flow_count{name=name,category=side,precision_index=defines.flow_precision_index[window],count=false} end
        end
      end
    end
    out[side]=map
  end
  return out
end
local function query(c,s,kind,method,window,key,quality)
  local args=string.format('%q',kind)
  if key then args=args..','..string.format('%q,%q',key,window)..(quality and ','..string.format('%q',quality) or '')
  elseif window then args=args..','..string.format('%q',window) end
  local direct=expected(s,kind,window,key,quality)
  guest(c,prefix.."local a=s."..method.."("..args.."); computer.setState('snapshot',a); a.input.changed=123")
  assert(equal(c.state.snapshot,direct),'native parity '..method..' '..kind..' '..tostring(window)..' '..tostring(key))
  assert(equal(direct,expected(s,kind,window,key,quality)),'query changed native statistics')
  log('TC_STAT parity '..method..' '..kind..' '..tostring(window)..' '..tostring(key)..' '..tostring(quality))
end
function M.run()
  storage.tc_stat_fixture={phase='power',start=game.tick,index=1,scopes={},cases={}}
  local x=f(); local forces={game.forces.player,game.create_force('tc-stat-other')}
  local surfaces={game.surfaces[1],game.create_surface('tc-stat-other',{width=64,height=64})}
  for si,surface in ipairs(surfaces) do
    surface.request_to_generate_chunks({0,0},1); surface.force_generate_chunk_requests()
    local tiles={}; for y=-10,12 do for xx=-10,16 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
    surface.set_tiles(tiles)
    if si==2 and script.active_mods['space-age'] then surface.override_pollution_type={name='spores'} end
    for fi,force in ipairs(forces) do
      local y=(fi-1)*6
      local c=build('computer',surface,force,0,y); local s=build('production_statistics',surface,force,3,y)
      wire(c,s,'red'); wire(c,s,'green'); x.scopes[#x.scopes+1]={c=c.id,s=s.id}
      local power=assert(surface.create_entity{name='electric-energy-interface',position={9,y},force=force})
      power.power_production=100000000; power.power_usage=0
      assert(surface.create_entity{name='substation',position={6,y},force=force})
      assert(runtime.save(c.id,busy,0)); assert(runtime.activate(c.id,game.tick))
      local item=stats(s,'item'); local fluid=stats(s,'fluid')
      item.on_flow({name='iron-plate',quality='normal'},si*100+fi)
      item.on_flow('copper-plate',-si*10-fi); item.on_flow('tc-stat-overlap',7)
      if script.active_mods.quality then item.on_flow({name='iron-plate',quality='legendary'},si*30+fi) end
      fluid.on_flow('water',si*20.25+fi); fluid.on_flow('steam',-si*2.5-fi); fluid.on_flow('tc-stat-overlap',.125)
    end
    surface.pollute({0,0},1000.5,'stone-furnace')
    surface.pollute({0,0},-.25,'tree-01')
  end
  local force=game.create_force('tc-stat-fresh')
  force.technologies['tc-circuit-computers'].researched=true; lifecycle.unlocks()
  assert(not force.recipes['tc-production-statistics'].enabled)
  force.technologies['tc-recipe-searcher'].researched=true; lifecycle.unlocks()
  assert(force.recipes['tc-production-statistics'].enabled and force.recipes['tc-recipe-searcher'].enabled and force.recipes['tc-factoriopedia-interface'].enabled)
  log('TC_STAT fresh-research-only-shared-unlock')
end
function M.on_load() resumed=f().phase=='frozen' end
function M.on_configuration_changed() error('unexpected statistics configuration change') end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local scope=x.scopes[1]; local c=registry.record(scope.c); local s=registry.record(scope.s)
  if x.phase=='frozen' then
    if not resumed then return end
    assert(c==x.saved.c and s==x.saved.s and c.state==x.saved.state and c.state.snapshot==x.saved.snapshot)
    assert(c.body.unit_number==x.saved.unit and s.body.unit_number==x.saved.stat_unit)
    assert(lifecycle.connector(c,'network','red').connection_count==x.saved.red and lifecycle.connector(c,'network','green').connection_count==x.saved.green)
    assert(registry.get().ledger.tick==x.saved.tick and registry.get().ledger.total==x.saved.total)
    assert(not admission.reserve(runtime.context(c,x.saved.tick),'work',1),'cold renewed credits')
    x.phase='cold-query'; log('TC_STAT cold-identity-snapshot-spent-credits-no-replay'); return
  end
  assert(event.tick-x.start<900,'statistics deadline '..x.phase)
  scheduler.tick(event.tick)
  for _,r in ipairs(x.scopes) do
    local computer=registry.record(r.c); assert(computer.status=='running',serpent.line(computer.diagnostic))
    if not computer.powered or not registry.record(r.s).powered then return end
  end
  if x.phase=='power' then
    guest(c,prefix..[[
      local methods=peripheral.getMethods(peripheral.getName(s),'red')
      assert(#methods==4 and methods[1]=='getHistory' and methods[2]=='getLimits' and methods[3]=='getRates' and methods[4]=='getTotals')
      refused('E_ARGUMENT',s.getTotals); refused('E_ARGUMENT',s.getTotals,'item',nil)
      refused('E_ARGUMENT',s.getRates,'item'); refused('E_ARGUMENT',s.getHistory,'item','iron-plate')
      refused('E_ARGUMENT',s.getTotals,s,'item'); refused('E_ARGUMENT',s.getTotals,1)
      refused('E_ARGUMENT',s.getHistory,'item','','one_minute'); refused('E_ARGUMENT',s.getHistory,'item','iron-plate','one_minute',false)
      refused('E_ARGUMENT',s.getHistory,'fluid','water','one_minute','normal')
      refused('E_RANGE',s.getTotals,'electricity'); refused('E_RANGE',s.getRates,'item','nope')
      refused('E_RANGE',s.getHistory,'item','nope','one_minute'); refused('E_RANGE',s.getHistory,'item','iron-plate','one_minute','nope')
      refused('E_RANGE',s.getHistory,'pollution','nope','one_minute')
      local l=s.getLimits(); assert(l.table_entries==1024 and not l.statistics_entries); l.table_entries=1; assert(s.getLimits().table_entries==1024)
    ]])
    for _,r in ipairs(x.scopes) do
      for _,kind in ipairs({'item','fluid','pollution'}) do x.cases[#x.cases+1]={scope=r,kind=kind,method='getTotals'} end
    end
    for _,kind in ipairs({'item','fluid','pollution'}) do
      for _,window in ipairs(windows) do
        x.cases[#x.cases+1]={scope=scope,kind=kind,method='getRates',window=window}
        local names=kind=='item' and {'iron-plate','copper-plate','tc-stat-overlap','steel-plate'} or kind=='fluid' and {'water','steam','tc-stat-overlap','crude-oil'} or {'stone-furnace','tree-01'}
        for _,key in ipairs(names) do x.cases[#x.cases+1]={scope=scope,kind=kind,method='getHistory',window=window,key=key} end
        if kind=='item' and script.active_mods.quality then x.cases[#x.cases+1]={scope=scope,kind=kind,method='getHistory',window=window,key='iron-plate',quality='legendary'} end
      end
    end
    contracts.run()
    x.phase='cases'; log('TC_STAT exact-methods-arguments-errors-detached-limits'); return
  elseif x.phase=='cases' then
    local case=x.cases[x.index]
    if case then query(registry.record(case.scope.c),registry.record(case.scope.s),case.kind,case.method,case.window,case.key,case.quality); x.index=x.index+1; return end
    log('TC_STAT all-windows-complete-native-parity '..#x.cases)
    x.phase='pollution-keys'; x.index=1; x.extra={}
    for _,r in ipairs(x.scopes) do
      local rec=registry.record(r.s); local native=stats(rec,'pollution'); local seen={}
      for _,map in ipairs({native.input_counts,native.output_counts}) do
        for key in pairs(map) do
          if not seen[key] then
            seen[key]=true
            for _,window in ipairs(windows) do x.extra[#x.extra+1]={scope=r,key=key,window=window} end
          end
        end
      end
      log('TC_STAT pollutant '..tostring(rec.body.surface.pollutant_type and rec.body.surface.pollutant_type.name)..' '..serpent.line(seen))
    end
    return
  elseif x.phase=='pollution-keys' then
    local case=x.extra[x.index]
    if case then query(registry.record(case.scope.c),registry.record(case.scope.s),'pollution','getHistory',case.window,case.key); x.index=x.index+1; return end
    log('TC_STAT all-recorded-native-pollution-source-sink-keys '..#x.extra)
    x.phase='timing-reset'; return
  elseif x.phase=='timing-reset' then
    local native=stats(s,'fluid'); native.clear()
    query(c,s,'fluid','getTotals')
    native.on_flow('water',.375)
    query(c,s,'fluid','getTotals')
    assert(native.get_current_input_sample('water')==.375)
    x.phase='merged'; return
  elseif x.phase=='merged' then
    query(c,s,'fluid','getTotals'); assert(c.state.snapshot.input.water==.375)
    log('TC_STAT native-clear-current-tick-and-fractional-merge')
    x.phase='example'; return
  elseif x.phase=='example' then
    guest(c,nil,program); assert(c.state.statistics_example)
    local empty=x.scopes[4]; local ec=registry.record(empty.c); local es=registry.record(empty.s)
    for _,kind in ipairs({'item','fluid','pollution'}) do stats(es,kind).clear() end
    guest(ec,nil,program)
    for _,kind in ipairs({'item','fluid','pollution'}) do
      local found=false; for _,entry in ipairs(ec.logs) do if entry.text==kind..': no recorded input' then found=true end end
      assert(found,'example empty branch '..kind)
    end
    local screen=build('monitor',c.body.surface,c.body.force,0,-4); wire(c,screen,'red')
    build('monitor',c.body.surface,c.body.force,1,-4)
    build('monitor',c.body.surface,c.body.force,0,-3)
    build('monitor',c.body.surface,c.body.force,1,-3)
    x.screen=screen.id
    assert(runtime.save(c.id,dashboard,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
    x.since=event.tick; x.phase='dashboard'; return
  elseif x.phase=='dashboard' then
    if not c.state.statistics_monitor then return end
    local group=assert(monitor.resolve(registry.record(x.screen)))
    local function row(y)
      local text=''; for col=1,group.model.width do text=text..string.char(group.model.cells[(y-1)*group.model.width+col][1]) end
      return text
    end
    assert(row(1):find('Iron /min 1m',1,true) and row(4):find('older -> newer',1,true))
    assert(row(7):find('Rows: in / out',1,true) or row(7):find('No activity',1,true))
    log('TC_STAT exact-shipped-reference-and-dashboard-real-monitor')
    assert(runtime.save(c.id,busy,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
    x.phase='authority'; return
  elseif x.phase=='authority' then
    lifecycle.power_entity(s).energy=0; s.powered=false
    guest(c,prefix..[[assert(s.getLimits().table_entries==1024)
      refused('E_UNPOWERED',s.getTotals,'item'); refused('E_UNPOWERED',s.getRates,'fluid','one_minute')
      refused('E_UNPOWERED',s.getHistory,'item','iron-plate','one_minute')]])
    lifecycle.power_entity(s).energy=1000; s.powered=true
    c.shell={version=1,id='statistics-fixture-shell',pending={},pending_bytes=0}
    local ok,e=shell.evaluate(c,"s=peripheral.find('production_statistics','red'); captured=s.getTotals",event.tick,1); assert(ok,serpent.line(e))
    local foreign=game.forces['tc-stat-other']; s.body.force=foreign
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item'); assert(not ok and e.code=='E_UNREACHABLE')",event.tick,2); assert(ok,serpent.line(e))
    s.body.force=c.body.force
    local position=s.body.position; local surface=s.body.surface
    -- Static combinators cannot teleport between surfaces; native moves clone/remove.
    local moved=assert(s.body.clone{position={12,8},surface=registry.record(x.scopes[3].s).body.surface,force=c.body.force})
    local moved_rec=assert(registry.by_entity(moved)); assert(moved_rec.id~=s.id)
    assert(lifecycle.remove(s.id,'cross-surface-move',true))
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item'); assert(not ok and e.code=='E_UNREACHABLE')",event.tick,2); assert(ok,serpent.line(e))
    guest(c,"assert(peripheral.wrap('"..moved_rec.id.."','red')==nil)")
    assert(lifecycle.remove(moved_rec.id,'fixture',true))
    s=build('production_statistics',surface,c.body.force,position.x,position.y); scope.s=s.id
    wire(c,s,'red'); wire(c,s,'green'); lifecycle.power_entity(s).energy=1000; s.powered=true
    ok,e=shell.evaluate(c,"s=peripheral.find('production_statistics','red'); captured=s.getTotals",event.tick,2); assert(ok,serpent.line(e))
    local relay=build('kv',c.body.surface,c.body.force,6,-3); local mixed=build('production_statistics',c.body.surface,c.body.force,9,-3)
    wire(s,relay,'red'); wire(relay,mixed,'green')
    guest(c,"assert(peripheral.wrap('"..mixed.id.."','red')==nil and peripheral.wrap('"..mixed.id.."','green')==nil)")
    local old_id=s.id; local pos=s.body.position; local before=expected(s,'item')
    assert(lifecycle.remove(old_id,'fixture',true))
    s=build('production_statistics',c.body.surface,c.body.force,pos.x,pos.y); wire(c,s,'red'); wire(c,s,'green'); scope.s=s.id
    lifecycle.power_entity(s).energy=1000; s.powered=true
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item'); assert(not ok and e.code=='E_UNREACHABLE')",event.tick,3); assert(ok,serpent.line(e))
    assert(equal(before,expected(s,'item')),'replacement reset native statistics')
    assert(shell.reset(c,'fixture'))
    local other=registry.record(x.scopes[3].s)
    guest(c,"assert(peripheral.wrap('"..other.id.."','red')==nil)")
    log('TC_STAT power-limits-both-colors-force-surface-mixed-path-stale-captured-identity')
    x.phase='pressure'; return
  elseif x.phase=='pressure' then
    for _,kind in ipairs({'work','allocations'}) do
      local probe=build('computer',c.body.surface,c.body.force,-4,kind=='work' and 0 or 4); wire(probe,s,'red')
      lifecycle.power_entity(probe).energy=2000; probe.powered=true
      assert(runtime.save(probe.id,busy,0)); assert(runtime.activate(probe.id,event.tick))
      local ctx=runtime.context(probe,event.tick)
      local source="function start() local s=peripheral.find('production_statistics','red'); pcall(function() for i=1,1000 do s.getHistory('item','iron-plate','one_minute') end end); computer.setState('escaped',true) end"
      local plan,e=compiler.compile(source,ctx); assert(plan,serpent.line(e))
      assert(admission.reserve(ctx,kind,(kind=='work' and limits.callback_work or limits.callback_allocations)-ctx.machine[kind]-2000))
      local ok,problem=compiler.run(plan,'start',{},function(g) return runtime.services(probe,event.tick,g) end,ctx)
      assert(not ok and problem.code=='E_BUDGET' and not probe.state.escaped,serpent.line(problem))
      assert(lifecycle.remove(probe.id,'fixture',true))
    end
    assert(not s.statistics and not s.history and not s.query)
    log('TC_STAT real-shared-work-allocation-fatal-refusal-no-partial-result-or-job')
    x.phase='late-zero'; return
  elseif x.phase=='late-zero' then
    query(c,s,'item','getRates','five_seconds')
    assert(c.state.snapshot.input.normal['iron-plate']==0,'recorded old item lost native zero-rate key')
    log('TC_STAT old-inventory-retained-with-zero-window-rate')
    if M.large then
      local native=stats(s,'item')
      for i=1,1030 do native.set_input_count('tc-stat-pressure-'..i,i) end
      local before=expected(s,'item')
      guest(c,prefix..[[refused('E_LIMIT',s.getTotals,'item'); refused('E_LIMIT',s.getRates,'item','one_minute')]])
      assert(equal(before,expected(s,'item')),'result refusal mutated native counters')
      log('TC_STAT real-1030-distinct-native-item-complete-result-refusal')
    end
    x.phase='cold-query'; return
  elseif x.phase=='cold-query' then
    query(c,s,'item','getHistory','one_minute','iron-plate')
    if resumed then x.phase='done'; log('TC_STAT cold-fresh-query'); log('TC_COLD_OK'); return end
    x.phase='freeze'; return
  elseif x.phase=='freeze' then
    local ctx=runtime.context(c,event.tick); local machine=ctx.machine
    assert(admission.reserve(ctx,'work',limits.callback_work-machine.work))
    x.saved={c=c,s=s,state=c.state,snapshot=c.state.snapshot,unit=c.body.unit_number,stat_unit=s.body.unit_number,
      red=lifecycle.connector(c,'network','red').connection_count,green=lifecycle.connector(c,'network','green').connection_count,
      tick=registry.get().ledger.tick,total=registry.get().ledger.total}
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
