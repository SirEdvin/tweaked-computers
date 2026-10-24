-- Capture only metadata and references to installed samples; never copy assets.
local L=require('scripts.speaker-limits')
local M={}
local function label(s) return type(s)=='string' and #s>0 end
local function dense(t)
  if type(t)~='table' then return false end
  local n=0
  for k in pairs(t) do
    n=n+1
    if type(k)~='number' or k%1~=0 or k<1 then return false end
  end
  if n==0 or n~=#t then return false end
  for i=1,n do if t[i]==nil then return false end end
  return true
end
function M.sound(source,name)
  local result
  if type(source)=='string' then result={filename=source}
  elseif type(source)=='table' then
    if source[1]~=nil then result={variations=table.deepcopy(source)}
    else result=table.deepcopy(source) end
  else error('invalid sample definition') end
  result.type='sound'; result.name=name; result.category='game-effect'; result.audible_distance_modifier=1
  return result
end
function M.generate(raw)
  local output={}; local header={version=1,instruments=0,instrument_cost=32,sound_count=0,sound_chunks=0}
  local function metadata(name,value) output[#output+1]={type='mod-data',name=name,data=value} end
  local body=raw['programmable-speaker'] and raw['programmable-speaker']['programmable-speaker']
  local instruments=body and body.instruments
  local index={}; local staged={}; local names={}
  local ok,e=pcall(function()
    if not dense(instruments) then error('malformed instrument inventory') end
    for i,instrument in ipairs(instruments) do
      if not label(instrument.name) or names[instrument.name] then error('invalid or duplicate instrument name') end
      names[instrument.name]=true
      if not dense(instrument.notes) then error('malformed note inventory') end
      local notes={}; local labels={}; local cost=320+#instrument.name
      for j,note in ipairs(instrument.notes) do
        if not label(note.name) or labels[note.name] then error('invalid or duplicate note name') end
        labels[note.name]=true
        local alias='tc-speaker-note-'..i..'-'..j
        if raw.sound and raw.sound[alias] then error('generated note alias conflicts with installed sound') end
        staged[#staged+1]=M.sound(note.sound,alias)
        notes[j]={name=note.name,path=alias,pitch=j-1}
        cost=cost+#note.name+#alias+96
      end
      staged[#staged+1]={type='mod-data',name='tc-speaker-instrument-'..i,data={version=1,name=instrument.name,notes=notes}}
      index[#index+1]={name=instrument.name,index=i,count=#notes,cost=cost}
      header.instrument_cost=header.instrument_cost+#instrument.name+96
    end
  end)
  if ok then
    table.sort(index,function(a,b) return a.name<b.name end)
    header.instruments=#index
    for _,p in ipairs(staged) do output[#output+1]=p end
    metadata('tc-speaker-instruments',{version=1,entries=index})
  else
    header.instrument_error=type(e)=='table' and e.code or 'E_UNSUPPORTED'
    header.instrument_message=(type(e)=='table' and e.message or tostring(e)):sub(1,256)
  end
  local paths={}
  local function add(path)
    if not label(path) then error('invalid native sound path') end
    paths[path]=true
  end
  -- Aliases are still staged, not in raw.sound. Do not hide another mod's
  -- unrelated named sound merely because it shares our namespace prefix.
  for name in pairs(raw.sound or {}) do add(name) end
  for name in pairs(raw['ambient-sound'] or {}) do add('ambient/'..name) end
  for _,utility in pairs(raw['utility-sounds'] or {}) do
    for field in pairs(utility) do if field~='name' and field~='type' then add('utility/'..field) end end
  end
  local families={entity={'build','mined','mining','rotated','open','close'},
    item={'open','close','pick','drop','move'},tile={'walking','mined','build-small','build-medium','build-large'}}
  for kind,records in pairs(raw) do
    local family=kind=='tile' and 'tile' or defines.prototypes.entity[kind]~=nil and 'entity'
      or defines.prototypes.item[kind]~=nil and 'item' or nil
    if family then
      -- Native path validation also accepts default/empty sound fields. Raw
      -- field presence is therefore not a complete path-existence oracle.
      for name in pairs(records) do
        for _,suffix in ipairs(families[family]) do add(family..'-'..suffix..'/'..name) end
      end
    end
  end
  do
    local sorted={}; for path in pairs(paths) do sorted[#sorted+1]=path end; table.sort(sorted)
    header.sound_count=#sorted; header.sound_chunks=math.ceil(#sorted/L.sound_chunk_size)
    for i=1,header.sound_chunks do
      local chunk={}; for j=(i-1)*L.sound_chunk_size+1,math.min(i*L.sound_chunk_size,#sorted) do chunk[#chunk+1]=sorted[j] end
      local cost=32; for _,path in ipairs(chunk) do cost=cost+#path+8 end
      metadata('tc-speaker-sound-index-'..i,{version=1,first=chunk[1],last=chunk[#chunk],count=#chunk,cost=cost})
      metadata('tc-speaker-sounds-'..i,{version=1,paths=chunk})
    end
  end
  metadata('tc-speaker-audio',header)
  return output
end
return M
