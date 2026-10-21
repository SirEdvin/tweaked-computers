-- Bounded prototype-stage metadata. Charge complete native blocks before .data.
local L=require('scripts.speaker-limits')
local errors=require('scripts.runtime.errors')
local M={}
local function unsupported() errors.raise('E_UNSUPPORTED','speaker catalogue missing or incompatible') end
local function string_ok(s) return type(s)=='string' and #s>0 and #s<=L.speaker_path_bytes end
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
  if not errors.integer(h.instruments,0,L.speaker_instruments)
    or not errors.integer(h.sound_count,0,L.speaker_sound_catalog_entries)
    or not errors.integer(h.sound_chunks,0,math.ceil(L.speaker_sound_catalog_entries/L.speaker_sound_page_size))
    or h.sound_chunks~=math.ceil(h.sound_count/L.speaker_sound_page_size) then unsupported() end
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
  local d=block('tc-speaker-instruments',h.instruments*(L.speaker_path_bytes+64)+32,spend)
  local a=d.entries
  if type(a)~='table' or #a~=h.instruments then unsupported() end
  local previous; local ids={}; local count=0
  for k,v in pairs(a) do
    count=count+1
    if not errors.integer(k,1,h.instruments) or type(v)~='table' or not string_ok(v.name)
      or not errors.integer(v.index,1,h.instruments) or ids[v.index]
      or not errors.integer(v.count,1,L.speaker_notes_per_instrument) then unsupported() end
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
  local d=block('tc-speaker-instrument-'..found.index,found.count*(L.speaker_path_bytes+96)+320,spend)
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
  local want=math.min(L.speaker_sound_page_size,h.sound_count-(i-1)*L.speaker_sound_page_size)
  if b.count~=want or not string_ok(b.first) or not string_ok(b.last) or b.first>b.last
    or not errors.integer(b.cost,32+want*9,32+want*(L.speaker_path_bytes+8)) then unsupported() end
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
function M.sounds(prefix,after,spend)
  local h=header(spend); status(h,'sound')
  local low,high=1,h.sound_chunks
  -- Binary-search complete fixed-size chunks; no giant native block/cache.
  while low<=high do
    local mid=math.floor((low+high)/2); local last=chunk_index(mid,h,spend).last
    if last<=after or last<prefix then low=mid+1 else high=mid-1 end
  end
  local result={sounds={}}; local previous
  for i=low,h.sound_chunks do
    local a=chunk(i,h,spend)
    if previous and a[1]<=previous then unsupported() end
    previous=a[#a]
    for _,path in ipairs(a) do
      if path>after and path>=prefix then
        spend(#prefix+#path+4)
        if path:sub(1,#prefix)~=prefix then return result end
        if M.valid(path,spend) then
          if #result.sounds==L.speaker_sound_page_size then result.next=result.sounds[#result.sounds]; return result end
          result.sounds[#result.sounds+1]=path
        end
      end
    end
  end
  return result
end
return M
