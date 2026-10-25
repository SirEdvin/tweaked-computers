-- Native targets with a labelled host double for the pending shared guard API.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local targets=require('scripts.configuration.targets')
local adapters=require('scripts.configuration.adapters')
local sections=require('scripts.configuration.sections')
local validation=require('scripts.configuration.validation')
local catalog=require('scripts.configuration.catalog')
local service=require('scripts.services.configurator')
local snapshot_contract=require('tests.configurator_snapshot_contract')
local M={}; local loaded=false
local function nop() end
local function state() return storage.configurator_resource_fixture end
local function check(code,fn)
  local ok,e=pcall(fn)
  assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
end
local function report(name) state().groups=state().groups+1; log('TC_CONTRACT '..name) end
local function create(name,x,y)
  return assert(game.surfaces[1].create_entity{name=name,position={x,y},force='player'})
end
local function item(entity) return {id=targets.identity(entity),entity=entity} end
local function connector(entity,wire)
  return entity.get_wire_connector(defines.wire_connector_id['circuit_'..wire],true)
end
local function host_guard()
  return {
    job=function(name,initial)
      if not state().job then state().job=initial(); state().job_name=name end
      assert(state().job_name==name); return state().job
    end,
    suspend=function() error({code='TEST_SUSPEND'},0) end,
    -- This double tests call ordering, not the common lifetime/result ledger.
    commit_configuration=function(rec,plan,commit)
      assert(rec.id==state().cfg and plan.id==state().id)
      if state().refuse then error({code='E_CAPACITY'},0) end
      return commit(nop)
    end,
  }
end
local function call(name,...)
  return service.guarded_methods[name](nil,registry.record(state().cfg),'red',game.tick,nop,host_guard(),state().id,...)
end
local function fresh() state().job=nil; state().job_name=nil end
local function shared_join(cfg)
  local outside=create('constant-combinator',3,15)
  local shared=assert(outside.get_or_create_control_behavior().add_section('resource-join'))
  shared.set_slot(5,{value={type='item',name='iron-plate',quality='normal',comparator='='},min=3})
  local entity=create('constant-combinator',9,15)
  local cb=entity.get_or_create_control_behavior()
  if cb.sections_count==0 then assert(cb.add_section('')) end
  local target=item(entity)
  local before=sections.get(target,nop)
  local patch={set={group='resource-join'}}
  local plan=sections.prepare_set(target,cfg,1,patch,nop)
  shared.set_slot(5,{value={type='item',name='iron-plate',quality='normal',comparator='='},min=9})
  check('E_BUSY',function() sections.commit(target,cfg,plan,nop) end)
  assert(validation.equal(before,sections.get(target,nop)) and shared.get_slot(5).min==9)
  local added=sections.prepare_add(target,cfg,{group='resource-join'},nop)
  shared.set_slot(5,{value={type='item',name='iron-plate',quality='normal',comparator='='},min=11})
  check('E_BUSY',function() sections.commit(target,cfg,added,nop) end)
  assert(validation.equal(before,sections.get(target,nop)) and not cfg.configuration_recovery)
  local joined=sections.set(target,cfg,1,patch,nop)
  assert(joined.group=='resource-join' and joined.filters[1].index==5 and joined.filters[1].min==11)
  assert(shared.get_slot(5).min==11)
  sections.set(target,cfg,1,{set={group='',filters={}}},nop)
  state().join={entity=entity,outside=outside,shared_index=shared.index,before=sections.get(target,nop),
    set=sections.prepare_set(target,cfg,1,patch,nop),add=sections.prepare_add(target,cfg,{group='resource-join'},nop)}
  report('shared-group-join-revalidates-outside-filters-before-set-and-add')
end
local function resume_shared_join(cfg)
  local saved=state().join; local target=item(saved.entity)
  local shared=saved.outside.get_control_behavior().get_section(saved.shared_index)
  assert(validation.equal(saved.before,sections.get(target,nop)) and shared.get_slot(5).min==11)
  assert(saved.set.incoming[5].min==11 and saved.add.incoming[5].min==11)
  shared.filters={}
  for _,filter in ipairs(state().filters) do
    local native=validation.native(catalog.section_fields.filters.items,filter); native.index=nil
    shared.set_slot(filter.index,native)
  end
  check('E_BUSY',function() sections.commit(target,cfg,saved.set,nop) end)
  check('E_BUSY',function() sections.commit(target,cfg,saved.add,nop) end)
  assert(validation.equal(saved.before,sections.get(target,nop)))
  local plan=sections.prepare_set(target,cfg,1,{set={group='resource-join'}},nop)
  assert(#plan.incoming==129 and plan.work>saved.set.work,'incoming group payload was omitted from preparation')
  local result=sections.commit(target,cfg,plan,nop)
  assert(#result.filters==129 and result.filters[129].value.name==state().filters[129].value.name)
  local added=sections.add(target,cfg,{group='resource-join'},nop)
  assert(#sections.get(target,nop)[added].filters==129 and shared.filters_count==129)
  report('cold-shared-group-growth-refuses-stale-plans-and-fresh-129-filter-joins-succeed')
end
function M.run()
  registry.initialize(); game.forces.player.research_all_technologies()
  storage.configurator_resource_fixture={groups=0,phase='armed'}
  snapshot_contract.run(report)
  local cfg=assert(lifecycle.build(create(defs.devices.configurator.entity_name,0,0)))
  cfg.powered=true; lifecycle.power_entity(cfg).energy=defs.devices.configurator.watts/30
  state().cfg=cfg.id
  shared_join(cfg)
  local entity=create('constant-combinator',3,0); state().entity=entity; state().id=targets.identity(entity)
  local target=lifecycle.connector(cfg,'targets','green')
  assert(target.connect_to(connector(entity,'green')))
  local cb=entity.get_or_create_control_behavior()
  if cb.sections_count==0 then assert(cb.add_section('')) end
  local i=1
  local long=string.rep('group-',60)
  local added=sections.add(item(entity),cfg,{group=long},nop)
  assert(sections.get(item(entity),nop)[added].group==long)
  assert(sections.remove(item(entity),cfg,added,nop))
  assert(not catalog.section_fields.group.max_bytes and not catalog.section_fields.filters.max_items)
  assert(catalog.section_fields.filters.items.fields.index.max==65535)
  check('E_RANGE',function() sections.set(item(entity),cfg,i,{set={filters={{index=65536}}}},nop) end)
  assert(sections.set(item(entity),cfg,i,{set={multiplier=1e20}},nop).multiplier>9007199254740991)
  check('E_RANGE',function() sections.set(item(entity),cfg,i,{set={multiplier=1e40}},nop) end)
  sections.set(item(entity),cfg,i,{set={multiplier=1}},nop)
  report('native-long-group-string-uint16-slot-and-float32-domain')

  local names={}; for name in pairs(prototypes.item) do names[#names+1]=name end; table.sort(names)
  assert(#names>=129)
  local filters={}
  for n=1,129 do filters[n]={index=n,value={type='item',name=names[n],quality='normal',comparator='='},min=0} end
  local ok,result=pcall(sections.set,item(entity),cfg,i,{set={filters=filters}},nop)
  assert(ok,serpent.line(result))
  assert(#result.filters==129 and result.filters[129].index==129 and cb.get_section(i).get_slot(129).value.name==names[129])
  for n,filter in ipairs(result.filters) do
    assert(filter.index==n and filter.value.name==names[n] and filter.min==0)
    local location=prototypes.item[names[n]].default_import_location
    assert(filter.import_from==(location and location.name or nil),'item-specific import default was lost')
  end
  local before=sections.get(item(entity),nop)
  check('E_ARGUMENT',function() sections.set(item(entity),cfg,i,{set={filters={[1]=filters[1],[3]=filters[3]}}},nop) end)
  check('E_ARGUMENT',function() sections.set(item(entity),cfg,i,{set={filters={filters[1],filters[1]}}},nop) end)
  check('E_ARGUMENT',function() sections.set(item(entity),cfg,i,{set={active=false,unknown=true}},nop) end)
  check('E_RANGE',function() sections.set(item(entity),cfg,i,{set={active=false,
    filters={{index=1,value={type='item',name='tc-resource-missing-item'}}}}},nop) end)
  assert(validation.equal(before,sections.get(item(entity),nop)) and not cfg.configuration_recovery)
  state().filters=filters
  report('native-section-129-distinct-filters-and-complete-readback')

  local decider=create('decider-combinator',8,0)
  local parameters={conditions={},outputs={{signal={type='virtual',name='signal-B'},copy_count_from_input=false,constant=2}}}
  for n=1,129 do parameters.conditions[n]={first_signal={type='virtual',name='signal-A'},comparator='>',constant=n} end
  local result=adapters.apply(item(decider),cfg,{set={parameters=parameters}},nop)
  assert(#result.values.parameters.conditions==129 and result.values.parameters.conditions[129].constant==129)
  state().decider=decider; state().parameters=parameters
  report('native-decider-129-conditions-beyond-former-array-envelope')

  local cursor={}
  check('TEST_SUSPEND',function() adapters.prepare(item(decider),cfg,{clear={'parameters'}},function()
    if cursor.complete then error({code='TEST_SUSPEND'},0) end
  end,cursor) end)
  local prepared=adapters.prepare(item(decider),cfg,nil,nop,cursor)
  assert(prepared.changes.parameters.clear)
  report('prepared-clear-reentry-does-not-repeat-or-reject-paid-fields')

  local schema=catalog.schemas.LuaDeciderCombinatorControlBehavior.parameters
  local complete=validation.begin(schema,parameters,'parameters'); local work=0
  validation.resume(complete,function(n) work=work+n end)
  state().validation=validation.begin(schema,parameters,'parameters'); state().paid=0; state().expected_work=work
  local steps=0
  check('TEST_SUSPEND',function() validation.resume(state().validation,function(n)
    if steps==37 then error({code='TEST_SUSPEND'},0) end
    steps=steps+1; state().paid=state().paid+n
  end) end)
  assert(not state().validation.done)
  report('private-schema-validation-paid-cursor-before-cold-resume')

  local patch={set={active=false}}
  check('E_BUSY',function() service.guarded_methods.setSection(nil,cfg,'red',game.tick,nop,
    {job=function() error('unreserved mutation must not begin') end},state().id,i,patch,'green') end)
  check('TEST_SUSPEND',function() call('setSection',i,patch,'green') end)
  assert(state().job.phase=='commit' and cb.get_section(i).active)
  state().refuse=true
  check('E_CAPACITY',function() call('setSection',i,patch,'green') end)
  assert(cb.get_section(i).active and not cfg.configuration_recovery)
  state().refuse=nil
  cb.get_section(i).multiplier=2
  check('E_BUSY',function() call('setSection',i,patch,'green') end)
  assert(cb.get_section(i).active and cb.get_section(i).multiplier==2 and not cfg.configuration_recovery)
  fresh()
  check('TEST_SUSPEND',function() call('setSection',i,patch,'green') end)
  assert(target.disconnect_from(connector(entity,'green')))
  check('E_UNREACHABLE',function() call('setSection',i,patch,'green') end)
  assert(cb.get_section(i).active)
  assert(target.connect_to(connector(entity,'green')))
  fresh()
  report('staged-pre-effect-refusal-competing-writer-and-live-disconnection')

  local outside=create('constant-combinator',3,5)
  local shared=outside.get_or_create_control_behavior().add_section('resource-shared')
  shared.set_slot(1,{value={type='item',name='iron-plate',quality='normal',comparator='='},min=3})
  sections.set(item(entity),cfg,i,{set={group='resource-shared'}},nop)
  check('E_SHARED_SCOPE',function() sections.set(item(entity),cfg,i,{set={filters=filters}},nop) end)
  local detach={set={group=''}}
  check('TEST_SUSPEND',function() call('setSection',i,detach,'green') end)
  shared.set_slot(1,{value={type='item',name='iron-plate',quality='normal',comparator='='},min=9})
  check('E_BUSY',function() call('setSection',i,detach,'green') end)
  assert(cb.get_section(i).group=='resource-shared' and shared.get_slot(1).min==9)
  fresh()
  check('TEST_SUSPEND',function() call('setSection',i,detach,'green') end)
  local detached=call('setSection',i,detach,'green')
  assert(detached.group=='' and detached.filters[1].min==9 and shared.get_slot(1).min==9)
  fresh(); state().outside=outside
  report('paused-shared-detach-detects-outside-writer-without-stale-restoration')

  local plan=adapters.prepare(item(decider),cfg,{set={parameters=parameters}},nop)
  decider.get_control_behavior().parameters={conditions={{constant=7}},outputs={{signal={type='virtual',name='signal-B'}}}}
  local changed=adapters.snapshot(item(decider),nop)
  check('E_BUSY',function() adapters.commit(item(decider),cfg,plan,nop) end)
  assert(validation.equal(changed,adapters.snapshot(item(decider),nop)))
  check('E_UNREACHABLE',function() adapters.commit({id=plan.id,entity=decider,protected=true},cfg,plan,nop) end)
  report('prepared-root-patch-revalidates-native-state-and-protection')

  -- Synthetic retained records test former count eviction/refusal, not failures.
  cfg.configuration_recovery={}
  for n=1,257 do cfg.configuration_recovery['host-fixture-'..n]={reason='host fixture retained recovery',before={value=n}} end
  state().recovery=cfg.configuration_recovery
  check('TEST_SUSPEND',function() call('setSection',i,patch,'green') end)
  assert(call('setSection',i,patch,'green').active==false)
  assert(cfg.configuration_recovery==state().recovery and cfg.configuration_recovery['host-fixture-1'].before.value==1)
  fresh()
  report('257-labelled-recovery-records-preserved-without-count-eviction')

  state().inventory=service.inspect(cfg,game.tick,nop)
  assert(#state().inventory.groups==1 and state().inventory.groups[1].green==1)
  local spent=0
  check('E_BUSY',function() service.inspect(cfg,game.tick,function(n) spent=spent+n; if spent>48 then error({code='E_BUSY'},0) end end) end)
  report('inspector-complete-observation-or-error-never-partial-total')

  check('TEST_SUSPEND',function() call('setSection',i,{set={active=true}},'green') end)
  assert(state().job.phase=='commit' and not cb.get_section(i).active)
  state().before=sections.get(item(entity),nop)
  log('TC_CONTRACT_TOTAL '..state().groups)
end
function M.on_load()
  if state().phase=='frozen' then loaded=true; log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_tick()
  if state().phase=='done' then return end
  if state().phase=='frozen' then
    if not loaded then return end
    loaded=false
    local cfg=registry.record(state().cfg)
    assert(cfg.configuration_recovery==state().recovery and cfg.configuration_recovery['host-fixture-257'].before.value==257)
    resume_shared_join(cfg)
    assert(validation.equal(state().before,sections.get(item(state().entity),nop)))
    validation.resume(state().validation,function(n) state().paid=state().paid+n end)
    assert(state().validation.done and state().paid==state().expected_work)
    assert(call('setSection',1,{set={active=true}},'green').active)
    assert(validation.equal(state().inventory.groups,service.inspect(cfg,game.tick,nop).groups))
    assert(state().outside.get_control_behavior().get_section(2).get_slot(1).min==9)
    state().phase='done'; log('TC_COLD_OK'); return
  end
  state().phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
