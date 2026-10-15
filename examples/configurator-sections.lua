-- Native source document, exercised by tests.configurator_full_engine.
-- Wire computer NETWORK red -> configurator NETWORK red, and a constant
-- combinator to the configurator TARGETS green connector.
return [[return {api_version=1,handlers={start=function(event)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  for _,device in ipairs(cfg.getDevices('green')) do
    if device.type=='constant-combinator' then
      local index=cfg.addSection(device.id,{active=false},'green')
      cfg.setSection(device.id,index,{set={active=true}},'green')
      computer.setState('section',index)
    end
  end
end}}]]
