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
          assert(not s.snapshot and s.logic_partial and s.logic_partial.tick==tick)
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
          assert(rows.red_tick.caption[2]==s.snapshot.details.red_tick and rows.green_tick.caption[2]==tick)
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
  check('inspector-staged-logic-expiry-admission-power-and-private-pairs',function()
    local r=records.logic; local p=players.player(2001,r.body)
    lifecycle.power_entity(r).energy=defs.devices.logic.watts/30
    local s=model.open(p,r.id)
    local function spend() end
    assert(not model.read(r,100,spend,s) and s.logic_partial.tick==100)
    assert(not model.read(r,100,spend,s),'one tick cannot advance both observations')
    local denied=0
    local admission=scheduler.maintenance({scheduler={last_tick=-1},ledger={tick=115,total=0}},115)
    local ok=scheduler.try_maintenance(function()
      model.read(r,115,function(n) denied=denied+n; admission(1000000000) end,s)
    end)
    assert(not ok and denied>0 and s.logic_partial.tick==100 and not s.snapshot)
    assert(not model.read(r,145,spend,s) and s.logic_partial.tick==145,'expired partial must be replaced, not published')
    local pair=model.read(r,160,spend,s)
    assert(pair.details.red_tick==145 and pair.details.green_tick==160 and pair.details.output_tick==160 and not s.logic_partial)
    assert(not model.read(r,175,spend,s))
    lifecycle.power_entity(r).energy=0
    local off=model.read(r,190,spend,s)
    assert(not off.powered and not off.details and not s.logic_partial)
    model.close(p.index,s.token)
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
  log('TC_CONTRACT_TOTAL '..groups)
  for _,r in pairs(records) do lifecycle.remove(r.id,'fixture-cleanup',true) end
  storage.tweaked_computers=original
end
return M
