local registry=require('scripts.registry')
local radar=require('scripts.radar')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
require('scripts.services.peripheral')
require('scripts.services.monitor')
require('scripts.services.kv')
require('scripts.device-art')
local M={}
function M.run()
  local root=registry.initialize()
  local records={}
  local surface=game.surfaces[1]
  local function body(name,x,y)
    return assert(surface.create_entity{name=name,position={x,y},force='player'})
  end
  for i=1,100 do
    local b=body('radar',i*4,0)
    records[i]=assert(radar.build(b)) -- Retained identities, not placement authority.
  end
  assert(#root.order==0,'dormant radars must have no recurring slots')
  assert(root.retained_count==100)
  records[1].modem={version=1,channels={[42]=true},count=1}
  local c=assert(lifecycle.build(body('tc-computer',0,8)))
  assert(#root.order==1 and root.order[1]==c.id and root.retained_count==101)
  local cap=limits.registry_entries; limits.registry_entries=root.retained_count
  local spare=body('radar',0,16)
  local refused,e=radar.build(spare); limits.registry_entries=cap
  assert(not refused and e.code=='E_CAPACITY' and spare.valid)
  assert(registry.remove(records[100].id) and root.retained_count==100)
  assert(not registry.remove(records[100].id) and root.retained_count==100)
  -- Migration is synchronized, not a gameplay cleanup cursor or on_load switch.
  local old_order={records[1].id,c.id}
  for i=2,99 do old_order[#old_order+1]=records[i].id end
  root.order=old_order; root.tracking_version=nil; root.retained_count=nil
  root.scheduler.cursor=80; root.scheduler.radar_cursor=99
  local ledger=root.ledger; ledger.tick=game.tick; ledger.total=123
  c.state.kept=true; local state=c.state; local modem=records[1].modem
  registry.initialize()
  assert(root.tracking_version==1 and root.retained_count==100)
  assert(#root.order==1 and root.order[1]==c.id and root.scheduler.cursor==1)
  assert(root.scheduler.radar_cursor==nil and root.ledger==ledger and ledger.total==123)
  assert(c.state==state and state.kept and records[1].modem==modem and modem.channels[42])
  local count=0; local original=registry.record
  registry.record=function(id)
    local rec=original(id)
    assert(not rec or rec.kind~='radar','recurring work visited a dormant radar')
    count=count+1; return rec
  end
  scheduler.tick(game.tick)
  registry.record=original
  assert(count>0 and records[1].modem==modem)
  assert(lifecycle.remove(c.id,'fixture',true))
  registry.record=function(id) error('zero-computer recurring identity visit: '..id) end
  scheduler.tick(game.tick+1)
  registry.record=original
  local order=root.order; root.tracking_version=99
  registry.initialize(); assert(not registry.supported(root) and root.order==order)
  scheduler.tick(game.tick+2)
  root.tracking_version=1
  log('TC_CONTRACT retained-radar-capacity-migration-and-zero-recurring-visits')
  log('TC_CONTRACT_TOTAL 1')
end
return M
