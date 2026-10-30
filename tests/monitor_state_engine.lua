-- Production-owner lifecycle and exact cold graph regressions. Synthetic credit
-- refusal is explicit; all normal progress uses the real scheduler/actual ticks.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local monitor=require('scripts.services.monitor')
local renderer=require('scripts.rendering')
local model=require('scripts.monitor-model')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local defs=require('scripts.device-definitions')
local M={}
local function nop() end
local function f() return storage.tc_monitor_state end
local function graph(roots,monitor_only)
  local seen,records={},{}
  local function visit(t)
    if type(t)~='table' or rawget(t,'__self') or seen[t] then return end
    seen[t]=true
    local record={target=t,entries={}}; records[#records+1]=record
    for k,v in pairs(t) do
      record.entries[#record.entries+1]={k,v}; visit(k); visit(v)
    end
  end
  for _,root in ipairs(roots) do visit(root) end
  local native={}
  for _,o in pairs(rendering.get_all_objects()) do
    if not monitor_only or o.type=='sprite' and (o.sprite=='tc-monitor-fill' or o.sprite:sub(1,9)=='tc-glyph-') then
      native[#native+1]={object=o,visible=o.visible}
    end
  end
  return {records=records,native=native}
end
local function unchanged(saved)
  for _,record in ipairs(saved.records) do
    local n=0; for _ in pairs(record.target) do n=n+1 end
    assert(n==#record.entries,'retained graph key count changed')
    for _,entry in ipairs(record.entries) do assert(record.target[entry[1]]==entry[2],'retained graph value/alias changed') end
  end
  for _,r in ipairs(saved.native) do assert(r.object.valid and r.object.visible==r.visible,'native visibility changed') end
end
local function guest(c,text)
  local ctx=admission.context(admission.new(),c.id,game.tick)
  local plan,e=compiler.compile('function start(e) '..text..' end',ctx)
  assert(plan,e and e.message)
  local ok,why=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(why))
end
local function build(kind,x,y,d)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  local r=assert(lifecycle.build(body)); lifecycle.power_entity(r).energy=100000; r.powered=true
  return r
end
local function wire(a,b,color)
  assert(lifecycle.connector(a,'network',color or 'red').connect_to(lifecycle.connector(b,'network',color or 'red')))
end
local function fuel()
  for _,id in ipairs(registry.get().order) do local r=registry.record(id)
    if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end
  end
end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
end]]
local function lane(c) return c.monitor_sync and registry.get().monitors.presentation.lanes[c.monitor_sync.key] end
local function select_group(c)
  guest(c,[[local refs={}
    for _,name in ipairs(peripheral.getNames('red')) do
      if peripheral.getType(name,'red')=='monitor' then refs[#refs+1]={name=name,wire='red'} end
    end
    peripheral.setMonitorSyncGroup(refs)
  ]])
end
local function paint(c,char)
  guest(c,"for _,r in ipairs(peripheral.getMonitorSyncGroup().members) do local m=peripheral.wrap(r.name,r.wire); "..
    "m.setPaletteColor(1,0x123456); m.setPaletteColor(1,0xFFFFFF); m.setCursorPos(1,1); m.write('"..char.."') end")
end
local function idle()
  local s=registry.get().monitors; local p=s.presentation
  if s.job or not p or #p.jobs>0 or #p.retired>0 or #p.orphans>0 or p.pending_cells>0 then return false end
  for _,g in pairs(s.groups) do if not g.render or g.render.presented_revision~=g.model.revision then return false end end
  return true
end
local function audit()
  local s=registry.get().monitors; local p=s.presentation; if not p then return end
  local front,fronts,staging,stages,retired,pending=0,0,0,0,0,0
  for _,g in pairs(s.groups) do if g.render then front=front+g.render.slots; fronts=fronts+1 end end
  for _,r in ipairs(p.orphans) do front=front+r.slots; fronts=fronts+1 end
  for _,j in ipairs(p.jobs) do staging=staging+j.slots; for _,r in ipairs(j.frames) do if r then stages=stages+1 end end end
  for _,r in ipairs(p.retired) do retired=retired+r.slots end
  for _,l in pairs(p.lanes) do if l.pending then pending=pending+l.pending.slots end end
  assert(front==p.front_cells and fronts==p.front_frames and staging==p.staging_cells and stages==p.staging_frames)
  assert(retired==p.retired_cells and pending==p.pending_cells)
  assert(front<=80000 and staging<=10584 and retired<=10584 and pending<=80000)
  assert(fronts<=256 and stages<=256 and #p.retired<=256)
  assert(#rendering.get_all_objects()<=model.limits.render_object_limit)
end
local function selection_contract(c)
  local s=registry.get().monitors
  local saved=graph({s,c.monitor_sync})
  guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
    local function bad(code,...)
      local ok,e=pcall(peripheral.setMonitorSyncGroup,...); assert(not ok and e.code==code)
    end
    bad('E_ARGUMENT',refs,true); bad('E_ARGUMENT',peripheral,refs)
    bad('E_ARGUMENT',{{name='',wire='red'}}); bad('E_ARGUMENT',{{name=string.rep('x',65),wire='red'}})
    bad('E_ARGUMENT',{{name=refs[1].name}}); bad('E_ARGUMENT',{{name=refs[1].name,wire=false}})
    bad('E_ARGUMENT',{{name=refs[1].name,wire='red', [1]=true}})
    bad('E_ARGUMENT',{[1]=refs[1],[3]=refs[2]})
    bad('E_ARGUMENT',{function() end}); bad('E_ARGUMENT',{{name=refs[1].name,wire='red',cycle=refs}})
    local ok,e=pcall(peripheral.getMonitorSyncGroup,true); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.getMonitorSyncGroup,peripheral); assert(not ok and e.code=='E_ARGUMENT')
    local status=peripheral.getMonitorSyncGroup(); status.members[1].wire='green'; status.members[2]=nil
    assert(#peripheral.getMonitorSyncGroup().members==2)
  ]])
  unchanged(saved)
  -- Guest language cannot construct metatables; exercise the exact host boundary.
  local ref=c.monitor_sync.members[1]
  for _,input in ipairs({setmetatable({},{}),{setmetatable({name=ref.name,wire='red'},{})}}) do
    local ok,e=pcall(renderer.select,c,game.tick,nop,input)
    assert(not ok and e.code=='E_ARGUMENT'); unchanged(saved)
  end
  local refs={}
  for _,r in ipairs(c.monitor_sync.members) do for _=1,2 do
    refs[#refs+1]={name=r.name,wire='green'}; refs[#refs+1]={name=r.name,wire='red'}
  end end
  renderer.select(c,game.tick,nop,refs)
  assert(#refs==8 and #c.monitor_sync.members==2)
  for i,r in ipairs(c.monitor_sync.members) do assert(r.wire=='red' and (i==1 or c.monitor_sync.members[i-1].name<r.name)) end
  unchanged(saved) -- Canonically identical selection must preserve every progress alias.
  local single={{name=ref.name,wire='red'}}
  renderer.select(c,game.tick,nop,single)
  local cost=0; renderer.select(c,game.tick,function(n) cost=cost+n end,single)
  renderer.select(c,game.tick,nop,refs)
  saved=graph({s,c.monitor_sync})
  local remaining=cost-1
  local ok,e=pcall(renderer.select,c,game.tick,function(n)
    remaining=remaining-n; if remaining<0 then error({code='E_BUSY'},0) end
  end,single)
  assert(not ok and e.code=='E_BUSY'); unchanged(saved)
  local foreign=monitor.resolve(registry.record(f().foreign))
  guest(c,"local ok,e=pcall(peripheral.setMonitorSyncGroup,{{name="..string.format('%q',foreign.id)..",wire='red'}}); assert(not ok and e.code=='E_UNREACHABLE')")
  unchanged(saved)
  local tile=registry.record(f().walls[1][1]); local power=lifecycle.power_entity(tile)
  local energy=power.energy; power.energy=0; tile.powered=false
  saved=graph({s,c.monitor_sync})
  guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
    local ok,e=pcall(peripheral.setMonitorSyncGroup,refs); assert(not ok and e.code=='E_UNPOWERED')]])
  unchanged(saved); power.energy=energy; tile.powered=true
  guest(c,[[for _,ref in ipairs(peripheral.getMonitorSyncGroup().members) do
    peripheral.call(ref.name,ref.wire,'setTextScale',0.5) end]])
  saved=graph({s,c.monitor_sync})
  guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
    local ok,e=pcall(peripheral.setMonitorSyncGroup,refs); assert(not ok and e.code=='E_CAPACITY')]])
  unchanged(saved)
  guest(c,[[for _,ref in ipairs(peripheral.getMonitorSyncGroup().members) do
    peripheral.call(ref.name,ref.wire,'setTextScale',1) end]])
  guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
    peripheral.setMonitorSyncGroup({}); peripheral.setMonitorSyncGroup(refs)]])
  log('TC_MONITOR_STATE_SELECTION_OK')
end
function M.new(kind)
  local test={}; local loaded=false
  -- Hold an actually prepared production job immediately before its prepaid swap.
  -- The scheduler's private refusal path, not a swallowed arbitrary exception,
  -- exhausts the unchanged ledger. This is resource-pressure evidence, not CPU.
  scheduler.register_phase('render','00-monitor-state-pressure',function(tick,spend)
    local x=f(); if not x or not (x.hold or x.retire_hold) then return end
    local c=registry.record(x.computer)
    renderer.tick(tick,function(n)
      local l=c and lane(c)
      local p=registry.get().monitors.presentation
      if x.hold and l and l.job and l.job.ready or x.retire_hold and p and p.retired_cells==10584 then
        local root=registry.get(); local remaining=200000-root.scheduler.maintenance_spent
        if remaining>0 then spend(remaining) end
        x.refused=true
        if x.retire_hold then x.retire_full=true end
      end
      spend(n)
    end)
  end)
  function test.run()
    storage.tc_monitor_state={kind=kind,phase='baseline',steps=0,walls={}}
    local x=f(); local c=build('computer',-3,0); x.computer=c.id
    local surface=game.create_surface('monitor-fixture',{width=32,height=32})
    local body=assert(surface.create_entity{name=defs.devices.monitor.entity_name,position={0,0},force='player'})
    local remote=assert(lifecycle.build(body)); lifecycle.power_entity(remote).energy=100000; remote.powered=true; x.foreign=remote.id
    for i,shape in ipairs({{3,6,0},{6,6,8}}) do
      local wall={}; x.walls[i]=wall
      for y=0,shape[2]-1 do for col=0,shape[1]-1 do wall[#wall+1]=build('monitor',shape[3]+col,y,(i-1)*4).id end end
      local previous=i==1 and c or registry.record(x.walls[i-1][1])
      wire(previous,registry.record(wall[1])); wire(previous,registry.record(wall[1]),'green')
    end
    assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
  end
  function test.on_load()
    loaded=true
    if f().phase=='frozen' then unchanged(f().saved); log('TC_MONITOR_STATE_LOAD_UNCHANGED '..kind) end
  end
  function test.on_configuration_changed() error('ordinary reload must not upgrade') end
  function test.on_tick(e)
    local x=f(); if x.phase=='done' then return end
    local root=registry.get(); local c=registry.record(x.computer); local s=root.monitors
    if x.phase=='frozen' then
      if not loaded then return end
      unchanged(x.saved)
      assert(root.scheduler.maintenance_tick==x.tick and root.scheduler.maintenance_spent==x.spent)
      renderer.tick(x.tick,scheduler.maintenance(root,x.tick,true)); unchanged(x.saved)
      local p=s.presentation; p.version=999
      local future=graph({root})
      renderer.tick(x.tick+1,nop); monitor.reconcile(x.tick+1,nop); unchanged(future)
      p.version=1
      x.saved=nil; x.hold=nil; x.phase='resuming'; x.changed=e.tick; loaded=false
      log('TC_MONITOR_STATE_COLD_RETAINED '..kind)
    end
    fuel(); scheduler.tick(e.tick); x.steps=x.steps+1
    assert(x.steps<1200,'monitor state deadline '..x.phase)
    assert(root.scheduler.maintenance_spent<=200000); audit()
    c=registry.record(x.computer); s=root.monitors
    local l=c and lane(c)
    if x.phase=='baseline' and idle() and c.state.boots==1 then
      select_group(c); paint(c,'A'); x.phase='first'
    elseif x.phase=='first' and idle() and l.presented_sequence>0 then
      selection_contract(c)
      x.hold=kind=='ready'; x.phase='capture'; x.sequence=lane(c).presented_sequence
      if kind=='idle' then paint(c,'A')
      elseif kind=='waiting' then
        local ref=c.monitor_sync.members[1]
        guest(c,"peripheral.call("..string.format('%q',ref.name)..",'red','setCursorPos',2,1)")
      else paint(c,'B') end
    elseif x.phase=='capture' then
      if kind=='pending' and l.job and not l.job.ready and not x.pending_write then
        paint(c,'C'); assert(l.pending==nil); x.pending_write=true; return
      end
      local ready=kind=='waiting' and l.status=='waiting' and next(l.participation)
        or kind=='idle' and idle() and l.presented_sequence>0
        or kind=='pending' and l.job and l.pending
        or kind=='preparing' and l.job and not l.job.ready
        or kind=='ready' and x.refused and l.job and l.job.ready
        or kind=='retiring' and #s.presentation.retired>0
      if ready then
        if kind=='preparing' then paint(c,'C'); assert(l.pending==nil) end
        if kind=='idle' then
          x.sequence=l.presented_sequence
          x.idle_saved=graph({s.groups,c.monitor_sync,s.presentation.lanes,s.presentation.work},true)
        end
        x.phase='frozen'; x.tick=e.tick; x.spent=root.scheduler.maintenance_spent
        x.saved=graph({root}); loaded=false
        game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
      end
    elseif x.phase=='resuming' then
      if kind=='idle' then
        unchanged(x.idle_saved); assert(l.presented_sequence==x.sequence and c.state.boots==1)
        if e.tick-x.changed<20 then return end
        x.phase='done'; log('TC_MONITOR_STATE_IDLE_UNCHANGED'); log('TC_COLD_OK'); return
      end
      if kind=='waiting' and e.tick-x.changed<5 then assert(l.presented_sequence==x.sequence); return end
      if kind=='waiting' and not x.completed_round then paint(c,'D'); x.completed_round=true end
      if idle() then
        assert(c.state.boots==1 and l.presented_sequence>x.sequence)
        if kind=='pending' then
          for _,r in ipairs(c.monitor_sync.members) do assert(s.groups[r.name].render.snapshot.cells[1][1]==67) end
          log('TC_MONITOR_STATE_PENDING_RETAINED')
        end
        if kind~='ready' then x.phase='done'; log('TC_COLD_OK'); return end
        x.actions={'cable','stop','fault','apply','remove-owner','remove-member','foreign-force','rotate'}
        x.action=1; x.phase='arm'
      end
    elseif x.phase=='arm' then
      if not idle() then return end
      if not c then c=build('computer',-3,0); x.computer=c.id
        wire(c,registry.record(x.walls[1][1])); wire(c,registry.record(x.walls[1][1]),'green')
        assert(runtime.save(c.id,source,c.saved_revision))
      end
      if c.status~='running' then local ok,why=runtime.activate(c.id,e.tick); assert(ok,serpent.line(why)) end
      select_group(c); paint(c,'E'); x.hold=true; x.refused=nil; x.phase='armed'
    elseif x.phase=='armed' and x.refused and l and l.job and l.job.ready then
      local action=x.actions[x.action]; local job=l.job; local selection=c.monitor_sync
      x.cancelled=job; x.old_sequence=l.presented_sequence; x.old_fronts={}; x.accepted={}
      for _,r in ipairs(selection.members) do local g=s.groups[r.name]
        x.old_fronts[g.id]=g.render; x.accepted[g.id]=g.model.cells
      end
      local target=registry.record(x.walls[1][1]); x.target=target.id
      local target_group=monitor.resolve(target); x.target_group=target_group.id; x.target_anchor=target_group.anchor
      x.hold=nil; x.phase='check'; x.changed=e.tick
      if action=='cable' then
        assert(lifecycle.connector(c,'network','red').disconnect_from(lifecycle.connector(target,'network','red')))
      elseif action=='stop' then runtime.stop(c.id)
      elseif action=='fault' then runtime.fault(c,{code='E_PROGRAM',message='fixture fault'},e.tick)
      elseif action=='apply' then assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,e.tick))
      elseif action=='remove-owner' then lifecycle.remove(c.id,'fixture',true)
      elseif action=='remove-member' then
        local pos=target.body.position; lifecycle.remove(target.id,'fixture',true)
        local replacement=build('monitor',pos.x,pos.y); x.walls[1][1]=replacement.id
        wire(c,replacement); wire(c,replacement,'green')
      elseif action=='foreign-force' then
        x.other_force=game.forces['monitor-fixture'] or game.create_force('monitor-fixture'); target.body.force=x.other_force
      elseif action=='rotate' then
        target.body.direction=defines.direction.east
        local ok,why=lifecycle.rotate(target,0); assert(ok,serpent.line(why))
        assert(target.direction==4 and target.body.direction==4,'rotation did not change geometry')
      end
      -- Cleanup may revoke later through paid authority work, but never publish
      -- the old job in the interval; unchanged fronts/models survive release.
      if action=='stop' or action=='fault' or action=='apply' or action=='remove-owner' then
        assert(job.cancelled and not job.complete and not c.monitor_sync)
        for id,front in pairs(x.old_fronts) do assert(s.groups[id].render==front and s.groups[id].model.cells==x.accepted[id]) end
      end
    elseif x.phase=='check' then
      local action=x.actions[x.action]
      if x.cancelled.complete then error('revoked/stale job published: '..action..' '..serpent.line{
        target=registry.record(x.target) and registry.record(x.target).direction,
        direction=x.cancelled.captures[1].direction,group=x.cancelled.captures[1].group and x.cancelled.captures[1].group.direction,
        membership=s.membership[x.target],selected=x.cancelled.lane.members}) end
      if action=='rotate' then
        if s.job or not x.cancelled.cancelled then
          if s.job and c.monitor_sync then
            local saved=graph({s,c.monitor_sync})
            guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
              local ok,e=pcall(peripheral.setMonitorSyncGroup,refs); assert(not ok and e.code=='E_NETWORK_PENDING')]])
            unchanged(saved); x.pending_proof=true
          end
          assert(e.tick-x.changed<=256,'rotation cancellation deadline'); return
        end
        assert(x.pending_proof,'rotation never exercised pending-proof preservation')
        assert(monitor.resolve(registry.record(x.target_anchor)).id==x.target_group,'surviving anchor identity changed')
        guest(c,'peripheral.setMonitorSyncGroup({})')
      elseif c and c.monitor_sync then
        assert(e.tick-x.changed<=256,'selection not revoked '..action); return
      end
      if not x.restored then
        if action=='cable' then wire(c,registry.record(x.target))
        elseif action=='foreign-force' then registry.record(x.target).body.force='player'
        elseif action=='rotate' then
          local target=registry.record(x.target); target.body.direction=0; lifecycle.on_rotated{entity=target.body,previous_direction=4}
        end
        x.restored=true
      end
      if idle() then
        assert(e.tick-x.changed<=256,'cleanup deadline '..action)
        if action~='remove-member' and action~='rotate' then
          for id,cells in pairs(x.accepted) do
            local g=s.groups[id]
            assert(g and g.model.cells==cells and cells[1][1]==69 and g.render.cells[1].value[1]==69,
              'release lost accepted shared model/front: '..action)
          end
        end
        log('TC_MONITOR_STATE_LIFECYCLE_OK '..action)
        x.action=x.action+1; x.restored=nil
        if x.action>#x.actions then
          local g=monitor.resolve(registry.record(x.walls[2][1])); x.maximum=g.id
          wire(registry.record(x.walls[1][1]),registry.record(x.walls[2][1]))
          guest(c,"peripheral.call("..string.format('%q',g.id)..",'red','setTextScale',0.5)")
          x.phase='maximum'
        else x.phase='arm' end
      end
    elseif x.phase=='maximum' and idle() then
      local g=s.groups[x.maximum]; assert(g.render.slots==10584)
      guest(c,"local m=peripheral.wrap("..string.format('%q',g.id)..",'red'); m.setPaletteColor(1,0x010203); m.setPaletteColor(1,0xFFFFFF)")
      x.retire_hold=true; x.phase='retirement-full'
    elseif x.phase=='retirement-full' and x.retire_full then
      local p=s.presentation; assert(p.retired_cells==10584)
      x.handles={}
      for _,o in pairs(rendering.get_all_objects()) do
        if o.type=='sprite' and (o.sprite=='tc-monitor-fill' or o.sprite:sub(1,9)=='tc-glyph-') then x.handles[#x.handles+1]=o end
      end
      local ids={}; for _,id in ipairs(root.order) do if registry.record(id).kind=='monitor' then ids[#ids+1]=id end end
      for _,id in ipairs(ids) do lifecycle.remove(id,'fixture-world-invalidation',true) end
      x.retire_hold=nil; x.phase='world-cleanup'; x.changed=e.tick
      log('TC_MONITOR_STATE_FULL_RETIREMENT_WORLD_INVALIDATION')
    elseif x.phase=='world-cleanup' and idle() then
      local p=s.presentation
      assert(#s.order==0 and p.front_cells==0 and p.front_frames==0 and p.staging_frames==0 and p.retired_frames==0)
      for _,o in ipairs(x.handles) do assert(not o.valid,'unaccounted native monitor object') end
      assert(e.tick-x.changed<=256)
      log('TC_MONITOR_STATE_WORLD_CLEANUP_OK ticks='..(e.tick-x.changed))
      x.phase='done'; log('TC_COLD_OK')
    end
  end
  return test
end
return M
