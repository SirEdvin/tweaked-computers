-- Packaged native engine and real entities/services; GUI/player delivery is mocked.
-- Explicit fixture ticks/energy are semantic evidence, not native-client latency.
local contracts=require('tests.editor_contract')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local shell=require('scripts.runtime.shell')
local compiler=require('scripts.runtime.compiler')
local sandbox=require('scripts.runtime.sandbox')
local codec=require('scripts.runtime.shell-values')
local admission=require('scripts.runtime.admission')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local presentation=require('scripts.monitor-presentation')
local logic=require('scripts.services.logic')
local peripheral=require('scripts.services.peripheral')
local kv=require('scripts.services.kv')
local snapshots=require('scripts.lifecycle-data')
local configurator=require('scripts.services.configurator')
local editor=require('scripts.ui.editor')
local model=require('scripts.ui.editor-model')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local M={}
function M.run()
  local previous=storage.tweaked_computers
  storage.tweaked_computers=nil; registry.initialize()
  local surface=game.surfaces[1]; local original_game=game; local tick=1000; local total=0
  local function build(kind,x,y)
    local rec=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
    lifecycle.power_entity(rec).energy=1000000; rec.powered=true; return rec
  end
  local rec=build('computer',0,0); local db=build('kv',3,0); local out=build('logic',6,0); local mon=build('monitor',0,4)
  local config=build('configurator',9,0)
  local inserter=assert(surface.create_entity{name='inserter',position={12,0},force='player'})
  assert(lifecycle.connector(config,'targets','green').connect_to(inserter.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
  for _,device in ipairs({db,out,mon,config}) do assert(lifecycle.connector(rec,'network','red').connect_to(lifecycle.connector(device,'network','red'))) end
  for _=1,200 do monitor.reconcile(tick,function() end); if not registry.get().monitors.job then break end end
  local screen=assert(monitor.resolve(mon))
  local a=contracts.player(3001,rec.body); local b=contracts.player(3002,rec.body)
  game={tick=tick,get_player=function(i) return i==a.index and a or i==b.index and b or nil end,connected_players={a,b}}
  local ok,problem=pcall(function()
    assert(editor.open(a,rec.id)); assert(editor.open(b,rec.id))
    local f=a.gui.screen[editor.frame_name]; local other=b.gui.screen[editor.frame_name]
    local function tab(p,gui,index)
      gui.content.selected_tab_index=index; editor.on_tab{player_index=p.index,element=gui.content,tick=tick}
    end
    tab(a,f,2); tab(b,other,2)
    local function group(name,fn) tick=tick+1; game.tick=tick; fn(); total=total+1; log('TC_CONTRACT shell-'..name) end
    local function submit(text,p,gui)
      p=p or a; gui=gui or f
      editor.refresh(p)
      local input=gui.content.console.prompt.command
      input.text=text; editor.on_text{player_index=p.index,element=input,tick=tick}
      editor.on_confirmed{player_index=p.index,element=input,tick=tick}
      assert(input.text=='','ingress failed: '..tostring(gui.content.console.shell_status.caption))
    end
    local function dispatch()
      rec.power_checked_tick=tick
      assert(scheduler.dispatch(rec,tick),'shell did not dispatch')
      assert(not scheduler.dispatch(rec,tick),'duplicate same-tick dispatch')
    end
    local function execute(text,expect,p,gui)
      submit(text,p,gui); dispatch()
      local d=rec.shell.diagnostic
      assert((d==nil)==(expect~=false),text..': '..(d and d.message or 'unexpected success'))
      return d
    end
    group('globals-locals-nil-false-exact-output',function()
      execute('x = 5; local y = 6')
      tick=tick+1; execute('print(x,y,false,nil)',true,b,other)
      assert(rec.logs[#rec.logs].text:find('5\tnil\tfalse\tnil',1,true))
      local raw=rec.logs[#rec.logs]; local text=raw.text; local bytes=rec.log_bytes
      editor.refresh(a)
      assert(f.content.console.output.text:find('output: 5 nil false nil',1,true),'Console exposed print tab separators to the native font')
      assert(not f.content.console.output.text:find('\t',1,true),'Console retained unsupported tab glyphs')
      assert(rec.logs[#rec.logs]==raw and raw.text==text and rec.log_bytes==bytes,'display formatting mutated stored log bytes')
      tick=tick+1; execute('print("left\\tright")')
      assert(rec.logs[#rec.logs].text:find('left\tright',1,true),'explicit guest tab was changed before storage')
      runtime.log(rec,'program\tmessage\nnext\tline',tick)
      editor.refresh(a)
      assert(f.content.console.output.text:find('output: left right',1,true))
      assert(f.content.console.output.text:find('program message\nnext line',1,true),'saved-program tabs or newlines displayed incorrectly')
      assert(not f.content.console.output.text:find('\t',1,true))
      tick=tick+1; local n=#rec.logs; execute('print(false,nil,3)'); assert(#rec.logs==n+2)
      tick=tick+1; execute('nil'); assert(rec.logs[#rec.logs].text:find('output: nil',1,true))
      tick=tick+1; execute('false'); assert(rec.logs[#rec.logs].text:find('output: false',1,true))
      tick=tick+1; n=#rec.logs; execute('print()'); assert(#rec.logs==n+2 and rec.logs[#rec.logs].text:match(' output: $'))
      local committed=rec.shell.values
      tick=tick+1; assert(execute('print(string.rep("x",'..limits.console_bytes..'))',false).code=='E_LIMIT')
      assert(rec.shell.values==committed)
      for _,entry in ipairs(rec.logs) do assert(#entry.text<=limits.console_bytes and not entry.text:find(string.rep('x',256),1,true),'partial oversized print was appended') end
    end)
    group('follow-off-and-focused-draft-refresh-stability',function()
      local c=f.content.console; local source=f.content.editor.source; local writes=source.text_writes
      c.follow.state=false; editor.on_checked{player_index=a.index,element=c.follow,tick=tick}
      local frozen=c.output.text
      execute('print("new shell output")')
      editor.refresh(a); assert(c.output.text==frozen and source.text_writes==writes)
      local input=c.prompt.command; input.text='unfinished'
      editor.on_text{player_index=a.index,element=input,tick=tick}
      local count=input.text_writes
      editor.resize(a); editor.refresh(a)
      assert(c.prompt.command==input and input.text=='unfinished' and input.text_writes==count)
      c.follow.state=true; editor.on_checked{player_index=a.index,element=c.follow,tick=tick}
      assert(c.output.text~=frozen and source.text_writes==writes)
      local scrolls=c.output.scrolls or 0
      editor.resize(a); editor.refresh(a)
      assert(c.output.scrolls>scrolls,'Follow did not settle scrolling after native layout changed')
      c.follow.state=false; editor.on_checked{player_index=a.index,element=c.follow,tick=tick}
      scrolls=c.output.scrolls
      editor.resize(a); editor.refresh(a)
      assert(c.output.scrolls==scrolls,'Follow-off moved the selectable snapshot')
      c.follow.state=true; editor.on_checked{player_index=a.index,element=c.follow,tick=tick}
    end)
    group('aliases-cycles-scalar-keys-and-local-functions',function()
      execute('a = {}; b = a; a.self = a; a[false] = 7; local function twice(x) return x*2 end; answer=twice(4)')
      tick=tick+1; execute('b.value=9; assert(a.value==9 and a.self==a and a[false]==7 and answer==8)')
    end)
    group('atomic-environment-and-real-effects-before-error',function()
      local graph=rec.shell.values
      execute('computer.setState("effect",11); x=99; error("after effect")',false)
      assert(rec.state.effect==11 and rec.shell.values==graph and rec.status=='stopped')
      tick=tick+1; execute('assert(x==5)')
    end)
    group('unsupported-retention-and-forged-binding-record',function()
      local graph=rec.shell.values
      assert(execute('f=function() end',false).code=='E_UNSUPPORTED'); assert(rec.shell.values==graph)
      tick=tick+1; execute('fake={name="'..db.id..'",wire="red",generation=1}; assert(not pcall(peripheral.getName,fake))')
    end)
    group('reserved-host-names-and-saved-program-boundary',function()
      for _,text in ipairs({'game.tick','_ENV','_G','peripheral = {}','print=1','storage','load("x")'}) do
        tick=tick+1; execute(text,false)
      end
      assert(not compiler.compile('x=1',admission.context(admission.new(),'program-boundary',0)))
      local rejected,location=compiler.compile('  game',admission.context(admission.new(),'shell-location',0),'shell')
      assert(not rejected and location.line==1 and location.column==3,'expression prefix leaked into source coordinates')
      local plan=assert(compiler.compile('false',admission.context(admission.new(),'shell-boundary',0),'shell'))
      assert(not compiler.run(plan,'start',{}, {},admission.context(admission.new(),'mode',0)))
    end)
    group('syntax-diagnostic-description-and-source-location',function()
      for _,case in ipairs({{source='x =',column=4},{source='local x = )',column=11}}) do
        local plan,problem=compiler.compile(case.source,admission.context(admission.new(),'shell-syntax',0),'shell')
        assert(not plan and problem.code=='E_PROGRAM' and problem.line==1 and problem.column==case.column,
          'syntax diagnostic lost original command position: '..tostring(problem and problem.column))
        assert(#problem.message>20,'syntax diagnostic omitted the parser explanation: '..problem.message)
      end
    end)
    group('authentic-facade-captured-method-and-generation-revocation',function()
      execute('p=peripheral.wrap("'..db.id..'","red"); put=p.set; get=p.get; p.set("shell","17")')
      tick=tick+1; execute('assert(peripheral.getName(p)=="'..db.id..'"); assert(get==p.get and put==p.set); assert(get("shell")=="17"); put("shell","18")')
      db.generation=db.generation+1; tick=tick+1; assert(execute('get("shell")',false).code=='E_UNREACHABLE')
    end)
    group('monitor-model-and-independent-selection-ownership',function()
      execute('m=peripheral.wrap("'..screen.id..'","red"); m.write("Shell"); peripheral.setMonitorSyncGroup({{name="'..screen.id..'",wire="red"}})')
      assert(rec.shell.monitor_sync and not rec.monitor_sync)
      tick=tick+1; execute('assert(peripheral.getMonitorSyncGroup().status~="none")')
      local marker={key='synthetic-other-owner',run_id='other-run'}
      rec.monitor_sync=marker -- Explicit synthetic ownership witness, not a running program.
      local revision=screen.model.revision
      assert(lifecycle.connector(rec,'network','red').disconnect_from(lifecycle.connector(mon,'network','red')))
      presentation.tick(tick,function() end)
      assert(not rec.shell.monitor_sync and rec.monitor_sync==marker and screen.model.revision==revision,'idle stopped-shell revocation changed another owner or model')
      rec.monitor_sync=nil
      assert(lifecycle.connector(rec,'network','red').connect_to(lifecycle.connector(mon,'network','red')))
    end)
    group('real-configurator-effects-and-normal-Data-boundary',function()
      execute('local cfg=peripheral.wrap("'..config.id..'","red"); local ds=cfg.getDevices("green"); assert(#ds==1); cfg.setConfiguration(ds[1].id,{set={circuit_enable_disable=true}},"green")')
      assert(inserter.get_control_behavior().circuit_enable_disable==true)
      tick=tick+1; execute('local cfg=peripheral.wrap("'..config.id..'","red"); local ds=cfg.getDevices("green"); cfg.setConfiguration(ds[1].id,{set={circuit_enable_disable=false}},"green"); error("after native write")',false)
      assert(inserter.get_control_behavior().circuit_enable_disable==false)
    end)
    group('handler-only-refusal-every-route',function()
      for _,text in ipairs({'computer.every(60,"sample")','computer.stop()',
        'peripheral.call("'..out.id..'","red","subscribe",{},"sample")',
        'local q=peripheral.wrap("'..out.id..'","red"); local sub=q.subscribe; sub({},"sample")'}) do
        tick=tick+1; assert(execute(text,false).code=='E_UNSUPPORTED')
      end
      assert(next(rec.timers)==nil and next(rec.subscriptions)==nil and rec.status=='stopped')
    end)
    group('logic-output-live-stopped-owner-and-exact-cleanup',function()
      execute('local q=peripheral.wrap("'..out.id..'","red"); q.setOutput({{signal={type="recipe",name="iron-plate"},count=7}}); assert(q.getOutput()[1].signal.type=="recipe" and q.getOutput()[1].count==7); assert(q.readSignal("red",{type="recipe",name="iron-plate"})==0); assert(#q.readSignals("red")==0)')
      assert(out.output_owner.kind=='shell' and out.output_bank[1].signal.type=='recipe')
      local bank,owner=out.output_bank,out.output_owner
      tick=tick+1
      execute('local q=peripheral.wrap("'..out.id..'","red"); for _,bad in ipairs({"both","blue",false}) do local ok,e=pcall(q.readSignals,bad); assert(not ok and e.code=="E_ARGUMENT"); ok,e=pcall(q.readSignal,bad,{type="recipe",name="iron-plate"}); assert(not ok and e.code=="E_ARGUMENT"); for _,method in ipairs({"getOutput","setOutput","clearOutput"}) do ok,e=pcall(peripheral.call,"'..out.id..'",bad,method,{}); assert(not ok and e.code=="E_ARGUMENT") end end; local ok,e=pcall(q.readSignals); assert(not ok and e.code=="E_ARGUMENT"); ok,e=pcall(q.readSignal,nil,{type="recipe",name="iron-plate"}); assert(not ok and e.code=="E_ARGUMENT"); ok,e=pcall(peripheral.call,"'..out.id..'",nil,"setOutput",{}); assert(not ok and e.code=="E_ARGUMENT")')
      assert(out.output_bank==bank and out.output_owner==owner and next(rec.subscriptions)==nil)
      tick=tick+1
      execute('peripheral.call("'..out.id..'","red","setOutput",{{signal={type="virtual",name="signal-A"},count=12}})')
      assert(out.output_owner.kind=='shell' and #out.output_bank==1)
      peripheral.check_outputs(tick,function() end)
      assert(out.output_owner and out.output_owner.kind=='shell')
      out.output_owner={computer_id=rec.id,kind='program',run_id='later-run',wire='red'}
      tick=tick+1; execute('error("cleanup")',false)
      assert(out.output_owner and out.output_owner.run_id=='later-run','shell cleared another principal output')
      lifecycle.clear_output(out)
    end)
    group('power-loss-cleans-under-exhaustion-without-discard-or-replay',function()
      execute('peripheral.call("'..out.id..'","red","setOutput",{})')
      local graph=rec.shell.values
      submit('x=999')
      local ctx=runtime.context(rec,tick)
      assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
      runtime.set_power(rec.id,false,tick)
      assert(rec.shell.values==graph and #rec.shell.pending==0 and not out.output_owner)
      tick=tick+1; runtime.set_power(rec.id,true,tick)
      execute('assert(x==5)')
    end)
    group('blank-invalid-paste-bounds-draft-and-duplicate-submit',function()
      local input=f.content.console.prompt.command
      input.text='   '; editor.on_text{player_index=a.index,element=input,tick=tick}
      local seq=registry.get().next_sequence; editor.on_confirmed{player_index=a.index,element=input,tick=tick}
      assert(registry.get().next_sequence==seq)
      input.text='draft'; editor.on_text{player_index=a.index,element=input,tick=tick}
      for _,bad in ipairs({'one\ntwo',string.rep('x',limits.shell_source_bytes+1)}) do
        input.text=bad; editor.on_text{player_index=a.index,element=input,tick=tick}; assert(input.text=='draft')
      end
      submit('x=6'); local count=#rec.shell.pending
      editor.on_click{player_index=a.index,element=f.content.console.prompt.execute,tick=tick}
      assert(#rec.shell.pending==count); dispatch()
    end)
    group('stale-hidden-other-window-and-independent-drafts',function()
      other.content.console.prompt.command.text='private draft'
      editor.on_text{player_index=b.index,element=other.content.console.prompt.command,tick=tick}
      tab(a,f,1); local input=f.content.console.prompt.command; local seq=registry.get().next_sequence
      input.text='x=999'; editor.on_text{player_index=a.index,element=input,tick=tick}; editor.on_confirmed{player_index=a.index,element=input,tick=tick}
      assert(registry.get().next_sequence==seq and model.session(b.index).shell_draft=='private draft')
      tab(a,f,2); submit('x=123'); a.opened={unrelated=true}; dispatch(); a.opened=f
      assert(rec.shell.status:find('Canceled',1,true)); tick=tick+1; execute('assert(x==6)')
    end)
    group('queue-capacity-and-fair-program-dispatch',function()
      runtime.save(rec.id,'return {api_version=1,handlers={start=function(e) computer.setState("neighbor",true); peripheral.setMonitorSyncGroup({{name="'..screen.id..'",wire="red"}}) end}}',0)
      assert(runtime.activate(rec.id,tick)); editor.refresh(a)
      for i=1,limits.shell_pending_entries do submit('x='..i) end
      local input=f.content.console.prompt.command; input.text='x=999'; editor.on_text{player_index=a.index,element=input,tick=tick}
      editor.on_confirmed{player_index=a.index,element=input,tick=tick}; assert(input.text=='x=999' and #rec.shell.pending==limits.shell_pending_entries)
      dispatch(); tick=tick+1; dispatch(); assert(rec.state.neighbor and rec.status=='running')
      for _=1,limits.shell_pending_entries do if shell.waiting(rec) then tick=tick+1; dispatch() end end
      local selection=rec.monitor_sync; assert(selection)
      tick=tick+1; assert(execute('peripheral.setMonitorSyncGroup({{name="'..screen.id..'",wire="red"}})',false).code=='E_BUSY')
      assert(rec.monitor_sync==selection,'shell conflict changed program selection')
    end)
    group('loop-failure-same-tick-credits-and-program-serviceability',function()
      execute('while true do end',false)
      assert(rec.shell.diagnostic.code=='E_BUDGET' and rec.status=='running')
      local ctx=runtime.context(rec,tick); local spent=ctx.machine.work
      assert(runtime.context(rec,tick).machine.work==spent)
      tick=tick+1; execute('assert(x==8)')
    end)
    group('failed-activation-and-automatic-fault-retain-values',function()
      local graph=rec.shell.values; local old=rec.saved_source; local session=rec.shell
      runtime.save(rec.id,'not valid Lua',rec.saved_revision)
      assert(not runtime.activate(rec.id,tick) and rec.shell==session and rec.shell.values==graph and rec.status=='running')
      runtime.fault(rec,{code='E_PROGRAM',message='fixture program fault'},tick)
      assert(rec.shell==session and rec.shell.values==graph)
      tick=tick+1; execute('assert(x==8)')
      runtime.save(rec.id,old,rec.saved_revision); assert(runtime.activate(rec.id,tick))
      assert(not rec.shell)
      tick=tick+1; rec.power_checked_tick=tick; assert(scheduler.dispatch(rec,tick))
    end)
    group('reset-confirmation-lifecycle-and-source-widget-stability',function()
      execute('x=1')
      local source=f.content.editor.source; local saved=rec.saved_source; local run=rec.run_id
      editor.on_click{player_index=a.index,element=f.content.console.prompt['reset-shell'],tick=tick}
      assert(rec.shell)
      editor.on_click{player_index=a.index,element=f.content.console.confirm_shell.buttons['confirm-shell'],tick=tick}
      assert(not rec.shell and rec.run_id==run and rec.saved_source==saved and rec.status=='running')
      editor.resize(a); editor.refresh(a); assert(f.content.editor.source==source)
      tick=tick+1; execute('assert(x==nil)')
      editor.refresh(b)
      editor.on_click{player_index=b.index,element=other.content.console.prompt['reset-shell'],tick=tick}
      assert(shell.reset(rec,'fixture'))
      editor.on_click{player_index=b.index,element=other.content.console.confirm_shell.buttons['confirm-shell'],tick=tick}
      assert(other.content.console.detail.text:find('E_BUSY',1,true),'stale Reset Shell feedback was hidden in another tab')
      assert(runtime.stop(rec.id) and rec.shell==nil)
    end)
    group('maximum-source-graph-and-binding-envelopes',function()
      assert(shell.reset(rec,'fixture')); editor.refresh(a)
      local maximum=limits.shell_value_bytes-87
      execute('payload=string.rep("x",'..maximum..')')
      tick=tick+1; execute('assert(#payload=='..maximum..')')
      local graph=rec.shell.values
      tick=tick+1; assert(execute('payload=payload.."x"',false).code=='E_LIMIT'); assert(rec.shell.values==graph)
      tick=tick+1; execute('payload=nil --'..string.rep('x',limits.shell_source_bytes-14))
      assert(shell.reset(rec,'fixture')); editor.refresh(a)
      local assignments={}
      for i=1,limits.shell_bindings do assignments[#assignments+1]='v'..i..'='..i end
      tick=tick+1; execute(table.concat(assignments,';'))
      graph=rec.shell.values
      tick=tick+1; assert(execute('overflow=true',false).code=='E_LIMIT'); assert(rec.shell.values==graph)
      assert(shell.reset(rec,'fixture')); editor.refresh(a)
    end)
    group('iterative-deep-graph-and-node-refusal',function()
      execute('deep={}; local c=deep; for i=1,300 do c.next={}; c=c.next end')
      tick=tick+1; execute('local c=deep; for i=1,300 do c=c.next end; assert(c~=nil)')
      local graph=rec.shell.values
      tick=tick+1; assert(execute('deep={}; local c=deep; for i=1,400 do c.next={}; c=c.next end',false).code=='E_LIMIT')
      assert(rec.shell.values==graph)
      tick=tick+1; execute('deep=nil')
    end)
    group('world-session-capacity-counts-idle-retained-records',function()
      assert(shell.reset(rec,'fixture')); editor.refresh(a)
      local placeholders={}
      for i=1,limits.shell_sessions do
        local c=build('computer',i*3,20); c.shell={version=1,id=c.id..'/fixture',pending={},pending_bytes=0}
        placeholders[#placeholders+1]=c
      end
      local input=f.content.console.prompt.command; input.text='x=1'
      editor.on_text{player_index=a.index,element=input,tick=tick}
      editor.on_confirmed{player_index=a.index,element=input,tick=tick}
      assert(not rec.shell and input.text=='x=1' and f.content.console.shell_status.caption:find('E_CAPACITY',1,true))
      for _,c in ipairs(placeholders) do c.shell=nil end
    end)
    group('transport-excludes-shell-without-changing-original-identity',function()
      execute('transport=42')
      local original=rec.shell
      local full=snapshots.computer_snapshot(rec,false); local settings=snapshots.settings(rec)
      assert(not full.shell and not settings.computer.shell and rec.shell==original)
      local copy=build('computer',0,12); snapshots.restore_computer(copy,full,false)
      assert(not copy.shell and rec.shell==original)
      snapshots.apply_settings(copy,settings); assert(not copy.shell and rec.shell==original)
    end)
    group('malformed-graphs-are-refused-without-publication',function()
      tick=tick+1; execute('x=1')
      local graph=rec.shell.values
      rec.shell.values={version=1,root=1,nodes={{kind='table',entries={{key='x',value={ref=2}}}}}}
      tick=tick+1; execute('x=2',false); assert(rec.shell.values~=graph)
      rec.shell.values=graph
      local s=rec.shell; s.version=99
      assert(not pcall(shell.session,rec)); assert(runtime.stop(rec.id) and rec.shell==s and s.version==99)
      s.version=1
    end)
    log('TC_CONTRACT_TOTAL '..total)
  end)
  game=original_game; storage.tweaked_computers=previous
  if not ok then error(problem,0) end
end
return M
