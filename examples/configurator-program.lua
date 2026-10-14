-- Native source document; executed by tests.configurator_engine.
return [[return {api_version=1,handlers={start=function(e)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  local devices=cfg.getDevices('green')
  for _,device in ipairs(devices) do
    if device.type=='inserter' then
      cfg.setConfiguration(device.id,{set={
        circuit_enable_disable=true,
        circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=4}
      }},'green')
      computer.setState('configured',device.id)
    end
  end
end}}]]
