-- Host-only physical graph policy. Native network IDs are never authority.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local errors=require('scripts.runtime.errors')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local M={}
function M.wire(wire)
  if wire~='red' and wire~='green' then errors.raise('E_ARGUMENT','explicit red or green wire required') end
  return wire
end
function M.same_scope(entity,origin)
  return entity and entity.valid and entity.type~='entity-ghost'
    and entity.force.index==origin.force_index and entity.surface.index==origin.surface_index
end
function M.discovery_vertex(connector,origin,wire)
  if not connector or not connector.valid or connector.is_ghost or not M.same_scope(connector.owner,origin) then return nil end
  local rec,role=registry.by_entity(connector.owner)
  if not rec then radar.pending(connector.owner); speaker.pending(connector.owner) end
  if not rec or (role~='network' and not (role=='body' and (rec.layout_version==2 or rec.native_carrier=='radar' or rec.native_carrier=='speaker')))
    or lifecycle.connector(rec,'network',wire)~=connector then return nil end
  return rec
end
-- The third argument is retained for host callers, not a cardinality ceiling.
function M.real_edges(connector,spend,remaining)
  if not connector or not connector.valid or connector.is_ghost then return {} end
  spend(connector.real_connection_count*4+4)
  return connector.real_connections
end
local function vertex(origin,wire,id)
  local rec=registry.record(id)
  local connector=rec and lifecycle.connector(rec,'network',wire)
  if M.discovery_vertex(connector,origin,wire)~=rec or not rec then return nil end
  return rec,connector
end
local function neighbor(connection,origin,wire)
  return connection.origin~=defines.wire_origin.radars and M.discovery_vertex(connection.target,origin,wire) or nil
end
local function reset(job,origin,wire,guard)
  local state={origin=origin.id,wire=wire,queue={origin.id},seen={[origin.id]=true},
    parents={},members={},graph={},cursor=1,cost=16,edge=1}
  -- The tenth root slot is the traversal edge cursor, absent between vertices.
  if guard then guard.job_admit(state,{{job,192+48*10}}) end
  for k in pairs(job) do job[k]=nil end
  for k,v in pairs(state) do job[k]=v end
  if guard then guard.job_release(state) end
end
-- One final live pass is prepaid before consulting native objects. Saved graph
-- preparation is never itself authority after a yield, reload or cable edit.
function M.validate_graph(origin,wire,job,spend)
  spend(job.cost)
  for _,id in ipairs(job.queue) do
    local rec,c=vertex(origin,wire,id); local saved=job.graph[id]
    if not rec or not saved or saved.generation~=rec.generation or saved.physical_count~=c.real_connection_count then return false end
    local found={}; local count=0
    for _,edge in ipairs(c.real_connections) do
      local other=neighbor(edge,origin,wire)
      if other and not found[other.id] then
        if not saved.neighbors[other.id] then return false end
        found[other.id]=true; count=count+1
      end
    end
    if count~=saved.count then return false end
  end
  return true
end
-- The optional job contains only IDs, scalars and tables; old host callers keep
-- the same return values. No member/prefix escapes before final revalidation.
function M.discover(origin,wire,spend,job,guard)
  M.wire(wire); spend=spend or function() end; job=job or {}
  if not job.queue then spend(16); reset(job,origin,wire,guard) end
  assert(job.origin==origin.id and job.wire==wire,'graph job binding mismatch')
  while job.cursor<=#job.queue do
    local id=job.queue[job.cursor]
    local rec,c=vertex(origin,wire,id)
    if not rec then reset(job,origin,wire,guard); errors.raise('E_NETWORK_PENDING','physical topology changed during traversal') end
    if not job.graph[id] then
      spend(8)
      local node={generation=rec.generation,neighbors={},count=0,physical_count=c.real_connection_count}
      if guard then
        local items={{job.graph,192+48*job.cursor}}
        if rec.kind~='computer' then
          items[#items+1]={job.members,192+48*(#job.members+1)}
          items[#items+1]={rec.id,#rec.id+32}
        end
        guard.job_admit(node,items)
      end
      job.graph[id]=node
      job.cost=job.cost+8+c.real_connection_count*4
      job.edge=1
      if rec.kind~='computer' then job.members[#job.members+1]=rec.id end
    end
    local connections=M.real_edges(c,spend)
    local saved=job.graph[id]
    while job.edge<=#connections do
      spend(4)
      local other=neighbor(connections[job.edge],origin,wire)
      if other then
        if guard and (not saved.neighbors[other.id] or not job.seen[other.id]) then
          local items={}
          if not saved.neighbors[other.id] then items[#items+1]={saved.neighbors,192+48*(saved.count+1)} end
          if not job.seen[other.id] then
            items[#items+1]={job.queue,192+48*(#job.queue+1)}
            items[#items+1]={job.seen,192+48*(#job.queue+1)}
            items[#items+1]={job.parents,192+48*#job.queue}
          end
          guard.job_admit(other.id,items)
        end
        if not saved.neighbors[other.id] then saved.neighbors[other.id]=true; saved.count=saved.count+1 end
        if not job.seen[other.id] then
          job.seen[other.id]=true; job.parents[other.id]=id; job.queue[#job.queue+1]=other.id
        end
      end
      job.edge=job.edge+1
    end
    job.cursor=job.cursor+1; job.edge=nil
  end
  if not M.validate_graph(origin,wire,job,spend) then
    reset(job,origin,wire,guard); errors.raise('E_NETWORK_PENDING','physical topology changed during traversal')
  end
  spend(#job.members+1)
  local members={}; for _,id in ipairs(job.members) do members[#members+1]=registry.record(id) end
  return members,job.parents
end
function M.witness(origin,member,parents,spend,job)
  job=job or {}; job.reversed=job.reversed or {}; job.seen=job.seen or {}
  if not job.started then job.id=member.id; job.started=true end
  while job.id do
    if spend then spend(4) end
    local id=job.id
    assert(not job.seen[id],'cyclic physical witness'); job.seen[id]=true
    job.reversed[#job.reversed+1]=id
    if id==origin.id then job.id=nil; break end
    job.id=parents[id]
  end
  assert(job.reversed[#job.reversed]==origin.id,'missing physical witness')
  job.path=job.path or {}; job.cursor=job.cursor or #job.reversed
  while job.cursor>0 do
    if spend then spend(2) end
    job.path[#job.path+1]=job.reversed[job.cursor]; job.cursor=job.cursor-1
  end
  return job.path
end
function M.validate_witness(origin,wire,path,spend)
  M.wire(wire)
  if type(path)~='table' or #path<1 or path[1]~=origin.id then return false end
  local cost=0
  for _,id in ipairs(path) do
    local _,c=vertex(origin,wire,id); if not c then return false end
    cost=cost+8+c.real_connection_count*4+4
  end
  spend(cost)
  local previous; local seen={}
  for _,id in ipairs(path) do
    if seen[id] then return false end; seen[id]=true
    local _,connector=vertex(origin,wire,id)
    if not connector then return false end
    if previous then
      local found=false
      for _,connection in ipairs(previous.real_connections) do
        if connection.origin~=defines.wire_origin.radars and connection.target==connector then found=true; break end
      end
      if not found then return false end
    end
    previous=connector
  end
  return true
end
return M
