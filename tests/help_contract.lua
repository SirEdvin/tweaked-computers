-- Static help checked against the same inventory used by actual compiled guests.
local help=require('scripts.ui.help')
local inventory=require('tests.api_inventory')
local M={}
function M.run()
  local expected={}
  local discovery=assert(inventory:match("for _,method in ipairs%(%{(.-)%}%)[^\n]*do"))
  expected.discovery=discovery
  local families=assert(inventory:match('local expected=%{(.-)\n  %}'))
  for kind,methods in families:gmatch('([%w_]+)=%{(.-)%}') do expected[kind]=methods end
  local total,family_count=0,0
  for kind,methods in pairs(expected) do
    local index=help.peripheral_topic(kind)
    if kind=='discovery' then
      assert(not index)
      for i,topic in ipairs(help.topics) do if topic.id=='peripheral.discovery' then index=i end end
    end
    local topic=assert(help.topics[assert(index,kind)])
    assert(topic.category=='Peripherals' and topic.id=='peripheral.'..kind)
    local starts={}; local count=0
    for method in methods:gmatch("'([%w_]+)'") do
      local signature='\n'..method..'('
      local first,last=topic.text:find(signature,1,true)
      assert(first,'missing signature '..kind..'.'..method)
      assert(not topic.text:find(signature,last+1,true),'duplicate entry '..kind..'.'..method)
      starts[#starts+1]={pos=first,method=method}; count=count+1
    end
    table.sort(starts,function(a,b) return a.pos<b.pos end)
    for i=2,#starts do
      local pos=starts[i].pos
      assert(topic.text:sub(pos-2,pos)=='\n\n\n','exactly two empty lines required before '..kind..'.'..starts[i].method)
      assert(topic.text:sub(pos-3,pos-3)~='\n','extra empty line before '..kind..'.'..starts[i].method)
      local previous=topic.text:sub(starts[i-1].pos+1,pos-3)
      assert(not previous:find('\n\n',1,true),'method paragraph split '..kind..'.'..starts[i-1].method)
    end
    assert(count>0); total=total+count; family_count=family_count+1
  end
  assert(family_count==8,'discovery plus all seven shipped families required')
  for _,kind in ipairs({'MONITOR','Monitor','radar','kv','unknown','monitor_extra',''}) do assert(not help.peripheral_topic(kind)) end
  assert(not help.peripheral_topic(nil))
  local mon=help.topics[help.peripheral_topic('monitor')].text
  assert(mon:find('setPaletteColor(color, rgb) or setPaletteColor(color, r, g, b)',1,true))
  assert(mon:find('setPaletteColour(color, rgb) or setPaletteColour(color, r, g, b)',1,true))
  for _,alias in ipairs({'TextColour','BackgroundColour','PaletteColour'}) do
    assert(mon:find('get'..alias..'(',1,true) and mon:find('set'..alias..'(',1,true))
  end
  assert(mon:find('monitor_touch',1,true) and mon:find('monitor_resize',1,true))
  assert(help.text:find('modem_message',1,true) and help.text:find('signal_changed',1,true))
  assert(help.text:find('xpcall',1,true) and help.text:find('Reset Shell',1,true))
  log('TC_HELP_METHOD_TOTAL '..total..' families='..family_count)
end
return M
