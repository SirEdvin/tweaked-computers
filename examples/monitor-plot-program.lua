-- Paste the returned API-v1 document into a computer. Draws a rolling sine
-- point trace: each step replaces one complete row on every selected screen.
-- Older rows deliberately retain the trail; this is not a batched full repaint.
return [[return {api_version=1,handlers={
 start=function(e)
  computer.setState('plot_refresh',true)
  computer.setState('plot_sample',0)
  local limits=computer.getLimits()
  computer.setState('plot_member_limit',limits.sync_group_members)
  computer.setState('plot_cell_limit',limits.sync_group_cells)
  computer.every(10,'plot')
  computer.every(300,'refresh')
  computer.on('peripheral_attach','refresh')
  computer.on('peripheral_detach','refresh')
  computer.on('monitor_resize','refresh')
 end,
 refresh=function(e)
  local views=computer.getState('plot_views') or {}
  if e.name~='timer' or computer.getState('plot_missing') or #views==0 then computer.setState('plot_refresh',true) end
 end,
 plot=function(e)
  local stage=computer.getState('plot_stage')
  if computer.getState('plot_refresh') then
   computer.setState('plot_refresh',false)
   computer.setState('plot_views',{})
   computer.setState('plot_seen',{})
   computer.setState('plot_missing',false)
   computer.setState('plot_wire',1)
   stage='scan'
  end
  local views=computer.getState('plot_views') or {}
  if stage=='scan' then
   local wire=computer.getState('plot_wire')==1 and 'red' or 'green'
   local ok,names=pcall(peripheral.getNames,wire)
   if not ok then return end
   local candidates={}
   for i=1,math.min(#names,8) do candidates[i]={name=names[i],wire=wire} end
   computer.setState('plot_candidates',candidates)
   computer.setState('plot_index',1)
   stage='inspect'
  elseif stage=='inspect' then
   local candidates=computer.getState('plot_candidates')
   local index=computer.getState('plot_index')
   local ref=candidates[index]
   if ref then
    local seen=computer.getState('plot_seen')
    if not seen[ref.name] and #views<computer.getState('plot_member_limit') then
     local ok,w,h=pcall(function()
      if peripheral.getType(ref.name,ref.wire)~='monitor' then return end
      return peripheral.call(ref.name,ref.wire,'getSize')
     end)
     if not ok then computer.setState('plot_missing',true) end
     if ok and w then
      local cells=w*h
      for _,view in ipairs(views) do cells=cells+view.width*view.height end
      if cells<=computer.getState('plot_cell_limit') then
       views[#views+1]={name=ref.name,wire=ref.wire,width=w,height=h}
       seen[ref.name]=true; computer.setState('plot_seen',seen)
       computer.setState('plot_views',views)
      end
     end
    end
    computer.setState('plot_index',index+1)
   elseif computer.getState('plot_wire')==1 then
    computer.setState('plot_wire',2); stage='scan'
   else stage='select' end
  elseif stage=='select' then
   local refs={}
   for _,view in ipairs(views) do refs[#refs+1]={name=view.name,wire=view.wire} end
   local ok=pcall(peripheral.setMonitorSyncGroup,refs)
   if ok then computer.setState('plot_index',1); stage='clear'
   else computer.setState('plot_refresh',true) end
  elseif stage=='clear' then
   local index=computer.getState('plot_index'); local view=views[index]
   if view then
    local ok=pcall(peripheral.call,view.name,view.wire,'clear')
    if not ok then computer.setState('plot_refresh',true) end
    computer.setState('plot_index',index+1)
   else stage='draw' end
  elseif stage=='draw' then
   local sample=computer.getState('plot_sample')+1
   local value=math.sin(computer.getTick()/120)
   local ok=pcall(function()
    for _,view in ipairs(views) do
     local width,height=view.width,view.height
     local x=1+(sample-1)%width
     local y=1+math.floor((1-value)*(height-1)/2+0.5)
     local text=string.rep(' ',x-1)..'*'..string.rep(' ',width-x)
     peripheral.call(view.name,view.wire,'setCursorPos',1,y)
     peripheral.call(view.name,view.wire,'blit',text,string.rep('5',width),string.rep('f',width))
    end
   end)
   if ok then computer.setState('plot_sample',sample)
   else computer.setState('plot_refresh',true) end
  end
  computer.setState('plot_stage',stage)
 end
}}]]
