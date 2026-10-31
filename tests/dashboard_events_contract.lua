-- Real scheduler ticks and native wires; player/GUI authority uses explicit doubles.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local model=require('scripts.dashboard-model')
local data=require('scripts.runtime.data')
local ui=require('scripts.ui.dashboard')
local service=require('scripts.services.dashboard')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local limits=require('scripts.runtime.limits')
local players=require('tests.editor_contract')
local editor=require('scripts.ui.editor')
local peripheral=require('scripts.services.peripheral')
local network=require('scripts.network')
local M={}
local state
local function counts(c,second) return c.state.clicks or 0,second.state.clicks or 0 end
function M.start(panel)
  local player=players.player(2003,panel.body)
  player.connected=true
  local console=players.player(2004,panel.body); console.connected=true
  state={player=player,console=console,phase='register'}
end
function M.tick(c,second,third,panel,guest,tick)
  local s=assert(state); local real_game=game
  game=setmetatable({tick=tick,get_player=function(i) if i==s.player.index then return s.player end; if i==s.console.index then return s.console end; return real_game.get_player(i) end},
    {__index=function(_,key) return real_game[key] end})
  local ok,done=pcall(function()
    scheduler.tick(tick)
    local function activate()
      local session=registry.get().dashboard_sessions[s.player.index]
      return service.click(panel,1,'button',s.player.index,session.token,tick)
    end
    if s.phase=='register' then
      model.set_leaf(panel,1,'button',true,true,function() end)
      ui.open(s.player,panel.id); ui.tick(tick,function() end)
      guest(c,[[local r=peripheral.find('dashboard','red'); local g=peripheral.find('dashboard','green')
        computer.setState('red',r.subscribe('clicked')); computer.setState('green',g.subscribe('clicked'))
        local ok,e=pcall(computer.on,'dashboard_click','clicked'); assert(not ok and e.code=='E_ARGUMENT')]])
      guest(second,[[computer.setState('red',peripheral.find('dashboard','red').subscribe('clicked'))]])
      peripheral.reconcile_one(c,'green',tick,function() end)
      local native=assert(real_game.surfaces[1].create_entity{name='radar',position={9,0},force='player'})
      assert(lifecycle.connector(panel,'network','green').connect_to(native.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
      peripheral.reconcile_one(c,'green',tick,function() end)
      assert(c.network_views.green.diagnostic.code=='E_NETWORK_PENDING' and c.subscriptions[c.state.green],
        'incomplete native discovery retired a connected dashboard registration')
      network.adopt_tick(tick,function() end)
      local adopted=assert(registry.by_entity(native))
      peripheral.reconcile_one(c,'green',tick,function() end)
      assert(c.subscriptions[c.state.green] and not c.network_views.green.diagnostic)
      assert(registry.remove(adopted.id,'fixture-native-adoption')); native.destroy()
      guest(third,[[peripheral.find('dashboard','green').subscribe('clicked')]])
      assert(registry.get().topology_interests.computers[third.id])
      local prior=registry.get().topology_interests; local order={}
      for _,item in ipairs(prior.order) do if item.owner.computer~=third then order[#order+1]=item end end
      prior.order=order; prior.computers[third.id]=nil; prior.cursor=1; prior.version=1
      local owner=prior.computers[c.id]; local views=c.network_views; local ledger=registry.get().ledger
      local credits,sequence=ledger.total,registry.get().next_sequence
      registry.initialize()
      assert(registry.get().topology_interests==prior and prior.order==order and prior.version==2 and prior.computers[third.id],
        'version-one index migration omitted dashboard-only demand or replaced retained membership')
      assert(prior.computers[c.id]==owner and c.network_views==views and registry.get().ledger==ledger
        and ledger.total==credits and registry.get().next_sequence==sequence,'index migration changed accepted state/credits')
      local diagnostic=registry.get().scheduling_diagnostic
      prior.version=1; prior.order=false
      local initialized,result=pcall(registry.initialize)
      assert(initialized and result==registry.get() and prior.version==1 and prior.order==false
        and registry.get().scheduling_diagnostic.code=='E_UNSUPPORTED','malformed legacy index crashed or was rewritten during migration')
      prior.version=2; prior.order=order; registry.get().scheduling_diagnostic=diagnostic
      lifecycle.connector(third,'network','green').disconnect_all()
      peripheral.reconcile_one(third,'green',tick,function() end)
      assert(next(third.subscriptions)==nil and not registry.get().topology_interests.computers[third.id],
        'detachment before the first topology baseline retained registration or demand')
      assert(lifecycle.connector(third,'network','green').connect_to(lifecycle.connector(panel,'network','green')))
      assert(activate())
      assert(#c.queue==2 and #second.queue==1 and #third.queue==0)
      assert((c.state.clicks or 0)==0 and (second.state.clicks or 0)==0,'GUI handler dispatched a guest callback')
      s.activation=tick; s.phase='fanout'
    elseif s.phase=='fanout' then
      if #c.queue>0 or #second.queue>0 then return end
      assert(c.state.clicks==2 and second.state.clicks==1 and not third.state.clicks)
      assert(c.state.last.wire=='green' and c.state.last.tick==s.activation and c.state.last.tab==1
        and c.state.last.button=='button' and c.state.last.peripheral==panel.id and c.state.last.player_index==s.player.index)
      assert(activate())
      guest(c,[[assert(peripheral.find('dashboard','red').unsubscribe(computer.getState('red'))) ]])
      assert(#c.queue==1 and c.queue[1].event.wire=='green')
      s.phase='cancel'
    elseif s.phase=='cancel' then
      if #c.queue>0 or #second.queue>0 then return end
      assert(c.state.clicks==3 and second.state.clicks==2)
      s.c,s.second=counts(c,second)
      assert(activate())
      for _,rec in ipairs({panel,c}) do
        rec.availability_version=99
        assert(not service.validate(c,c.queue[1],function() end),'dispatch accepted an unavailable endpoint')
        rec.availability_version=1
      end
      lifecycle.connector(c,'network','green').disconnect_all()
      s.detached=tick; s.phase='path'
    elseif s.phase=='path' then
      if #c.queue>0 or #second.queue>0 then return end
      assert(c.state.clicks==s.c and second.state.clicks==s.second+1,'detached recipient received the queued click')
      if c.subscriptions[c.state.green] then
        assert(tick-s.detached<limits.topology_latency_ticks,'dashboard-only registration survived definitive detachment')
        return
      end
      assert(not registry.get().topology_interests.computers[c.id],'last dashboard registration retained topology demand')
      s.second=second.state.clicks
      assert(lifecycle.connector(c,'network','green').connect_to(lifecycle.connector(panel,'network','green')))
      assert(activate() and #c.queue==0,'reconnection revived a retired dashboard registration')
      s.second=s.second+1 -- The still-authorized second computer receives this click.
      guest(c,[[local p=peripheral.find('dashboard','green'); assert(not p.unsubscribe(computer.getState('green'))); computer.setState('green',p.subscribe('clicked'))]])
      local body=assert(real_game.surfaces[1].create_entity{name='tc-dashboard-shell',position={9,3},force='player'})
      lifecycle.on_built{entity=body}; local extra=assert(registry.by_entity(body))
      assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(extra,'network','red')))
      model.set_tab(extra,1,{title='Replacement',content={type='button',id='button',text='Go'}},function() end)
      s.extra=extra.id; s.phase='replacement-ready'
    elseif s.phase=='replacement-ready' then
      local extra=assert(registry.record(s.extra)); if not extra.powered then return end
      guest(c,"peripheral.wrap("..string.format('%q',extra.id)..",'red').subscribe('clicked')")
      ui.open(s.player,extra.id); ui.tick(tick,function() end)
      local session=registry.get().dashboard_sessions[s.player.index]
      assert(service.click(extra,1,'button',s.player.index,session.token,tick) and #c.queue==1 and #second.queue==0)
      local old_unit=extra.body.unit_number; assert(extra.body.die())
      local body=assert(real_game.surfaces[1].create_entity{name='tc-dashboard-shell',position={9,3},force='player'})
      lifecycle.on_built{entity=body}; local replacement=assert(registry.by_entity(body))
      assert(replacement.id~=extra.id and replacement.body.unit_number~=old_unit)
      model.set_tab(replacement,1,{title='Replacement',content={type='button',id='button',text='Go'}},function() end)
      s.replacement=replacement.id; s.phase='replacement-check'
    elseif s.phase=='replacement-check' then
      if #c.queue>0 then return end
      assert(c.state.clicks==s.c and second.state.clicks==s.second,'same-position replacement received the old click')
      lifecycle.remove(s.replacement,'fixture-replacement-cleanup',true); service.revoke(c,s.extra,'red')
      ui.open(s.player,panel.id); ui.tick(tick,function() end)
      s.case=1; s.phase='invalidate'
    elseif s.phase=='invalidate' then
      if #c.queue>0 or #second.queue>0 then return end
      assert((c.state.clicks or 0)==s.c and (second.state.clicks or 0)==s.second,'revoked delivery executed')
      if s.restore then
        s.restore(); s.restore=nil
        if not registry.get().dashboard_sessions[s.player.index] then ui.open(s.player,panel.id); ui.tick(tick,function() end) end
      end
      local cases={
        function() model.set_leaf(panel,1,'button',false,true,function() end); return function() model.set_leaf(panel,1,'button',true,true,function() end) end end,
        function() s.player.connected=false; return function() s.player.connected=true end end,
        function() s.player.force={index=panel.force_index+1}; return function() s.player.force=panel.body.force end end,
        function() s.player.surface={index=panel.surface_index+1}; return function() s.player.surface=panel.body.surface end end,
        function() s.player.controller_type=defines.controllers.ghost; return function() s.player.controller_type=defines.controllers.god end end,
        function() s.player.can_reach_entity=function() return false end; return function() s.player.can_reach_entity=function() return true end end end,
        function() s.player.permission_group={allows_action=function() return false end}; return function() s.player.permission_group=nil end end,
        function() local tab=panel.dashboard.tabs['1']; local definition=data.copy(tab.definition)
          definition.title='Replacement'; model.set_tab(panel,1,definition,function() end)
          return function() ui.open(s.player,panel.id); ui.tick(tick,function() end) end end,
        function() ui.close(s.player); return function() ui.open(s.player,panel.id); ui.tick(tick,function() end) end end,
      }
      local change=cases[s.case]
      if change then
        assert(activate()); s.restore=change(); s.case=s.case+1
      else
        -- All prior denied clicks are gone; none is retried after restoration.
        assert(activate()); runtime.retire(second,'stopped','fixture')
        assert(next(second.subscriptions)==nil and #second.queue==0)
        s.phase='retire'
      end
    elseif s.phase=='retire' then
      if #c.queue>0 then return end
      assert(c.state.clicks==s.c+1 and second.state.clicks==s.second)
      assert(runtime.activate(second.id,tick)); s.phase='restart'
    elseif s.phase=='restart' then
      if #second.queue>0 then return end
      guest(second,[[peripheral.find('dashboard','red').subscribe('clicked')]])
      local before_c,before_second=counts(c,second)
      -- Fan-out refusal is pre-publication: a short allowance makes no queue prefix.
      local ceiling=limits.maintenance_work_per_tick; limits.maintenance_work_per_tick=1
      local accepted=activate(); limits.maintenance_work_per_tick=ceiling
      assert(not accepted and #c.queue==0 and #second.queue==0)
      assert((c.state.clicks or 0)==before_c and (second.state.clicks or 0)==before_second)
      s.c,s.second=before_c,before_second; s.phase='overflow'
    elseif s.phase=='overflow' then
      for i=1,limits.event_queue_entries do assert(runtime.enqueue(c,'clicked',{name='fixture'},tick,function() end)) end
      assert(activate())
      assert(c.status=='faulted' and c.diagnostic.code=='E_CAPACITY' and #c.queue==0 and next(c.subscriptions)==nil)
      assert(#second.queue==1 and second.status=='running','one full queue blocked another subscriber')
      s.phase='finish'
    elseif s.phase=='finish' then
      if #second.queue>0 then return end
      assert(c.state.clicks==s.c and second.state.clicks==s.second+1)
      assert(runtime.activate(c.id,tick)); ui.close(s.player)
      assert(editor.open(s.console,third.id))
      local frame=assert(s.console.gui.screen[editor.frame_name])
      frame.content.selected_tab_index=2; editor.on_tab{player_index=s.console.index,element=frame.content,tick=tick}
      local input=frame.content.console.prompt.command
      input.text="peripheral.find('dashboard','red').subscribe('clicked')"
      editor.on_text{player_index=s.console.index,element=input,tick=tick}
      editor.on_confirmed{player_index=s.console.index,element=input,tick=tick}
      assert(input.text=='' and #third.shell.pending==1)
      s.phase='console'
    elseif s.phase=='console' then
      if #third.shell.pending>0 then return end
      assert(third.shell.diagnostic and third.shell.diagnostic.code=='E_UNSUPPORTED' and next(third.subscriptions)==nil)
      editor.on_player_unavailable{player_index=s.console.index}
      log('TC_DASHBOARD_EVENTS scheduled-two-colors-all-subscribers-cancel-retire-authority-layout-overflow-no-backlog')
      return true
    end
  end)
  game=real_game
  assert(ok,done)
  if done then state=nil end
  return done
end
return M
