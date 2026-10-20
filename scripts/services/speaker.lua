-- Synchronous positional submissions. No playback handles, queues or callbacks.
local registry=require('scripts.registry')
local peripheral=require('scripts.services.peripheral')
local speaker=require('scripts.speaker')
local audio=require('scripts.speaker-audio')
local L=require('scripts.speaker-limits')
local common=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={methods={}}
local function arity(n,min,max)
  if n<min or n>(max or min) then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
end
local function text(v,empty)
  if type(v)~='string' or not empty and #v==0 then errors.raise('E_ARGUMENT','sound/instrument string required') end
  if #v>L.speaker_path_bytes then errors.raise('E_LIMIT','speaker string exceeds limit') end
  return v
end
local function volume(v)
  if v==nil then return 1 end
  if type(v)~='number' or not errors.finite(v) then errors.raise('E_ARGUMENT','finite volume required') end
  if v<0 or v>1 then errors.raise('E_RANGE','volume must be from 0 to 1') end
  return v
end
function M.methods.getLimits(c,r,w,t,spend,...)
  arity(select('#',...),0)
  local result={}; for k,v in pairs(common) do result[k]=v end
  for k,v in pairs(L) do result[k]=v end
  return result
end
function M.methods.getInstruments(c,r,w,t,spend,...)
  arity(select('#',...),0)
  local result={}; for _,v in ipairs(audio.index(spend)) do result[#result+1]=v.name end
  return result
end
function M.methods.getNotes(c,r,w,t,spend,...)
  arity(select('#',...),1); local instrument=text(...)
  local result={}; for _,v in ipairs(audio.instrument(instrument,spend)) do result[#result+1]={name=v.name,pitch=v.pitch} end
  return result
end
function M.methods.getSounds(c,r,w,t,spend,...)
  arity(select('#',...),0,2); local prefix,after=...
  return audio.sounds(prefix==nil and '' or text(prefix,true),after==nil and '' or text(after,true),spend)
end
local function ledger(t,spend)
  spend((L.speaker_world_submissions_per_tick+1)*24)
  local root=registry.get(); local s=root.speaker_audio
  if s==nil then s={version=1,tick=t,total=0,computers={},speakers={}}; root.speaker_audio=s end
  if type(s)~='table' or getmetatable(s) or s.version~=1 or not errors.integer(s.tick,0,t)
    or not errors.integer(s.total,0,L.speaker_world_submissions_per_tick)
    or type(s.computers)~='table' or getmetatable(s.computers) or type(s.speakers)~='table' or getmetatable(s.speakers) then
    errors.raise('E_UNSUPPORTED','unsupported speaker admission state; retained')
  end
  local function identity(id) return type(id)=='string' and #id>0 and #id<=common.identifier_bytes end
  local count,sum=0,0
  for id,n in pairs(s.computers) do
    count=count+1
    if count>L.speaker_world_submissions_per_tick or not identity(id)
      or not errors.integer(n,1,L.speaker_computer_submissions_per_tick) then errors.raise('E_UNSUPPORTED','invalid computer audio credits; retained') end
    sum=sum+n
  end
  if sum~=s.total then errors.raise('E_UNSUPPORTED','invalid aggregate audio credits; retained') end
  count,sum=0,0
  for id,v in pairs(s.speakers) do
    count=count+1
    if count>L.speaker_world_submissions_per_tick or not identity(id) or type(v)~='table' or getmetatable(v)
      or not errors.integer(v.notes,0,L.speaker_notes_per_tick) or not errors.integer(v.sounds,0,L.speaker_sounds_per_tick)
      or v.notes+v.sounds==0 then errors.raise('E_UNSUPPORTED','invalid speaker audio credits; retained') end
    sum=sum+v.notes+v.sounds
  end
  if sum~=s.total then errors.raise('E_UNSUPPORTED','invalid speaker aggregate; retained') end
  if s.tick<t then s.tick=t; s.total=0; s.computers={}; s.speakers={} end
  return s
end
local function submit(c,r,t,spend,kind,path,vol)
  local s=ledger(t,spend); local local_count=s.speakers[r.id]
  local limit=kind=='notes' and L.speaker_notes_per_tick or L.speaker_sounds_per_tick
  if s.total>=L.speaker_world_submissions_per_tick
    or (s.computers[c.id] or 0)>=L.speaker_computer_submissions_per_tick
    or local_count and local_count[kind]>=limit then return false end
  -- No fallible work/return admission may follow this point. The service boundary
  -- reserved its boolean snapshot and immediate guarded-call return beforehand.
  spend(32)
  local request={path=path,position=r.body.position,volume_modifier=vol,override_sound_type='game-effect'}
  if not local_count then local_count={notes=0,sounds=0}; s.speakers[r.id]=local_count end
  s.total=s.total+1; s.computers[c.id]=(s.computers[c.id] or 0)+1; local_count[kind]=local_count[kind]+1
  local ok=pcall(r.body.surface.play_sound,request)
  if not ok then errors.raise('E_ENGINE','native sound submission failed; allowance retained') end
  return true
end
function M.methods.playNote(c,r,w,t,spend,...)
  arity(select('#',...),1,3); local instrument,vol,pitch=...
  text(instrument); vol=volume(vol); pitch=pitch==nil and 0 or pitch
  if type(pitch)~='number' or not errors.finite(pitch) then errors.raise('E_ARGUMENT','finite numeric pitch required') end
  local notes=audio.instrument(instrument,spend)
  if not errors.integer(pitch,0,#notes-1) then errors.raise('E_RANGE','pitch outside instrument note inventory') end
  local path=notes[pitch+1].path
  if not audio.valid(path,spend) then errors.raise('E_UNSUPPORTED','generated note alias unavailable') end
  return submit(c,r,t,spend,'notes',path,vol)
end
function M.methods.playSound(c,r,w,t,spend,...)
  arity(select('#',...),1,2); local path,vol=...
  text(path); vol=volume(vol)
  if not audio.valid(path,spend) then errors.raise('E_RANGE','invalid Factorio sound path') end
  return submit(c,r,t,spend,'sounds',path,vol)
end
peripheral.register_type('speaker',{methods=M.methods,available=function(r) return speaker.available(r) end,callback_stable=true})
return M
