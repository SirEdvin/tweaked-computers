-- Paste only the document inside the long brackets into the computer editor.
return [[function start(event)
    local searcher = peripheral.find("recipe_searcher", "red")
    assert(searcher, "Connect a Recipe Searcher with a red Network wire")

    local limits = searcher.getLimits()
    assert(limits.recipe_search_results == 50)

    local ok, recipes = pcall(searcher.findRecipes, "item", "iron-plate")
    if not ok then
        if type(recipes) ~= "table" or recipes.code ~= "E_LIMIT" then
            error(recipes)
        end
        recipes = searcher.findRecipes("item", "iron-plate", "smelting")
    end
    for _, recipe in ipairs(recipes) do
        computer.log(recipe.name .. " / " .. recipe.category
            .. " / seconds=" .. tostring(recipe.energy)
            .. " / enabled=" .. tostring(recipe.enabled))
    end

    local fluids = searcher.findRecipes("fluid", "petroleum-gas", "chemistry")
    computer.setState("recipe_count", #recipes)
    computer.setState("fluid_recipe_count", #fluids)
end]]
