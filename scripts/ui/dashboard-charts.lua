-- The optional library is imported only by dashboard-model during control parsing.
local model=require('scripts.dashboard-model')
local charts=model.charts
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local M={}
local wanted={}
local surface_name='tc-dashboard-charts'
local function root()
  local r=registry.get()
  r.dashboard_presentation=r.dashboard_presentation or {states={},cursor=1}
  return r.dashboard_presentation
end
local function destroy(objects)
  for _,object in ipairs(objects or {}) do if object.valid then object.destroy() end end
end
local function release(p,state)
  destroy(state.objects)
  if state.chunk then
    destroy(state.chunk.light_ids)
    if p.surface and p.surface.surface.valid then
      p.surface.chunk_freelist[#p.surface.chunk_freelist+1]=state.chunk.coord
    end
  end
end
local function reset(p)
  for _,state in pairs(p.states) do release(p,state) end
  p.states={}
  if p.surface and p.surface.surface.valid then
    p.deleting=p.surface.surface; game.delete_surface(p.deleting)
  end
  p.surface=nil
end
function M.begin() wanted={} end
function M.show(rec,slot,node,tab,camera,status)
  local key=rec.id..'/'..slot..'/'..node.id
  wanted[key]=wanted[key] or {rec=rec,slot=slot,node=node,tab=tab,cameras={},statuses={},scales={}}
  return key
end
function M.view(key,camera,status,scale)
  local request=wanted[key]; request.cameras[#request.cameras+1]=camera; request.statuses[#request.statuses+1]=status; request.scales[#request.scales+1]=scale
end
local function signature(node,value)
  if node.type=='line' then return value, value.index, value.sum, value.data[value.index==0 and value.length or value.index] end
  return value
end
function M.finish(spend)
  local p=root()
  if p.surface and not p.surface.surface.valid then reset(p) end
  if p.deleting and p.deleting.valid then return end
  p.deleting=nil
  for key,state in pairs(p.states) do if not wanted[key] then release(p,state); p.states[key]=nil end end
  if not charts then
    if p.surface then reset(p) end
    for _,request in pairs(wanted) do for _,status in ipairs(request.statuses) do status.caption='Charts unavailable: enable factorio-charts'; end end
    return
  end
  local keys={}; for key in pairs(wanted) do keys[#keys+1]=key end; table.sort(keys)
  local count=#keys; if count==0 then return end
  local start=math.min(p.cursor,count)
  for offset=0,count-1 do
    local index=(start+offset-1)%count+1; local key=keys[index]; local request=wanted[key]
    local node=request.node; local value=request.tab.charts[node.id]
    local a,b,c,d=signature(node,value)
    local state=p.states[key]
    local status_text
    local empty=node.type=='line' and #value.data<2 or node.type=='stacked_bars' and #value==0
    if empty then status_text=node.type=='line' and 'Collecting samples' or 'No duration data'
    elseif not state or state.a~=a or state.b~=b or state.c~=c or state.d~=d or state.format~=node.format then
      local cost=4096+(node.type=='line' and node.capacity*#node.series*32 or #value*#node.phases*64)
      if cost>math.min(limits.maintenance_work_per_tick,limits.host_work_per_tick) then
        status_text='Chart exceeds a fresh maintenance allowance; reduce its data/capacity'
      else
        local admitted=scheduler.try_maintenance(function() spend(cost) end)
        if not admitted then status_text='Chart update pending (previous image may be stale)'
        else
          local ok,e=pcall(function()
            if not p.surface then
              if game.get_surface(surface_name) then error('private chart surface name is already occupied') end
              p.surface={surface=game.create_surface(surface_name,{width=1,height=1}),chunk_freelist={}}
              p.surface=charts.surface.create(surface_name)
            end
            state=state or {}; p.states[key]=state
            if not state.chunk then state.chunk=charts.surface.allocate_chunk(p.surface) end
            local objects
            if node.type=='line' then
              local ordered
              ordered,objects=charts.render.line_graph(p.surface.surface,state.chunk,{data=value.data,index=value.index,
                length=value.length,sum=value.sum,counts=value.counts,label_format=node.format=='number' and tostring or node.format,ttl=0})
            else
              local colors={}; for i,name in ipairs(node.phases) do colors[name]=charts.colors.get_series_color(i) end
              objects=charts.render.stacked_bars(p.surface.surface,state.chunk,{deliveries=value,phase_order=node.phases,phase_colors=colors,ttl=0})
            end
            destroy(state.objects); state.objects=objects; state.a=a; state.b=b; state.c=c; state.d=d; state.format=node.format
          end)
          if not ok then
            -- A library exception can leave handles it never returned. Delete only our surface.
            reset(p); status_text='Chart rendering failed; retained data is unchanged'
            log('Dashboard chart rendering failure: '..tostring(e))
          end
        end
      end
    end
    state=p.states[key]
    for i,camera in ipairs(request.cameras) do
      if camera.valid then
        local available=state and state.chunk and p.surface and p.surface.surface.valid and not empty
        camera.visible=available and true or false
        if available then
          local params=charts.surface.get_camera_params(state.chunk,{widget_width=camera.style.minimal_width,widget_height=camera.style.minimal_height})
          camera.surface_index=p.surface.surface.index; camera.position=params.position; camera.zoom=params.zoom*request.scales[i]
        end
        request.statuses[i].caption=status_text or ''
      end
    end
  end
  p.cursor=start%count+1
end
function M.hide_from_force(force)
  local p=registry.get().dashboard_presentation
  if p and p.surface and p.surface.surface.valid then force.set_surface_hidden(p.surface.surface,true) end
end
registry.register_cleanup('dashboard-charts',function(rec)
  if rec.kind~='dashboard' then return end
  local p=registry.get().dashboard_presentation
  if p then for key,state in pairs(p.states) do if key:sub(1,#rec.id+1)==rec.id..'/' then release(p,state); p.states[key]=nil end end end
end)
return M
