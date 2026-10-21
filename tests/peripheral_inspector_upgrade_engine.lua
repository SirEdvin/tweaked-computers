-- Injected only into the baseline's fixture allowlist; production code is the
-- pinned pre-inspector Git object. Candidate upgrade runs in a separate process.
local registry=require('scripts.registry')
local defs=require('scripts.device-definitions')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local kv=require('scripts.services.kv')
local monitor=require('scripts.services.monitor')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc_inspector_upgrade end
local program='return {api_version=1,handlers={start=function(e) computer.setState("boots",(computer.getState("boots") or 0)+1); local io=peripheral.find("logic_handler","red"); assert(io); io.setOutput({{signal={type="virtual",name="signal-A"},count=13}}) end}}'
function M.run()
  storage.tc_inspector_upgrade={records={},parts={},phase='boot'}
  local s=game.surfaces[1]
  for i,kind in ipairs(defs.order) do
    local r=assert(lifecycle.build(assert(s.create_entity{name=defs.devices[kind].entity_name,position={i*3,0},force='player'})))
    assert(r.layout_version==2 and not r.body.operable,'baseline must be the genuine pre-inspector shell implementation')
    f().records[kind]=r; f().parts[#f().parts+1]=r.body
    lifecycle.power_entity(r).energy=defs.devices[kind].watts/30
    lifecycle.power_entity(r).power_usage=0
    r.powered=true; r.power_checked_tick=game.tick
    for _,part in pairs(r.children) do f().parts[#f().parts+1]=part end
  end
  local c=f().records.computer; local io=f().records.logic
  for _,color in ipairs({'red','green'}) do
    local previous=c
    for _,kind in ipairs({'kv','monitor','logic','configurator','recipe_searcher'}) do
      local next_rec=f().records[kind]
      assert(lifecycle.connector(previous,'network',color).connect_to(lifecycle.connector(next_rec,'network',color)))
      previous=next_rec
    end
  end
  runtime.save(c.id,program,0); assert(runtime.activate(c.id,game.tick)); assert(scheduler.dispatch(c,game.tick))
  assert(c.state.boots==1 and io.output_bank[1].count==13)
  kv.methods.set(nil,f().records.kv,nil,game.tick,nop,'binary\0','retained\255')
  kv.methods.hset(nil,f().records.kv,nil,game.tick,nop,'hash','field','value')
  kv.methods.expire(nil,f().records.kv,nil,game.tick,nop,'binary\0',6000)
  for _=1,200 do monitor.reconcile(game.tick,nop) end
  local g=assert(monitor.resolve(f().records.monitor))
  f().group=g; f().model=g.model; f().database=f().records.kv.database
  f().bank=io.output_bank; f().owner=io.output_owner; f().state=c.state; f().active=c.active; f().run=c.run_id
  registry.get().player_drafts[1]={documents={[c.id]={source='dirty retained draft',base_source=program,base_revision=c.saved_revision}}}
  f().ledger=registry.get().scheduler; f().spent=f().ledger.maintenance_spent
  log('TC_CONTRACT pre-inspector-layout2-save-populated-identities-wires-data-owner-and-draft')
  log('TC_CONTRACT_TOTAL 1')
end
local function retained()
  local x=f(); local c=x.records.computer; local io=x.records.logic
  for _,part in ipairs(x.parts) do assert(part.valid and registry.by_entity(part),'existing physical objects must not be recreated') end
  for kind,r in pairs(x.records) do
    assert(registry.record(r.id)==r and r.layout_version==2)
    local cb=r.body.get_control_behavior(); assert(not cb.enabled and cb.sections_count==0)
    for _,role in ipairs(defs.devices[kind].roles) do for _,color in ipairs({'red','green'}) do assert(lifecycle.connector(r,role,color)) end end
  end
  assert(c.state==x.state and c.active==x.active and c.state.boots==1 and c.run_id==x.run)
  assert(io.output_owner==x.owner and io.output_bank==x.bank and x.bank[1].count==13)
  assert(x.records.kv.database==x.database and x.database.entries['binary\0'].value=='retained\255')
  assert(x.database.entries['binary\0'].deadline==360000)
  assert(monitor.resolve(x.records.monitor)==x.group and x.group.model==x.model)
  assert(registry.get().scheduler==x.ledger and x.ledger.maintenance_spent==x.spent)
  assert(registry.get().player_drafts[1].documents[c.id].source=='dirty retained draft')
end
function M.on_load() loaded=true; if f().phase=='frozen' then retained(); log('TC_INSPECTOR_UPGRADE_LOAD_UNCHANGED') end end
function M.on_configuration_changed()
  retained()
  for kind,r in pairs(f().records) do assert(r.body.operable==(kind~='computer')) end
  f().upgraded=true
end
function M.on_tick()
  local x=f(); if x.phase=='done' then return end
  if x.phase=='boot' then
    retained(); loaded=false; x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif loaded then
    retained(); x.phase='done'; log(x.upgraded and 'TC_UPGRADE_OK' or 'TC_COLD_OK')
  end
end
return M
