-- Complete catalogue snapshots; only plain metadata/names survive a slice.
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local peripheral=require('scripts.services.peripheral')
local work=require('scripts.services.inventory-work')
local M={}
local function fail(message) errors.raise('E_UNSUPPORTED',message) end
local function native(fn,...)
  local ok,value=pcall(fn,...)
  if not ok then errors.raise('E_ENGINE','recipe catalogue access failed') end
  return value
end
local function name(value,field)
  if type(value)~='string' or #value==0 then errors.raise('E_ARGUMENT','nonempty name required',field) end
  return value
end
local function put(t,k,v,typ)
  if type(v)~=typ or typ=='number' and not errors.finite(v) then fail('unsupported recipe metadata field: '..k) end
  t[k]=v
end
local function optional(t,v,fields)
  for _,k in ipairs(fields) do if v[k]~=nil then put(t,k,v[k],'number') end end
end
local function component(v,product)
  local t={}
  if v.type~='item' and v.type~='fluid' then fail('unsupported recipe component type') end
  put(t,'type',v.type,'string'); put(t,'name',v.name,'string')
  if product then
    if not errors.finite(v.probability) or v.probability<0 or v.probability>1 then fail('unsupported product probability') end
    put(t,'probability',v.probability,'number')
    if v.amount~=nil then put(t,'amount',v.amount,'number')
    else put(t,'amount_min',v.amount_min,'number'); put(t,'amount_max',v.amount_max,'number') end
    optional(t,v,{'ignored_by_stats','ignored_by_productivity'})
    optional(t,v,v.type=='item' and {'extra_count_fraction','percent_spoiled'} or {'temperature','fluidbox_index'})
  else
    put(t,'amount',v.amount,'number'); optional(t,v,{'ignored_by_stats'})
    if v.type=='fluid' then optional(t,v,{'temperature','minimum_temperature','maximum_temperature','fluidbox_index','fluidbox_multiplier'}) end
  end
  for _,k in ipairs({'fluidbox_index','fluidbox_multiplier'}) do
    if t[k]~=nil and t[k]%1~=0 then fail('noninteger fluidbox metadata') end
  end
  return t
end
local function project(recipe,force_recipe,job,spend)
  if not job.source then
    spend(32)
    job.source=native(function()
      return {name=recipe.name,category=recipe.category,additional_categories=recipe.additional_categories,
        energy=recipe.energy,enabled=force_recipe.enabled,enabled_by_default=recipe.enabled,
        hidden=recipe.hidden,hidden_from_player_crafting=recipe.hidden_from_player_crafting,
        hidden_from_flow_stats=recipe.hidden_from_flow_stats,hidden_in_factoriopedia=recipe.hidden_in_factoriopedia,
        ingredients=recipe.ingredients,products=recipe.products,surface_conditions=recipe.surface_conditions or {}}
    end)
  end
  local s=job.source
  if not job.result then
    if type(s.name)~='string' or type(s.category)~='string' then fail('unsupported recipe identity') end
    spend(128+#s.name+#s.category)
    local t={additional_categories={},ingredients={},products={},surface_conditions={}}
    put(t,'name',s.name,'string'); put(t,'category',s.category,'string'); put(t,'energy',s.energy,'number')
    for _,k in ipairs({'enabled','enabled_by_default','hidden','hidden_from_player_crafting','hidden_from_flow_stats','hidden_in_factoriopedia'}) do put(t,k,s[k],'boolean') end
    job.result=t; job.category=1; job.seen={}; job.sort={}
  end
  local t=job.result
  while job.category<=#s.additional_categories do
    local category=s.additional_categories[job.category]
    if type(category)~='string' then fail('unsupported recipe category') end
    spend(#category+#s.category+4)
    if category~=s.category and not job.seen[category] then t.additional_categories[#t.additional_categories+1]=category; job.seen[category]=true end
    job.category=job.category+1
  end
  work.sort(t.additional_categories,job.sort,spend,function(v) return v end)
  for _,field in ipairs({'ingredients','products','surface_conditions'}) do
    local source=s[field]
    if type(source)~='table' then fail('expected native recipe array') end
    while #t[field]<#source do
      local i=#t[field]+1; local v=source[i]
      spend(256+(type(v.name)=='string' and #v.name or 0)+(type(v.property)=='string' and #v.property or 0))
      local value
      if field=='surface_conditions' then
        value={}; put(value,'property',v.property,'string')
        if v.min~=nil and v.min~=-math.huge then put(value,'min',v.min,'number') end
        if v.max~=nil and v.max~=math.huge then put(value,'max',v.max,'number') end
      else value=component(v,field=='products') end
      t[field][i]=value
    end
  end
  return t
end
local methods={}
function methods.getLimits(_,_,_,_,spend,...)
  if select('#',...)~=0 then errors.raise('E_ARGUMENT','getLimits expects no arguments') end
  local result={}
  for k,v in pairs(limits) do spend(#k+1); result[k]=v end
  return result
end
-- Host callers may pass a job explicitly; the public binding supplies guard.job.
function M.find(computer,spend,job,product_type,product_name,category)
  if type(product_type)~='string' then errors.raise('E_ARGUMENT','product type must be a string') end
  if product_type~='item' and product_type~='fluid' then errors.raise('E_RANGE','product type must be item or fluid','product_type') end
  name(product_name,'product_name'); if category~=nil then name(category,'category') end
  if not prototypes[product_type][product_name] then errors.raise('E_RANGE','unknown product','product_name') end
  if category and not prototypes.recipe_category[category] then errors.raise('E_RANGE','unknown recipe category','category') end
  if not job.matches then
    job.matches={}; job.sort={}; job.result={}; job.cursor=1
  end
  if not job.scanned then
    spend(32)
    local candidates=native(prototypes.get_recipe_filtered,{{filter='has-product-'..product_type,elem_filters={{filter='name',name=product_name}}}})
    local advance,state=pairs(candidates)
    while true do
      spend(4)
      local recipe_name,recipe=advance(state,job.key)
      if not recipe_name then job.scanned=true; break end
      spend(#recipe_name+(category and #category+32 or 0)+4)
      if not category or native(recipe.has_category,category) then job.matches[#job.matches+1]=recipe_name end
      job.key=recipe_name
    end
  end
  work.sort(job.matches,job.sort,spend,function(v) return v end)
  local force=native(function() return game.forces[computer.force_index] end)
  if not force then errors.raise('E_ENGINE','requesting force is unavailable') end
  while job.cursor<=#job.matches do
    local recipe_name=job.matches[job.cursor]
    job.recipe=job.recipe or {}
    local recipe=prototypes.recipe[recipe_name]
    local force_recipe=native(function() return force.recipes[recipe_name] end)
    if not recipe or not force_recipe then errors.raise('E_ENGINE','force recipe is unavailable') end
    job.result[job.cursor]=project(recipe,force_recipe,job.recipe,spend)
    job.cursor=job.cursor+1; job.recipe=nil
  end
  return job.result
end
function methods.findRecipes(computer,_,_,_,spend,...)
  local count=select('#',...)
  if count~=2 and count~=3 then errors.raise('E_ARGUMENT','findRecipes expects two or three arguments; use dots') end
  return M.find(computer,spend,{},...)
end
M.methods=methods
peripheral.register_type('recipe_searcher',{with_guard=true,methods={
  getLimits=function(c,r,w,t,spend,guard,...) return methods.getLimits(c,r,w,t,spend,...) end,
  findRecipes=function(c,r,w,t,spend,guard,...)
    local n=select('#',...)
    if n~=2 and n~=3 then errors.raise('E_ARGUMENT','findRecipes expects two or three arguments; use dots') end
    return M.find(c,spend,work.job(guard,'recipe-search'),...)
  end
}})
return M
