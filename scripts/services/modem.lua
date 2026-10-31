-- Closed native radar datagrams. All proof/copy/admission precedes publication.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local radar=require('scripts.radar')
local data=require('scripts.runtime.data')
local errors=require('scripts.runtime.errors')
local common=require('scripts.runtime.limits')
local M={methods={}}
-- Frozen transport envelope: tests.modem_engine and the paid chart/logic
-- competition fixture exercise these bounds without increasing common budgets.
local limits={channel_min=0,channel_max=65535,open_channels=128,
  message_bytes=4096,message_nodes=256,message_depth=8,routing_candidates=64,
  deliveries_per_transmit=8,transmits_per_computer_tick=2,transmits_per_tick=16}
local function arity(n,want) if n~=want then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function channel(value)
  if type(value)~='number' then errors.raise('E_ARGUMENT','numeric channel required') end
  if not errors.integer(value,0,65535) then errors.raise('E_RANGE','channel must be an integer from 0 to 65535') end
  return value
end
local function state(rec,spend) return radar.state(rec,spend) end
function M.methods.getLimits(c,r,w,t,spend,...)
  arity(select('#',...),0)
  local result={}; for k,v in pairs(limits) do result[k]=v end
  result.string_bytes=common.string_bytes; result.table_entries=common.table_entries
  result.data_nodes=common.data_nodes; result.data_depth=common.data_depth
  return result
end
function M.methods.isWireless(c,r,w,t,spend,...)
  arity(select('#',...),0); return true
end
function M.methods.open(c,r,w,t,spend,...)
  arity(select('#',...),1); local ch=channel(...); local s=state(r,spend)
  if s.channels[ch] then return end
  if s.count==limits.open_channels then errors.raise('E_CAPACITY','open modem channel capacity reached') end
  s.channels[ch]=true; s.count=s.count+1
end
function M.methods.isOpen(c,r,w,t,spend,...)
  arity(select('#',...),1); local ch=channel(...); return state(r,spend).channels[ch]==true
end
function M.methods.close(c,r,w,t,spend,...)
  arity(select('#',...),1); local ch=channel(...); local s=state(r,spend)
  if s.channels[ch] then s.channels[ch]=nil; s.count=s.count-1 end
end
function M.methods.closeAll(c,r,w,t,spend,...)
  arity(select('#',...),0); local s=state(r,spend); s.channels={}; s.count=0
end
local function payload(value,spend)
  if value==nil then return nil end
  local ok,copied,stats=pcall(data.copy,value,spend,limits.message_bytes)
  if not ok then
    if type(copied)=='table' and copied.code=='E_CAPACITY' then errors.raise('E_LIMIT','modem payload byte limit exceeded') end
    error(copied,0)
  end
  if stats.nodes>limits.message_nodes then errors.raise('E_LIMIT','modem payload node limit exceeded') end
  local function depth(v,d)
    spend(1)
    if d>limits.message_depth then errors.raise('E_LIMIT','modem payload depth limit exceeded') end
    if type(v)=='table' then for _,x in pairs(v) do depth(x,d+1) end end
  end
  depth(copied,0); return copied
end
local function ledger(root,tick,spend)
  spend((limits.transmits_per_tick+1)*8+1)
  local s=root.modem_transport
  if s==nil then s={version=1,tick=tick,total=0,computers={}}; root.modem_transport=s end
  if type(s)~='table' or s.version~=1 or not errors.integer(s.tick,0,tick)
    or not errors.integer(s.total,0,limits.transmits_per_tick) or type(s.computers)~='table' then
    errors.raise('E_UNSUPPORTED','unsupported modem admission state; retained')
  end
  local count=0; local sum=0
  for id,n in pairs(s.computers) do
    count=count+1
    if count>limits.transmits_per_tick or type(id)~='string' or #id>common.identifier_bytes
      or not errors.integer(n,1,limits.transmits_per_computer_tick) then errors.raise('E_UNSUPPORTED','invalid modem credits; retained') end
    sum=sum+n
  end
  if sum~=s.total then errors.raise('E_UNSUPPORTED','invalid modem aggregate credits; retained') end
  if s.tick~=tick then s.tick=tick; s.total=0; s.computers={} end
  return s
end
local function eligible(sender,receiver)
  return receiver.native_carrier=='radar' and sender.id~=receiver.id
    and sender.force_index==receiver.force_index and radar.available(receiver)
    and (sender.surface_index==receiver.surface_index
      or sender.modem_tier=='interplanetary' and receiver.modem_tier=='interplanetary' and script.active_mods['space-age'])
end
function M.methods.transmit(c,r,w,t,spend,...)
  arity(select('#',...),3)
  local ch,reply,value=...; channel(ch); channel(reply); state(r,spend)
  local message=payload(value,spend)
  local root=registry.get(); local credits=ledger(root,t,spend)
  if credits.total>=limits.transmits_per_tick or (credits.computers[c.id] or 0)>=limits.transmits_per_computer_tick then
    errors.raise('E_LIMIT','modem transmission rate exceeded; retry on a later tick')
  end
  spend(#root.order*8+1)
  local candidates={}; local count=0
  local computers={}
  for _,rec in pairs(root.computers) do
    if rec.status=='running' and rec.force_index==r.force_index
      and (rec.surface_index==r.surface_index or r.modem_tier=='interplanetary' and script.active_mods['space-age'])
      and lifecycle.available(rec) then
      for _,sub in pairs(rec.subscriptions) do
        spend(4)
        if sub.event_name=='modem_message' then computers[#computers+1]=rec; break end
      end
    end
  end
  spend(#computers*16+1); table.sort(computers,function(a,b) return a.id<b.id end)
  local plan={}
  for _,computer in ipairs(computers) do
    local paths={}
    -- Both full inventories must succeed, even when the first has a match.
    for _,wire in ipairs({'red','green'}) do
      local inventory=peripheral.inventory(computer,wire,spend)
      for id in pairs(inventory) do
        local rec=registry.record(id)
        if rec and eligible(r,rec) and state(rec,spend).channels[ch] then
          if not candidates[id] then
            count=count+1
            if count>limits.routing_candidates then errors.raise('E_LIMIT','modem routing candidate limit exceeded') end
            candidates[id]=rec
          end
          paths[id]=paths[id] or {}; paths[id][#paths[id]+1]=wire
        end
      end
    end
    local names={}; for id in pairs(paths) do names[#names+1]=id end
    local subscriptions={}
    spend(common.subscriptions*16+#names*16+1)
    for _,sub in pairs(computer.subscriptions) do if sub.event_name=='modem_message' then subscriptions[#subscriptions+1]=sub end end
    table.sort(names); table.sort(subscriptions,function(a,b) return a.sequence<b.sequence end)
    for _,id in ipairs(names) do
      local receiver=candidates[id]; local distance
      if receiver.surface_index==r.surface_index then
        local a,b=r.body.position,receiver.body.position
        distance=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
      end
      for _,sub in ipairs(subscriptions) do
        if #plan>=limits.deliveries_per_transmit then errors.raise('E_LIMIT','modem handler delivery limit exceeded') end
        local event={name='modem_message',peripheral=id,wire=paths[id][1],wires=paths[id],
          channel=ch,replyChannel=reply,message=message,distance=distance,sent_tick=t}
        local item=assert(runtime.prepare_event(computer,sub.handler,event,t,spend))
        plan[#plan+1]={computer=computer,item=item}
      end
    end
  end
  if not errors.integer(root.next_sequence,1,9007199254740990-#plan) then errors.raise('E_CAPACITY','modem event sequence exhausted') end
  -- Cover every possible recipient retirement, cleanup hook and diagnostic log.
  -- No spend/copy/graph proof remains after this reservation.
  spend(#plan*(#root.order*16+common.subscriptions^2+common.console_entries^2+2048)+1)
  credits.total=credits.total+1; credits.computers[c.id]=(credits.computers[c.id] or 0)+1
  for _,delivery in ipairs(plan) do runtime.publish_event(delivery.computer,delivery.item,t) end
end
peripheral.register_type('radar',{methods=M.methods,callback_stable=true,available=function(rec,spend)
  radar.state(rec,spend); return radar.available(rec)
end})
return M
