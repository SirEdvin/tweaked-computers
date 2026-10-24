-- Bounded plain-graph validation; cursor keys are data, never iterator closures.
local errors=require('scripts.runtime.errors')
local M={}
local state_fields={version=true,root=true,queue=true,head=true,seen=true,tuple_sum=true,tuple_count=true}
local job_fields={value=true,key=true,started=true}
local function refuse() errors.raise('E_UNSUPPORTED','non-data or malformed checkpoint; continuation retained') end
local function fields(value,allowed,spend)
  for key in pairs(value) do spend(1); if not allowed[key] then refuse() end end
end
local function push(state,value) state.queue[#state.queue+1]={value=value} end
function M.advance(checkpoint,executable,spend,owner,frame_bytes)
  local state=checkpoint.validation
  if state==nil then
    state={version=2,root=checkpoint,queue={},head=1,seen={}}
    if owner then state.tuple_sum=0; state.tuple_count=0 end
    push(state,checkpoint); checkpoint.validation=state
  end
  if type(state)~='table' or getmetatable(state) or state.version~=2 or state.root~=checkpoint
    or type(state.queue)~='table' or getmetatable(state.queue) or type(state.seen)~='table' or getmetatable(state.seen)
    or not errors.integer(state.head,1,#state.queue+1)
    or owner and (not errors.integer(state.tuple_sum,0,9007199254740991)
      or not errors.integer(state.tuple_count,0,executable.call_count)) then refuse() end
  fields(state,state_fields,spend)
  while state.queue[state.head] do
    local job=state.queue[state.head]
    if type(job)~='table' or getmetatable(job) then refuse() end
    fields(job,job_fields,spend); spend(1)
    if job.started~=nil and type(job.started)~='boolean' then refuse() end
    local value=job.value
    local kind=type(value)
    if kind~='table' and kind~='string' and kind~='number' and kind~='boolean' and kind~='nil' then refuse() end
    if job.key~=nil then
      local key_kind=type(job.key)
      if kind~='table' or not job.started or key_kind~='table' and key_kind~='string' and key_kind~='boolean' and key_kind~='number'
        or key_kind=='number' and job.key~=job.key then refuse() end
    end
    -- Strings are immutable scalars: type validation reads no character payload.
    local done=kind~='table'
    if not done then
      if getmetatable(value) then refuse() end
      if not job.started then
        if state.seen[value]~=nil and state.seen[value]~=true then refuse() end
        if state.seen[value] then done=true else state.seen[value]=true; job.started=true end
      end
      if not done then
        if job.key~=nil and rawget(value,job.key)==nil then refuse() end
        spend(2)
        -- Pinned Factorio next() is ordered, not an assumed Lua hash layout;
        -- the cold cursor fixture covers reference keys and >1024 indices.
        local key,child=next(value,job.key)
        if key==nil then done=true
        else
          if value==checkpoint.frame.locals and not errors.integer(key,1,executable.locals)
            or value==checkpoint.tuple_capacities and (not errors.integer(key,0,executable.slots)
              or not executable.calls[key] or not errors.integer(child,1,9007199254740991)
              or child>=checkpoint.tuple_control)
            or (value==checkpoint.frame.slots or value==checkpoint.frame.tuples)
              and not errors.integer(key,1,executable.slots) then refuse() end
          if value==checkpoint.frame.tuples and (type(child)~='table' or getmetatable(child)
            or not errors.integer(child.n,0,9007199254740991)) then refuse() end
          if value==checkpoint.tuple_capacities then
            local sum=state.tuple_sum+child-1
            if not errors.integer(sum,0,9007199254740991) then refuse() end
            state.tuple_sum=sum; state.tuple_count=state.tuple_count+1
          end
          job.key=key
          if value~=checkpoint or key~='validation' then push(state,key); push(state,child) end
        end
      end
    end
    if done then state.queue[state.head]=false; state.head=state.head+1 end
  end
  if owner then
    local node=owner.values[checkpoint]
    if state.tuple_count~=executable.call_count or not node
      or node.record.bytes~=frame_bytes+16*(state.tuple_sum+checkpoint.tuple_control-2) then refuse() end
  end
  checkpoint.validation=nil
end
return M
