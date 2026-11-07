local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local principal=require('scripts.runtime.principal')
local admission=require('scripts.runtime.admission')
local environment=require('scripts.runtime.environment')
require('scripts.services.peripheral')
local M={}
function M.run()
  local count=0
  for _,kind in ipairs(defs.order) do
    local def=defs.devices[kind]
    assert(#def.roles==def.width and def.watts==nil)
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
  local previous=storage.tweaked_computers
  storage.tweaked_computers=nil; registry.initialize()
  local surface=game.surfaces[1]
  local computer_body=assert(surface.create_entity{name=defs.devices.computer.entity_name,position={-30,-30},force='player'})
  local database_body=assert(surface.create_entity{name=defs.devices.kv.entity_name,position={-27,-30},force='player'})
  local c=assert(lifecycle.build(computer_body)); local db=assert(lifecycle.build(database_body))
  c.status='running'; c.run_id=c.id..'/proof-test'
  local ok,problem=pcall(function()
    for _,field in ipairs({'generation','force_index','surface_index'}) do
      local check=principal.proof(c,principal.program(c)); local original=c[field]
      c[field]=original+1
      local accepted=pcall(check); c[field]=original
      assert(not accepted,'owner proof widened its '..field)
    end
    local check=principal.proof(c,principal.program(c)); local run=c.run_id
    c.run_id=run..'-retired'; assert(not pcall(check)); c.run_id=run
    local a=lifecycle.connector(c,'network','red'); local b=lifecycle.connector(db,'network','red')
    for _,throws in ipairs({false,true}) do
      assert(a.connect_to(b))
      local ctx=admission.context(admission.new(),c.id,0)
      local g=environment.new(ctx,function(guard) return runtime.services(c,0,guard) end); g.initialize()
      local api=g.globals.peripheral; local present=api.isPresent
      assert(g.execute(present,db.id,'red') and not g.execute(present,db.id,'green'))
      local native=principal.available; local checks=0
      principal.available=function(...) checks=checks+1; return native(...) end
      for _=1,3 do assert(g.execute(present,db.id,'red')) end
      principal.available=native
      assert(checks==0,'stable metadata repeated physical owner checks')
      local facade=g.execute(api.wrap,db.id,'red'); local captured=facade.getLimits
      assert(type(g.execute(captured))=='table')
      local generation=db.generation; db.generation=generation+1
      local accepted,e=pcall(g.execute,captured); db.generation=generation
      assert(not accepted and e.code=='E_UNREACHABLE')
      local change=g.service(function()
        assert(a.disconnect_from(b))
        if throws then error({code='E_ARGUMENT',message='after physical change'},0) end
      end)
      assert(pcall(g.execute,change)~=throws)
      assert(not g.execute(present,db.id,'red'),'unclassified service retained a stale physical proof')
      accepted,e=pcall(g.execute,captured)
      assert(not accepted and e.code=='E_UNREACHABLE')
      accepted,e=pcall(g.execute,facade.getLimits)
      assert(not accepted and e.code=='E_UNREACHABLE','wrapped call retained a revoked path')
      accepted,e=pcall(g.execute,api.call,db.id,'red','getLimits')
      assert(not accepted and e.code=='E_UNREACHABLE','named call retained a revoked path')
      local next_guard=environment.new(admission.context(admission.new(),c.id,1),function(guard) return runtime.services(c,1,guard) end)
      next_guard.initialize()
      assert(not next_guard.execute(next_guard.globals.peripheral.isPresent,db.id,'red'))
    end
  end)
  lifecycle.remove(db.id,'proof-fixture',true); lifecycle.remove(c.id,'proof-fixture',true)
  storage.tweaked_computers=previous
  assert(ok,problem)
  count=count+1; log('TC_CONTRACT callback-proof-scope-generation-color-retirement-and-throwing-invalidation')
  return count
end
return M
