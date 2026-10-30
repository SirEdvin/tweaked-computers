-- Two cold engine processes; player/GUI delivery is explicitly table-backed.
local contracts=require('tests.editor_contract')
local registry=require('scripts.registry')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
local loaded=false
local old_source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.after(8,'later')
end

function later(e) computer.setState('once',(computer.getState('once') or 0)+1) end]]
local saved_source=contracts.source(41)
local draft_source=contracts.source(43)
local function plain(value,seen)
  local typ=type(value); assert(typ~='function' and typ~='thread','executable persistence')
  if typ~='table' or value.object_name then return end
  assert(not getmetatable(value),'persisted metatable')
  if seen[value] then return end; seen[value]=true
  for k,v in pairs(value) do plain(k,seen); plain(v,seen) end
end
local function snapshot()
  local f=storage.tc06_fixture; local r=registry.get(); local rec=registry.record(f.id)
  local s,b=model.session(f.player); local d=b.documents[rec.id]; local m=r.ledger.machines[rec.id]
  return {id=rec.id,unit=rec.body.unit_number,port=rec.children.network.unit_number,run=rec.run_id,
    active_source=rec.active.source,active_revision=rec.active.revision,saved_source=rec.saved_source,
    saved_revision=rec.saved_revision,draft=d.source,base_source=d.base_source,base_revision=d.base_revision,
    token=s.token,boots=rec.state.boots,ledger_tick=r.ledger.tick,total=r.ledger.total,compile=m.compile,
    work=m.work,allocations=m.allocations,scheduler_tick=r.scheduler.last_tick,sequence=r.next_sequence,
    tab=s.tab,focus=s.focus,before_focus=s.before_focus,follow=s.follow,search=s.search,category=s.category,topic=s.topic,
    review_source=s.review and s.review.source,review_revision=s.review and s.review.revision,
    logs=serpent.line(rec.logs),log_bytes=rec.log_bytes}
end
local function frozen()
  local f=storage.tc06_fixture; local now=snapshot()
  for key,value in pairs(f.snapshot) do assert(now[key]==value,'cold editor changed '..key) end
  local rec=registry.record(f.id)
  assert(rec.active.source==old_source and rec.saved_source==saved_source and not rec.state.value and not rec.state.once)
  local n=0; for id,timer in pairs(rec.timers) do n=n+1; assert(id==f.timer and timer.deadline==f.deadline) end
  assert(n==1 and #rec.queue==0); plain(registry.get(),{})
end
function M.run()
  contracts.run()
  storage.tweaked_computers=nil; registry.initialize()
  local surface=game.surfaces[1]
  local body=assert(surface.create_entity{name='tc-computer',position={0,0},force='player'})
  local rec=assert(lifecycle.build(body))
  assert(surface.create_entity{name='substation',position={0,4},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={3,4},force='player'})
  supply.power_production=1000000; supply.power_usage=0
  local player=contracts.player(1001,body)
  assert(editor.open(player,rec.id))
  local f=player.gui.screen[editor.frame_name]
  local original_game=game
  game={get_player=function() return player end,tick=original_game.tick}
  local ok,e=pcall(function()
    f.content.editor.source.text=old_source
    editor.on_text{player_index=player.index,element=f.content.editor.source,tick=original_game.tick}
    editor.on_click{player_index=player.index,element=f.content.editor.actions.save,tick=original_game.tick}
    editor.on_click{player_index=player.index,element=f.content.editor.actions.activate,tick=original_game.tick}
  end)
  game=original_game; if not ok then error(e,0) end
  assert(rec.saved_revision==1 and rec.active.revision==1 and rec.active.source==old_source)
  storage.tc06_fixture={phase='armed',id=rec.id,player=player.index,start_tick=game.tick}
end
function M.on_load()
  loaded=true
  if storage.tc06_fixture.phase=='frozen' then frozen(); log('TC_COLD_ON_LOAD_UNCHANGED editor-draft-active-saved-ledger') end
end
function M.on_tick(event)
  local f=storage.tc06_fixture
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    frozen(); loaded=false
    local rec=registry.record(f.id)
    local ctx=runtime.context(rec,f.snapshot.ledger_tick)
    assert(ctx.machine.compile==f.snapshot.compile and ctx.ledger.total==f.snapshot.total)
    assert(not admission.reserve(ctx,'compile',limits.compile_work+1-ctx.machine.compile))
    assert(ctx.machine.compile==f.snapshot.compile and ctx.ledger.total==f.snapshot.total)
    local player=contracts.player(f.player,rec.body)
    assert(editor.open(player,rec.id)); local gui=player.gui.screen[editor.frame_name]
    assert(gui.content.editor.source.text==draft_source and rec.active.source==old_source and rec.saved_source==saved_source)
    assert(gui.content.selected_tab_index==1 and not model.session(player.index).focus,'explicit reopen starts in Editor')
    local original_game=game
    game={get_player=function() return player end,tick=event.tick}
    gui.content.selected_tab_index=2
    local ok,e=pcall(editor.on_tab,{player_index=player.index,element=gui.content,tick=event.tick})
    game=original_game; if not ok then error(e,0) end
    assert(gui.content.console.output.text==f.console,'cold Console changed retained elapsed timestamps')
    assert(serpent.line(rec.logs)==f.snapshot.logs and rec.log_bytes==f.snapshot.log_bytes)
    model.close(player.index,model.session(player.index).token); gui.destroy()
    f.phase='resumed'
  elseif f.phase=='armed' then
    loaded=false; scheduler.tick(event.tick)
    local rec=registry.record(f.id)
    if not rec.state.boots then assert(event.tick<f.start_tick+60,'native power boot deadline'); return end
    assert(rec.status=='running' and rec.state.boots==1)
    local player=contracts.player(f.player,rec.body); local s=model.session(player.index)
    model.edit(player,s.token,saved_source); model.action(player,s.token,'save',event.tick)
    model.edit(player,s.token,draft_source)
    -- Table-backed real UI routes: retain bounded presentation/review state in
    -- the same cold save as dirty/saved/active sources and spent credits.
    assert(editor.open(player,rec.id)); local gui=player.gui.screen[editor.frame_name]
    local original_game=game
    game={get_player=function() return player end,tick=event.tick}
    local ok,e=pcall(function()
      local function tab(index)
        gui.content.selected_tab_index=index
        editor.on_tab{player_index=player.index,element=gui.content,tick=event.tick}
      end
      tab(4); local search=gui.content.reference.filters.search; search.text='state'
      editor.on_text{player_index=player.index,element=search,tick=event.tick}
      local category=gui.content.reference.filters.category; category.selected_index=4
      editor.on_selection{player_index=player.index,element=category,tick=event.tick}
      runtime.log(rec,'retained\tzero\nnext line',59)
      runtime.log(rec,'retained long-hour',21600000)
      tab(2); gui.content.console.follow.state=false
      f.console=gui.content.console.output.text
      assert(f.console=='[00:00:00] retained zero\nnext line\n[100:00:00] retained long-hour')
      editor.on_checked{player_index=player.index,element=gui.content.console.follow,tick=event.tick}
      tab(5)
      editor.on_click{player_index=player.index,element=gui.content.maintenance.review_actions.review,tick=event.tick}
      editor.on_click{player_index=player.index,element=gui.title.toggle_focus,tick=event.tick}
    end)
    game=original_game; if not ok then error(e,0) end
    local retained=model.session(player.index)
    assert(retained.focus and retained.tab==1 and retained.before_focus==5 and retained.follow==false and retained.search=='state')
    assert(rec.saved_revision==2 and rec.active.revision==1)
    for id,timer in pairs(rec.timers) do f.timer=id; f.deadline=timer.deadline end
    assert(f.timer)
    f.snapshot=snapshot(); f.phase='frozen'; f.freeze_tick=event.tick; plain(registry.get(),{})
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if f.phase=='resumed' then
    scheduler.tick(event.tick)
    local rec=registry.record(f.id)
    assert(rec.status=='running' and rec.state.boots==1 and rec.active.source==old_source)
    if event.tick>=f.deadline+2 then
      assert(rec.state.once==1 and not rec.state.value and next(rec.timers)==nil)
      local _,b=model.session(f.player)
      assert(b.documents[f.id].source==draft_source and rec.saved_source==saved_source)
      f.phase='done'; log('TC_COLD_OK editor-drafts saved-active-divergence no-startup-replay once-only real-powered-body')
    end
  end
end
return M
