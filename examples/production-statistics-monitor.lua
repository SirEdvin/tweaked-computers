-- Presentation only: each refresh reads native history, never records a series.
return [[function start() computer.every(120,"draw") end

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
end]]
