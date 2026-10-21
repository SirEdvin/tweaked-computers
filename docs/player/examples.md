# Complete runnable programs

Copy a whole code block into the [single-document editor](editor.md), Validate,
Save, then Run. These are the exact shipped source documents, with host wrappers
removed. There is no guest require/file import. Small fixtures are not unlimited
factory managers; keep the described topology. Runtime effects were exercised by
the implementation harness; documentation checks compile these blocks without
claiming graphical keyboard/focus/touch delivery.

## reference-speaker

The in-game Reference → Examples → One speaker note tutorial includes complete research, power, red-wire setup, execution steps and expected results. This is the same small program, not an external prerequisite.

```lua
function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect one speaker on red")
  local admitted = speaker.playNote("piano", 0.5, 0)
  print("Note submitted:", admitted)
end

```

## reference-recipe

The in-game Find iron plate recipes tutorial connects one powered Recipe Searcher on red and prints actual smelting matches. This supplementary copy uses the exact same source.

```lua
function start(event)
  local recipes = peripheral.find("recipe_searcher", "red")
  assert(recipes, "Connect one Recipe Searcher on red")
  local matches = recipes.findRecipes("item", "iron-plate", "smelting")
  print("Iron plate smelting recipes:", #matches)
  for _, recipe in ipairs(matches) do
    print(recipe.name)
  end
end

```

## reference-factory

The in-game Small factory dashboard tutorial includes the exact four-peripheral and chest/inserter setup, red discovery/INPUT and green TARGETS/OUTPUT separation. It teaches one inserter, a three-second KV hash and a two-line monitor; use its complete in-game setup.

```lua
function start(event)
  local cfg = peripheral.find("configurator", "red")
  assert(cfg, "Connect a Configurator on red")
  local target = nil
  for _, device in ipairs(cfg.getDevices("green")) do
    if device.type == "inserter" then
      assert(not target, "Use only one target inserter")
      target = device
    end
  end
  assert(target, "Connect an inserter on TARGETS green")
  cfg.setConfiguration(target.id, {set = {
    circuit_enable_disable = true,
    circuit_condition = {
      first_signal = {type = "virtual", name = "signal-A"},
      comparator = ">", constant = 0
    }
  }}, "green")
  computer.every(60, "update")
end

function update(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local screen = peripheral.find("monitor", "red")
  assert(io and db and screen, "Connect logic, database and monitor on red")
  local count = io.readSignal("red", {type = "item", name = "iron-plate"})
  local output = 0
  local status = "STOPPED"
  if count < 100 then
    output = 1
    status = "FILLING"
  end
  io.setOutput({{signal = {type = "virtual", name = "signal-A"}, count = output}})
  db.hset("stock:iron", "count", tostring(count), "status", status)
  db.expire("stock:iron", 3)
  screen.setCursorPos(1, 1)
  screen.write("Iron: " .. tostring(count) .. "    ")
  screen.setCursorPos(1, 2)
  screen.write(status .. "    ")
end

```

## reference-writer

Computer 1 of the self-contained Two-computer shared data tutorial. Run this writer on the shared red database before running shared-telemetry on computer 2 with the shared red and a different physical green database.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  assert(db, "Connect the shared database on red")
  db.hset("stock:iron", "count", "5", "status", "FILLING")
end

```

## speaker-alarm

Connect a powered vanilla programmable-speaker to a computer Network on red. Plays one positional effect every 120 ticks. False admission waits for the next timer, never a same-tick retry. Stop prevents future calls, not cancellation of an already submitted sample.

```lua
function start(event)
  computer.setState("accepted", false)
  computer.every(120, "alarm")
end

function alarm(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local accepted = speaker.playSound("utility/wire_connect_pole", 0.5)
  computer.setState("accepted", accepted)
  if not accepted then computer.log("Speaker busy; the next timer will retry") end
end
```

## speaker-melody

Connect a powered vanilla programmable-speaker on red. Discovers zero-based piano indices and requests one note every 30 ticks; advances only after admission. This is simulation scheduling, not sample-accurate sequencing. Disconnect/power errors fault the program; reconnect and Run again.

```lua
function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local notes = speaker.getNotes("piano")
  assert(#notes >= 3)
  computer.setState("speaker", peripheral.getName(speaker))
  computer.setState("pitches", {notes[1].pitch, notes[2].pitch, notes[3].pitch, notes[2].pitch})
  computer.setState("step", 1)
  computer.every(30, "note")
end

function note(event)
  local speaker = peripheral.wrap(computer.getState("speaker"), "red")
  assert(speaker, "Speaker disconnected; reconnect and Run again")
  local step = computer.getState("step")
  local pitches = computer.getState("pitches")
  if speaker.playNote("piano", 0.35, pitches[step]) then
    computer.setState("step", step % #pitches + 1)
  end
end
```

## speaker-catalogue

Connect a powered vanilla programmable-speaker on red. Fetches at most one page per callback and stores the last page and cumulative count as plain state. Completes without a busy loop. The bounded Console history is not a complete catalogue export; inspect last_page while paging or reuse the continuation pattern with your own storage.

```lua
function start(event)
  computer.setState("after", "")
  computer.setState("count", 0)
  computer.setState("complete", false)
  computer.after(1, "page")
end

function page(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local result = speaker.getSounds("", computer.getState("after"))
  computer.setState("last_page", result.sounds)
  computer.setState("count", computer.getState("count") + #result.sounds)
  computer.log("Sound paths discovered: " .. tostring(computer.getState("count")))
  if result.next then
    computer.setState("after", result.next)
    computer.after(1, "page")
  else
    computer.setState("complete", true)
  end
end
```

## modem-sender

Wire one powered computer to one native radar on red. Run modem-receiver on a different computer/radar on the same force and surface first. Sends on numeric channel 200 every 60 ticks and receives explicit replies on 201; these numbers are not wire colors.

```lua
function start(event)
  computer.setState("starts", (computer.getState("starts") or 0) + 1)
  local modem = peripheral.find("modem", "red")
  assert(modem, "Connect a powered radar on red")
  modem.open(201)
  computer.on("modem_message", "reply")
  computer.every(60, "send")
end

function send(event)
  local modem = peripheral.find("modem", "red")
  assert(modem)
  local sequence = (computer.getState("sent") or 0) + 1
  modem.transmit(200, 201, {sequence = sequence, text = "Hello, distant factory"})
  computer.setState("sent", sequence)
end

function reply(event)
  if event.channel == 201 then
    assert(event.sequence > (computer.getState("last_sequence") or 0))
    computer.setState("last_sequence", event.sequence)
    computer.setState("last_reply", event.message)
    computer.log("Reply received on channel 201")
  end
end
```

## modem-receiver

Wire a second powered computer to its own radar on red, without connecting the two discovery graphs. Start this receiver before modem-sender. Shares channel 200 on the physical radar, registers a named handler and replies explicitly; no ACK/retry guarantee or remote peripheral authority.

```lua
function start(event)
  computer.setState("starts", (computer.getState("starts") or 0) + 1)
  local modem = peripheral.find("modem", "red")
  assert(modem, "Connect a powered radar on red")
  modem.open(200)
  computer.on("modem_message", "receive")
end

function receive(event)
  if event.channel ~= 200 then return end
  assert(event.sequence > (computer.getState("last_sequence") or 0))
  computer.setState("last_sequence", event.sequence)
  computer.setState("last_message", event.message)
  computer.setState("received", (computer.getState("received") or 0) + 1)
  computer.log("Message received on channel 200")
  local modem = peripheral.wrap(event.peripheral, event.wire)
  if modem then
    modem.transmit(event.replyChannel, 200, {received = event.message})
  end
end
```

## function-program

Power a computer; no peripheral or wire is required. In an empty Editor draft, choose Insert starter (or paste this whole document), Validate, Save, then Run. Insertion and validation do not save or execute anything. The first dispatch calls `sample()` immediately and logs its returned count in Console; the `samples` value in explicit computer state increases once, then once more at the first 60-tick timer deadline. Private `increment` is declared before use and is not exported. `sample` is forward-visible and registration uses its string name, not its function value. Each callback has fresh locals/functions; reapplying keeps the explicit count, while ordinary reload does not replay `start`. These functions are not callable from the live Console. The legacy descriptor examples below remain supported.

```lua
local function increment(value)
  return value + 1
end

function start(event)
  local total = sample()
  print("Initial sample count:", total)
  computer.every(60, "sample")
end

function sample(event)
  local total = increment(computer.getState("samples") or 0)
  computer.setState("samples", total)
  return total
end
```

## recipe-searcher-program

Research Recipe Searcher separately, power it and connect its Network directly to a computer on red. Paste the whole document, Validate, Save and Run. Searches item/fluid products and refines E_LIMIT by exact category; a single category may still exceed 50 or other budgets.

```lua
return {
    api_version = 1,
    handlers = {
        start = function(event)
            local searcher = peripheral.find("recipe_searcher", "red")
            assert(searcher, "Connect a Recipe Searcher with a red Network wire")

            local limits = searcher.getLimits()
            assert(limits.recipe_search_results == 50)

            local ok, recipes = pcall(searcher.findRecipes, "item", "iron-plate")
            if not ok then
                if type(recipes) ~= "table" or recipes.code ~= "E_LIMIT" then
                    error(recipes)
                end
                recipes = searcher.findRecipes("item", "iron-plate", "smelting")
            end
            for _, recipe in ipairs(recipes) do
                computer.log(recipe.name .. " / " .. recipe.category
                    .. " / seconds=" .. tostring(recipe.energy)
                    .. " / enabled=" .. tostring(recipe.enabled))
            end

            local fluids = searcher.findRecipes("fluid", "petroleum-gas", "chemistry")
            computer.setState("recipe_count", #recipes)
            computer.setState("fluid_recipe_count", #fluids)
        end
    }
}
```

## peripheral-program

Wire a computer NETWORK to any device NETWORK on red. Inspect each color in Peripherals; read program output in Console.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.on('peripheral_attach', 'changed')
      computer.on('peripheral_detach', 'changed')
      for _, wire in ipairs({'red', 'green'}) do
        local names = peripheral.getNames(wire)
        computer.setState('names_' .. wire, names)
        for _, name in ipairs(names) do
          local info = peripheral.describe(name, wire)
          local device = peripheral.wrap(name, wire)
          if info and device then
            local capacities = device.getLimits()
            computer.log(wire .. ' / ' .. peripheral.getName(device) .. ' / ' .. info.type)
            assert(peripheral.getWire(device) == wire and type(capacities) == 'table')
          end
        end
      end
    end,
    changed = function(event)
      computer.log(event.name .. ' / ' .. event.wire .. ' / ' .. event.peripheral)
      local ok, names = pcall(peripheral.getNames, event.wire)
      if ok then computer.setState('names_' .. event.wire, names)
      else computer.log('Discovery unavailable; retry after the next topology event or timer.') end
    end
  }
}
```

## logic-controller

Follow [your first inserter controller](first-controller.md). Stock INPUT red, discovery NETWORK red, OUTPUT to the inserter.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.setState("starts", (computer.getState("starts") or 0) + 1)
      local io = peripheral.find("logic_handler", "red")
      assert(io, "Wire a logic NETWORK port to the computer on red")
      io.subscribe({input="red", signals={{type="item",name="iron-plate",quality="normal"}}, initial=true}, "changed")
      computer.log("Controller subscribed")
    end,
    changed = function(event)
      local io = peripheral.wrap(event.peripheral, event.wire)
      if not io then return end
      local stock = 0
      for _,entry in ipairs(event.current) do stock=entry.count end
      local enabled = 0
      if stock < 100 then enabled=1 end
      io.setOutput({{signal={type="virtual",name="signal-A",quality="normal"},count=enabled}})
      computer.setState("stock", stock)
      computer.setState("sample_tick", event.sample_tick)
      computer.setState("last_changes", event.changes)
      computer.setState("input_connected", event.connected)
      computer.setState("resync", event.resync)
    end
  }
}
```

## kv-program

Connect one powered database NETWORK on red. Save/Run; inspect the delayed status/TTL in Console.

```lua
return {
  api_version=1,
  handlers={
    start=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      db.hset('machine','status','ready','owner',computer.getID())
      db.expire('machine',30)
      computer.after(60,'inspect')
    end,
    inspect=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      local fields=db.hgetall('machine')
      computer.log(fields.status or 'expired')
      computer.log('TTL='..tostring(db.ttl('machine')))
    end
  }
}
```

## monitor-program

Connect a powered monitor NETWORK on red. Run, then activate a character cell; use matching adjacent tiles to test resize.

```lua
return {api_version=1,handlers={
  start=function(event)
    computer.on('monitor_touch','touched')
    computer.on('monitor_resize','resized')
    local m=peripheral.find('monitor','red')
    if m then
      m.setBackgroundColour(colors.black); m.setTextColour(colors.lime)
      m.clear(); m.setCursorPos(1,1); m.write('READY')
    end
  end,
  touched=function(event)
    local m=peripheral.wrap(event.peripheral,event.wire)
    if m then
      m.setCursorPos(1,1)
      m.write(tostring(event.x)..','..tostring(event.y))
    end
  end,
  resized=function(event)
    local m=peripheral.wrap(event.peripheral,event.wire)
    if m then m.setCursorPos(1,1); m.write('RESIZED') end
  end
}}
```

## monitor-plot-program

Connect up to four powered logical monitors on red/green. Uses one shared sine sample and replaces one complete row per screen, retaining older rows as a rolling trace. Startup discovery, geometry inspection, selection and clearing are deliberately sliced across callbacks. Checks at most eight names per color; red wins duplicate names. Resize/detach events restart discovery; unavailable screens are retried periodically. This is not a full-grid repaint or an unlimited factory/network benchmark.

```lua
return {api_version=1,handlers={
 start=function(e)
  computer.setState('plot_refresh',true)
  computer.setState('plot_sample',0)
  local limits=computer.getLimits()
  computer.setState('plot_member_limit',limits.sync_group_members)
  computer.setState('plot_cell_limit',limits.sync_group_cells)
  computer.every(10,'plot')
  computer.every(300,'refresh')
  computer.on('peripheral_attach','refresh')
  computer.on('peripheral_detach','refresh')
  computer.on('monitor_resize','refresh')
 end,
 refresh=function(e)
  local views=computer.getState('plot_views') or {}
  if e.name~='timer' or computer.getState('plot_missing') or #views==0 then computer.setState('plot_refresh',true) end
 end,
 plot=function(e)
  local stage=computer.getState('plot_stage')
  if computer.getState('plot_refresh') then
   computer.setState('plot_refresh',false)
   computer.setState('plot_views',{})
   computer.setState('plot_seen',{})
   computer.setState('plot_missing',false)
   computer.setState('plot_wire',1)
   stage='scan'
  end
  local views=computer.getState('plot_views') or {}
  if stage=='scan' then
   local wire=computer.getState('plot_wire')==1 and 'red' or 'green'
   local ok,names=pcall(peripheral.getNames,wire)
   if not ok then return end
   local candidates={}
   for i=1,math.min(#names,8) do candidates[i]={name=names[i],wire=wire} end
   computer.setState('plot_candidates',candidates)
   computer.setState('plot_index',1)
   stage='inspect'
  elseif stage=='inspect' then
   local candidates=computer.getState('plot_candidates')
   local index=computer.getState('plot_index')
   local ref=candidates[index]
   if ref then
    local seen=computer.getState('plot_seen')
    if not seen[ref.name] and #views<computer.getState('plot_member_limit') then
     local ok,w,h=pcall(function()
      if peripheral.getType(ref.name,ref.wire)~='monitor' then return end
      return peripheral.call(ref.name,ref.wire,'getSize')
     end)
     if not ok then computer.setState('plot_missing',true) end
     if ok and w then
      local cells=w*h
      for _,view in ipairs(views) do cells=cells+view.width*view.height end
      if cells<=computer.getState('plot_cell_limit') then
       views[#views+1]={name=ref.name,wire=ref.wire,width=w,height=h}
       seen[ref.name]=true; computer.setState('plot_seen',seen)
       computer.setState('plot_views',views)
      end
     end
    end
    computer.setState('plot_index',index+1)
   elseif computer.getState('plot_wire')==1 then
    computer.setState('plot_wire',2); stage='scan'
   else stage='select' end
  elseif stage=='select' then
   local refs={}
   for _,view in ipairs(views) do refs[#refs+1]={name=view.name,wire=view.wire} end
   local ok=pcall(peripheral.setMonitorSyncGroup,refs)
   if ok then computer.setState('plot_index',1); stage='clear'
   else computer.setState('plot_refresh',true) end
  elseif stage=='clear' then
   local index=computer.getState('plot_index'); local view=views[index]
   if view then
    local ok=pcall(peripheral.call,view.name,view.wire,'clear')
    if not ok then computer.setState('plot_refresh',true) end
    computer.setState('plot_index',index+1)
   else stage='draw' end
  elseif stage=='draw' then
   local sample=computer.getState('plot_sample')+1
   local value=math.sin(computer.getTick()/120)
   local ok=pcall(function()
    for _,view in ipairs(views) do
     local width,height=view.width,view.height
     local x=1+(sample-1)%width
     local y=1+math.floor((1-value)*(height-1)/2+0.5)
     local text=string.rep(' ',x-1)..'*'..string.rep(' ',width-x)
     peripheral.call(view.name,view.wire,'setCursorPos',1,y)
     peripheral.call(view.name,view.wire,'blit',text,string.rep('5',width),string.rep('f',width))
    end
   end)
   if ok then computer.setState('plot_sample',sample)
   else computer.setState('plot_refresh',true) end
  end
  computer.setState('plot_stage',stage)
 end
}}
```

## smooth-sine-chart

Connect up to four powered logical monitors on red/green. Draws a connected green line using 2×3 mosaic subpixels instead of text markers, with a gray axis. Samples one phase and updates all selected screens every two ticks, submitting only rows whose glyphs or colors changed. Uses scale 2 when a footprint axis exceeds three tiles, otherwise scale 1, and bounds grids to 32 columns / 22 rows. Ships with version 0.1.7 and its runtime/presenter optimizations; older published archives retain their original example. Paste the complete source, then Validate, Save and Run. Do not run other content writers on the same screens with this row-cached example. See the [subpixel design and verification boundaries](monitor-animation.md).

```lua
return {
    api_version = 1,
    handlers = {
        start = function()
            computer.deleteState("smooth_chart")
            computer.every(2, "plot")
        end,

        plot = function()
            local C, P, M, S = computer, peripheral, math, string
            local ok = pcall(function()
                local c = C.getState("smooth_chart") or { next = 0 }
                local tick = C.getTick()

                if tick >= c.next then
                    local refs = {}
                    for _, wire in ipairs({ "red", "green" }) do
                        local names = P.getNames(wire)
                        for i = 1, M.min(#names, 16) do
                            local name = names[i]
                            local info = P.describe(name, wire)
                            if #refs < 8 and info.type == "monitor" and info.powered then
                                local m = P.wrap(name, wire)
                                local scale = M.max(info.footprint.width, info.footprint.height) > 3 and 2 or 1
                                if m.getTextScale() ~= scale then
                                    m.setTextScale(scale)
                                end
                                refs[#refs + 1] = { name = name, wire = wire }
                            end
                        end
                    end

                    P.setMonitorSyncGroup(refs)
                    local views = P.getMonitorSyncGroup().members
                    for _, v in ipairs(views) do
                        for _, old in ipairs(c.views or {}) do
                            if v.name == old.name then
                                v.width = old.width;
                                v.height = old.height
                            end
                        end
                    end
                    c.views = views;
                    c.next = tick + 600
                end

                c.phase = tick / 120
                local previous = c.frames or {}
                local frames = {}
                for _, v in ipairs(c.views) do
                    local m = P.wrap(v.name, v.wire)
                    local w, h = m.getSize()
                    if w < 3 or h < 3 or w > 32 or h > 22 then
                        error("Resized")
                    end
                    if v.width ~= w or v.height ~= h then
                        m.setCursorBlink(false)
                    end
                    m.setCursorPos(1, 1)

                    local key = w .. "/" .. h
                    local old = v.width == w and v.height == h and previous[key]
                    local rows = frames[key]
                    if not rows then
                        rows = {}
                        local pw, ph = w * 2, (h - 1) * 3
                        local masks = {}
                        local previous_y

                        -- Join samples on a 2x3-subpixel grid, not with text markers.
                        -- Store only occupied cell masks, not a full pixel canvas.
                        for px = 0, pw - 1 do
                            local py = 1 + M.floor(
                                (1 - M.sin(c.phase + px * 6.283185307179586 / (pw - 1)))
                                    * (ph - 3) / 2 + 0.5
                            )
                            local from = previous_y or py
                            for sy = M.min(from, py), M.max(from, py) do
                                local cell = M.floor(sy / 3) * w + M.floor(px / 2) + 1
                                local bit = 2 ^ ((sy % 3) * 2 + px % 2)
                                local mask = masks[cell] or 0
                                if mask % (bit * 2) < bit then
                                    masks[cell] = mask + bit
                                end
                            end
                            previous_y = py
                        end

                        -- Pack text/foreground/background together so row-cache
                        -- comparisons include color inversions as well as glyphs.
                        rows[1] = S.sub(" SINE / LIVE" .. S.rep(" ", w), 1, w)
                            .. S.rep("0", w) .. S.rep("f", w)
                        local blank = S.rep(" ", w) .. S.rep("5", w) .. S.rep("f", w)
                        for y = 2, h do
                            rows[y] = blank
                        end
                        local middle = M.floor(ph / 2)
                        local axis = 3 * 2 ^ ((middle % 3) * 2)
                        local af, ab = "7", "f"
                        if axis >= 32 then
                            axis = 63 - axis
                            af, ab = ab, af
                        end
                        rows[M.floor(middle / 3) + 2] = S.rep(S.char(128 + axis), w)
                            .. S.rep(af, w) .. S.rep(ab, w)

                        -- Encode only occupied cells; never scan a dense pixel canvas.
                        for cell, mask in pairs(masks) do
                            local y = M.floor((cell - 1) / w) + 2
                            local x = (cell - 1) % w + 1
                            local fg, bg = "5", "f"
                            -- The sixth subpixel is always the background.
                            -- Complement the mask and swap colors when it is lit.
                            if mask >= 32 then
                                mask = 63 - mask
                                fg, bg = bg, fg
                            end
                            local glyph = mask == 0 and " " or S.char(128 + mask)
                            local row = rows[y]
                            rows[y] = S.sub(row, 1, x - 1) .. glyph
                                .. S.sub(row, x + 1, w + x - 1) .. fg
                                .. S.sub(row, w + x + 1, w * 2 + x - 1) .. bg
                                .. S.sub(row, w * 2 + x + 1)
                        end
                        frames[key] = rows
                    end

                    for y = 1, h do
                        if not old or rows[y] ~= old[y] then
                            m.setCursorPos(1, y)
                            m.blit(S.sub(rows[y], 1, w), S.sub(rows[y], w + 1, w * 2), S.sub(rows[y], w * 2 + 1))
                        end
                    end
                    v.width = w;
                    v.height = h
                    v.phase = c.phase
                end

                c.frames = frames
                C.setState("smooth_chart", c)
            end)

            if not ok then
                C.deleteState("smooth_chart")
            end
        end
    }
}
```

## configurator-program

Discovery NETWORK red; separate TARGETS green to one inserter. Sets A > 4, not A > 0. Supply an external A signal of at least 5 for motion.

```lua
return {api_version=1,handlers={start=function(e)
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
end}}
```

## configurator-sections

Discovery NETWORK red; TARGETS green to one constant combinator. Adds a section, activates it and saves its actual index in computer state; it intentionally writes no signal filters.

```lua
return {api_version=1,handlers={start=function(event)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  for _,device in ipairs(cfg.getDevices('green')) do
    if device.type=='constant-combinator' and device.configurable then
      local index=cfg.addSection(device.id,{active=false},'green')
      cfg.setSection(device.id,index,{set={active=true}},'green')
      computer.setState('section',index)
    end
  end
end}}
```

## factory-controller

Follow the complete [factory wiring tutorial](factory.md). Keep one device per type reachable. Paste this whole document.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local io = peripheral.find("logic_handler", "red")
      local db = peripheral.find("kv_database", "red")
      local monitor = peripheral.find("monitor", "red")
      local cfg = peripheral.find("configurator", "red")
      assert(io and db and monitor and cfg, "Connect all four peripherals")
      computer.setState("starts", (computer.getState("starts") or 0) + 1)
      if computer.getState("enabled") == nil then computer.setState("enabled", true) end
      local configured = 0
      for _, device in ipairs(cfg.getDevices("green")) do
        if device.type == "inserter" then
          local caps = cfg.getCapabilities(device.id, "green")
          local enable = caps.settings.circuit_enable_disable
          local condition = caps.settings.circuit_condition
          if enable and enable.writable and condition and condition.writable then
            cfg.setConfiguration(device.id, {set = {
              circuit_enable_disable = true,
              circuit_condition = {
                first_signal = {type = "virtual", name = "signal-A", quality = "normal"},
                comparator = ">", constant = 0
              }
            }}, "green")
            configured = configured + 1
          end
        end
      end
      assert(configured > 0, "Connect a configurable inserter to the target port")
      -- Full expansion capability readback and subscription admission share
      -- the callback ceiling; finish setup on the next real simulation tick.
      computer.after(1, "ready")
    end,
    ready = function(event)
      local io = peripheral.find("logic_handler", "red")
      local monitor = peripheral.find("monitor", "red")
      assert(io and monitor, "Required peripheral disconnected during setup")
      monitor.setTextScale(1)
      io.subscribe({input = "red", signals = {
        {type = "item", name = "iron-plate", quality = "normal"}
      }, initial = true}, "changed")
      computer.on("monitor_touch", "touched")
      computer.on("monitor_resize", "resized")
      computer.every(60, "refresh")
      computer.after(1, "refresh")
    end,
    changed = function(event)
      computer.after(1, "refresh")
    end,
    touched = function(event)
      local monitor = peripheral.find("monitor", "red")
      if monitor and event.peripheral == peripheral.getName(monitor) then
        computer.setState("enabled", not computer.getState("enabled"))
        computer.after(1, "refresh")
      end
    end,
    resized = function(event)
      computer.after(1, "refresh")
    end,
    refresh = function(event)
      local io = peripheral.find("logic_handler", "red")
      local db = peripheral.find("kv_database", "red")
      local monitor = peripheral.find("monitor", "red")
      assert(io and db and monitor, "Required peripheral disconnected")
      local count = io.readSignal("red", {type = "item", name = "iron-plate", quality = "normal"})
      local output = 0
      if computer.getState("enabled") and count < 100 then output = 1 end
      io.setOutput({{signal = {type = "virtual", name = "signal-A", quality = "normal"}, count = output}})
      local status = "STOPPED"
      if output == 1 then status = "FILLING" end
      db.hset("stock:iron", "count", tostring(count), "status", status,
        "sample_tick", tostring(computer.getTick()))
      db.expire("stock:iron", 3)
      monitor.setBackgroundColor(colors.black)
      monitor.setTextColor(colors.white)
      monitor.clear()
      monitor.setCursorPos(1, 1)
      monitor.write("Iron: " .. tostring(count))
      monitor.setCursorPos(1, 2)
      monitor.setTextColor(colors.lime)
      monitor.write(status)
      monitor.setCursorPos(1, 3)
      monitor.write("Touch to toggle")
    end
  }
}
```

## shared-telemetry

Use the [second-computer setup](factory.md#second-computer-shared-and-private-data): shared database on red, separate physical database on green.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local shared = peripheral.find("kv_database", "red")
      local independent = peripheral.find("kv_database", "green")
      assert(shared and independent, "Connect one database on each color")
      assert(peripheral.getName(shared) ~= peripheral.getName(independent), "Use two physical databases")
      shared.set("observer", computer.getID())
      independent.set("observer", "private")
      computer.every(60, "inspect")
    end,
    inspect = function(event)
      local shared = peripheral.find("kv_database", "red")
      local independent = peripheral.find("kv_database", "green")
      assert(shared and independent, "Database disconnected")
      local stock = shared.hgetall("stock:iron")
      computer.setState("shared_status", stock.status or "expired")
      computer.setState("shared_count", stock.count or "expired")
      computer.setState("private_status", independent.hget("stock:iron", "status") or "absent")
      computer.setState("observer", shared.get("observer"))
      computer.log((stock.status or "expired") .. " / private=" .. independent.get("observer"))
    end
  }
}
```
