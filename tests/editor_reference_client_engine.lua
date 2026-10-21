-- Opt-in native input scene; observes production GUI, never synthesizes GUI events.
local base=require('tests.shell_client_engine')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local editor=require('scripts.ui.editor')
local model=require('scripts.ui.editor-model')
local help=require('scripts.ui.help')
local defs=require('scripts.device-definitions')
local M={}
-- Host-only survey controls. Visual coverage may use these; keyboard/dropdown,
-- contextual navigation and actual clipboard acceptance use native input.
remote.add_interface('tc-ui2',{
  view=function(index)
    local p=game.get_player(1); local root=assert(p.gui.screen[editor.frame_name])
    local r=root.content.reference
    root.content.selected_tab_index=4; editor.on_tab{player_index=p.index,element=root.content,tick=game.tick}
    r.filters.category.selected_index=1; editor.on_selection{player_index=p.index,element=r.filters.category,tick=game.tick}
    r.filters.search.text=''; editor.on_text{player_index=p.index,element=r.filters.search,tick=game.tick}
    r.topics.selected_index=index; editor.on_selection{player_index=p.index,element=r.topics,tick=game.tick}
    editor.resize(p)
  end,
  scroll=function(index)
    local r=game.get_player(1).gui.screen[editor.frame_name].content.reference.reference_text
    r.scroll_to_element(assert(r['block_'..index]),'top-third')
  end
})
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
      local blocks={}; local texts={}
      for _,v in ipairs(reference.reference_text.children) do
        blocks[#blocks+1]={name=v.name,text=v.text,kind=v.tags.reference_kind,index=v.index,
          width=v.style.minimal_width,height=v.style.minimal_height,wrap=v.word_wrap,read_only=v.read_only}
        texts[#texts+1]=v.text
      end
      snapshots[#snapshots+1]={player=p.index,tab=s.tab,peripheral=s.peripheral,wire=s.wire,
        peripheral_wire=s.peripheral_wire,inventory=s.inventory,search=s.search,category=s.category,
        topic=topic and topic.id,topic_title=topic and topic.title,topic_text=table.concat(texts,'\n'),blocks=blocks,
        filter_search=reference.filters.search.text,filter_category=reference.filters.category.selected_index,
        topic_selection=reference.topics.selected_index,details=root.content.peripherals.details.text,
        source=root.content.editor.source.text,draft=b.documents[c.id].source,message=s.message,
        source_index=root.content.editor.source.index,reference_actions=reference.actions~=nil,
        resolution=p.display_resolution,scale=p.display_scale,location=root.location}
    end
  end
  helpers.write_file('reference-client-state.json',helpers.table_to_json({tick=event.tick,players=snapshots,
    saved=c.saved_source,revision=c.saved_revision,active_source=c.active and c.active.source,run=c.run_id,
    state=c.state,status=c.status,shell=c.shell,database=registry.record(f.db).database,topics=help.topics}),false)
end
return M
