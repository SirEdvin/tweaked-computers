# Complete runnable programs

Copy a complete code block into the [single-document editor](editor.md).
Select Validate. Select Save. Select Run.
These are the exact supplied source documents without their host wrappers.
There is no guest require or file import. These small fixtures are not unlimited factory managers.
Keep the specified topology. The implementation harness tested runtime effects.
Documentation checks compile these blocks. They do not prove graphical keyboard, focus, or touch behavior.

## dashboard-program

Research Native circuit computers. Build a Dashboard and a computer. Neither device needs electricity. Connect Network red. Select Validate. Select Save. Select Run. Close the computer. Open the Dashboard normally. Left-click Acknowledge. The saved clicked handler changes the status from Ready to Acknowledged. A chart library is not necessary. Console cannot subscribe.

```lua
function start(event)
    local panel = peripheral.find("dashboard", "red")
    assert(panel, "Connect a Dashboard on red")
    panel.setTab(1, {
        title = "Overview",
        content = {type = "column", id = "root", children = {
            {type = "label", id = "status", text = "Ready"},
            {type = "button", id = "ack", text = "Acknowledge"}
        }}
    })
    panel.subscribe("clicked")
end

function clicked(event)
    local panel = peripheral.wrap(event.peripheral, event.wire)
    if event.tab == 1 and event.button == "ack" then
        panel.setText(1, "status", "Acknowledged")
    end
end
```

## dashboard-charts

Use the same Dashboard setup with red wiring and no electricity. Optionally enable unmodified factorio-charts 1.2.0 for rolling lines and duration bars in seconds. Without it, labels and buttons still work. Twelve startup samples wrap an eight-slot line before the window opens. Scroll Overview to see both charts. Switch among six tabs. Acknowledge a button. Live label updates keep the selected tab and unchanged identity selection. X positions use sample order, not wall time. This is not the native production widget.

```lua
function start()
  local p=peripheral.find('dashboard','red'); assert(p,'Connect a Dashboard on red')
  local available=false
  for _,name in ipairs(peripheral.getMethods(peripheral.getName(p),'red')) do if name=='appendSample' then available=true end end
  local children={{type='label',id='status',text='Ready — explicit samples, duration bars in seconds'},
    {type='button',id='ack',text='Acknowledge'},
    {type='label',id='heartbeat',text='Updates 0'}}
  if available then
    children[4]={type='line',id='trend',series={'input','output'},capacity=8,format='number'}
    children[5]={type='stacked_bars',id='durations',phases={'work','wait'}}
  end
  p.setTab(1,{title='Overview',content={type='column',id='root',children=children}})
  for slot=2,6 do p.setTab(slot,{title='Panel '..slot,content={type='column',id='root',children={
    {type='label',id='note',text='Independent viewer tab '..slot},
    {type='button',id='ack',text='Acknowledge'}}}}) end
  if available then
    for i=1,12 do p.appendSample(1,'trend',{input=i,output=i/2}) end
    p.setBars(1,'durations',{{work=1,wait=2},{work=3,wait=1},{work=2,wait=0}})
  end
  p.subscribe('clicked')
  computer.every(60,'refresh')
  computer.setState('boots',(computer.getState('boots') or 0)+1)
end

function refresh()
  local p=peripheral.find('dashboard','red')
  local n=(computer.getState('updates') or 0)+1
  computer.setState('updates',n)
  p.setText(1,'heartbeat','Updates '..n)
end

function clicked(event)
  local p=peripheral.wrap(event.peripheral,event.wire)
  local count=(computer.getState('clicks') or 0)+1
  computer.setState('clicks',count)
  p.setText(1,'status','Acknowledged '..count)
end
```

## production-statistics-program

Research Recipe Searcher. Craft a Production Statistics device. Connect Network red to the computer. Neither device needs electricity. Select Validate. Select Save. Select Run. The program logs local native item, fluid, and pollution totals and rates. It then logs the newest and oldest iron history for production and consumption. Empty input differs from an E_LIMIT refusal of the complete result. Host-work exhaustion remains fatal. This small Console example is not an unlimited export.

```lua
function start()
  local stats=peripheral.find("production_statistics","red")
  assert(stats,"Connect a Production Statistics device on red")
  local function report()
    for _,kind in ipairs({"item","fluid","pollution"}) do
      local totals=stats.getTotals(kind)
      local rates=stats.getRates(kind,"one_minute")
      local count=0
      if kind=="item" then
        for quality,items in pairs(totals.input) do
          for name,amount in pairs(items) do
            count=count+1
            computer.log(quality.." "..name.." produced="..tostring(amount).." /min="..tostring(rates.input[quality][name]))
          end
        end
      else
        for name,amount in pairs(totals.input) do
          count=count+1
          computer.log(kind.." "..name.." input="..tostring(amount).." /min="..tostring(rates.input[name]))
        end
      end
      if count==0 then computer.log(kind..": no recorded input") end
    end
    local h=stats.getHistory("item","iron-plate","one_minute")
    computer.log("Iron produced/min newest="..tostring(h.input[1]).." oldest="..tostring(h.input[300]))
    computer.log("Iron consumed/min newest="..tostring(h.output[1]).." oldest="..tostring(h.output[300]))
  end
  local ok,e=pcall(report)
  if not ok then
    if type(e)=="table" and e.code=="E_LIMIT" then computer.log("Complete statistics query exceeds shared Data limits")
    else error(e) end
  end
  computer.setState("statistics_example",true)
end
```

## production-statistics-monitor

Connect a Production Statistics device and monitor on red. Neither device needs electricity. Use a display with at least 14 columns and 7 rows. Select Validate. Select Save. Select Run. Wait 120 ticks. The display shows one-minute iron rates and both 300-sample native histories. The oldest sample is on the left. The newest sample is on the right. Both series use one peak scale. The program does not accumulate history. Query refused means E_LIMIT, not empty data. No activity means both native series are zero.

```lua
function start() computer.every(120,"draw") end

function draw()
  local stats=peripheral.find("production_statistics","red")
  local screen=peripheral.find("monitor","red")
  assert(stats and screen,"Connect statistics and monitor devices on red")
  local width,height=screen.getSize()
  assert(width>=14 and height>=7,"Use a monitor with at least 14 columns and 7 rows")
  local function draw()
    local rates=stats.getRates("item","one_minute")
    local h=stats.getHistory("item","iron-plate","one_minute")
    local input=rates.input.normal or {}
    local output=rates.output.normal or {}
    local peak=0
    for i=1,300 do peak=math.max(peak,h.input[i],h.output[i]) end
    local function trace(values)
      local chars=".:-=+*#@"
      local text=""
      for x=1,width do
        -- Native newest-first stays unchanged; only the display runs oldest left.
        local i=301-math.floor(1+(x-1)*299/(width-1))
        local level=peak>0 and math.floor(values[i]/peak*7) or 0
        text=text..string.sub(chars,level+1,level+1)
      end
      return text
    end
    screen.clear()
    screen.setCursorPos(1,1); screen.write("Iron /min 1m")
    screen.setCursorPos(1,2); screen.write("In "..tostring(input["iron-plate"] or 0))
    screen.setCursorPos(1,3); screen.write("Out "..tostring(output["iron-plate"] or 0))
    screen.setCursorPos(1,4); screen.write("older -> newer")
    screen.setCursorPos(1,5); screen.write(trace(h.input))
    screen.setCursorPos(1,6); screen.write(trace(h.output))
    screen.setCursorPos(1,7); screen.write(peak==0 and "No activity" or "Rows: in / out")
  end
  local ok,e=pcall(draw)
  if not ok then
    if type(e)=="table" and e.code=="E_LIMIT" then
      screen.clear(); screen.setCursorPos(1,1); screen.write("Query refused")
    else error(e) end
  end
  computer.setState("statistics_monitor",true)
end
```

## factoriopedia-program

Research Recipe Searcher. Craft a Factoriopedia Interface. It does not need electricity. Connect its Network to a computer on red. Paste the complete document. Select Validate. Select Save. Select Run. The program logs the item reference rocket capacity, water bounds, and both complete name lists, or E_LIMIT. These results do not prove that a current silo or tank can perform an operation.

```lua
function start(event)
  local encyclopedia = peripheral.find("factoriopedia_interface", "red")
  assert(encyclopedia, "Connect a Factoriopedia Interface on red")
  local item = encyclopedia.getItem("iron-plate")
  computer.log(item.name .. " stack size=" .. tostring(item.stack_size))
  if item.rocket_capacity ~= nil then
    computer.log("Reference items per rocket=" .. tostring(item.rocket_capacity))
  else
    computer.log("No finite mass-limited rocket count")
  end
  local fluid = encyclopedia.getFluid("water")
  computer.log(fluid.name .. " temperature=" .. tostring(fluid.default_temperature)
    .. ".." .. tostring(fluid.max_temperature) .. " C")
  local function reportNames(method, label)
    local ok, result = pcall(method)
    if ok then
      computer.log(label .. ": " .. tostring(#result))
    elseif type(result) == "table" and result.code == "E_LIMIT" then
      computer.log(label .. ": complete list exceeds shared Data limits")
    else
      error(result)
    end
  end
  reportNames(encyclopedia.listItems, "Installed item names")
  reportNames(encyclopedia.listFluids, "Installed fluid names")
  computer.setState("factoriopedia_example", true)
end
```

## reference-speaker

Open Reference → Examples → One speaker note in the game. The tutorial contains research, power, red-wire setup, execution procedures, and expected results. This is the same program. The in-game tutorial does not require this external copy.

```lua
function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect one speaker on red")
  local admitted = speaker.playNote("piano", 0.5, 0)
  print("Note submitted:", admitted)
end

```

## reference-recipe

The in-game Find iron plate recipes tutorial uses one Recipe Searcher connected on red. The device does not need electricity. The tutorial prints actual smelting matches. This additional copy uses exactly the same source.

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

Use the complete in-game Small factory dashboard setup. It specifies four peripherals, the chest and inserter, and separate wiring. Discovery and INPUT use red. TARGETS and OUTPUT use green. The tutorial controls one inserter, a KV hash with a three-second TTL, and two monitor rows.

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

This is computer 1 in the complete Two-computer shared data tutorial. Run this writer on the shared red database first. Then run shared-telemetry on computer 2. Computer 2 uses the shared red database and a different physical database on green.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  assert(db, "Connect the shared database on red")
  db.hset("stock:iron", "count", "5", "status", "FILLING")
end

```

## speaker-alarm

Connect a powered vanilla programmable-speaker to a computer Network on red. The program plays one positional effect every 120 ticks. After a false result, it waits for the next timer. It does not retry in the same tick. Stop prevents future calls. It cannot cancel a submitted sample.

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

Connect a powered vanilla programmable-speaker on red. The program finds zero-based piano indices and requests one note every 30 ticks. It advances only after the audio quota permits submission. This uses simulation scheduling, not audio-sample timing. A disconnection or power error faults the program. Reconnect the speaker. Select Run again.

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

Connect a powered vanilla programmable-speaker on red. The program gets at most one page per callback. It stores the last page and cumulative count as plain state. It completes without a busy loop. Console history has limits and is not a complete catalogue export. Examine last_page during paging, or use the continuation pattern with your own storage.

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

Connect one computer to one powered native radar with a red wire. First, run modem-receiver on a different computer and radar in the same force and surface. The sender transmits on numeric channel 200 every 60 ticks. It receives explicit replies on 201. These numbers are not wire colors.

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

Connect a second computer to its own powered native radar with a red wire. Do not connect the two discovery graphs. Start this receiver before modem-sender. It shares channel 200 on the physical radar, registers a named handler, and replies explicitly. It guarantees neither ACK nor retries. It gives no authority over remote peripherals.

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

Place a computer. Electricity, peripherals, and wires are not necessary. In an empty Editor draft, choose Insert starter or paste this complete document. Select Validate. Select Save. Select Run. Insertion and validation do not save or execute code. The first dispatch immediately calls `sample()` and logs its result in Console. The explicit `samples` state increases once. It increases again at the first 60-tick timer deadline. Private `increment` is declared before use and is not exported. `sample` is visible before its declaration. Registration uses its string name, not its function value. Each callback has new locals and functions. Apply keeps the explicit count. An ordinary reload does not replay `start`. The live Console cannot call these functions.

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

Research Recipe Searcher separately. Connect its Network directly to a computer on red. Neither device needs electricity. Paste the complete document. Select Validate. Select Save. Select Run. The program searches item and fluid products. After E_LIMIT, it restricts the search to an exact category. One category can still exceed 50 results or other budgets.

```lua
function start(event)
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
```

## peripheral-program

Connect a computer NETWORK to a device NETWORK with a red wire. Examine each color in Peripherals. Read program output in Console.

```lua
function start(event)
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
end

function changed(event)
  computer.log(event.name .. ' / ' .. event.wire .. ' / ' .. event.peripheral)
  local ok, names = pcall(peripheral.getNames, event.wire)
  if ok then computer.setState('names_' .. event.wire, names)
  else computer.log('Discovery unavailable; retry after the next topology event or timer.') end
end
```

## logic-controller

Follow [your first inserter controller](first-controller.md). Stock uses INPUT red. Discovery uses NETWORK red. OUTPUT connects to the inserter.

```lua
function start(event)
  computer.setState("starts", (computer.getState("starts") or 0) + 1)
  local io = peripheral.find("logic_handler", "red")
  assert(io, "Wire a logic NETWORK port to the computer on red")
  io.subscribe({input="red", signals={{type="item",name="iron-plate",quality="normal"}}, initial=true}, "changed")
  computer.log("Controller subscribed")
end

function changed(event)
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
```

## kv-program

Connect one database NETWORK on red. The database does not need electricity. Select Save. Select Run. Examine the delayed status and TTL in Console.

```lua
function start(event)
  local db=peripheral.find('kv_database','red')
  if not db then return end
  db.hset('machine','status','ready','owner',computer.getID())
  db.expire('machine',30)
  computer.after(60,'inspect')
end

function inspect(event)
  local db=peripheral.find('kv_database','red')
  if not db then return end
  local fields=db.hgetall('machine')
  computer.log(fields.status or 'expired')
  computer.log('TTL='..tostring(db.ttl('machine')))
end
```

## monitor-program

Connect a monitor NETWORK on red. The monitor does not need electricity. Select Run. Activate a character cell. Use matching adjacent tiles to test resize.

```lua
function start(event)
  computer.on('monitor_touch','touched')
  computer.on('monitor_resize','resized')
  local m=peripheral.find('monitor','red')
  if m then
    m.setBackgroundColour(colors.black); m.setTextColour(colors.lime)
    m.clear(); m.setCursorPos(1,1); m.write('READY')
  end
end

function touched(event)
  local m=peripheral.wrap(event.peripheral,event.wire)
  if m then
    m.setCursorPos(1,1)
    m.write(tostring(event.x)..','..tostring(event.y))
  end
end

function resized(event)
  local m=peripheral.wrap(event.peripheral,event.wire)
  if m then m.setCursorPos(1,1); m.write('RESIZED') end
end
```

## monitor-plot-program

Connect at most four logical monitors on red or green. They do not need electricity. The program uses one shared sine sample and replaces one complete row per screen. It keeps older rows as a rolling trace. Startup discovery, geometry checks, selection, and clearing use separate callbacks. It checks at most eight names per color. Red has priority for duplicate names. Resize or detach events restart discovery. It periodically retries unavailable screens. This is not a complete-grid repaint or an unlimited factory or network benchmark.

```lua
function start(e)
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
end

function refresh(e)
 local views=computer.getState('plot_views') or {}
 if e.name~='timer' or computer.getState('plot_missing') or #views==0 then computer.setState('plot_refresh',true) end
end

function plot(e)
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
```

## smooth-sine-chart

Connect at most four logical monitors on red or green. They do not need electricity. The program draws a connected green line with 2×3 mosaic subpixels and a gray axis. It does not use text markers. It samples one phase and updates all selected screens every two ticks. It submits only rows with changed glyphs or colors. It uses scale 2 when a footprint axis exceeds three tiles. Otherwise, it uses scale 1. Grids have at most 32 columns and 22 rows. This example ships with version 0.1.7 and its runtime and presenter optimizations. Older published archives keep their original example. Paste the complete source. Select Validate. Select Save. Select Run. Do not run other content writers on these screens. This example caches rows. See the [subpixel design and verification boundaries](monitor-animation.md).

```lua
function start()
    computer.deleteState("smooth_chart")
    computer.every(2, "plot")
end

function plot()
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
```

## graphics-sine-chart

Connect at most four monitors on red or green. They do not need electricity. Use a 2×2 display or a larger one. The program changes each display to graphics mode. It draws gray axes, the title SINE / LIVE, an iron plate icon and one green polygon curve. Every two ticks, one set call moves the curve vertices. Narrow displays omit the title or the icon. Without a reachable monitor, setup fails. Paste the complete source. Select Validate. Select Save. Select Run. See the [monitor API](api/monitor.md).

```lua

local function wave(w, h, phase)
    -- A thick curve as a triangle strip: one upper and one lower vertex per sample.
    local top, bottom = 16, h - 6
    local mid, amp = (top + bottom) / 2, (bottom - top) / 2 - 2
    local n = math.max(8, math.floor((w - 16) / 4))
    local points = {}
    for i = 0, n do
        local x = 8 + i * (w - 16) / n
        local y = mid - amp * math.sin(phase + i * 6.283185307179586 / n)
        points[#points + 1] = { x, y - 1.5 }
        points[#points + 1] = { x, y + 1.5 }
    end
    return points
end

function start()
    computer.on("monitor_resize", "setup")
    setup()
    computer.every(2, "plot")
end

function setup()
    local views, seen = {}, {}
    for _, wire in ipairs({ "red", "green" }) do
        for _, name in ipairs(peripheral.getNames(wire)) do
            if #views < 4 and not seen[name] and peripheral.getType(name, wire) == "monitor" then
                seen[name] = true
                local m = peripheral.wrap(name, wire)
                m.setMode("graphics")
                m.clear()
                local w, h = m.getSize()
                local mid = math.floor((16 + h - 6) / 2)
                m.drawLine({ from = { 6, mid }, to = { w - 6, mid }, color = { 0.45, 0.45, 0.45 }, width = 1 })
                m.drawLine({ from = { 6, 16 }, to = { 6, h - 6 }, color = { 0.45, 0.45, 0.45 }, width = 1 })
                if w >= 72 then
                    m.drawText({ text = "SINE / LIVE", target = { 6, 3 }, color = { 0.94, 0.94, 0.94 } })
                end
                if w >= 100 then
                    m.drawSprite({ sprite = "item/iron-plate", target = { w - 12, 10 }, x_scale = 0.25, y_scale = 0.25 })
                end
                local curve = m.drawPolygon({ vertices = wave(w, h, 0), color = { 0.5, 0.8, 0.1 } })
                views[#views + 1] = { name = name, wire = wire, curve = curve, w = w, h = h }
            end
        end
    end
    assert(#views > 0, "Connect a monitor NETWORK on red or green")
    computer.setState("graphics_chart", views)
end

function plot()
    local phase = computer.getTick() / 120
    for _, v in ipairs(computer.getState("graphics_chart") or {}) do
        local m = peripheral.wrap(v.name, v.wire)
        if m then
            m.set(v.curve, { vertices = wave(v.w, v.h, phase) })
        end
    end
end

```

## configurator-program

Connect discovery NETWORK red. Connect separate TARGETS green to one inserter. The program sets A > 4, not A > 0. Supply an external A signal of at least 5 to move the inserter.

```lua
function start(e)
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
end
```

## configurator-sections

Connect discovery NETWORK red. Connect TARGETS green to one constant combinator. The program adds a section, activates it, and saves its actual index in computer state. It deliberately writes no signal filters.

```lua
function start(event)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  for _,device in ipairs(cfg.getDevices('green')) do
    if device.type=='constant-combinator' and device.configurable then
      local index=cfg.addSection(device.id,{active=false},'green')
      cfg.setSection(device.id,index,{set={active=true}},'green')
      computer.setState('section',index)
    end
  end
end
```

## factory-controller

Follow the complete [factory wiring tutorial](factory.md). Keep one device per type reachable. Paste this whole document.

```lua
function start(event)
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
end

function ready(event)
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
end

function changed(event)
  computer.after(1, "refresh")
end

function touched(event)
  local monitor = peripheral.find("monitor", "red")
  if monitor and event.peripheral == peripheral.getName(monitor) then
    computer.setState("enabled", not computer.getState("enabled"))
    computer.after(1, "refresh")
  end
end

function resized(event)
  computer.after(1, "refresh")
end

function refresh(event)
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
```

## shared-telemetry

Use the [second-computer setup](factory.md#second-computer-shared-and-private-data). Connect the shared database on red. Connect a separate physical database on green.

```lua
function start(event)
  local shared = peripheral.find("kv_database", "red")
  local independent = peripheral.find("kv_database", "green")
  assert(shared and independent, "Connect one database on each color")
  assert(peripheral.getName(shared) ~= peripheral.getName(independent), "Use two physical databases")
  shared.set("observer", computer.getID())
  independent.set("observer", "private")
  computer.every(60, "inspect")
end

function inspect(event)
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
```

## Retained API examples

These complete sources come from the former API companions.
Use a separate stopped computer for each program. Do not combine programs.
The [wiring guide](getting-started.md), [factory setup](factory.md) and
[current typed reference](api/types.md) explain their device roles and limits.
The historical source identities below record the origins of these examples. They are not alternative API contracts.

### player-kv-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `docs/player/api/kv.md:1`.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then
    computer.log("Connect a database on red NETWORK")
    return
  end
  local ok, value = pcall(db.get, "counter")
  if ok then
    computer.log(value or "No counter yet")
  elseif type(value) == "table" then
    computer.log(value.code .. ": " .. value.message)
  else
    computer.log(tostring(value))
  end
end
```

### function-program

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `docs/player/api/language.md:1`.

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

### player-recipe-searcher-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `docs/player/api/recipe-searcher.md:1`.

```lua
function start(event)
    local searcher = peripheral.find("recipe_searcher", "red")
    assert(searcher, "Connect a Recipe Searcher on red")
    local recipes = searcher.findRecipes("item", "iron-plate", "smelting")
    local limits = searcher.getLimits()
end
```

### api-examples-1

Use one computer, one database, one Logic Handler, one Configurator and a 2×2 monitor rectangle.
Join their NETWORK ports on red. Separately connect a stock-reading chest to INPUT red.
Connect OUTPUT green and Configurator TARGET green to the powered inserters.
Enable chest content reading manually. The program configures inserters, not the chest.

Source identity: `openspec/api/examples.md:1`.

```lua
function start(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local monitor = peripheral.find("monitor", "red")
  local cfg = peripheral.find("configurator", "red")
  assert(io and db and monitor and cfg, "Connect all four peripherals")

  if computer.getState("enabled") == nil then
    computer.setState("enabled", true)
  end
  local configured = 0
  for _, device in ipairs(cfg.getDevices("green")) do
    if device.type == "inserter" then
      local caps = cfg.getCapabilities(device.id, "green")
      local enable = caps.settings.circuit_enable_disable
      local condition = caps.settings.circuit_condition
      if enable and enable.writable and condition and condition.writable then
        cfg.setConfiguration(device.id, {
          set = {
            circuit_enable_disable = true,
            circuit_condition = {
              first_signal = { type = "virtual", name = "signal-A", quality = "normal" },
              comparator = ">", constant = 0
            }
          }
        }, "green")
        configured = configured + 1
      end
    end
  end
  assert(configured > 0, "Connect a configurable inserter to the target port")

  -- Configuration/capability readback and subscriptions share one callback
  -- ceiling. Admit the next setup phase on a later real simulation tick.
  computer.after(1, "ready")
end

function ready(event)
  local io = peripheral.find("logic_handler", "red")
  local monitor = peripheral.find("monitor", "red")
  assert(io and monitor, "Required peripheral disconnected during setup")
  monitor.setTextScale(1)
  io.subscribe({
    input = "red",
    signals = { { type = "item", name = "iron-plate", quality = "normal" } },
    initial = true
  }, "changed")
  computer.on("monitor_touch", "touched")
  computer.on("monitor_resize", "resized")
  computer.every(60, "refresh")
  computer.after(1, "refresh")
end

function changed(event)
  -- Coarse refresh also exists; this wakes it promptly for stock changes.
  computer.after(1, "refresh")
end

function touched(event)
  local monitor = peripheral.find("monitor", "red")
  if monitor and event.peripheral == peripheral.getName(monitor) then
    computer.setState("enabled", not computer.getState("enabled"))
    computer.after(1, "refresh")
  end
end

function resized(event)
  computer.after(1, "refresh")
end

function refresh(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local monitor = peripheral.find("monitor", "red")
  assert(io and db and monitor, "Required peripheral disconnected")

  -- Read current native input instead of acting on an old queued sample.
  local count = io.readSignal("red", {
    type = "item", name = "iron-plate", quality = "normal"
  })
  local output = 0
  if computer.getState("enabled") and count < 100 then output = 1 end
  io.setOutput({
    { signal = { type = "virtual", name = "signal-A", quality = "normal" }, count = output }
  })

  local status = "STOPPED"
  if output == 1 then status = "FILLING" end
  db.hset("stock:iron", "count", tostring(count),
    "status", status, "sample_tick", tostring(computer.getTick()))
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
```

### computer-runtime-base-globals-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/computer-runtime/base-globals-api.md:1`.

```lua
function start(event)
  local values = table.pack(false, nil, 3)
  assert(unpack == table.unpack)
  print(_VERSION, unpack(values, 1, values.n))
  local t = {}
  assert(rawequal(rawset(t, "ready", false), t))
  assert(rawget(t, "ready") == false)
  assert(rawlen("hello") == 5)
  local ok, message = xpcall(function()
    error("sample failure")
  end, function(problem)
    return "handled: " .. tostring(problem)
  end)
  assert(ok == false)
  print(message)
end
```

### computer-runtime-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/computer-runtime/lua-api.md:1`.

```lua
function start(event)
  local boots = computer.getState("boots") or 0
  computer.setState("boots", boots + 1)
  computer.every(60, "sample")
end

function sample(event)
  computer.log("Sampling at tick " .. tostring(event.tick))
end
```

### computer-runtime-lua-api-2

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/computer-runtime/lua-api.md:2`.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then
    computer.log("Connect a database with a complete red path")
    return
  end
  local ok, value = pcall(db.get, "counter")
  if ok then
    computer.log(value or "No counter yet")
  elseif type(value) == "table" then
    computer.log(value.code .. ": " .. value.message)
  else
    computer.log(tostring(value))
  end
end
```

### console-shell-lua-api-1

These are separate live Console commands, not a saved program.
Replace the example `tc-42` with your red-connected monitor name.
Run each line in order. The write changes the real monitor.
Stop, Run, or confirmed Reset Shell clears these bindings.

Source identity: `openspec/specs/console-shell/lua-api.md:1`.

```text
p = peripheral.wrap("tc-42", "red")
print(p.getSize())
p.setCursorPos(1, 1); p.write("Shell test")
size = p.getSize
print(size())
```

### dashboard-program

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/dashboard-interface/lua-api.md:1`.

```lua
function start(event)
    local panel = peripheral.find("dashboard", "red")
    assert(panel, "Connect a Dashboard on red")
    panel.setTab(1, {
        title = "Overview",
        content = {type = "column", id = "root", children = {
            {type = "label", id = "status", text = "Ready"},
            {type = "button", id = "ack", text = "Acknowledge"}
        }}
    })
    panel.subscribe("clicked")
end

function clicked(event)
    local panel = peripheral.wrap(event.peripheral, event.wire)
    if event.tab == 1 and event.button == "ack" then
        panel.setText(1, "status", "Acknowledged")
    end
end
```

### device-configurator-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/device-configurator/lua-api.md:1`.

```lua
function start(event)
  local cfg = peripheral.find("configurator", "red")
  if not cfg then return end
  for _, device in ipairs(cfg.getDevices("green")) do
    computer.log(device.prototype .. " at " ..
      tostring(device.position.x) .. "," .. tostring(device.position.y))
    if device.type == "inserter" then
      local caps = cfg.getCapabilities(device.id, "green")
      local enable = caps.settings.circuit_enable_disable
      local condition = caps.settings.circuit_condition
      if enable and enable.writable and condition and condition.writable then
        cfg.setConfiguration(device.id, {
          set = {
            circuit_enable_disable = true,
            circuit_condition = {
              comparator = ">",
              first_signal = { type = "virtual", name = "signal-A", quality = "normal" },
              constant = 0
            }
          }
        }, "green")
      end
    end
  end
end
```

### factoriopedia-interface-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/factoriopedia-interface/lua-api.md:1`.

```lua
function start(event)
    local encyclopedia = peripheral.find("factoriopedia_interface", "red")
    assert(encyclopedia, "Connect a Factoriopedia Interface on red")

    local item = encyclopedia.getItem("iron-plate")
    computer.log(item.name .. " stack size=" .. tostring(item.stack_size))
    if item.rocket_capacity ~= nil then
        computer.log("Reference items per rocket=" .. tostring(item.rocket_capacity))
    else
        computer.log("No finite mass-limited rocket count")
    end

    local fluid = encyclopedia.getFluid("water")
    computer.log(fluid.name .. " temperature="
        .. tostring(fluid.default_temperature) .. ".."
        .. tostring(fluid.max_temperature) .. " C")

    local function reportNames(method, label)
        local ok, result = pcall(method)
        if ok then
            computer.log(label .. ": " .. tostring(#result))
        elseif type(result) == "table" and result.code == "E_LIMIT" then
            computer.log(label .. ": complete list exceeds shared Data limits")
        else
            error(result)
        end
    end
    reportNames(encyclopedia.listItems, "Installed item names")
    reportNames(encyclopedia.listFluids, "Installed fluid names")
end
```

### kv-database-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/kv-database/lua-api.md:1`.

```lua
function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then return end
  db.hset("machine", "status", "ready", "owner", computer.getID())
  db.expire("machine", 30)
  computer.after(60, "inspect")
end

function inspect(event)
  local db = peripheral.find("kv_database", "red")
  if not db then return end
  local fields = db.hgetall("machine")
  computer.log(fields.status or "expired")
  computer.log("TTL=" .. tostring(db.ttl("machine")))
end
```

### logic-handler-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/logic-handler/lua-api.md:1`.

```lua
function start(event)
  local io = peripheral.find("logic_handler", "red")
  if io then
    io.subscribe({
      input = "red",
      signals = { { type = "item", name = "iron-plate", quality = "normal" } },
      initial = true
    }, "changed")
  end
end

function changed(event)
  local io = peripheral.wrap(event.peripheral, event.wire)
  if not io then return end
  local count = 0
  for _, entry in ipairs(event.current) do
    count = entry.count
  end
  local enable = 0
  if count < 100 then enable = 1 end
  io.setOutput({
    { signal = { type = "virtual", name = "signal-A", quality = "normal" }, count = enable }
  })
end
```

### monitor-display-buffering-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/monitor-display/buffering-api.md:1`.

```lua
function start(event)
  local members, seen = {}, {}
  for _, wire in ipairs({"red", "green"}) do
    for _, name in ipairs(peripheral.getNames(wire)) do
      if not seen[name] and peripheral.getType(name, wire) == "monitor" then
        seen[name] = true
        members[#members + 1] = {name = name, wire = wire}
      end
    end
  end
  peripheral.setMonitorSyncGroup(members)
  computer.log("Selected synchronized monitors")
end
```

### monitor-display-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/monitor-display/lua-api.md:1`.

```lua
function start(event)
  computer.on("monitor_touch", "touched")
  computer.on("monitor_resize", "resized")
  local m = peripheral.find("monitor", "red")
  if m then
    m.setBackgroundColor(colors.black)
    m.setTextColor(colors.lime)
    m.clear()
    m.setCursorPos(1, 1)
    m.write("READY")
  end
end

function touched(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write(tostring(event.x) .. "," .. tostring(event.y))
  end
end

function resized(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write("RESIZED")
  end
end
```

### peripheral-network-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/peripheral-network/lua-api.md:1`.

```lua
function start(event)
  for _, wire in ipairs({ "red", "green" }) do
    for _, name in ipairs(peripheral.getNames(wire)) do
      local info = peripheral.describe(name, wire)
      if info then
        computer.log(wire .. " / " .. name .. " / " .. info.type)
      end
    end
  end
end
```

### production-statistics-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/production-statistics/lua-api.md:1`.

```lua
function start()
  local stats = peripheral.find("production_statistics", "red")
  assert(stats, "Connect a Production Statistics device with red wire")
  local items = stats.getTotals("item")
  local normal = items.input.normal or {}
  computer.log("Iron produced: " .. tostring(normal["iron-plate"] or 0))

  local fluids = stats.getRates("fluid", "one_minute")
  computer.log("Water consumed/min: " .. tostring(fluids.output.water or 0))

  local pollution = stats.getTotals("pollution")
  for name, amount in pairs(pollution.input) do
    computer.log(name .. " emitted " .. tostring(amount))
  end

  local history = stats.getHistory("item", "iron-plate", "one_minute", "normal")
  computer.log("Newest iron production/min: " .. tostring(history.input[1]))
end
```

### program-editor-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/program-editor/lua-api.md:1`.

```lua
function start(event)
  computer.log("Controller started")
  computer.on("peripheral_attach", "attached")
end

function attached(event)
  computer.log(event.peripheral .. " attached on " .. event.wire)
end
```

### recipe-searcher-program

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/recipe-searcher/lua-api.md:1`.

```lua
function start(event)
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
```

### speaker-peripheral-lua-api-1

Connect the peripherals named in the source on their stated discovery color.
Keep discovery NETWORK, Logic INPUT/OUTPUT and Configurator TARGET wiring separate.
Custom devices do not need electricity. Native radars, speakers, and factory targets keep their own power requirements.
Select Validate. Select Save. Select Run. Examine Console and the device.

Source identity: `openspec/specs/speaker-peripheral/lua-api.md:1`.

```lua
function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla speaker on red")
  for _, instrument in ipairs(speaker.getInstruments()) do
    computer.log(instrument)
  end
  local notes = speaker.getNotes("piano")
  assert(#notes > 0)
  computer.log(notes[1].name)
  computer.log(tostring(speaker.playNote("piano", 0.5, notes[1].pitch)))
  local page = speaker.getSounds("utility/")
  if #page.sounds > 0 then
    computer.log(tostring(speaker.playSound(page.sounds[1], 0.5)))
  end
  computer.setState("speaker", peripheral.getName(speaker))
  computer.every(60, "chime")
end

function chime(event)
  local speaker = peripheral.wrap(computer.getState("speaker"), "red")
  if speaker then
    local accepted = speaker.playNote("piano", 0.25, 0)
    if not accepted then computer.log("Speaker busy this tick") end
  end
end
```
