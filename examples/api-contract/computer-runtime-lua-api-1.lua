function start(event)
  local boots = computer.getState("boots") or 0
  computer.setState("boots", boots + 1)
  computer.every(60, "sample")
end

function sample(event)
  computer.log("Sampling at tick " .. tostring(event.tick))
end
