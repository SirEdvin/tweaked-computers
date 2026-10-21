-- Stateless catalogue snapshots. No native objects, indexes or force caches escape.
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local peripheral=require('scripts.services.peripheral')
local M={}
local MAX_RESULTS=50
-- Native-call admission, not a C++ timing bound. Charge returned candidates and
-- projected metadata separately; unrelated installed recipes/categories are free.
local LOOKUP_WORK=32
local function fail(message) errors.raise('E_UNSUPPORTED',message) end
local function native(fn,...)
  local ok,value=pcall(fn,...)
  if not ok then errors.raise('E_ENGINE','recipe catalogue access failed') end
  return value
end
local function name(value,field,spend)
  if type(value)~='string' or #value==0 then errors.raise('E_ARGUMENT','nonempty name required',field) end
  if #value>limits.string_bytes then errors.raise('E_LIMIT','name exceeds string limit',field) end
  spend(#value+1)
  return value
end
local function projector(spend)
  local nodes,bytes=0,0
  local sizes={}
  local function account(value)
    nodes=nodes+1
    local typ=type(value)
    local cost=1
    if typ=='string' then
      if #value>limits.string_bytes then errors.raise('E_LIMIT','recipe string exceeds limit') end
      cost=#value; bytes=bytes+cost
    elseif typ=='number' then
      if not errors.finite(value) then fail('nonfinite recipe metadata') end
      bytes=bytes+8
    elseif typ=='boolean' then bytes=bytes+1
    elseif typ~='table' then fail('unsupported recipe metadata value') end
    if nodes>limits.data_nodes or bytes>limits.peripheral_call_bytes then errors.raise('E_LIMIT','complete recipe snapshot exceeds Data limits') end
    spend(cost+1)
  end
  local function container()
    local t={}; account(t); sizes[t]=0; return t
  end
  local function put(t,key,value,typ)
    if type(value)~=typ then fail('unexpected recipe metadata field: '..tostring(key)) end
    sizes[t]=sizes[t]+1
    if sizes[t]>limits.table_entries then errors.raise('E_LIMIT','recipe container exceeds limit') end
    if type(key)=='string' then
      bytes=bytes+#key; spend(#key+1)
      if bytes>limits.peripheral_call_bytes then errors.raise('E_LIMIT','complete recipe snapshot exceeds byte limit') end
    else spend(1) end
    if typ~='table' then account(value) end
    t[key]=value
  end
  local function optional(t,source,fields)
    for _,field in ipairs(fields) do
      spend(1)
      if source[field]~=nil then put(t,field,source[field],'number') end
    end
  end
  local function array(source,convert)
    if type(source)~='table' then fail('expected native recipe array') end
    if #source>limits.table_entries then errors.raise('E_LIMIT','complete recipe array exceeds limit') end
    spend(#source+1)
    local result=container()
    for i,v in ipairs(source) do put(result,i,convert(v),'table') end
    return result
  end
  local function component(v,product)
    local t=container()
    if v.type~='item' and v.type~='fluid' then fail('unsupported recipe component type') end
    put(t,'type',v.type,'string'); put(t,'name',v.name,'string')
    if product then
      if not errors.finite(v.probability) or v.probability<0 or v.probability>1 then fail('unsupported product probability') end
      put(t,'probability',v.probability,'number')
      if v.amount~=nil then put(t,'amount',v.amount,'number')
      else put(t,'amount_min',v.amount_min,'number'); put(t,'amount_max',v.amount_max,'number') end
      optional(t,v,{'ignored_by_stats','ignored_by_productivity'})
      if v.type=='item' then optional(t,v,{'extra_count_fraction','percent_spoiled'})
      else optional(t,v,{'temperature','fluidbox_index'}) end
    else
      put(t,'amount',v.amount,'number'); optional(t,v,{'ignored_by_stats'})
      if v.type=='fluid' then optional(t,v,{'temperature','minimum_temperature','maximum_temperature','fluidbox_index','fluidbox_multiplier'}) end
    end
    for _,field in ipairs({'fluidbox_index','fluidbox_multiplier'}) do
      if t[field]~=nil and t[field]%1~=0 then fail('noninteger fluidbox metadata') end
    end
    return t
  end
  local function project(recipe,force_recipe)
    -- Native properties may materialize arrays. No Lua-side scan precedes its admission.
    spend(32)
    local source=native(function()
      return {name=recipe.name,category=recipe.category,additional_categories=recipe.additional_categories,
        energy=recipe.energy,enabled=force_recipe.enabled,enabled_by_default=recipe.enabled,
        hidden=recipe.hidden,hidden_from_player_crafting=recipe.hidden_from_player_crafting,
        hidden_from_flow_stats=recipe.hidden_from_flow_stats,hidden_in_factoriopedia=recipe.hidden_in_factoriopedia,
        ingredients=recipe.ingredients,products=recipe.products,surface_conditions=recipe.surface_conditions or {}}
    end)
    local t=container()
    put(t,'name',source.name,'string'); put(t,'category',source.category,'string'); put(t,'energy',source.energy,'number')
    for _,field in ipairs({'enabled','enabled_by_default','hidden','hidden_from_player_crafting','hidden_from_flow_stats','hidden_in_factoriopedia'}) do
      put(t,field,source[field],'boolean')
    end
    local categories=container(); local seen={}
    if #source.additional_categories>limits.table_entries then errors.raise('E_LIMIT','additional categories exceed limit') end
    spend(#source.additional_categories+1)
    for _,category in ipairs(source.additional_categories) do
      if type(category)~='string' then fail('unsupported recipe category') end
      spend(#category+#source.category+1)
      if category~=source.category and not seen[category] then
        put(categories,#categories+1,category,'string'); seen[category]=true
      end
    end
    table.sort(categories,function(a,b) spend(#a+#b+1); return a<b end)
    put(t,'additional_categories',categories,'table')
    put(t,'ingredients',array(source.ingredients,function(v) return component(v,false) end),'table')
    put(t,'products',array(source.products,function(v) return component(v,true) end),'table')
    put(t,'surface_conditions',array(source.surface_conditions,function(v)
      local condition=container(); put(condition,'property',v.property,'string')
      if v.min~=nil and v.min~=-math.huge then put(condition,'min',v.min,'number') end
      if v.max~=nil and v.max~=math.huge then put(condition,'max',v.max,'number') end
      return condition
    end),'table')
    return t
  end
  return container,put,project
end
local methods={}
function methods.getLimits(_,_,_,_,spend,...)
  if select('#',...)~=0 then errors.raise('E_ARGUMENT','getLimits expects no arguments') end
  local result={recipe_search_results=MAX_RESULTS}
  for k,v in pairs(limits) do spend(#k+1); result[k]=v end
  return result
end
function methods.findRecipes(computer,_,_,_,spend,...)
  local count=select('#',...)
  if count~=2 and count~=3 then errors.raise('E_ARGUMENT','findRecipes expects two or three arguments; use dots') end
  local product_type,product_name,category=...
  if type(product_type)~='string' then errors.raise('E_ARGUMENT','product type must be a string') end
  if product_type~='item' and product_type~='fluid' then errors.raise('E_RANGE','product type must be item or fluid','product_type') end
  name(product_name,'product_name',spend)
  if category~=nil then name(category,'category',spend) end
  if not prototypes[product_type][product_name] then errors.raise('E_RANGE','unknown product','product_name') end
  if category and not prototypes.recipe_category[category] then errors.raise('E_RANGE','unknown recipe category','category') end
  spend(LOOKUP_WORK+#product_name+(category and #category or 0))
  local candidates=native(prototypes.get_recipe_filtered,{{filter='has-product-'..product_type,elem_filters={{filter='name',name=product_name}}}})
  local matches={}
  for recipe_name,recipe in pairs(candidates) do
    spend(#recipe_name+(category and #category or 0)+4)
    if category then spend(LOOKUP_WORK+#category) end
    if not category or native(recipe.has_category,category) then
      if #matches==MAX_RESULTS then errors.raise('E_LIMIT','More than 50 recipes; select a crafting category','results') end
      matches[#matches+1]=recipe_name
    end
  end
  table.sort(matches,function(a,b) spend(#a+#b+1); return a<b end)
  local force=native(function() return game.forces[computer.force_index] end)
  if not force then errors.raise('E_ENGINE','requesting force is unavailable') end
  local container,put,project=projector(spend)
  local result=container()
  for i,recipe_name in ipairs(matches) do
    spend(#recipe_name+1)
    local force_recipe=native(function() return force.recipes[recipe_name] end)
    if not force_recipe then errors.raise('E_ENGINE','force recipe is unavailable') end
    put(result,i,project(candidates[recipe_name],force_recipe),'table')
  end
  return result
end
M.methods=methods
peripheral.register_type('recipe_searcher',{methods=methods})
return M
