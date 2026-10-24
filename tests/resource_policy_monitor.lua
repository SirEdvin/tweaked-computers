-- An unfinished writer holds new seals, not shared model reads or other fronts.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local defs=require('scripts.device-definitions')
local contract=require('tests.monitor_policy_contract')
local M={}; local loaded=false
local function nop() end
local function group(id) return monitor.resolve(registry.record(id)) end
function M.run()
  contract.geometry()
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    return assert(lifecycle.build(body))
  end
  local c,a,b=build('computer',-3),build('monitor',0),build('monitor',10)
  local tiles=contract.build(c)
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(a,'network','red')))
  for _=1,20 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
  assert(group(a.id) and group(b.id))
  contract.decrease(tiles)
  storage.tc_monitor_hold={phase='bootstrap',computer=c.id,monitor=a.id,other=b.id,origin=game.tick,tiles=tiles}
end
function M.on_load()
  local f=storage.tc_monitor_hold
  if f.phase=='frozen' then
    local c=registry.computer(f.computer); local g=group(f.monitor)
    contract.check(c,f.groups)
    assert(c.invocation==f.invocation and g.render==f.front and g.model.revision==f.revision)
    assert(registry.get().ledger.total==f.spent and c.state.prefix)
    local hold=assert(g.invocation_holds[c.id..'/program'])
    assert(hold.invocation==c.invocation)
    loaded=true; log('TC_MONITOR_HOLD_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_monitor_hold
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  local c=registry.computer(f.computer)
  local g,other=group(f.monitor),group(f.other)
  if loaded then
    loaded=false; assert(runtime.stop(c.id)); assert(c.state.prefix and g.model.revision==f.revision)
    f.phase='stopped'
  end
  for _,id in ipairs(registry.get().order) do
    local r=registry.record(id); if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end
  end
  scheduler.tick(event.tick)
  assert(event.tick-f.origin<300,'invocation monitor hold deadline')
  if f.phase=='bootstrap' then
    if not g.render or not other.render then return end
    f.front=g.render; f.other_front=other.render
    local source='function start() local m=peripheral.wrap('..string.format('%q',g.id)..',"red"); m.setCursorPos(1,1); m.write("A"); computer.setState("prefix",true); while true do end end'
    runtime.save(c.id,source,c.saved_revision); assert(runtime.activate(c.id,event.tick))
    f.phase='drawing'
  elseif f.phase=='drawing' then
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    if not c.state.prefix then return end
    assert(c.invocation and g.render==f.front and g.model.cells[1][1]==65)
    local hold=assert(g.invocation_holds[c.id..'/program']); assert(hold.invocation==c.invocation)
    f.groups=contract.select(c,f.tiles)
    assert(registry.get().monitors.presentation.lanes[g.id].waiting_invocation)
    local target=group(f.tiles[6]); f.commit_front=target.render
    model.calls.setCursorPos(target.model,nop,1,1); model.calls.write(target.model,nop,'Z'); renderer.participate(target)
    f.commit_allowance=settings.global['tc-render-commit-work'].value
    contract.setting('tc-render-commit-work',1); f.phase='commit-blocked'
  elseif f.phase=='commit-blocked' then
    assert(g.render==f.front and group(f.tiles[6]).render==f.commit_front)
    local status=renderer.status(c,nop,nil,'left')
    if status.status~='blocked' then return end
    assert(status.diagnostic.code=='E_CAPACITY' and status.diagnostic.setting=='tc-render-commit-work'
      and status.diagnostic.requested>status.diagnostic.limit and status.diagnostic.recoverable)
    local lane=registry.get().monitors.presentation.lanes[c.monitor_sync_groups.left.key]
    assert(lane.job.ready and not lane.job.complete)
    f.commit_job=lane.job
    contract.setting('tc-render-commit-work',f.commit_allowance); f.phase='commit-resume'
  elseif f.phase=='commit-resume' then
    assert(g.render==f.front)
    local target=group(f.tiles[6]); if target.render==f.commit_front then return end
    assert(target.render.snapshot.cells[1][1]==90 and f.commit_job.complete)
    log('TC_CONTRACT monitor-policy-actionable-atomic-blockage-and-resume-without-producer-replay')
    model.calls.setCursorPos(other.model,nop,1,1); model.calls.write(other.model,nop,'N'); renderer.participate(other)
    f.phase='unrelated'
  elseif f.phase=='unrelated' then
    assert(c.invocation and g.render==f.front and g.model.cells[1][1]==65,'unfinished writer sealed a partial model')
    if other.render==f.other_front then return end
    assert(other.render.snapshot.cells[1][1]==78,'unrelated display did not progress')
    f.invocation=c.invocation; f.revision=g.model.revision; f.spent=registry.get().ledger.total
    f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='stopped' and g.render~=f.front then
    assert(c.status=='stopped' and c.invocation==nil and c.state.prefix)
    assert(g.render.snapshot.cells[1][1]==65 and g.render.snapshot.revision==f.revision)
    assert(next(g.invocation_holds)==nil,'Stop retained an invocation publication hold')
    assert(not c.monitor_sync and next(c.monitor_sync_groups)==nil,'Stop retained a named synchronization group')
    f.phase='done'; log('TC_CONTRACT invocation-holds-survive-cold-unrelated-front-progress-and-stop-release'); log('TC_COLD_OK')
  end
end
return M
