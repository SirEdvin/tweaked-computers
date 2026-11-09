-- Static help checked against the same inventory used by actual compiled guests.
local help=require('scripts.ui.help')
local inventory=require('tests.api_inventory')
local api_reference=require('scripts.ui.api-reference')
local M={}
function M.run()
  for _,topic in ipairs(help.topics) do
    assert(topic.blocks and #topic.blocks>1,'every topic needs structured, copyable sections: '..topic.title)
    assert(topic.blocks[1].kind=='heading')
    for _,block in ipairs(topic.blocks) do
      assert(type(block.text)=='string' and #block.text>0)
      assert(block.kind=='heading' or block.kind=='prose' or block.kind=='signature' or block.kind=='code')
    end
  end
  for _,id in ipairs({'starter','speaker','logic','recipe','factory','shared','statistics','dashboard','dashboard_charts','graphics'}) do
    local tutorial=assert(help.tutorials[id],'missing self-contained tutorial '..id)
    for _,key in ipairs({'purpose','setup','steps','expected','failures','code'}) do
      assert(type(tutorial[key])=='string' and #tutorial[key]>0,id..' missing '..key)
    end
  end
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
      starts[#starts+1]={pos=first,method=method}; count=count+1
    end
    for _,method in ipairs(starts) do
      local matched=0; local signatures={}
      for i,part in ipairs(topic.blocks) do
        if part.kind=='signature' and part.text:sub(1,#method.method+1)==method.method..'(' then
          matched=matched+1
          assert(not signatures[part.text],'duplicate overload '..kind..'.'..method.method)
          signatures[part.text]=true
          local parameters,returns=false,false
          for j=i+1,#topic.blocks do
            local next=topic.blocks[j]
            if next.kind=='signature' then break end
            if next.kind=='heading' and next.text=='Parameters' then parameters=true end
            if next.kind=='heading' and next.text=='Returns' then returns=true end
          end
          assert(parameters and returns,'isolated parameter/result sections '..kind..'.'..method.method)
        end
      end
      local expected_count=1
      if kind=='discovery' and method.method=='find' then expected_count=11 end
      if kind=='monitor' and (method.method=='blit' or method.method=='setPaletteColor' or method.method=='setPaletteColour') then expected_count=2 end
      assert(matched==expected_count,'exact native overload inventory '..kind..'.'..method.method)
    end
    assert(count>0); total=total+count; family_count=family_count+1
  end
  assert(family_count==11,'discovery plus all ten shipped families required')
  for _,kind in ipairs({'MONITOR','Monitor','radar','kv','unknown','monitor_extra',''}) do assert(not help.peripheral_topic(kind)) end
  assert(not help.peripheral_topic(nil))
  for _,topic in ipairs(help.topics) do
    if topic.category=='Computer' then
      local found=false
      for i,part in ipairs(topic.blocks) do
        if part.kind=='signature' and part.text=='log(text: string)' then
          assert(not part.text:find(' -> ',1,true))
          for j=i+1,#topic.blocks do
            if topic.blocks[j].kind=='signature' then break end
            if topic.blocks[j].text:find('No result positions.',1,true)==1 then found=true end
          end
        end
      end
      assert(found,'computer.log documents its actual empty return tuple, not its output effect')
    end
  end
  local mon=help.topics[help.peripheral_topic('monitor')].text
  assert(mon:find('setPaletteColor(color: TC.Color, rgb: integer)',1,true))
  assert(mon:find('setPaletteColour(color: TC.Color, rgb: integer)',1,true))
  for _,alias in ipairs({'TextColour','BackgroundColour','PaletteColour'}) do
    assert(mon:find('get'..alias..'(',1,true) and mon:find('set'..alias..'(',1,true))
  end
  assert(mon:find('monitor_touch',1,true) and mon:find('monitor_resize',1,true))
  assert(help.text:find('modem_message',1,true) and help.text:find('signal_changed',1,true))
  assert(help.text:find('xpcall',1,true) and help.text:find('Reset Shell',1,true))
  local by_id={}
  for _,topic in ipairs(help.topics) do if topic.id then assert(not by_id[topic.id]); by_id[topic.id]=topic end end
  local types=0
  for name,location in pairs(help.type_topics) do
    local topic=assert(by_id[location.topic],name)
    assert(topic.text:find(name,1,true),'unreachable exact public name '..name)
    types=types+1
  end
  for _,name in ipairs({'TC.Config.SignalID','TC.Config.Read.SignalID','TC.MonitorTouch','TC.SignalChanged','TC.DashboardLine','TC.Limits'}) do
    assert(help.type_topics[name],name)
  end
  helpers.write_file('typed-api-reference.json',helpers.table_to_json(api_reference),false)
  log('TC_HELP_PUBLIC_RECORDS '..types)
  log('TC_HELP_METHOD_TOTAL '..total..' families='..family_count)
end
return M
