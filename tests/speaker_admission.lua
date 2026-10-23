-- Explicit native sink/guard doubles; headless success is not audibility proof.
local registry=require('scripts.registry')
local speaker=require('scripts.services.speaker')
local carrier=require('scripts.speaker')
local peripheral=require('scripts.services.peripheral')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local harness=require('tests.radio_test_guard')
local catalogue_contract=require('tests.speaker_catalogue_contract')
local M={}
function M.run()
  registry.initialize()
  local requests={}; local current; local fail=false
  local record={id='speaker-fixture',body={position={x=3,y=7},surface={play_sound=function(request)
    requests[#requests+1]=request
    assert(request.position.x==3 and request.position.y==7 and request.override_sound_type=='game-effect')
    if fail then error('injected native failure') end
  end}}}
  local authority,available=peripheral.authority,carrier.available
  peripheral.authority=function() return record end; carrier.available=function() return true end
  local ok,problem=pcall(function()
    local function call(method,...)
      local guard=harness.new(current)
      return speaker.methods[method]({id='computer-fixture'},record,'red',game.tick,guard.spend,guard,...)
    end
    for _=1,65 do current={}; assert(call('playNote','piano',0,0)) end
    for _=1,17 do current={}; assert(call('playSound','utility/wire_connect_pole',0)) end
    assert(#requests==82)
    current={}; assert(call('playSound','utility/wire_connect_pole',0))
    assert(call('playSound','utility/wire_connect_pole',0) and #requests==83)
    log('TC_CONTRACT removed-speaker-computer-world-counts-and-attempted-call-idempotence')
    current={}; fail=true
    local success,e=pcall(call,'playSound','utility/wire_connect_pole',0)
    assert(not success and e.code=='E_ENGINE' and #requests==84)
    success,e=pcall(call,'playSound','utility/wire_connect_pole',0)
    assert(not success and e.code=='E_ENGINE' and #requests==84)
    fail=false
    log('TC_CONTRACT native-failure-is-not-replayed')
    for _,which in ipairs({'work','allocations'}) do
      local ctx=admission.context(admission.new(),'prepared-boolean-'..which,game.tick)
      local g=sandbox.new(ctx,{}); local entered=0
      local fn=g.service(function()
        g.prepare_boolean_result(); entered=entered+1; current={}
        return call('playSound','utility/wire_connect_pole',0)
      end)
      if which=='work' then ctx.machine.work=limits.callback_work-5
      else ctx.machine.allocations=limits.callback_allocations-2 end
      local before=#requests; assert(not pcall(g.call,fn)); assert(entered==0 and #requests==before)
    end
    log('TC_CONTRACT insufficient-prepaid-result-submits-nothing')
    catalogue_contract.run()
    log('TC_CONTRACT complete-configurable-pages-and-invalid-native-candidates')
    log('TC_CONTRACT_TOTAL 4')
  end)
  peripheral.authority,carrier.available=authority,available
  assert(ok,serpent.line(problem))
end
return M
