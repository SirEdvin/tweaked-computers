local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local targets=require('scripts.configuration.targets')
local adapters=require('scripts.configuration.adapters')
local validation=require('scripts.configuration.validation')
local sections=require('scripts.configuration.sections')
local catalog=require('scripts.configuration.catalog')
local service=require('scripts.services.configurator')
local compiler=require('scripts.runtime.compiler')
local runtime=require('scripts.runtime.computer')
local admission=require('scripts.runtime.admission')
local section_example=require('examples.configurator-sections')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc11_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..serpent.line(e))
end
local function sorted(map) local a={}; for k in pairs(map) do a[#a+1]=k end; table.sort(a); return a end
local function build(kind,pos)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position=pos,force='player'})
  local rec=assert(lifecycle.build(b)); lifecycle.power_entity(rec).energy=defs.devices[kind].watts/30
  rec.powered=true; return rec
end
local signal={type='virtual',name='signal-A',quality='normal'}
local each={type='virtual',name='signal-each',quality='normal'}
local everything={type='virtual',name='signal-everything',quality='normal'}
local condition={comparator='>',first_signal=signal,constant=4}
local parameter_samples={
  ArithmeticCombinatorParameters={operation='+',first_signal=each,first_signal_networks={red=true,green=false},second_constant=2,output_signal=each},
  DeciderCombinatorParameters={conditions={{first_signal=each,constant=2,comparator='>=',compare_type='and',first_signal_networks={red=false,green=true}}},outputs={{signal=each,constant=5,copy_count_from_input=false,networks={red=true,green=false}}}},
  SelectorCombinatorParameters={operation='select',select_max=false,index_signal=signal},
  ProgrammableSpeakerCircuitParameters={instrument_id=0,note_id=0,signal_value_is_pitch=true,stop_playing_sounds=true},
}
local function sample(s)
  if s.kind=='boolean' then return true end
  if s.kind=='enum' then return s.values[1] end
  if s.concept=='SignalID' then return signal end
  if s.concept=='CircuitConditionDefinition' then return condition end
  if parameter_samples[s.concept] then return parameter_samples[s.concept] end
  if s.kind=='array' and s.items.concept=='DisplayPanelMessageDefinition' then return {{condition=condition,icon=signal,text='Factory ready'}} end
  error('unhandled field '..serpent.line(s))
end
function M.run()
  registry.initialize(); game.forces.player.research_all_technologies()
  storage.tc11_fixture={groups=0,phase='armed',entities={},exercised={},samples=0,gated={}}
  local cfg=build('configurator',{0,0}); f().cfg=cfg.id
  local pos=0
  for _,class in ipairs(sorted(catalog.fixtures)) do
    for _,name in ipairs(catalog.fixtures[class]) do
      if prototypes.entity[name] then
        pos=pos+1
        local e
        if name=='space-platform-hub' then
          local platform=assert(game.forces.player.create_space_platform{name='TC11',planet='nauvis',starter_pack='space-platform-starter-pack'})
          e=assert(platform.apply_starter_pack())
        else e=assert(game.surfaces[1].create_entity{name=name,position={pos*12,20},force='player'}) end
        local cb=assert(e.get_or_create_control_behavior())
        assert(cb.object_name==class,name..' class mismatch')
        local item={id=targets.identity(e),entity=e,connectors={}}
        f().exercised[class]=f().exercised[class] or {}
        adapters.capabilities(item,nop)
        for _,field in ipairs(sorted(catalog.schemas[class])) do
          local s=catalog.schemas[class][field]
          local restriction=adapters.unavailable(item,class,field)
          if restriction then
            local before=adapters.snapshot(item,nop)
            error_is('E_UNSUPPORTED',function() adapters.apply(item,cfg,{set={[field]=sample(s)}},nop) end)
            assert(validation.equal(before,adapters.snapshot(item,nop)))
            assert(not adapters.capabilities(item,nop).settings[field].writable)
          else
            local value=sample(s)
            log('TC11_WRITE '..name..'.'..field)
            local ok,result=pcall(adapters.apply,item,cfg,{set={[field]=value}},nop)
            if not ok then log('TC11_FAILURE '..serpent.line(result)..' CURRENT '..serpent.line(cb[field])..' EXPECT '..serpent.line(validation.normal(s,validation.native(s,value)))) end
            assert(ok,name..'.'..field..': '..serpent.line(result))
            assert(validation.equal(result.values[field],validation.normal(s,validation.native(s,value))),name..'.'..field)
            if s.kind=='boolean' then assert(adapters.apply(item,cfg,{set={[field]=false}},nop).values[field]==false) end
            if s.kind=='enum' then for _,v in ipairs(adapters.capabilities(item,nop).settings[field].values) do
              log('TC11_ENUM '..name..'.'..field..' '..v)
              local worked,result=pcall(adapters.apply,item,cfg,{set={[field]=v}},nop)
              assert(worked,serpent.line(result)); assert(result.values[field]==v)
            end end
            if s.clearable then
              local clearok,clearresult=pcall(adapters.apply,item,cfg,{clear={field}},nop)
              assert(clearok,name..'.'..field..' clear: '..serpent.line(clearresult))
              adapters.apply(item,cfg,{set={[field]=value}},nop)
            end
            f().exercised[class][field]=true; f().samples=f().samples+1
          end
        end
        f().entities[#f().entities+1]={entity=e,id=item.id,configuration=adapters.snapshot(item,nop)}
      else
        assert(class=='LuaAgriculturalTowerControlBehavior' or class=='LuaAsteroidCollectorControlBehavior' or class=='LuaSpacePlatformHubControlBehavior','unexpected missing prototype '..name)
        f().gated[class]=true
      end
    end
    if not f().gated[class] then report('native-family-'..class) end
  end
  for class,names in pairs(catalog.fixtures) do
    if not f().gated[class] then for field in pairs(catalog.schemas[class]) do
      assert(f().exercised[class][field] or (class=='LuaAsteroidCollectorControlBehavior' and field=='connect_to_logistic_network'),class..'.'..field..' not exercised')
    end end
  end
  log('TC11_FIELD_SAMPLES '..f().samples)
  -- Rich parameter variants, legal wildcards and complete-patch preflight.
  local function find(name)
    for _,r in ipairs(f().entities) do if r.entity.name==name then return {id=r.id,entity=r.entity} end end
  end
  local selector=find('selector-combinator')
  local speaker=find('programmable-speaker'); local speaker_before=adapters.snapshot(speaker,nop)
  error_is('E_RANGE',function() adapters.apply(speaker,cfg,{set={circuit_condition=condition,circuit_parameters={instrument_id=4294967295,note_id=0,signal_value_is_pitch=false,stop_playing_sounds=false}}},nop) end)
  assert(validation.equal(speaker_before,adapters.snapshot(speaker,nop)))
  if not script.feature_flags.space_travel then error_is('E_UNSUPPORTED',function() adapters.apply(find('cargo-landing-pad'),cfg,{set={circuit_exclusive_mode_of_operation='set_requests'}},nop) end) end
  local variants={
    {operation='count',count_signal=signal}, {operation='random',random_update_interval=60},
    {operation='stack-size'}, {operation='rocket-capacity'},
    {operation='quality-filter',quality_filter={quality='normal',comparator='>='}},
    {operation='quality-transfer',quality_destination_signal=signal,quality_source_static={name='normal'},select_quality_from_signal=false},
    {operation='quality-transfer',quality_destination_signal=signal,quality_source_signal={type='item',name='iron-plate'},select_quality_from_signal=true},
  }
  for _,p in ipairs(variants) do
    log('TC11_VARIANT '..serpent.line(p))
    local ok,e=pcall(adapters.apply,selector,cfg,{set={parameters=p}},nop); assert(ok,serpent.line(e))
  end
  local before=adapters.snapshot(selector,nop)
  error_is('E_ARGUMENT',function() adapters.apply(selector,cfg,{set={parameters={operation='count',random_update_interval=1}}},nop) end)
  error_is('E_ARGUMENT',function() adapters.apply(selector,cfg,{set={parameters={operation='quality-transfer'}}},nop) end)
  assert(validation.equal(before,adapters.snapshot(selector,nop)))
  local arithmetic=find('arithmetic-combinator')
  error_is('E_RANGE',function() adapters.apply(arithmetic,cfg,{set={parameters={second_signal=each}}},nop) end)
  error_is('E_ARGUMENT',function() adapters.apply(arithmetic,cfg,{set={parameters={first_signal=signal,output_signal=each}}},nop) end)
  local decider=find('decider-combinator')
  adapters.apply(decider,cfg,{set={parameters={conditions={{first_signal=everything,second_signal=signal}},outputs={{signal=everything}}}}},nop)
  adapters.apply(decider,cfg,{set={parameters={conditions={{first_signal=each,constant=0,comparator='>'}},outputs={{signal={type='virtual',name='signal-anything'}}}}}},nop)
  local quality=prototypes.quality.uncommon and 'uncommon' or 'normal'
  adapters.apply(arithmetic,cfg,{set={parameters={first_signal={type='item',name='iron-plate',quality=quality},second_constant=3,output_signal=signal}}},nop)
  assert(adapters.snapshot(arithmetic,nop).values.parameters.first_signal.quality==quality)
  report('parameter-variants-network-selection-quality-and-wildcard-preflight')
  -- Real constant-combinator sections; outside shared member is intentionally unwired.
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={3,0},force='player'})
  local item={id=targets.identity(entity),entity=entity}
  assert(lifecycle.connector(cfg,'targets','green').connect_to(entity.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
  local function call(name,...)
    return service.methods[name](nil,cfg,'red',game.tick,nop,item.id,...)
  end
  local filter={{index=4,value={type='item',name='iron-plate',quality=quality,comparator='='},min=7}}
  local i=call('addSection',{active=false,multiplier=2,filters=filter},'green')
  assert(i>=1 and call('getSections','green')[i].filters[1].index==4)
  assert(entity.get_control_behavior().get_section(i).get_slot(4).min==7)
  local other=assert(game.surfaces[1].create_entity{name='constant-combinator',position={3,5},force='player'})
  local shared=other.get_or_create_control_behavior().add_section('tc11-shared')
  shared.set_slot(4,{value={type='item',name='iron-plate',quality=quality,comparator='='},min=11})
  call('setSection',i,{set={group='tc11-shared'}},'green')
  local outside=serpent.line(shared.filters)
  error_is('E_SHARED_SCOPE',function() call('setSection',i,{set={filters=filter}},'green') end)
  error_is('E_SHARED_SCOPE',function() call('addSection',{group='tc11-shared',filters=filter},'green') end)
  local detached=call('setSection',i,{set={group=''}},'green')
  assert(detached.filters[1].min==11 and detached.filters[1].index==4 and serpent.line(shared.filters)==outside)
  call('setSection',i,{set={filters=filter,active=true,multiplier=3}},'green')
  assert(serpent.line(shared.filters)==outside and shared.group=='tc11-shared' and shared.multiplier==1 and shared.active)
  local detailed={{index=4,value={type='item',name='iron-plate',quality=quality,comparator='='},min=3,max=12,minimum_delivery_count=4,import_from='nauvis'}}
  local detail=call('setSection',i,{set={filters=detailed,multiplier=0.1}},'green')
  assert(detail.filters[1].max==12 and detail.filters[1].minimum_delivery_count==4 and detail.filters[1].import_from=='nauvis')
  call('setSection',i,{set={filters=filter}},'green')
  local j=call('addSection',{filters={{index=1,value='signal-B',min=0}}},'green')
  assert(call('removeSection',i,'green') and call('getSections','green')[j-1].filters[1].value.name=='signal-B')
  assert(not call('removeSection',999,'green'))
  local previous=call('getSections','green')
  error_is('E_ARGUMENT',function() call('setSection',j-1,{set={filters={filter[1],filter[1]}}},'green') end)
  error_is('E_RANGE',function() call('setSection',j-1,{set={filters={{index=129}}}},'green') end)
  assert(validation.equal(previous,call('getSections','green')))
  error_is('E_ARGUMENT',function() call('setSection',j-1,{set={filters={{index=1,value='signal-B'},{index=2,value={type='virtual',name='signal-B',quality='normal'}}}}},'green') end)
  error_is('E_ARGUMENT',function() call('setSection',j-1,{set={filters={{index=1,min=1,value={type='item',name='iron-plate',quality='normal',comparator='>'}}}}},'green') end)
  error_is('E_RANGE',function() call('setSection',j-1,{set={filters={{index=1,value={type='item',name='iron-plate',quality='no-such-quality'}}}}},'green') end)
  assert(validation.equal(previous,call('getSections','green')))
  error_is('E_BUSY',function() sections.set(item,cfg,j-1,{set={active=false}},function(n) if n>1024 then error({code='E_BUSY'},0) end end) end)
  assert(validation.equal(previous,call('getSections','green')))
  local cyclic={}; cyclic.set=cyclic
  error_is('E_ARGUMENT',function() call('setSection',j-1,cyclic,'green') end)
  report('native-sections-sparse-index-shift-groups-detach-and-atomic-refusals')
  -- A constant combinator cannot create nonmanual sections in the native API.
  -- Labelled host double tests protection, without pretending it is engine creation.
  local fake_section={index=1,type=defines.logistic_section_type.manual,is_manual=false,active=true,group='',multiplier=1,filters_count=0}
  local fake={id='tc11-protected-double',entity={type='constant-combinator',get_control_behavior=function() return {sections_count=1,get_section=function() return fake_section end} end}}
  error_is('E_READ_ONLY',function() sections.set(fake,cfg,1,{set={active=false}},nop) end)
  error_is('E_READ_ONLY',function() sections.remove(fake,cfg,1,nop) end)
  assert(fake_section.active)
  report('labelled-host-double-nonmanual-section-protection')
  local state={index=1,type=defines.logistic_section_type.manual,is_manual=true,active=true,group='',multiplier=1,filters_count=0,valid=true}
  local failure='once'
  local proxy=setmetatable({},{__index=state,__newindex=function(_,k,v)
    if k=='active' and failure then local mode=failure; if mode=='once' then failure=nil end; error('injected section setter failure') end
    state[k]=v
  end})
  local failing={id='tc11-recovery-double',entity={type='constant-combinator',get_control_behavior=function() return {sections_count=1,get_section=function() return proxy end} end}}
  local initial=sections.get(failing,nop)
  error_is('E_ENGINE',function() sections.set(failing,cfg,1,{set={active=false,multiplier=2}},nop) end)
  assert(validation.equal(initial,sections.get(failing,nop)) and not cfg.configuration_recovery)
  failure='always'
  error_is('E_ENGINE',function() sections.set(failing,cfg,1,{set={active=false,multiplier=2}},nop) end)
  f().recovery=assert(cfg.configuration_recovery[failing.id]); assert(f().recovery.before[1].active)
  error_is('E_ENGINE',function() sections.set(failing,cfg,1,{set={multiplier=4}},nop) end)
  report('labelled-section-setter-recovery-and-retained-fault')
  -- Real compiled caller, fixed registered methods and live target authority.
  local c=build('computer',{-3,0})
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(cfg,'network','red')))
  c.status='running'; c.run_id=c.id..'/fixture'
  local source=section_example
  local ctx=admission.context(admission.new(),c.id,game.tick); local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local ok,e=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(e)); assert(c.state.section)
  report('compiled-source-through-real-section-facade-and-target-wire')
  f().section_item=item; f().sections=sections.get(item,nop); f().other=other
  f().outside=sections.get({id=targets.identity(other),entity=other},nop)
  for _,r in ipairs(f().entities) do r.configuration=adapters.snapshot({id=r.id,entity=r.entity},nop) end
  log('TC_CONTRACT_TOTAL '..f().groups)
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then
    assert(f().section_item.entity.valid and f().section_item.entity==f().section_alias)
    assert(registry.record(f().cfg).configuration_recovery['tc11-recovery-double']==f().recovery)
    log('TC_COLD_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  if f().phase=='done' then return end
  if f().phase=='frozen' then
    if not loaded then return end
    loaded=false
    for _,r in ipairs(f().entities) do
      local s=adapters.snapshot({id=r.id,entity=r.entity},nop)
      assert(validation.equal(s.values,r.configuration.values) and validation.equal(s.unset,r.configuration.unset),r.entity.name..' cold configuration changed')
    end
    assert(validation.equal(sections.get(f().section_item,nop),f().sections))
    assert(registry.record(f().cfg).configuration_recovery['tc11-recovery-double']==f().recovery)
    assert(validation.equal(sections.get({id=targets.identity(f().other),entity=f().other},nop),f().outside))
    f().phase='done'; log('TC_COLD_OK'); return
  end
  loaded=false
  -- Freeze actual participants before requesting a durable snapshot.
  for _,r in ipairs(f().entities) do if r.entity.type~='space-platform-hub' then r.entity.disabled_by_script=true end end
  f().section_alias=f().section_item.entity
  f().phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
