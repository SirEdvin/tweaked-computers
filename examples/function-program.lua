local function increment(value)
  return value + 1
end

function start(event)
  local total = sample()
  computer.log("Initial sample count: " .. tostring(total))
  computer.every(60, "sample")
end

function sample(event)
  local total = increment(computer.getState("samples") or 0)
  computer.setState("samples", total)
  return total
end
