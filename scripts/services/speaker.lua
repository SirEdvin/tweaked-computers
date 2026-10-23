-- Native positional submissions, with all work/result admission before audio.
local peripheral=require('scripts.services.peripheral')
local speaker=require('scripts.speaker')
local audio=require('scripts.speaker-audio')
local common=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={methods={}}
local function arity(n,min,max)
  if n<min or n>(max or min) then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
end
local function text(v,empty)
  if type(v)~='string' or not empty and #v==0 then errors.raise('E_ARGUMENT','sound/instrument string required') end
  return v
end
local function volume(v)
  if v==nil then return 1 end
  if type(v)~='number' or not errors.finite(v) then errors.raise('E_ARGUMENT','finite volume required') end
  if v<0 or v>1 then errors.raise('E_RANGE','volume must be from 0 to 1') end
  return v
end
function M.methods.getLimits(c,r,w,t,spend,guard,...)
  arity(select('#',...),0)
  local result={}; for k,v in pairs(common) do result[k]=v end
  result.speaker_sound_page_size=common.speaker_sound_page_size or 50
  return result
end
function M.methods.getInstruments(c,r,w,t,spend,guard,...)
  arity(select('#',...),0)
  local result={}; for _,v in ipairs(audio.index(spend)) do result[#result+1]=v.name end
  return result
end
function M.methods.getNotes(c,r,w,t,spend,guard,...)
  arity(select('#',...),1); local instrument=text(...)
  local result={}; for _,v in ipairs(audio.instrument(instrument,spend)) do result[#result+1]={name=v.name,pitch=v.pitch} end
  return result
end
function M.methods.getSounds(c,r,w,t,spend,guard,...)
  arity(select('#',...),0,2); local prefix,after=...
  return audio.sounds(prefix==nil and '' or text(prefix,true),after==nil and '' or text(after,true),spend,guard)
end
local function submit(c,r,w,spend,guard,path,vol)
  -- Admit both outcome fields before playback; native failure must not grow the job.
  local job=guard.job('speaker-submit',function() return {attempted=false,failed=false} end)
  if job.attempted then
    if job.failed then errors.raise('E_ENGINE','native sound submission failed; not retried') end
    return true
  end
  guard.prepare_boolean_result()
  spend(32)
  local current=peripheral.authority(c,r.id,w,spend)
  if current~=r then errors.raise('E_UNREACHABLE','speaker binding is no longer reachable') end
  if not speaker.available(r) then errors.raise('E_UNPOWERED','speaker is unavailable') end
  local request={path=path,position=r.body.position,volume_modifier=vol,override_sound_type='game-effect'}
  -- No yield or fallible result admission follows this irreversible boundary.
  job.attempted=true
  local ok=pcall(r.body.surface.play_sound,request)
  job.failed=not ok
  if not ok then errors.raise('E_ENGINE','native sound submission failed; not retried') end
  return true
end
function M.methods.playNote(c,r,w,t,spend,guard,...)
  arity(select('#',...),1,3); local instrument,vol,pitch=...
  text(instrument); vol=volume(vol); pitch=pitch==nil and 0 or pitch
  if type(pitch)~='number' or not errors.finite(pitch) then errors.raise('E_ARGUMENT','finite numeric pitch required') end
  local notes=audio.instrument(instrument,spend)
  if not errors.integer(pitch,0,#notes-1) then errors.raise('E_RANGE','pitch outside instrument note inventory') end
  local path=notes[pitch+1].path
  if not audio.valid(path,spend) then errors.raise('E_UNSUPPORTED','generated note alias unavailable') end
  return submit(c,r,w,spend,guard,path,vol)
end
function M.methods.playSound(c,r,w,t,spend,guard,...)
  arity(select('#',...),1,2); local path,vol=...
  text(path); vol=volume(vol)
  if not audio.valid(path,spend) then errors.raise('E_RANGE','invalid Factorio sound path') end
  return submit(c,r,w,spend,guard,path,vol)
end
peripheral.register_type('speaker',{methods=M.methods,with_guard=true,available=function(r) return speaker.available(r) end,callback_stable=true})
return M
