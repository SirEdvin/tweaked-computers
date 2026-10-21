-- Opt-in native input scene; observes production GUI, never synthesizes GUI events.
local base=require('tests.shell_client_engine')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local editor=require('scripts.ui.editor')
local model=require('scripts.ui.editor-model')
local help=require('scripts.ui.help')
local defs=require('scripts.device-definitions')
local M={}
function M.run()
  base.run()
  local fixture=storage.tc_shell_client; local c=registry.record(fixture.computer)
  local surface=c.body.surface
  local search=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.recipe_searcher.entity_name,position={12,0},force='player'})))
  local radar=assert(lifecycle.build(assert(surface.create_entity{name='radar',position={16,0},force='player'})))
  local speaker=assert(lifecycle.build(assert(surface.create_entity{name='programmable-speaker',position={19,0},force='player'})))
  local function connector(r,wire)
    if r.native_carrier then return r.body.get_wire_connector(defines.wire_connector_id['circuit_'..wire],true) end
    return lifecycle.connector(r,'network',wire)
  end
  for _,r in ipairs({search,radar,speaker}) do
    assert(connector(c,'red').connect_to(connector(r,'red'),false))
  end
  assert(connector(c,'green').connect_to(connector(registry.record(fixture.db),'green'),false))
  -- Retained state is initialized only by fixture setup; UI navigation cannot write it.
  c.state.navigation_witness={retained=true}
end
M.on_player_joined=base.on_player_joined
function M.on_tick(event)
  base.on_tick(event)
  if event.tick%15~=0 then return end
  local f=storage.tc_shell_client; local c=registry.record(f.computer); local snapshots={}
  for _,p in pairs(game.connected_players) do
    local root=p.gui.screen[editor.frame_name]; local s,b=model.session(p.index)
    if root and s then
      local reference=root.content.reference
      local topic=s.topic and help.topics[s.topic]
      snapshots[#snapshots+1]={player=p.index,tab=s.tab,peripheral=s.peripheral,wire=s.wire,
        peripheral_wire=s.peripheral_wire,inventory=s.inventory,search=s.search,category=s.category,
        topic=topic and topic.id,topic_title=topic and topic.title,topic_text=reference.reference_text.text,
        filter_search=reference.filters.search.text,filter_category=reference.filters.category.selected_index,
        topic_selection=reference.topics.selected_index,details=root.content.peripherals.details.text,
        source=root.content.editor.source.text,draft=b.documents[c.id].source,message=s.message,
        resolution=p.display_resolution,scale=p.display_scale,location=root.location}
    end
  end
  helpers.write_file('reference-client-state.json',helpers.table_to_json({tick=event.tick,players=snapshots,
    saved=c.saved_source,revision=c.saved_revision,active_source=c.active and c.active.source,run=c.run_id,
    state=c.state,status=c.status,shell=c.shell,database=registry.record(f.db).database}),false)
end
return M
