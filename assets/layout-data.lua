-- Host-only export of the production geometry; also used by packaged data tests.
local defs=require('scripts.device-definitions')
local M={}
local function number(n) return string.format('%.17g',n) end
function M.json()
  local devices={}
  for _,kind in ipairs(defs.order) do
    local def=defs.devices[kind]; local directions={}
    for i,name in ipairs({'north','east','south','west'}) do
      local roles={}
      for index,role in ipairs(def.roles) do
        local x,y=defs.offset(kind,index,(i-1)*4); local contacts={}
        for _,color in ipairs({'red','green'}) do
          local cx,cy=defs.contact(kind,role,color,(i-1)*4)
          contacts[#contacts+1]='"'..color..'":['..number(cx)..','..number(cy)..']'
        end
        local c=defs.colors[role]
        roles[#roles+1]='"'..role..'":{"center":['..number(x)..','..number(y)..'],"color":['..number(c[1])..','..number(c[2])..','..number(c[3])..'],"contacts":{'..table.concat(contacts,',')..'}}'
      end
      directions[#directions+1]='"'..name..'":{'..table.concat(roles,',')..'}'
    end
    devices[#devices+1]='"'..kind..'":{"width":'..def.width..',"directions":{'..table.concat(directions,',')..'}}'
  end
  return '{"devices":{'..table.concat(devices,',')..'}}'
end
return M
