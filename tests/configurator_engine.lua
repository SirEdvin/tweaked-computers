local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local targets=require('scripts.configuration.targets')
local adapters=require('scripts.configuration.adapters')
local validation=require('scripts.configuration.validation')
local catalog=require('scripts.configuration.catalog')
local service=require('scripts.services.configurator')
local compiler=require('scripts.runtime.compiler')
local runtime=require('scripts.runtime.computer')
local admission=require('scripts.runtime.admission')
local example=require('examples.configurator-program')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc10_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..serpent.line(e))
end
local function build(kind,pos)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].name,position=pos,force='player'})
  lifecycle.on_built{entity=b}; b.energy=defs.devices[kind].watts/30
  local rec=assert(registry.by_entity(b)); rec.powered=true; return rec
end
local function create(name,pos,force)
  return assert(game.surfaces[1].create_entity{name=name,position=pos,force=force or 'player'})
end
local function connector(entity,wire,input)
  return assert(entity.get_wire_connector(defines.wire_connector_id[(input or 'circuit')..'_'..wire],true))
end
local signal={type='virtual',name='signal-A',quality='normal'}
local condition={comparator='>',first_signal=signal,constant=4}
function M.run()
  registry.initialize(); storage.tc10_fixture={groups=0,phase='armed'}
  local cfg=build('configurator',{0,0}); local c=build('computer',{-3,0})
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(cfg,'network','red')))
  local pole=create('small-electric-pole',{3,0}); local ins=create('inserter',{5,0}); local arithmetic=create('arithmetic-combinator',{3,3})
  assert(lifecycle.connector(cfg,'targets','green').connect_to(connector(pole,'green')))
  assert(connector(pole,'green').connect_to(connector(ins,'green')))
  assert(connector(pole,'green').connect_to(connector(arithmetic,'green','combinator_input')))
  local outside=create('steel-chest',{6,3}); assert(connector(arithmetic,'green','combinator_output').connect_to(connector(outside,'green')))
  local inv=targets.inventory(cfg,'green',nop); local id=targets.identity(ins)
  assert(inv[id] and inv[targets.identity(pole)] and inv[targets.identity(arithmetic)] and not inv[targets.identity(outside)])
  assert(next(targets.inventory(cfg,'red',nop))==nil)
  local description=service.describe(inv[id],'green',nop)
  assert(description.position.x==ins.position.x and description.position.y==ins.position.y and description.quality=='normal' and description.configurable)
  local unsupported=service.describe(inv[targets.identity(pole)],'green',nop); assert(not unsupported.configurable and unsupported.configuration.reason)
  report('real-pole-relay-isolated-combinator-colour-and-rich-descriptors')
  local foreign=create('steel-chest',{5,-3},game.create_force('tc10-other'))
  assert(connector(pole,'green').connect_to(connector(foreign,'green')))
  assert(not targets.inventory(cfg,'green',nop)[targets.identity(foreign)])
  local ghost=game.surfaces[1].create_entity{name='entity-ghost',inner_name='steel-chest',position={5,-5},force='player'}
  if ghost then assert(not targets.inventory(cfg,'green',nop)[targets.identity(ghost)]) end
  local helper=build('kv',{0,4})
  assert(connector(pole,'green').connect_to(lifecycle.connector(helper,'network','green')))
  local protected=targets.inventory(cfg,'green',nop)[targets.identity(helper.body)]
  assert(protected and protected.protected); assert(not service.describe(protected,'green',nop).configurable)
  error_is('E_READ_ONLY',function() adapters.apply(protected,cfg,{set={read_contents=true}},nop) end)
  report('foreign-force-ghost-exclusion-and-owned-helper-protection')
  local before=adapters.snapshot(inv[id],nop)
  error_is('E_RANGE',function() adapters.apply(inv[id],cfg,{set={circuit_enable_disable=true,circuit_condition={first_signal={type='item',name='not-a-real-item'}}}},nop) end)
  assert(validation.equal(before,adapters.snapshot(inv[id],nop)))
  error_is('E_READ_ONLY',function() adapters.apply(inv[id],cfg,{set={circuit_condition={fulfilled=true}}},nop) end)
  error_is('E_ARGUMENT',function() adapters.apply(inv[id],cfg,{set={circuit_condition=condition},clear={'circuit_condition'}},nop) end)
  error_is('E_ARGUMENT',function() adapters.apply(inv[id],cfg,{clear={'circuit_condition','circuit_condition'}},nop) end)
  local spent=0
  error_is('E_BUSY',function() adapters.apply(inv[id],cfg,{set={circuit_enable_disable=true}},function(n) spent=spent+n; if n>1024 then error({code='E_BUSY'},0) end end) end)
  assert(validation.equal(before,adapters.snapshot(inv[id],nop)))
  report('whole-patch-malformed-prototype-readonly-conflict-and-budget-atomicity')
  local after=adapters.apply(inv[id],cfg,{set={circuit_enable_disable=true,circuit_condition=condition,circuit_set_filters=true,circuit_read_hand_contents=true,circuit_hand_read_mode='hold',circuit_set_stack_size=true,circuit_stack_control_signal=signal}},nop)
  assert(after.values.circuit_enable_disable and after.values.circuit_condition.constant==4 and after.values.circuit_hand_read_mode=='hold')
  assert(ins.get_control_behavior().circuit_condition.first_signal.name=='signal-A')
  after=adapters.apply(inv[id],cfg,{set={circuit_enable_disable=false},clear={'circuit_condition','logistic_condition'}},nop)
  assert(after.values.circuit_enable_disable==false)
  assert(adapters.apply(inv[id],cfg,{clear={'circuit_stack_control_signal'}},nop).values.circuit_stack_control_signal==nil)
  for _,comparator in ipairs({'=','>','<','>=','<=','!=','≥','≤','≠'}) do
    local definition={comparator=comparator,first_signal={type='item',name='iron-plate'},constant=4}
    local actual=adapters.apply(inv[id],cfg,{set={circuit_condition=definition}},nop)
    assert(actual.values.circuit_condition.first_signal.type=='item' and actual.values.circuit_condition.first_signal.quality=='normal')
  end
  error_is('E_ARGUMENT',function() adapters.apply(inv[id],cfg,{set={circuit_condition={first_signal=signal,second_signal=signal,constant=1}}},nop) end)
  error_is('E_RANGE',function() adapters.apply(inv[id],cfg,{set={circuit_condition={first_signal={type='virtual',name='signal-each'}}}},nop) end)
  error_is('E_RANGE',function() adapters.apply(inv[id],cfg,{set={circuit_stack_control_signal={type='item',name='iron-plate',quality='unknown-quality'}}},nop) end)
  report('real-inserter-all-settings-condition-signal-enum-false-and-clear-readback')
  local fixtures={
    {'wooden-chest','LuaContainerControlBehavior'}, {'proxy-container','LuaProxyContainerControlBehavior'}, {'transport-belt','LuaTransportBeltControlBehavior'},
    {'pump','LuaPumpControlBehavior'}, {'loader','LuaLoaderControlBehavior'}, {'splitter','LuaSplitterControlBehavior'},
    {'accumulator','LuaAccumulatorControlBehavior'}, {'electric-mining-drill','LuaMiningDrillControlBehavior'},
    {'storage-tank','LuaStorageTankControlBehavior'}, {'stone-wall','LuaWallControlBehavior'}, {'power-switch','LuaGenericOnOffControlBehavior'}
  }
  local exercised={}; local samples=0
  for i,entry in ipairs(fixtures) do
    local entity=create(entry[1],{i*8,20}); local cb=entity.get_or_create_control_behavior()
    assert(cb and cb.object_name==entry[2],entry[1]..' class '..tostring(cb and cb.object_name))
    local item={id=targets.identity(entity),entity=entity,connectors={}}
    exercised[entry[2]]=exercised[entry[2]] or {}
    for name,schema in pairs(catalog.schemas[entry[2]]) do
      local value
      if schema.kind=='boolean' then value=true
      elseif schema.kind=='enum' then value=schema.values[1]
      elseif schema.concept=='SignalID' then value=signal
      elseif schema.concept=='CircuitConditionDefinition' then value=condition
      else error('unhandled basic fixture field '..name) end
      local result=adapters.apply(item,cfg,{set={[name]=value}},nop)
      assert(validation.equal(result.values[name],validation.normal(schema,validation.native(schema,value))),entry[1]..'.'..name)
      if schema.kind=='boolean' then assert(adapters.apply(item,cfg,{set={[name]=false}},nop).values[name]==false) end
      if schema.kind=='enum' then
        for _,enum in ipairs(schema.values) do assert(adapters.apply(item,cfg,{set={[name]=enum}},nop).values[name]==enum) end
      end
      if schema.clearable then adapters.apply(item,cfg,{clear={name}},nop) end
      exercised[entry[2]][name]=true; samples=samples+1
    end
  end
  f().exercised=exercised; f().basic_fields=samples; report('actual-native-basic-family-every-field-enum-and-boolean-readback-'..samples)
  -- Exact catalogue coverage is counted, not inferred from equal array lengths.
  local classes,fields,concepts,enums=0,0,0,0
  for _,schemas in pairs(catalog.schemas) do classes=classes+1; for _,s in pairs(schemas) do fields=fields+1; assert(s.kind and type(s.readable)=='boolean' and type(s.writable)=='boolean') end end
  for _ in pairs(catalog.concepts) do concepts=concepts+1 end; for _ in pairs(catalog.enum_values) do enums=enums+1 end
  assert(classes==36 and fields==164 and concepts==29 and enums==10)
  local caps=adapters.capabilities(inv[targets.identity(arithmetic)],nop); assert(not caps.settings.parameters.writable and caps.settings.parameters.unavailable_reason=='adapter_pending_tc11')
  local copied=adapters.capabilities(inv[id],nop); copied.settings.circuit_condition.fields.constant.min=999
  assert(adapters.capabilities(inv[id],nop).settings.circuit_condition.fields.constant.min==-2147483648)
  report('full-counted-catalogue-schema-copy-and-honest-pending-adapter-ledger')
  -- Host-only injected engine doubles: exercise narrow unexpected setter failures,
  -- not actual third-party callbacks or native GUI rendering.
  local values={object_name='LuaGenericOnOffControlBehavior',valid=true,circuit_enable_disable=false,connect_to_logistic_network=false}
  local failure='once'; local changes=0
  local fake=setmetatable({},{__index=values,__newindex=function(_,k,v)
    changes=changes+1
    if k=='circuit_enable_disable' and failure then
      local mode=failure; if mode=='once' then failure=nil end
      if mode=='ignore' then return end
      error('injected native setter failure')
    end
    values[k]=v
  end})
  local fake_item={id='fixture-failure',entity={valid=true,get_control_behavior=function() return fake end}}
  local initial=adapters.snapshot(fake_item,nop)
  error_is('E_ENGINE',function() adapters.apply(fake_item,cfg,{set={circuit_condition=condition,connect_to_logistic_network=true,circuit_enable_disable=true}},nop) end)
  assert(validation.equal(initial,adapters.snapshot(fake_item,nop)) and not cfg.configuration_recovery)
  failure='ignore'
  error_is('E_ENGINE',function() adapters.apply(fake_item,cfg,{set={circuit_condition=condition,circuit_enable_disable=true}},nop) end)
  assert(validation.equal(initial,adapters.snapshot(fake_item,nop)) and not cfg.configuration_recovery)
  failure='always'
  error_is('E_ENGINE',function() adapters.apply(fake_item,cfg,{set={circuit_condition=condition,connect_to_logistic_network=true,circuit_enable_disable=true}},nop) end)
  local recovery=cfg.configuration_recovery[fake_item.id]; assert(recovery and recovery.before.values.circuit_enable_disable==false)
  local count=changes; error_is('E_ENGINE',function() adapters.apply(fake_item,cfg,{set={connect_to_logistic_network=false}},nop) end); assert(changes==count)
  report('injected-setter-failure-restoration-and-retained-target-local-fault')
  -- Native compiler/service boundary, real separate target wire, actual setters.
  c.status='running'; c.run_id=c.id..'/fixture'
  local source=example
  local ctx=admission.context(admission.new(),c.id,game.tick); local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local ok,diagnostic=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(diagnostic)); assert(c.state.configured==id and ins.get_control_behavior().circuit_enable_disable)
  runtime.stop(c.id); assert(ins.get_control_behavior().circuit_enable_disable)
  local malicious={}; malicious.set=malicious
  error_is('E_ARGUMENT',function() adapters.apply(inv[id],cfg,malicious,nop) end)
  local caps_now=adapters.capabilities(inv[id],nop)
  assert(caps_now.observations.circuit_condition_fulfilled.writable==false)
  error_is('E_READ_ONLY',function() adapters.apply(inv[id],cfg,{set={disabled=true}},nop) end)
  report('compiled-native-program-through-actual-configurator-facade-and-setters')
  assert(connector(pole,'green').disconnect_from(connector(ins,'green')))
  assert(not targets.lookup(cfg,id,'green',nop,true))
  assert(select('#',service.methods.getDevice(c,cfg,'red',game.tick,nop,id,'green'))==1)
  assert(service.methods.getDevice(c,cfg,'red',game.tick,nop,id,'green')==nil)
  error_is('E_UNREACHABLE',function() targets.lookup(cfg,id,'green',nop) end)
  local position=ins.position; ins.destroy(); ins=create('inserter',position)
  assert(connector(pole,'green').connect_to(connector(ins,'green')))
  assert(targets.identity(ins)~=id and not targets.lookup(cfg,id,'green',nop,true))
  f().cfg=cfg.id; f().ins=ins; f().id=targets.identity(ins); f().recovery=recovery
  local newitem=targets.lookup(cfg,f().id,'green',nop)
  adapters.apply(newitem,cfg,{set={circuit_enable_disable=true,circuit_condition=condition}},nop)
  f().configuration=adapters.snapshot(newitem,nop)
  report('disconnection-and-same-coordinate-replacement-refuse-old-identity')
  -- One compact upper-envelope graph case; no combinatorial matrix.
  local big=build('configurator',{0,40}); local previous=lifecycle.connector(big,'targets','red')
  local chain={}
  for i=1,255 do
    local p=create('small-electric-pole',{i,40}); chain[#chain+1]=p
    local next_connector=connector(p,'red'); assert(previous.connect_to(next_connector)); previous=next_connector
  end
  local complete=targets.inventory(big,'red',nop); local count=0; for _ in pairs(complete) do count=count+1 end
  assert(count==255)
  local extra=create('small-electric-pole',{256,40}); assert(previous.connect_to(connector(extra,'red')))
  error_is('E_LIMIT',function() targets.inventory(big,'red',nop) end)
  extra.destroy(); for _,p in ipairs(chain) do p.destroy() end; lifecycle.remove(big.id,'fixture-cleanup',true)
  report('real-maximum-connector-inventory-and-complete-result-overflow-refusal')
  log('TC_CONTRACT_TOTAL '..f().groups)
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then
    local cfg=registry.record(f().cfg)
    assert(cfg.configuration_recovery['fixture-failure']==f().recovery and f().ins.valid)
    log('TC_COLD_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  if f().phase=='done' then return end
  if f().phase=='frozen' then
    if not loaded then return end
    loaded=false
    local cfg=registry.record(f().cfg); local item=targets.lookup(cfg,f().id,'green',nop)
    local actual=adapters.snapshot(item,nop)
    assert(item.entity==f().ins and validation.equal(actual.values,f().configuration.values) and validation.equal(actual.unset,f().configuration.unset))
    assert(cfg.configuration_recovery['fixture-failure']==f().recovery)
    assert(adapters.apply(item,cfg,{set={circuit_enable_disable=false}},nop).values.circuit_enable_disable==false)
    f().phase='done'; log('TC_COLD_OK'); return
  end
  loaded=false; f().phase='frozen'
  game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
