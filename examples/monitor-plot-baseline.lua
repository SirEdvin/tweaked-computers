-- Exact historical four-row guest source; see the adjacent provenance record.
return [====[function start(event)
  computer.setState("plot_screen", 0)
  computer.deleteState("plot_job")
  computer.every(5, "plot")
end

function plot(event)
  local job = computer.getState("plot_job")
  if not job then
    local screens, seen = {}, {}
    for _, wire in ipairs({"red", "green"}) do
      pcall(function()
        for _, name in ipairs(peripheral.getNames(wire)) do
          if not seen[name] and peripheral.getType(name, wire) == "monitor" then
            seen[name] = true
            screens[#screens + 1] = {name = name, wire = wire}
          end
        end
      end)
    end
    if #screens == 0 then return end
    local index = (computer.getState("plot_screen") or 0) % #screens + 1
    computer.setState("plot_screen", index)
    job = {name = screens[index].name, wire = screens[index].wire,
      row = 1, phase = computer.getTick() / 120}
  end

  local ok = pcall(function()
    local m = peripheral.wrap(job.name, job.wire)
    if not m then computer.deleteState("plot_job"); return end
    if m.getTextScale() ~= 1 then
      m.setTextScale(1)
      job.row = 1
    end
    local width, height = m.getSize()
    if width < 3 or height < 3 then
      computer.deleteState("plot_job"); return
    end
    if job.width ~= width or job.height ~= height then
      job.row, job.width, job.height = 1, width, height
    end

    -- Fix the phase for a complete frame, including later row batches.
    local samples = {}
    for x = 2, width do
      -- Replace this expression to plot another function in [-1, 1].
      local value = math.sin(job.phase + (x - 2) * 0.25)
      samples[x] = 2 + math.floor((1 - value) * (height - 2) / 2 + 0.5)
    end

    local middle = 2 + math.floor((height - 2) / 2)
    local background = string.rep("f", width)
    local last = math.min(height, job.row + 3)
    for y = job.row, last do
      local text, foreground
      if y == 1 then
        local title = string.sub("y=sin(x+t)", 1, width)
        text = title .. string.rep(" ", width - #title)
        foreground = string.rep("0", width)
      else
        text = "|" .. string.rep(y == middle and "-" or " ", width - 1)
        foreground = string.rep("7", width)
        for x = 2, width do
          if samples[x] == y then
            text = string.sub(text, 1, x - 1) .. "*" .. string.sub(text, x + 1)
            foreground = string.sub(foreground, 1, x - 1) .. "5" .. string.sub(foreground, x + 1)
          end
        end
      end
      m.setCursorPos(1, y)
      m.blit(text, foreground, background)
    end

    job.row = last + 1
    if job.row > height then
      computer.deleteState("plot_job")
    else
      computer.setState("plot_job", job)
    end
  end)
  -- Ordinary disconnect/power errors skip this screen, not the whole program.
  if not ok then computer.deleteState("plot_job") end
end
]====]
