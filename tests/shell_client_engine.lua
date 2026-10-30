-- Opt-in native-client/late-join scene. The observer never submits guest source.
-- Use a copied package with the tc-smoke production fixture setting; never a
-- player save. All ordinary production GUI events, services and ticks remain real.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local editor=require('scripts.ui.editor')
local monitor=require('scripts.services.monitor')
local defs=require('scripts.device-definitions')
local M={}
function M.run()
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true)
    remote.call('freeplay','set_disable_crashsite',true)
  end
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({0,0},2); surface.force_generate_chunk_requests()
  surface.always_day=true
  local function build(kind,x,y)
    return assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
  end
  local c=build('computer',0,0); local db=build('kv',3,0)
  local tiles={build('monitor',0,4),build('monitor',1,4),build('monitor',0,5),build('monitor',1,5)}
  local logic=build('logic',6,0); local config=build('configurator',9,0)
  for _,r in ipairs({db,logic,config,tiles[1]}) do
    assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(r,'network','red')))
  end
  local pole=assert(surface.create_entity{name='substation',position={4,4},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={7,4},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  local source='function start(e) computer.every(30,"beat") end\n\nfunction beat(e) computer.setState("heartbeat",(computer.getState("heartbeat") or 0)+1) end'
  runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  storage.tc_shell_client={computer=c.id,db=db.id,monitor_tile=tiles[1].id,logic=logic.id,configurator=config.id,start=game.tick,supply=supply,pole=pole}
end
function M.on_player_joined(event)
  local f=storage.tc_shell_client; local p=game.get_player(event.player_index)
  if not f or not p then return end
  p.teleport({0,-2},game.surfaces[1]); p.zoom=1
  p.print('Isolated live Console scene. Open Console; use the exact monitor name in Peripherals. No history. Commands have real effects.')
  editor.open(p,f.computer)
end
function M.on_tick(event)
  scheduler.tick(event.tick)
  if event.tick%15~=0 then return end
  local f=storage.tc_shell_client; local c=registry.record(f.computer); local tile=registry.record(f.monitor_tile)
  local display=tile and monitor.resolve(tile)
  local snapshot={tick=event.tick,computer=c.id,program=c.status,run=c.run_id,state=c.state,
    saved_source=c.saved_source,saved_revision=c.saved_revision,active=c.active,
    shell=c.shell,logs=c.logs,monitor=display and display.id,monitor_model=display and display.model,
    db=f.db,logic=f.logic,configurator=f.configurator,players={}}
  for _,p in pairs(game.connected_players) do
    local frame=p.gui.screen[editor.frame_name]
    local input=frame and frame.content and frame.content.console and frame.content.console.prompt.command
    local console=frame and frame.content and frame.content.console
    snapshot.players[#snapshot.players+1]={index=p.index,opened=frame and p.opened==frame or false,
      command=input and input.text,tab=frame and frame.content and frame.content.selected_tab_index,
      follow=console and console.follow.state,output=console and console.output.text}
  end
  helpers.write_file('shell-client-state.json',helpers.table_to_json(snapshot),false)
  if c.shell and c.shell.status~=f.last_status then
    f.last_status=c.shell.status
    helpers.write_file('shell-client-events.jsonl',helpers.table_to_json({tick=event.tick,status=f.last_status,diagnostic=c.shell.diagnostic})..'\n',true)
  end
end
return M
