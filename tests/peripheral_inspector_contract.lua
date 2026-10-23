-- Host contracts only; native input/rendering requires a connected client.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local kv=require('scripts.services.kv')
local model=require('scripts.ui.peripheral-inspector-model')
local players=require('tests.editor_contract')
local inspector=require('scripts.ui.peripheral-inspector')
local monitor=require('scripts.services.monitor')
local terminal=require('scripts.monitor-model')
local scheduler=require('scripts.scheduler')
local logic=require('scripts.services.logic')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local original=storage.tweaked_computers
  storage.tweaked_computers=nil
  registry.initialize()
  local surface=game.surfaces[1]
  local groups=0
  local function check(name,fn) fn(); groups=groups+1; log('TC_CONTRACT '..name) end
  local records={}
  for i,kind in ipairs({'kv','monitor','logic','configurator','recipe_searcher'}) do
    local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={i*8,100},force='player'})
    local rec=assert(lifecycle.build(body)); records[kind]=rec
  end
  check('inspector-five-family-authority-and-sessions',function()
    for _,rec in pairs(records) do
      local a=players.player(2001,rec.body); local b=players.player(2002,rec.body)
      assert(rec.body.operable)
      local s=model.open(a,rec.id); local other=model.open(b,rec.id)
      assert(model.current(a,s.token)==rec and s.token~=other.token)
      assert(not pcall(model.current,a,other.token))
      a.can_reach_entity=function() return false end
      assert(not pcall(model.current,a,s.token))
      assert(model.current(b,other.token)==rec)
      model.close(a.index,s.token); model.close(b.index,other.token)
    end
  end)
  check('inspector-byte-escape-is-literal-and-reversible',function()
    assert(model.escape('')=='""')
    assert(model.escape('a\0\255\\"\n[img=x]')=='"a\\x00\\xFF\\\\\\"\\x0A\\x5Bimg=x\\x5D"')
  end)
  check('inspector-kv-live-detached-expiry-and-integrity',function()
    local rec=records.kv
    local function spend() end
    kv.methods.set(nil,rec,nil,0,spend,'','')
    kv.methods.set(nil,rec,nil,0,spend,'expired','retained')
    kv.methods.expire(nil,rec,nil,0,spend,'expired',1)
    kv.methods.hset(nil,rec,nil,0,spend,'hash','\0','\255')
    local original=rec.database
    local view=kv.inspect(rec,60,spend)
    assert(#view.entries==2 and view.tick==60 and original.entries.expired)
    assert(view.entries[1].key=='' and view.entries[1].value=='')
    view.entries[2].fields[1].value='changed'
    assert(original.entries.hash.fields['\0']=='\255' and rec.database==original)
    local bad=rec.database; rec.database={version=99}
    assert(not pcall(kv.inspect,rec,60,spend)); assert(rec.database.version==99); rec.database=bad
  end)
  check('inspector-logic-regions-exist-before-any-query-admission',function()
    local p=players.player(2001,records.logic.body)
    local f=assert(inspector.open(p,records.logic.id))
    assert(f.details.logic_regions and f.details.logic_regions.inputs and f.details.logic_regions.outputs,
      'logic inputs and output must not remain blank while a query is pending')
    assert(not f.actions and not f.details.logic_regions.inputs.red_tick,'no sample trackers or Refresh controls')
    inspector.close(p)
  end)
  check('inspector-every-family-has-visible-pending-content-without-query-credits',function()
    for _,kind in ipairs({'kv','monitor','logic','configurator','recipe_searcher'}) do
      local p=players.player(2001,records[kind].body)
      local f=assert(inspector.open(p,records[kind].id))
      assert(#f.details.children>0,'initial '..kind..' inspector must never be blank')
      local function captions(e)
        if type(e.caption)=='table' then
          assert(e.caption[1]~='tc-inspector.copy-help' and not tostring(e.caption[1]):match('%-help$'),
            'long help belongs in tooltips/reference, not the main inspector')
        end
        for _,child in ipairs(e.children) do captions(child) end
      end
      captions(f); inspector.close(p)
    end
  end)
  check('inspector-owned-native-construction-copy-close-and-foreign-event',function()
    local real=game
    for _=1,200 do monitor.reconcile(real.tick,function() end) end
    local tick=0
    for _,rec in pairs(records) do
      tick=tick+15
      lifecycle.power_entity(rec).energy=defs.devices[rec.kind].watts/30
      local p=players.player(2001,rec.body)
      game={tick=tick,get_player=function(i) if i==p.index then return p end end,connected_players={p}}
      local ok,e=pcall(function()
        local f=assert(inspector.open(p,rec.id))
        assert(p.opened==f and f.identity.api_name.read_only)
        inspector.tick(tick)
        if rec.kind=='logic' then
          local s=model.session(p.index)
          assert(s.snapshot.details.red_tick==tick and not s.snapshot.details.green_tick)
          tick=tick+15; game.tick=tick; inspector.tick(tick)
        end
        assert(model.session(p.index).snapshot and not model.session(p.index).pending,'paid refresh must complete for '..rec.kind)
        if rec.kind~='monitor' then assert(f.identity.api_name.text==rec.id) end
        if rec.kind=='logic' then
          local s=model.session(p.index); local details=f.details.logic_regions
          local rows=details.inputs; local old=s.snapshot.details.red_tick
          tick=tick+15; game.tick=tick; inspector.tick(tick)
          tick=tick+15; game.tick=tick; inspector.tick(tick)
          assert(s.snapshot.details.red_tick>old and details==f.details.logic_regions and rows==details.inputs)
          assert(not rows.red_tick and not rows.green_tick and not details.outputs.output_tick)
        end
        inspector.on_click{player_index=p.index,element=f.identity.select_name}
        if rec.kind~='monitor' then assert(f.identity.api_name.focused and f.identity.api_name.selection[2]==#rec.id) end
        local s=model.session(p.index)
        if rec.kind=='kv' then
          local selected=s.key; s.redraw=true
          inspector.on_click{player_index=p.index,element=f.details.key_rows.key_2}
          assert(s.key==selected,'unpresented snapshot must refuse old row actions')
          s.redraw=false
        end
        inspector.on_click{player_index=p.index,element={valid=true,name='dismiss'}}
        assert(model.session(p.index)==s and f.valid)
        inspector.on_closed{player_index=p.index,element=f}
        assert(not f.valid and not model.session(p.index))
      end)
      game=real; assert(ok,e)
    end
  end)
  check('inspector-empty-red-input-completes-through-production-scheduler',function()
    local rec=records.logic; local real=game
    local p=players.player(2001,rec.body)
    local source=assert(surface.create_entity{name='constant-combinator',position={24,97},force='player'})
    assert(source.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(rec,'input','red')))
    local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
    game=setmetatable({tick=tick,connected_players={p},get_player=function(i) if i==p.index then return p end end},
      {__index=function(_,key) return real[key] end})
    local ok,e=pcall(function()
      local f=assert(inspector.open(p,rec.id)); local s=model.session(p.index)
      for _=1,90 do
        lifecycle.power_entity(rec).energy=defs.devices.logic.watts/30
        game.tick=tick; scheduler.tick(tick); tick=tick+1
        if s.snapshot and s.snapshot.details.red_tick and s.snapshot.details.green_tick and not s.pending and not s.redraw then break end
      end
      assert(s.snapshot and not s.pending and not s.redraw,
        'empty red input never finished: '..serpent.line({partial=s.logic_partial,snapshot=s.snapshot,pending=s.pending,redraw=s.redraw,ledger=registry.get().scheduler}))
      assert(s.snapshot.details.connected.red and not s.snapshot.details.connected.green)
      assert(#s.snapshot.details.red==0 and #s.snapshot.details.green==0 and #s.snapshot.details.output==0)
      assert(f.availability.caption[1]=='tc-inspector.available')
      inspector.close(p)
    end)
    game=real; source.destroy(); assert(ok,e)
  end)
  check('inspector-exact-physical-generation-and-permission-boundaries',function()
    local r=records.kv; local p=players.player(2001,r.body)
    for _,action in ipairs({defines.input_action.open_gui,defines.input_action.gui_click,defines.input_action.gui_text_changed}) do
      p.permission_group={allows_action=function(a) return a~=action end}
      assert(not pcall(model.open,p,r.id))
    end
    p.permission_group=nil
    local s=model.open(p,r.id); local generation=r.generation
    r.generation=generation+1; assert(not pcall(model.current,p,s.token)); r.generation=generation
    local force=p.force; p.force={index=999}; assert(not pcall(model.current,p,s.token)); p.force=force
    local surface=p.surface; p.surface={index=999}; assert(not pcall(model.current,p,s.token)); p.surface=surface
    assert(model.current(p,s.token)==r); model.close(p.index,s.token)
  end)
  check('inspector-independent-logic-admission-errors-power-and-retained-samples',function()
    local r=records.logic; local p=players.player(2001,r.body)
    lifecycle.power_entity(r).energy=defs.devices.logic.watts/30
    local s=model.open(p,r.id)
    local function spend() end
    local first=model.read(r,100,spend,s); s.snapshot=first
    assert(first.details.red_tick==100 and first.details.red and not first.details.green and first.details.output_tick==100)
    local job={}
    assert(logic.inspect_input(r,'red',101,spend,job).tick==101)
    assert(logic.inspect_input(r,'red',102,spend,job).tick==101,'resumed observation changed its acquisition tick')
    local admission=scheduler.maintenance({scheduler={last_tick=-1},ledger={tick=115,total=0}},115)
    local input=logic.inspect_input
    logic.inspect_input=function(rec,wire,tick,paid) paid(1000000000); return input(rec,wire,tick,paid) end
    local ok,blocked=pcall(model.read,r,115,admission,s)
    logic.inspect_input=input; assert(ok,blocked); s.snapshot=blocked
    assert(blocked.details.errors.green=='E_BUSY' and not blocked.details.green and blocked.details.red_tick==100)
    assert(blocked.details.output_tick==115 and first.details.errors.green==nil,'refusal must not mutate the prior detached view')
    local red=model.read(r,145,spend,s); s.snapshot=red
    assert(red.details.red_tick==145 and red.details.errors.green=='E_BUSY')
    local green=model.read(r,160,spend,s); s.snapshot=green
    assert(green.details.red_tick==145 and green.details.green_tick==160 and not next(green.details.errors))
    logic.inspect_input=function() error({code='E_LIMIT'},0) end
    local success,limited=pcall(model.read,r,175,spend,s)
    logic.inspect_input=input; assert(success,limited)
    assert(limited.details.errors.red=='E_LIMIT' and limited.details.red_tick==145 and limited.details.green_tick==160)
    lifecycle.power_entity(r).energy=0
    local off=model.read(r,190,spend,s)
    assert(not off.powered and not off.details and not s.logic_partial and not s.logic_next)
    model.close(p.index,s.token)
  end)
  check('inspector-blocked-input-does-not-hide-other-wire-or-own-output',function()
    local r=records.logic; local real=game; local input=logic.inspect_input
    local p=players.player(2001,r.body)
    local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
    game={tick=tick,connected_players={p},get_player=function() return p end}
    logic.inspect_input=function(rec,wire,t,spend)
      if wire=='red' then spend(1000000000) end
      return input(rec,wire,t,spend)
    end
    local ok,e=pcall(function()
      local f=assert(inspector.open(p,r.id)); local s=model.session(p.index)
      for _=1,4 do
        lifecycle.power_entity(r).energy=defs.devices.logic.watts/30
        game.tick=tick; inspector.tick(tick); tick=tick+15
      end
      assert(s.snapshot.details.errors.red=='E_BUSY' and not s.snapshot.details.red)
      assert(s.snapshot.details.green and s.snapshot.details.green_tick and s.snapshot.details.output)
      assert(f.details.logic_regions.inputs.red_slots and f.details.logic_regions.outputs.output_slots)
      assert(f.availability.caption[1]=='tc-inspector.signals-pending')
      assert(not r.output_owner and not r.logic_sample,'inspection must not create a writer or subscription sample')
      inspector.close(p)
    end)
    logic.inspect_input=input; game=real; assert(ok,e)
  end)
  check('inspector-maximum-kv-key-field-and-value-reachable-through-paid-pages',function()
    local r=records.kv; local original=r.database; local entries={}
    for i=1,126 do entries[#entries+1]={key=string.format('key-%03d',i),type='string',value=''} end
    local long=string.rep('\255',8192); local last=string.rep('z',256)
    entries[#entries+1]={key='long',type='string',value=long}
    local fields={}; for i=1,128 do fields[i]={field=string.format('field-%03d',i),value=tostring(i)} end
    entries[#entries+1]={key=last,type='hash',fields=fields}
    r.database=kv.import{version=1,entries=entries}
    local view=kv.inspect(r,200,function() end)
    assert(#view.entries==128 and #view.entries[128].fields==128 and view.entries[128].key==last)
    local p=players.player(2001,r.body); local real=game; local tick=210
    lifecycle.power_entity(r).energy=defs.devices.kv.watts/30
    game={tick=tick,get_player=function() return p end,connected_players={p}}
    local ok,e=pcall(function()
      local f=inspector.open(p,r.id); local s=model.session(p.index)
      s.snapshot={kind='kv',powered=true,name=r.id,tick=200,details=view}; s.pending=false; s.redraw=true
      local function refresh() inspector.tick(tick); tick=tick+15; game.tick=tick end
      local function click(element) inspector.on_click{player_index=p.index,element=assert(element)}; refresh() end
      refresh(); click(f.identity.select_name)
      local writes=f.identity.api_name.text_writes
      for _=2,16 do click(f.details.keys_page.next_page) end
      click(f.details.key_rows.key_128)
      assert(#f.details.full_key.text==258 and s.key==last)
      for _=2,16 do click(f.details.fields_page.next_page) end
      click(f.details.field_rows.field_128)
      assert(f.details.full_field.text=='"field-128"' and f.details.full_value.text=='"128"')
      click(f.details.key_rows.key_127)
      local chunks={}
      for i=1,16 do
        chunks[i]=f.details.full_value.text
        assert(chunks[i]=='"'..string.rep('\\xFF',512)..'"')
        if i<16 then click(f.details.value_chunks.next_page) end
      end
      assert(s.value_page==16 and not f.details.value_chunks.next_page.enabled)
      assert(f.identity.api_name.text_writes==writes and f.identity.api_name.focused,'unchanged copy selection must survive paging')
      inspector.close(p)
    end)
    game=real; r.database=original; assert(ok,e)
  end)
  check('inspector-full-byte-capacity-admitted-without-precomputed-snapshots',function()
    local r=records.kv; local original=r.database; local real=game
    local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
    local cases={}
    local keys={}
    for i=0,127 do keys[#keys+1]={key=string.rep('k',127)..string.char(i),type='string',value=''} end
    cases[#cases+1]=keys -- 128 long common prefixes exactly fill 16 KiB.
    local hashes={}
    for i=1,2 do
      local fields={}
      for j=0,127 do fields[#fields+1]={field=string.rep('f',62)..string.char(j),value=''} end
      hashes[#hashes+1]={key=tostring(i),type='hash',fields=fields}
    end
    cases[#cases+1]=hashes -- All 256 fields, long common prefixes, within bytes.
    cases[#cases+1]={{key='',type='hash',fields={{field='',value='empty'},{field='\0',value='nul'},
      {field='\0a',value='prefix'},{field='\255',value='high'},{field='a',value='ascii'}}}}
    local ok,e=pcall(function()
      for _,entries in ipairs(cases) do
        r.database=kv.import{version=1,entries=entries}
        local database=r.database; local before=serpent.line(database)
        lifecycle.power_entity(r).energy=defs.devices.kv.watts/30
        local p=players.player(2001,r.body)
        game={tick=tick,get_player=function() return p end,connected_players={p}}
        local f=assert(inspector.open(p,r.id)); local s=model.session(p.index)
        for _=1,4 do inspector.tick(tick); tick=tick+15; game.tick=tick end
        assert(s.snapshot and not s.pending and not s.redraw and f.details.key_rows,'legal full data must reach actual paid GUI draw')
        assert(#s.snapshot.details.entries==#entries and r.database==database and serpent.line(database)==before)
        local last
        for _,entry in ipairs(s.snapshot.details.entries) do
          assert(not last or last<entry.key); last=entry.key
          local previous
          for _,field in ipairs(entry.fields or {}) do
            assert(not previous or previous<field.field); previous=field.field
          end
        end
        inspector.close(p)
      end
    end)
    game=real; r.database=original; assert(ok,e)
  end)
  check('inspector-automatic-kv-changes-preserve-mounted-selection-and-close-stops-queries',function()
    local r=records.kv; local real=game; local original=r.database; local read=model.read; local calls=0
    r.database=kv.import{version=1,entries={{key='kept',type='hash',fields={{field='field',value='before'}}}}}
    local p=players.player(2001,r.body)
    local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
    game={tick=tick,connected_players={p},get_player=function() return p end}
    model.read=function(...) calls=calls+1; return read(...) end
    local ok,e=pcall(function()
      lifecycle.power_entity(r).energy=defs.devices.kv.watts/30
      local f=assert(inspector.open(p,r.id)); local s=model.session(p.index)
      local function poll() game.tick=tick; inspector.tick(tick); tick=tick+15 end
      poll(); assert(s.snapshot and not s.pending)
      local key=f.details.key_rows.key_1; local field=f.details.field_rows.field_1
      local full=f.details.full_key; full.focus(); full.select_all(); local writes=full.text_writes
      kv.methods.hset(nil,r,nil,tick,function() end,'kept','field','after')
      poll()
      assert(f.details.full_value.text=='"after"' and f.details.key_rows.key_1==key and f.details.field_rows.field_1==field)
      assert(f.details.full_key==full and full.text_writes==writes and full.focused and full.selection)
      assert(s.key=='kept' and s.field=='field' and s.page==1 and s.field_page==1 and s.value_page==1)
      local value=f.details.full_value; local value_writes=value.text_writes; poll()
      assert(f.details.full_value==value and value.text_writes==value_writes)
      inspector.close(p); local stopped=calls; poll(); assert(calls==stopped)
    end)
    model.read=read; game=real; r.database=original; assert(ok,e)
  end)
  check('inspector-automatic-multiviewer-admission-rotates-without-new-credits',function()
    local r=records.kv; local real=game; local original=r.database; local viewers={}
    local entries={}; for i=1,128 do entries[i]={key=string.format('k%03d',i),type='string',value=string.rep('v',100)} end
    r.database=kv.import{version=1,entries=entries}
    local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
    local first=tick
    game={tick=tick,connected_players=viewers,get_player=function(i) return viewers[i-3000] end}
    local ok,e=pcall(function()
      lifecycle.power_entity(r).energy=defs.devices.kv.watts/30
      for i=1,16 do viewers[i]=players.player(3000+i,r.body); inspector.open(viewers[i],r.id) end
      for _=1,32 do
        game.tick=tick; inspector.tick(tick)
        local spent=registry.get().scheduler.maintenance_spent
        assert(spent<=limits.maintenance_work_per_tick and spent+(registry.get().ledger.tick==tick and registry.get().ledger.total or 0)<=limits.host_work_per_tick)
        tick=tick+15
      end
      for _,p in ipairs(viewers) do
        local s=model.session(p.index)
        assert(s.snapshot and s.snapshot.tick>first and #s.snapshot.details.entries==128,'automatic viewer starved or published a prefix')
        assert(not s.logic_partial and type(s.pending)=='boolean')
        inspector.close(p)
      end
    end)
    for _,p in ipairs(viewers) do inspector.close(p) end
    game=real; r.database=original; assert(ok,e)
  end)
  check('inspector-cardinal-single-nonsquare-maximum-and-pending-geometry',function()
    local cases={}; local extras={}
    for orientation,direction in ipairs({0,4,8,12}) do
      for shape,size in ipairs({{1,1},{2,3},{6,6}}) do
        local w,h=size[1],size[2]; local worldw,worldh=w,h
        if direction==4 or direction==12 then worldw,worldh=h,w end
        local members={}; cases[#cases+1]={members=members,w=w,h=h}
        for y=1,worldh do for x=1,worldw do
          local b=assert(surface.create_entity{name=defs.devices.monitor.entity_name,
            position={100+orientation*12+x,180+shape*12+y},direction=direction,force='player'})
          local r=assert(lifecycle.build(b)); members[#members+1]=r; extras[#extras+1]=r
        end end
      end
    end
    for _=1,200 do monitor.reconcile(2000,function() end) end
    assert(not registry.get().monitors.job)
    for _,case in ipairs(cases) do
      local a=monitor.inspect(case.members[1],2000,function() end)
      local b=monitor.inspect(case.members[#case.members],2000,function() end)
      assert(a.name==b.name and a.width_tiles==case.w and a.height_tiles==case.h and a.tiles==case.w*case.h)
      local g=monitor.resolve(case.members[1]); terminal.scale(g.model,case.w,case.h,function() end,2)
      local revision=g.model.revision; local c=monitor.inspect(case.members[#case.members],2001,function() end)
      local width,height=terminal.size(case.w,case.h,2)
      assert(c.columns==width and c.rows==height and c.scale==2 and g.model.revision==revision)
      assert(not lifecycle.has_power(case.members[1]),'metadata test must cover committed unpowered geometry')
    end
    local state=registry.get().monitors; state.job={}
    local ok,err=pcall(monitor.inspect,cases[1].members[1],2001,function() end)
    assert(not ok and err.code=='E_NETWORK_PENDING'); state.job=nil
    local selected=cases[1].members[1]; local p=players.player(2001,selected.body)
    local session=model.open(p,selected.id); local at=selected.body.position; local dir=selected.body.direction
    assert(lifecycle.remove(selected.id,'fixture-replacement',true))
    local replacement=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.monitor.entity_name,position=at,direction=dir,force='player'})))
    assert(not pcall(model.current,p,session.token),'replacement must never inherit an old inspector')
    model.close(p.index,session.token); extras[#extras+1]=replacement
    for _,r in ipairs(extras) do if registry.record(r.id) then lifecycle.remove(r.id,'fixture-cleanup',true) end end
  end)
  for _,kind in ipairs({'kv','monitor','logic','configurator','recipe_searcher'}) do
    check('inspector-'..kind..'-deferred-failed-and-recovered-details-stay-visible',function()
      local r=records[kind]; local real=game; local read=model.read
      for _=1,200 do monitor.reconcile(real.tick,function() end) end
      local p=players.player(2001,r.body)
      local tick=math.ceil(((registry.get().scheduler.maintenance_tick or 0)+15)/15)*15
      game={tick=tick,connected_players={p},get_player=function() return p end}
      local ok,e=pcall(function()
        lifecycle.power_entity(r).energy=defs.devices[kind].watts/30
        local f=assert(inspector.open(p,r.id)); local s=model.session(p.index)
        local initial=f.details.children[1]
        model.read=function(rec,t,spend,session) spend(1000000000); return read(rec,t,spend,session) end
        inspector.tick(tick)
        assert(not s.snapshot and initial.valid and #f.details.children>0 and s.pending)
        if kind=='monitor' then assert(not f.identity.select_name.enabled)
        else assert(f.identity.api_name.text==r.id and f.identity.select_name.enabled) end
        model.read=read
        for _=1,4 do
          tick=tick+15; game.tick=tick; inspector.tick(tick)
        end
        assert(s.snapshot and not s.pending and not s.redraw and #f.details.children>0)
        local previous=s.snapshot; local first=f.details.children[1]
        s.pending=true
        model.read=function() error({code='E_NETWORK_PENDING'},0) end
        tick=tick+15; game.tick=tick; inspector.tick(tick)
        assert(s.snapshot==previous and first.valid and #f.details.children>0,'failed refresh erased '..kind..' details')
        assert(f.availability.caption[1]=='tc-inspector.unavailable')
        if kind=='monitor' then assert(f.identity.api_name.text=='' and not f.identity.select_name.enabled) end
        model.read=read
        tick=tick+15; game.tick=tick; inspector.tick(tick)
        assert(s.snapshot~=previous and not s.pending and f.identity.select_name.enabled)
        inspector.close(p)
      end)
      model.read=read; game=real; assert(ok,e)
    end)
  end
  log('TC_CONTRACT_TOTAL '..groups)
  for _,r in pairs(records) do lifecycle.remove(r.id,'fixture-cleanup',true) end
  storage.tweaked_computers=original
end
return M
