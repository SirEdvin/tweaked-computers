local defs=require('scripts.device-definitions')
local M={}
function M.run()
  local count=0
  for _,kind in ipairs(defs.order) do
    local def=defs.devices[kind]
    assert(#def.roles==def.width and def.watts>0)
    for _,direction in ipairs({0,4,8,12}) do
      local seen={}
      for i,role in ipairs(def.roles) do
        local x,y=defs.offset(kind,i,direction)
        assert(not seen[x..','..y]); seen[x..','..y]=role
        assert((direction==0 or direction==8) and y==0 or (direction==4 or direction==12) and x==0)
        local ox,oy=defs.offset(kind,i,(direction+8)%16)
        assert(ox==-x and oy==-y)
      end
    end
    for _,ingredient in ipairs(def.ingredients) do assert(ingredient[2]>0 and ingredient[2]%1==0) end
    count=count+1; log('TC_CONTRACT physical_geometry_'..kind)
  end
  assert(not pcall(defs.offset,'logic',1,1))
  count=count+1; log('TC_CONTRACT physical_cardinal_refusal')
  return count
end
return M
