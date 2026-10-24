-- Paste only the document inside the long brackets into the computer editor.
return [[return {
    api_version = 1,
    handlers = {
        start = function(event)
            local searcher = peripheral.find("recipe_searcher", "red")
            assert(searcher, "Connect a Recipe Searcher with a red Network wire")

            local recipes = searcher.findRecipes("item", "iron-plate", "smelting")
            for _, recipe in ipairs(recipes) do
                computer.log(recipe.name .. " / " .. recipe.category
                    .. " / seconds=" .. tostring(recipe.energy)
                    .. " / enabled=" .. tostring(recipe.enabled))
            end

            local fluids = searcher.findRecipes("fluid", "petroleum-gas", "chemistry")
            computer.setState("recipe_count", #recipes)
            computer.setState("fluid_recipe_count", #fluids)
        end
    }
}]]
