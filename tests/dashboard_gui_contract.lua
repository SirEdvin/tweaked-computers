-- Engine-hosted GUI doubles; native input/appearance is verified separately.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local model=require('scripts.dashboard-model')
local ui=require('scripts.ui.dashboard')
local service=require('scripts.services.dashboard')
local players=require('tests.editor_contract')
local M={}
local function definition(text)
  return {title='Literal [img=iron-plate]',content={type='column',id='root',children={
    {type='row',id='row',children={{type='label',id='status',text=text or '[img=iron-plate]'}}},
    {type='button',id='ack',text='[color=red]Acknowledge[/color]'}}}}
end
function M.run()
  local saved=storage.tweaked_computers; local real_game=game; local click=service.click
  storage.tweaked_computers=nil; registry.initialize()
  local body=assert(real_game.surfaces[1].create_entity{name='tc-dashboard-shell',position={40,40},force='player'})
  local rec=assert(lifecycle.build(body)); lifecycle.power_entity(rec).energy=500
  model.set_tab(rec,1,definition(),function() end)
  model.set_tab(rec,2,{title='Second',content={type='label',id='only',text='Second viewer'}},function() end)
  local a,b=players.player(2001,body),players.player(2002,body)
  a.connected=true; b.connected=true
  local by_index={[a.index]=a,[b.index]=b}; local hits=0
  game=setmetatable({tick=100,get_player=function(i) return by_index[i] end,connected_players={a,b}},
    {__index=function(_,key) return real_game[key] end})
  service.click=function(r,slot,id,index,token,tick)
    assert(r==rec and slot==1 and id=='ack' and index==a.index and token==registry.get().dashboard_sessions[a.index].token)
    hits=hits+1; return true
  end
  local ok,problem=pcall(function()
    local fa=assert(ui.open(a,rec.id)); local fb=assert(ui.open(b,rec.id)); ui.tick(100,function() end)
    local sa=registry.get().dashboard_sessions[a.index]; local sb=registry.get().dashboard_sessions[b.index]
    assert(sa.token~=sb.token and sa.selected==1 and sb.selected==1)
    local first=sa.tabs['1']; local button=first.elements.ack
    assert(first.elements.status.style.rich_text_setting==defines.rich_text_setting.disabled)
    assert(button.plain_caption.caption=='[color=red]Acknowledge[/color]' and button.caption=='')
    assert(first.tab.caption=='' and first.tab.plain_caption.caption=='Literal [img=iron-plate]')

    assert(fa.api_name.read_only and fa.api_name.text==rec.id)
    local function activate(element,player,mouse)
      ui.on_click{element=element,player_index=(player or a).index,button=mouse or defines.mouse_button_type.left}
    end
    activate(button); assert(hits==1)
    activate(button,a,defines.mouse_button_type.right); assert(hits==1)
    activate(sb.tabs['1'].elements.ack); assert(hits==1,'foreign viewer element was accepted')
    local forged=fa.add{type='button',caption='Forged',tags=fa.tags}; activate(forged); assert(hits==1)
    first.body.visible=false; activate(button); first.body.visible=true; assert(hits==1)
    button.enabled=false; activate(button); button.enabled=true; assert(hits==1)
    local tags=fa.tags; fa.tags={token=sa.token+1,player=a.index}; activate(button); fa.tags=tags; assert(hits==1)
    fa.content.selected_tab_index=2; ui.on_tab{element=fa.content,player_index=a.index}
    activate(button); assert(hits==1 and sa.selected==2 and sb.selected==1)
    fa.api_name.focus(); fa.api_name.select_all(); local selection=fa.api_name.selection
    first.body.vertical_scroll_position=37
    model.set_leaf(rec,1,'status','Targeted update',false,function() end); ui.tick(101,function() end)
    assert(sa.tabs['1']==first and first.elements.ack==button and first.elements.status.caption=='Targeted update')
    assert(sa.selected==2 and sb.selected==1 and first.body.vertical_scroll_position==37)
    assert(fa.api_name.focused and fa.api_name.selection==selection and fa.api_name.text_writes==0)
    fa.content.selected_tab_index=1; ui.on_tab{element=fa.content,player_index=a.index}
    model.set_tab(rec,1,definition('Replacement'),function() end); ui.tick(102,function() end)
    assert(not button.valid); activate(button); assert(hits==1,'stale rebuilt control was accepted')
    local replacement=sa.tabs['1'].elements.ack; activate(replacement); assert(hits==2)
    model.set_leaf(rec,1,'ack',false,true,function() end); ui.tick(103,function() end)
    activate(replacement); assert(hits==2)
    a.display_resolution={width=1024,height=768}; a.display_scale=1.25; ui.on_size{player_index=a.index}
    assert(fa.location.x>=0 and fa.location.y>=0 and fa.style.minimal_width*1.25<=1024 and fa.style.minimal_height*1.25<=768)
    ui.on_closed{player_index=a.index,element=fb}; assert(registry.get().dashboard_sessions[a.index]==sa)
    ui.on_closed{player_index=a.index,element=fa}; assert(not registry.get().dashboard_sessions[a.index] and not fa.valid)
    for _,deny in ipairs({'connected','force','surface','reach','permission','ghost'}) do
      a.connected=true; a.force=body.force; a.surface=body.surface; a.can_reach_entity=function() return true end
      a.permission_group=nil; a.controller_type=defines.controllers.god
      if deny=='connected' then a.connected=false
      elseif deny=='force' then a.force={index=body.force.index+1}
      elseif deny=='surface' then a.surface={index=body.surface.index+1}
      elseif deny=='reach' then a.can_reach_entity=function() return false end
      elseif deny=='permission' then a.permission_group={allows_action=function() return false end}
      else a.controller_type=defines.controllers.ghost end
      assert(not ui.open(a,rec.id),'unauthorized open: '..deny)
    end
    ui.close(b); assert(not fb.valid)
  end)
  service.click=click; game=real_game
  lifecycle.remove(rec.id,'fixture_cleanup',true); storage.tweaked_computers=saved
  assert(ok,problem)
  log('TC_DASHBOARD_GUI doubles-actual-elements-sessions-disabled-stale-scope-focus-scroll-resize')
end
return M
