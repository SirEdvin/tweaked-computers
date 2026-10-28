-- Native render objects/surfaces with GUI camera doubles; not visual acceptance.
local model=require('scripts.dashboard-model')
local presentation=require('scripts.ui.dashboard-charts')
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local service=require('scripts.services.dashboard')
local lifecycle=require('scripts.lifecycle')
local data=require('scripts.runtime.data')
local M={}
local state
local function request(panel,id,count)
  local tab=panel.dashboard.tabs['6']; local node=model.widget(tab,id)
  local key=presentation.show(panel,6,node,tab)
  local status
  for _=1,count or 1 do
    local camera={valid=true,style={minimal_width=450,minimal_height=350}}
    status={}; presentation.view(key,camera,status,1)
  end
  return key,status
end
function M.start() state={phase=1} end
function M.tick(panel,tick)
  local s=assert(state); local root=registry.get()
  local spend=scheduler.maintenance(root,tick,true)
  local function render(id,count)
    presentation.begin(); local key,status=request(panel,id,count); presentation.finish(spend)
    return root.dashboard_presentation.states[key],status
  end
  if s.phase==1 then
    model.set_tab(panel,6,{title='Resource check',content={type='column',id='root',children={
      {type='line',id='line',series={'a','b'},capacity=3},
      {type='stacked_bars',id='bars',phases={'work','wait'}}}}},function() end,true)
    if not model.charts then
      local rendered,status=render('line',2)
      assert(not rendered and status.caption:find('unavailable',1,true) and not root.dashboard_presentation.surface)
      service.methods.removeTab(nil,panel,'red',tick,function() end,6); state=nil
      log('TC_DASHBOARD_RENDER absent-no-import-placeholder'); return true
    end
    for i=1,5 do model.append(panel,6,'line',{a=i,b=2*i},function() end) end
    model.bars(panel,6,'bars',{{work=1,wait=2},{work=3,wait=1}},function() end)
    local rendered,status=render('line',2)
    assert(rendered and #rendered.objects>10 and status.caption=='')
    s.objects=rendered.objects; s.coord=rendered.chunk.coord; s.ring=panel.dashboard.tabs['6'].charts.line
    s.other=rendering.draw_text{text='unrelated world drawing',surface=game.surfaces[1],target={0,0},color={1,1,1}}
  elseif s.phase==2 then
    local rendered=render('line',2)
    assert(rendered.objects==s.objects,'unchanged/shared cameras redrew the chart')
    presentation.begin(); presentation.finish(spend)
    for _,object in ipairs(s.objects) do assert(not object.valid) end
    assert(next(root.dashboard_presentation.states)==nil and #root.dashboard_presentation.surface.chunk_freelist==1)
    model.append(panel,6,'line',{a=6,b=12},function() end)
    presentation.begin(); presentation.finish(spend)
    assert(next(root.dashboard_presentation.states)==nil and s.ring.index==0,'closed append drew or lost history')
  elseif s.phase==3 then
    local rendered=render('line',2)
    assert(rendered.chunk.coord.x==s.coord.x and rendered.chunk.coord.y==s.coord.y,'closed/reopened chunk was not reused')
    s.objects=rendered.objects
    local force=game.create_force('tc-dashboard-hidden-force')
    presentation.hide_from_force(force)
    assert(force.get_surface_hidden(root.dashboard_presentation.surface.surface))
    model.append(panel,6,'line',{a=7,b=14},function() end)
    local ceiling=limits.maintenance_work_per_tick
    spend(1000)
    limits.maintenance_work_per_tick=root.scheduler.maintenance_spent+4096
    -- A 4288-work atom fits the fresh ceiling but not this tick's remaining tail.
    local rendered,status=render('line',2)
    limits.maintenance_work_per_tick=ceiling
    assert(rendered.objects==s.objects and status.caption:find('pending',1,true))
    limits.maintenance_work_per_tick=4096
    rendered,status=render('line',2); limits.maintenance_work_per_tick=ceiling
    assert(rendered.objects==s.objects and status.caption:find('fresh maintenance',1,true))
    assert(s.ring.data[1].a==7,'render refusal changed accepted data')
  elseif s.phase==4 then
    model.append(panel,6,'line',{a=8,b=16},function() end)
    model.bars(panel,6,'bars',{{work=2,wait=1},{work=1,wait=3}},function() end)
    presentation.begin(); local line=request(panel,'line'); local bars=request(panel,'bars')
    local ceiling=limits.maintenance_work_per_tick; limits.maintenance_work_per_tick=6000
    presentation.finish(spend); limits.maintenance_work_per_tick=ceiling
    s.fair_line=root.dashboard_presentation.states[line].objects
    s.fair_bars=root.dashboard_presentation.states[bars].objects
  elseif s.phase==5 then
    model.append(panel,6,'line',{a=9,b=18},function() end)
    model.bars(panel,6,'bars',{{work=3,wait=1},{work=2,wait=2}},function() end)
    presentation.begin(); local line=request(panel,'line'); local bars=request(panel,'bars')
    local ceiling=limits.maintenance_work_per_tick; limits.maintenance_work_per_tick=6000
    presentation.finish(spend); limits.maintenance_work_per_tick=ceiling
    assert(root.dashboard_presentation.states[line].objects~=s.fair_line,'continuously dirty first chart starved its peer')
    assert(root.dashboard_presentation.states[bars].objects==s.fair_bars,'fairness probe did not constrain the native render allowance')
  elseif s.phase==6 then
    local original=model.charts.render.line_graph
    local definition=data.copy(panel.dashboard.tabs['6'].definition)
    definition.content.children[1].format='time'; model.set_tab(panel,6,definition,function() end)
    model.charts.render.line_graph=function(surface,chunk)
      rendering.draw_line{surface=surface,from=chunk.coord,to={chunk.coord.x+1,chunk.coord.y+1},color={1,1,1},width=1}
      error('injected partial renderer failure')
    end
    local ok,rendered,status=pcall(render,'line',2)
    model.charts.render.line_graph=original
    assert(ok,rendered)
    assert(not rendered and status.caption:find('failed',1,true) and s.other.valid)
    s.deleted=root.dashboard_presentation.deleting
  elseif s.phase==7 then
    assert(not s.deleted.valid,'partial-failure private surface survived cleanup')
    local rendered=render('line',2)
    assert(rendered and rendered.objects[1].valid and s.other.valid)
    assert(panel.dashboard.tabs['6'].charts.line==s.ring and s.ring.data[1].a==7)
    s.deleted=root.dashboard_presentation.surface.surface
    assert(game.delete_surface(s.deleted))
  elseif s.phase==8 then
    assert(not s.deleted.valid)
    local rendered=render('line',2)
    assert(rendered and rendered.objects[1].valid and s.other.valid,'deleted private surface did not reconstruct')
    local bar=render('bars')
    assert(bar and #bar.objects==14)
    local definition=panel.dashboard.tabs['6'].definition
    service.methods.removeTab(nil,panel,'red',tick,function() end,6)
    presentation.begin(); presentation.finish(spend)
    assert(next(root.dashboard_presentation.states)==nil and s.other.valid)
    local rec=assert(lifecycle.build(assert(game.surfaces[1].create_entity{name='tc-dashboard-shell',position={12,6},force='player'})))
    model.set_tab(rec,6,definition,function() end)
    for i=1,2 do model.append(rec,6,'line',{a=i,b=i},function() end) end
    presentation.begin(); local key=request(rec,'line'); presentation.finish(spend)
    local owned=assert(root.dashboard_presentation.states[key])
    lifecycle.remove(rec.id,'fixture-cleanup',true)
    for _,object in ipairs(owned.objects) do assert(not object.valid) end
    for _,light in ipairs(owned.chunk.light_ids) do assert(not light.valid) end
    assert(not root.dashboard_presentation.states[key] and s.other.valid)
    s.other.destroy(); state=nil
    log('TC_DASHBOARD_RENDER shared-stationary-closed-reuse-refusal-partial-error-surface-recovery-isolation')
    return true
  end
  s.phase=s.phase+1
end
return M
