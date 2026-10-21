-- Host dispatch/ledger boundary fixture. Stub sinks prove requests, NOT audibility
-- or physical authority; tests.speaker_engine and real clients cover those.
local registry=require('scripts.registry')
local speaker=require('scripts.services.speaker')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local catalogue_contract=require('tests.speaker_catalogue_contract')
local M={}
local function nop() end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
end
function M.run()
  registry.initialize()
  local requests={}; local groups=0
  local function report(s) groups=groups+1; log('TC_CONTRACT '..s) end
  local function record(id,fail)
    return {id=id,body={position={x=3,y=7},surface={play_sound=function(request)
      requests[#requests+1]=request
      assert(request.position.x==3 and request.position.y==7 and request.override_sound_type=='game-effect')
      assert(request.volume_modifier>=0 and request.volume_modifier<=1)
      if fail then error('fixture native failure') end
    end}}}
  end
  local function call(c,r,t,method,...) return speaker.methods[method]({id=c},r,'red',t,nop,...) end
  local a,b=record('speaker-a'),record('speaker-b')
  for _=1,8 do assert(call('computer-a',a,0,'playNote','piano',0,0)) end
  assert(call('computer-a',a,0,'playSound','utility/wire_connect_pole',0))
  local count=#requests
  assert(not call('computer-b',a,0,'playNote','piano',1,0))
  assert(not call('computer-b',a,0,'playSound','utility/wire_connect_pole',1))
  assert(#requests==count)
  for _=1,7 do assert(call('computer-a',b,0,'playNote','piano',1,0)) end
  assert(registry.get().speaker_audio.computers['computer-a']==16)
  assert(not call('computer-a',b,0,'playNote','piano',1,0))
  assert(call('computer-b',b,0,'playNote','piano',1,0))
  assert(call('computer-b',b,0,'playSound','utility/wire_connect_pole',1))
  report('separate-speaker-note-effect-shared-computer-and-zero-volume-quotas')
  local serial=0
  while registry.get().speaker_audio.total<64 do
    serial=serial+1; local r=record('speaker-world-'..serial)
    for _=1,8 do
      if registry.get().speaker_audio.total<64 then assert(call('computer-world-'..serial,r,0,'playNote','piano',1,0)) end
    end
  end
  local full=registry.get().speaker_audio; count=#requests
  assert(full.total==64 and count==64)
  assert(not call('fresh-computer',record('fresh-speaker'),0,'playSound','utility/wire_connect_pole',1))
  error_is('E_RANGE',function() call('fresh-computer',a,0,'playSound','invalid-path') end)
  error_is('E_RANGE',function() call('fresh-computer',a,0,'playNote','piano',2,0) end)
  assert(#requests==count and full.total==64)
  assert(call('computer-a',a,1,'playSound','utility/wire_connect_pole',0))
  assert(registry.get().speaker_audio.total==1 and registry.get().speaker_audio.tick==1)
  report('world-64-no-refused-prefix-validation-before-rate-and-genuine-clock-renewal')
  local failing=record('native-error',true)
  error_is('E_ENGINE',function() call('error-computer',failing,2,'playSound','utility/wire_connect_pole',0) end)
  assert(registry.get().speaker_audio.total==1)
  count=#requests
  assert(not call('error-computer',failing,2,'playSound','utility/wire_connect_pole',0))
  assert(#requests==count)
  report('native-error-retains-allowance-without-automatic-replay')
  local original=registry.get().speaker_audio
  registry.get().speaker_audio={version=999,tick=2}
  error_is('E_UNSUPPORTED',function() call('error-computer',a,3,'playSound','utility/wire_connect_pole',0) end)
  assert(registry.get().speaker_audio.version==999)
  registry.get().speaker_audio=original
  report('unknown-admission-state-is-inert-and-not-reset')
  for _,which in ipairs({'work','allocations'}) do
    local ctx=admission.context(admission.new(),'prepared-boolean-'..which,3)
    local g=sandbox.new(ctx,{}); local entered=0
    local fn=g.service(function()
      g.prepare_boolean_result(); entered=entered+1
      return call('prepared',record('prepared'),3,'playSound','utility/wire_connect_pole',0)
    end)
    if which=='work' then ctx.machine.work=limits.callback_work-5
    else ctx.machine.allocations=limits.callback_allocations-2 end
    count=#requests; assert(not pcall(g.call,fn)); assert(entered==0 and #requests==count)
  end
  report('insufficient-immediate-return-work-or-allocation-produces-zero-dispatches')
  catalogue_contract.run()
  report('bounded-catalogue-invalid-candidates-exact-full-pagination-and-failures')
  log('TC_CONTRACT_TOTAL '..groups)
end
return M
