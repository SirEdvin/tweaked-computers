-- Small in-game Reference tutorial; host wrapper is not guest source.
return [[function start(event)
  local recipes = peripheral.find("recipe_searcher", "red")
  assert(recipes, "Connect one Recipe Searcher on red")
  local matches = recipes.findRecipes("item", "iron-plate", "smelting")
  print("Iron plate smelting recipes:", #matches)
  for _, recipe in ipairs(matches) do
    print(recipe.name)
  end
end
]]
