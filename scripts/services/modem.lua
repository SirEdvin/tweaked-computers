-- Broadcast preparation is private; publication resumes at the saved recipient.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local radar=require('scripts.radar')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local common=require('scripts.runtime.limits')
local M={methods={}}
local MAX=9007199254740991
local function arity(n,want) if n~=want then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function channel(value)
  if type(value)~='number' then errors.raise('E_ARGUMENT','numeric channel required') end
  if not errors.integer(value,0,MAX) then errors.raise('E_RANGE','channel must be a nonnegative safe integer') end
  return value
end
local function state(rec,spend) return radar.state(rec,spend) end
local function channels(rec,s,count,guard)
  -- The owner outlives the calling computer; registry retirement releases it.
  guard.host_resize('radar-channels:'..rec.id,count==0 and 0 or 128+count*32)
end
function M.methods.getLimits(c,r,w,t,spend,guard,...)
  arity(select('#',...),0)
  local result={}; for k,v in pairs(common) do result[k]=v end
  result.channel_min=0; result.channel_max=MAX
  return result
end
function M.methods.isWireless(c,r,w,t,spend,guard,...)
  arity(select('#',...),0); return true
end
function M.methods.open(c,r,w,t,spend,guard,...)
  arity(select('#',...),1); local ch=channel(...); local s=state(r,spend)
  if s.channels[ch] then return end
  guard.prepare_empty_result(); channels(r,s,s.count+1,guard)
  s.channels[ch]=true; s.count=s.count+1
end
function M.methods.isOpen(c,r,w,t,spend,guard,...)
  arity(select('#',...),1); local ch=channel(...); return state(r,spend).channels[ch]==true
end
function M.methods.close(c,r,w,t,spend,guard,...)
  arity(select('#',...),1); local ch=channel(...); local s=state(r,spend)
  if s.channels[ch] then
    guard.prepare_empty_result(); channels(r,s,s.count-1,guard)
    s.channels[ch]=nil; s.count=s.count-1
  end
end
function M.methods.closeAll(c,r,w,t,spend,guard,...)
  arity(select('#',...),0); local s=state(r,spend)
  guard.prepare_empty_result(); channels(r,s,0,guard); s.channels={}; s.count=0
end
local function eligible(sender,receiver)
  return receiver.native_carrier=='radar' and sender.id~=receiver.id
    and sender.force_index==receiver.force_index and radar.available(receiver)
    and (sender.surface_index==receiver.surface_index
      or sender.modem_tier=='interplanetary' and receiver.modem_tier=='interplanetary' and script.active_mods['space-age'])
end
local function running(computer,sender)
  return computer and computer.status=='running' and computer.powered
    and computer.force_index==sender.force_index and lifecycle.has_power(computer)
    and computer.body.force.index==sender.force_index and computer.body.surface.index==computer.surface_index
    and (computer.surface_index==sender.surface_index
      or sender.modem_tier=='interplanetary' and script.active_mods['space-age'])
end
local function grow(job,guard,bytes)
  guard.job_resize(job.bytes+bytes)
  job.bytes=job.bytes+bytes
end
local function receiver_plan(computer,sender,ch,spend)
  local paths={}
  for _,wire in ipairs({'red','green'}) do
    for id in pairs(peripheral.inventory(computer,wire,spend)) do
      spend(4)
      local receiver=registry.record(id)
      if receiver and eligible(sender,receiver) and state(receiver,spend).channels[ch] then
        paths[id]=paths[id] or {}; paths[id][#paths[id]+1]=wire
      end
    end
  end
  local names,subscriptions={},{}
  for id in pairs(paths) do spend(#id+4); names[#names+1]=id end
  for _,sub in pairs(computer.subscriptions) do
    spend(4)
    if sub.event_name=='modem_message' then
      subscriptions[#subscriptions+1]={id=sub.id,handler=sub.handler,sequence=sub.sequence}
    end
  end
  spend((#names+#subscriptions)*16+1)
  table.sort(names); table.sort(subscriptions,function(a,b) return a.sequence<b.sequence end)
  return {computer=computer.id,run_id=computer.run_id,generation=computer.generation,
    paths=paths,names=names,subscriptions=subscriptions,receiver=1,subscription=1}
end
local function live_delivery(sender,delivery,spend,guard)
  local computer=registry.record(delivery.computer); local receiver=registry.record(delivery.receiver)
  if not running(computer,sender) or computer.run_id~=delivery.run_id or computer.generation~=delivery.generation
    or not receiver or receiver.generation~=delivery.receiver_generation or not eligible(sender,receiver)
    or not state(receiver,spend).channels[delivery.channel] then return nil end
  local sub=computer.subscriptions[delivery.subscription]
  if not sub or sub.event_name~='modem_message' or sub.handler~=delivery.item.handler or sub.sequence~=delivery.sequence then return nil end
  -- Rebuild both local paths; no captured inventory is authority after suspension.
  local wires={}
  for _,wire in ipairs({'red','green'}) do
    local ok,inventory=pcall(peripheral.inventory,computer,wire,spend)
    if not ok then
      if type(inventory)=='table' and (inventory.code=='E_NETWORK_PENDING' or inventory.code=='E_UNREACHABLE') then return nil end
      if type(inventory)=='table' and inventory.code=='E_CAPACITY' then return guard.suspend() end
      error(inventory,0)
    end
    if inventory[receiver.id] then wires[#wires+1]=wire end
  end
  if #wires==0 then return nil end
  return computer,wires
end
function M.methods.transmit(c,r,w,t,spend,guard,...)
  arity(select('#',...),3)
  local ch,reply,value=...; channel(ch); channel(reply)
  local job=guard.job('modem-transmit',function()
    return {phase='payload',sent_tick=t,ids={},scan=1,plan={},cursor=1,bytes=512,
      sender_generation=r.generation,force=r.force_index,surface=r.surface_index}
  end)
  if job.phase=='payload' then
    local message,stats
    if value~=nil then message,stats=data.copy(value,spend,common.pending_work_bytes) end
    grow(job,guard,stats and stats.bytes or 0)
    job.message=message; job.phase='inventory'
  end
  local root=registry.get()
  if job.phase=='inventory' then
    while job.scan<=#root.order do
      local id=root.order[job.scan]; spend(#id+8)
      if root.computers[id] then grow(job,guard,#id+32); job.ids[#job.ids+1]=id end
      job.scan=job.scan+1
    end
    spend(#job.ids*16+1); table.sort(job.ids); job.scan=1; job.phase='prepare'
  end
  while job.phase=='prepare' do
    if not job.current then
      if job.scan>#job.ids then job.phase='deliver'; break end
      local computer=registry.record(job.ids[job.scan]); spend(8)
      if running(computer,r) then
        local current=receiver_plan(computer,r,ch,spend)
        local bytes=256+#current.computer+#current.run_id
        for _,id in ipairs(current.names) do bytes=bytes+#id+192 end
        for _,sub in ipairs(current.subscriptions) do bytes=bytes+#sub.id+#sub.handler+128 end
        grow(job,guard,bytes); current.bytes=bytes; job.current=current
      else job.scan=job.scan+1 end
    else
      local current=job.current
      local id=current.names[current.receiver]; local sub=current.subscriptions[current.subscription]
      if not id then
        guard.job_resize(job.bytes-current.bytes); job.bytes=job.bytes-current.bytes
        job.current=nil; job.scan=job.scan+1
      elseif not sub then spend(1); current.receiver=current.receiver+1; current.subscription=1
      else
        local computer=registry.record(current.computer); local receiver=registry.record(id)
        spend(16)
        if running(computer,r) and computer.run_id==current.run_id and receiver and eligible(r,receiver) then
          local distance
          if receiver.surface_index==r.surface_index then
            local a,b=r.body.position,receiver.body.position
            distance=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
          end
          local event={name='modem_message',peripheral=id,wire=current.paths[id][1],wires=current.paths[id],
            channel=ch,replyChannel=reply,message=job.message,distance=distance,sent_tick=job.sent_tick}
          local item=runtime.prepare_event(computer,sub.handler,event,job.sent_tick,spend)
          if item then
            grow(job,guard,(item.bytes or 256)+256+#id+#current.computer+#current.run_id+#sub.id)
            job.plan[#job.plan+1]={computer=current.computer,generation=current.generation,run_id=current.run_id,
              receiver=id,receiver_generation=receiver.generation,subscription=sub.id,sequence=sub.sequence,channel=ch,item=item}
          end
        end
        current.subscription=current.subscription+1
      end
    end
  end
  guard.prepare_empty_result()
  while job.cursor<=#job.plan do
    local delivery=job.plan[job.cursor]
    local authorized,target=pcall(peripheral.authority,c,r.id,w,spend)
    if not authorized then
      if type(target)=='table' and target.code=='E_CAPACITY' then return guard.suspend() end
      if type(target)=='table' and (target.code=='E_NETWORK_PENDING' or target.code=='E_UNREACHABLE') then target=nil
      else error(target,0) end
    end
    if not radar.available(r) or r.generation~=job.sender_generation or r.force_index~=job.force
      or r.surface_index~=job.surface or target~=r then
      -- Losing the sending endpoint cancels the remaining datagram, not its prefix.
      job.cursor=#job.plan+1; return
    end
    local computer=live_delivery(r,delivery,spend,guard)
    -- Authority, sequence and publication work are paid before this one effect.
    spend(32)
    if computer then
      if not errors.integer(root.next_sequence,1,MAX-1) then errors.raise('E_CAPACITY','modem event sequence exhausted') end
      -- Metadata remains the prepared receive-time route; authority above is live.
      runtime.publish_event(computer,delivery.item,game.tick)
    end
    job.cursor=job.cursor+1
  end
end
peripheral.register_type('radar',{methods=M.methods,with_guard=true,callback_stable=true,available=function(rec,spend)
  radar.state(rec,spend); return radar.available(rec)
end})
return M
