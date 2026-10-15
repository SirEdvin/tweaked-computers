-- Narrow preferred-carrier feasibility gate, before lifecycle conversion.
local defs=require('scripts.device-definitions')
local M={}
function M.run()
  for i,kind in ipairs(defs.order) do
    local def=defs.devices[kind]
    local b=assert(game.surfaces[1].create_entity{name=def.entity_name,position={i*8,0},force='player'})
    b.operable=false
    local cb=b.get_or_create_control_behavior(); cb.enabled=false
    for n=cb.sections_count,1,-1 do cb.remove_section(n) end
    assert(b.type=='constant-combinator' and not b.operable and cb.sections_count==0)
    assert(b.get_wire_connector(defines.wire_connector_id.circuit_red,true))
    assert(b.get_wire_connector(defines.wire_connector_id.circuit_green,true))
    local p=assert(b.surface.create_entity{name=def.power_name,position=b.position,force=b.force})
    assert(not p.prototype.selectable_in_game and not p.prototype.has_flag('not-blueprintable')==false)
    p.power_usage=def.watts/60; p.energy=def.watts/30
    assert(p.energy==def.watts/30)
    for _,role in ipairs(def.roles) do if role~='network' then
      local a=assert(b.surface.create_entity{name=defs.pad_name(kind,role),position=b.position,force=b.force})
      assert(a.get_wire_connector(defines.wire_connector_id.circuit_red,true)~=b.get_wire_connector(defines.wire_connector_id.circuit_red,true))
      a.destroy()
    end end
    p.destroy(); b.destroy()
  end
  log('TC_CONTRACT circuit-shell-private-power-independent-pads-feasible')
  log('TC_CONTRACT_TOTAL 1')
end
return M
