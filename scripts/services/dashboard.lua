local model=require('scripts.dashboard-model')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local M={methods={}}
local player_authorized
function M.register_player_authority(fn) assert(not player_authorized); player_authorized=fn end
local function method(name,n,fn)
  M.methods[name]=function(c,r,w,t,spend,...)
    if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
    return fn(c,r,w,t,spend,...)
  end
end
method('setTab',2,function(c,r,w,t,spend,slot,definition) model.set_tab(r,slot,definition,spend) end)
method('getTab',1,function(c,r,w,t,spend,slot)
  local tab=model.current(r).tabs[model.slot(slot)]
  if tab then return (data.copy(tab.definition,spend,limits.peripheral_call_bytes)) end
  return nil
end)
method('removeTab',1,function(c,r,w,t,spend,slot)
  local key=model.slot(slot); local previous=model.current(r)
  if not previous.tabs[key] then return false end
  spend(16); local candidate={version=1,generation=previous.generation,tabs={}}
  for k,v in pairs(previous.tabs) do if k~=key then candidate.tabs[k]=v end end
  r.dashboard=candidate; return true
end)
method('setText',3,function(c,r,w,t,spend,slot,id,text) model.set_leaf(r,slot,id,text,false,spend) end)
method('setEnabled',3,function(c,r,w,t,spend,slot,id,enabled) model.set_leaf(r,slot,id,enabled,true,spend) end)
method('getLimits',0,function(c,r,w,t,spend)
  local result=data.copy(limits,spend,limits.peripheral_call_bytes)
  result.dashboard_tabs=model.tabs; result.dashboard_state_bytes=limits.state_bytes
  if model.charts then result.chart_line_series=model.charts.colors.get_max_series(); result.chart_bar_entries=model.bar_entries end
  return result
end)
method('subscribe',1,function(c,r,w,t,spend,handler)
  return runtime.subscribe(c,'dashboard_click',handler,{peripheral=r.id,generation=r.generation,wire=w},spend)
end)
local function remove_queued(c,id)
  local queue,bytes={},0
  for _,item in ipairs(c.queue) do
    if item.event.subscription_id~=id then queue[#queue+1]=item; bytes=bytes+item.bytes end
  end
  c.queue=queue; c.queue_bytes=bytes
  registry.ready_changed(c)
end
method('unsubscribe',1,function(c,r,w,t,spend,id)
  if type(id)~='string' then errors.raise('E_ARGUMENT','subscription ID required') end
  local sub=c.subscriptions[id]
  if sub and (sub.event_name~='dashboard_click' or sub.details.peripheral~=r.id or sub.details.wire~=w) then errors.raise('E_ARGUMENT','subscription belongs to another dashboard binding') end
  spend(#c.queue*2+1)
  local exists=runtime.unsubscribe(c,id,spend); remove_queued(c,id); return exists
end)
if model.charts then
  method('appendSample',3,function(c,r,w,t,spend,slot,id,values) model.append(r,slot,id,values,spend) end)
  method('setBars',3,function(c,r,w,t,spend,slot,id,bars) model.bars(r,slot,id,bars,spend) end)
  method('clearChart',2,function(c,r,w,t,spend,slot,id) model.clear(r,slot,id,spend) end)
end
local function authorized(c,r,sub,spend)
  if not r or not r.body.valid or r.generation~=sub.details.generation or not lifecycle.available(r)
    or c.status~='running' or not lifecycle.available(c) then return false end
  local ok,target=pcall(peripheral.authority,c,r.id,sub.details.wire,spend)
  if not ok then if type(target)~='table' or not target.code then error(target,0) end; return false end
  return target==r
end
function M.click(r,slot,id,player_index,token,tick)
  local tab=model.current(r).tabs[model.slot(slot)]; local button=model.widget(tab,id,'button')
  if not button.enabled or not player_authorized or not player_authorized(player_index,r,token,slot) then return false end
  local root=registry.get(); local spend=scheduler.maintenance(root,tick)
  local admitted,deliveries=scheduler.try_maintenance(function()
    spend(limits.registry_entries+limits.aggregate_subscriptions+1)
    local subscriptions={}
    for _,c in pairs(root.computers) do
      for _,sub in pairs(c.subscriptions) do
        if sub.event_name=='dashboard_click' and sub.details.peripheral==r.id then
          subscriptions[#subscriptions+1]={c=c,sub=sub}
        end
      end
    end
    spend(#subscriptions*#subscriptions+1)
    table.sort(subscriptions,function(a,b) return a.sub.sequence<b.sub.sequence end)
    local items={}
    for _,entry in ipairs(subscriptions) do
      local c,sub=entry.c,entry.sub
      if authorized(c,r,sub,spend) then
        local item=runtime.prepare_event(c,sub.handler,{name='dashboard_click',peripheral=r.id,wire=sub.details.wire,
          subscription_id=sub.id,tab=slot,button=id,player_index=player_index},tick,spend)
        if item then
          item.dashboard={layout=tab.generation,token=token,unit=r.body.unit_number}
          -- Overflow may retire a run and its existing outputs/subscriptions.
          spend(limits.registry_entries*4+limits.subscriptions*2+#c.queue*2+128)
          items[#items+1]={c=c,item=item}
        end
      end
    end
    return items
  end)
  if not admitted then return false end -- No private retry/backlog or delivered prefix.
  for _,entry in ipairs(deliveries) do runtime.publish_event(entry.c,entry.item,tick) end
  return true
end
function M.validate(c,item,spend)
  local event=item.event; local sub=c.subscriptions[event.subscription_id]
  local r=registry.record(event.peripheral); local proof=item.dashboard
  if not sub or sub.event_name~='dashboard_click' or not proof or not r or r.kind~='dashboard'
    or not r.body.valid or r.body.unit_number~=proof.unit or not authorized(c,r,sub,spend) then return false end
  local tab=model.current(r).tabs[model.slot(event.tab)]
  if not tab or tab.generation~=proof.layout then return false end
  local ok,button=pcall(model.widget,tab,event.button,'button')
  return ok and button.enabled and player_authorized and player_authorized(event.player_index,r,proof.token,event.tab) or false
end
function M.revoke(c,name,wire,reason)
  if reason=='unavailable' or reason=='limit' then return end -- Incomplete discovery is not definitive detachment.
  local ids={}
  for id,sub in pairs(c.subscriptions) do
    if sub.event_name=='dashboard_click' and sub.details.peripheral==name and sub.details.wire==wire then ids[#ids+1]=id end
  end
  for _,id in ipairs(ids) do runtime.unsubscribe(c,id); remove_queued(c,id) end
end
peripheral.register_type('dashboard',{methods=M.methods})
peripheral.register_revocation('dashboard-subscriptions',M.revoke)
scheduler.register_dashboard_validator(M.validate)
return M
