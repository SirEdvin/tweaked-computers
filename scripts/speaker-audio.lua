-- Prototype metadata is complete; native copy blocks are paid before .data.
local L=require('scripts.speaker-limits')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local MAX=9007199254740991
local function unsupported() errors.raise('E_UNSUPPORTED','speaker catalogue missing or incompatible') end
local function string_ok(s) return type(s)=='string' and #s>0 end
local function block(name,cost,spend)
  spend(cost)
  local p=prototypes.mod_data[name]
  if not p then unsupported() end
  local d=p.data
  if type(d)~='table' or d.version~=1 then unsupported() end
  return d
end
local function header(spend)
  local h=block('tc-speaker-audio',2048,spend)
  if not errors.integer(h.instruments,0,MAX) or not errors.integer(h.instrument_cost,32,MAX)
    or not errors.integer(h.sound_count,0,MAX) or not errors.integer(h.sound_chunks,0,MAX)
    or h.sound_chunks~=math.ceil(h.sound_count/L.sound_chunk_size) then unsupported() end
  return h
end
local function status(h,kind)
  local e=h[kind..'_error']
  if e then
    if e~='E_LIMIT' and e~='E_UNSUPPORTED' then unsupported() end
    errors.raise(e,'installed speaker '..kind..' catalogue unavailable')
  end
end
function M.index(spend)
  local h=header(spend); status(h,'instrument')
  local d=block('tc-speaker-instruments',h.instrument_cost,spend)
  local a=d.entries
  if type(a)~='table' or #a~=h.instruments then unsupported() end
  local previous; local ids={}; local count=0
  for k,v in pairs(a) do
    count=count+1
    if not errors.integer(k,1,h.instruments) or type(v)~='table' or not string_ok(v.name)
      or not errors.integer(v.index,1,h.instruments) or ids[v.index]
      or not errors.integer(v.count,1,MAX) or not errors.integer(v.cost,320,MAX) then unsupported() end
    ids[v.index]=true
  end
  if count~=h.instruments then unsupported() end
  for _,v in ipairs(a) do if previous and v.name<=previous then unsupported() end; previous=v.name end
  return a
end
function M.instrument(name,spend)
  local found
  for _,v in ipairs(M.index(spend)) do if v.name==name then found=v; break end end
  if not found then errors.raise('E_RANGE','unknown Factorio instrument','instrument') end
  local d=block('tc-speaker-instrument-'..found.index,found.cost,spend)
  if d.name~=name or type(d.notes)~='table' or #d.notes~=found.count then unsupported() end
  local count=0
  for k in pairs(d.notes) do count=count+1; if not errors.integer(k,1,found.count) then unsupported() end end
  if count~=found.count then unsupported() end
  local names={}
  for j,v in ipairs(d.notes) do
    if type(v)~='table' or not string_ok(v.name) or names[v.name] or v.pitch~=j-1
      or v.path~='tc-speaker-note-'..found.index..'-'..j then unsupported() end
    names[v.name]=true
  end
  return d.notes
end
local function chunk_index(i,h,spend)
  local b=block('tc-speaker-sound-index-'..i,640,spend)
  local want=math.min(L.sound_chunk_size,h.sound_count-(i-1)*L.sound_chunk_size)
  if b.count~=want or not string_ok(b.first) or not string_ok(b.last) or b.first>b.last
    or not errors.integer(b.cost,32+want*9,MAX) then unsupported() end
  return b
end
local function chunk(i,h,spend)
  local b=chunk_index(i,h,spend)
  -- The generator bounds each block and records its exact worst-case copy
  -- charge separately. Binary search never materializes the path blocks.
  local d=block('tc-speaker-sounds-'..i,b.cost,spend)
  local a=d.paths; local want=b.count
  if type(a)~='table' or #a~=want then unsupported() end
  local count=0; local previous
  for k in pairs(a) do count=count+1; if not errors.integer(k,1,want) then unsupported() end end
  if count~=want then unsupported() end
  local cost=32
  for _,s in ipairs(a) do
    if not string_ok(s) or previous and s<=previous then unsupported() end; previous=s
    cost=cost+#s+8
  end
  if a[1]~=b.first or a[#a]~=b.last or cost~=b.cost then unsupported() end
  return a
end
function M.valid(path,spend)
  spend(#path+16)
  local ok,value=pcall(helpers.is_valid_sound_path,path)
  if not ok then errors.raise('E_ENGINE','native sound validation failed') end
  return value
end
function M.sounds(prefix,after,spend,guard)
  -- Native copies and string scans cannot yield internally or fit a larger slice later.
  local atomic=guard and guard.atomic or spend
  local function initial() return {phase='header',result={sounds={}},bytes=512} end
  local job=guard and guard.job('speaker-sounds',initial) or initial()
  local function resize(bytes)
    if guard then guard.job_resize(bytes) end
    job.bytes=bytes
  end
  if job.phase=='header' then
    local h=header(atomic); status(h,'sound')
    job.header=h; job.low=1; job.high=h.sound_chunks
    job.page_size=limits.speaker_sound_page_size or 50; job.phase='search'
  end
  local h=job.header
  while job.phase=='search' and job.low<=job.high do
    local mid=math.floor((job.low+job.high)/2); local last=chunk_index(mid,h,atomic).last
    if last<=after or last<prefix then job.low=mid+1 else job.high=mid-1 end
  end
  if job.phase=='search' then job.index=job.low; job.offset=1; job.phase='scan' end
  while job.index<=h.sound_chunks do
    if not job.chunk then
      local b=chunk_index(job.index,h,atomic)
      -- Admit the native .data copy before retaining its current scan block.
      if guard then guard.job_resize(job.bytes+b.cost) end
      local a=chunk(job.index,h,atomic)
      if job.previous and a[1]<=job.previous then unsupported() end
      job.chunk=a; job.chunk_bytes=b.cost; job.bytes=job.bytes+b.cost
    end
    while job.offset<=#job.chunk do
      local path=job.chunk[job.offset]
      atomic(#prefix+#path+4)
      if path>after and path>=prefix then
        if path:sub(1,#prefix)~=prefix then return job.result end
        if M.valid(path,atomic) then
          if #job.result.sounds==job.page_size then
            job.result.next=job.result.sounds[#job.result.sounds]; return job.result
          end
          resize(job.bytes+#path+32)
          job.result.sounds[#job.result.sounds+1]=path
        end
      end
      job.offset=job.offset+1
    end
    local previous=job.chunk[#job.chunk]
    resize(job.bytes-job.chunk_bytes-(job.previous_bytes or 0)+#previous+8)
    job.previous=previous; job.previous_bytes=#previous+8; job.chunk=nil; job.chunk_bytes=nil
    job.index=job.index+1; job.offset=1
  end
  return job.result
end
return M
