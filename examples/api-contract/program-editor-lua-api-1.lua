function start(event)
  computer.log("Controller started")
  computer.on("peripheral_attach", "attached")
end

function attached(event)
  computer.log(event.peripheral .. " attached on " .. event.wire)
end
