---@class Recipe<R> : { type: string, forEachResult: (fun(self: R, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))), forEachIngredient: (fun(self: R, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean) }
local Recipe = {}

local jsonutils = require('utils.jsonutils')

---@param path string
---@param recipeParser fun(data: any): Recipe<R>|nil
---@param recipeHandler fun(recipe: Recipe<R>)
local function readRecipeFiles(path, recipeParser, recipeHandler)
    if fs.isDir(path) then
        for _, filename in pairs(fs.list(path)) do
            readRecipeFiles(fs.combine(path, filename), recipeParser, recipeHandler)
        end
    else
        local data = jsonutils.readJsonFile(path)
        local recipe = recipeParser(data)
        if recipe then
            recipeHandler(recipe)
        else
        if string.sub(path, 1, 12) ~= 'recipes/temp' then
            print(textutils.serialise(data))
            print('Unable to parse recipe \'' .. path .. '\'.')
        end
        end
    end
end

---@class Cookbook : { parser: Parser, itemRecipes: { [string]: { [Recipe<R>]: integer }}, fluidRecipes: { [string]: { [Recipe<R>]: integer }}, readCookbook: fun(self: Cookbook, recipeParser: (fun(data: any): Recipe<R>|nil)) }
local cookbook = {
    parser = require('utils.parser'),
    itemRecipes = {},
    fluidRecipes = {},
    readCookbook = function(self, recipeParser)
        self.itemRecipes = {}
        self.fluidRecipes = {}

        readRecipeFiles('recipes', recipeParser, function(recipe)
            recipe:forEachResult(function(item)
                local recipes = self.itemRecipes[item.name] or {}
                recipes[recipe] = item.count
                self.itemRecipes[item.name] = recipes
            end, function(fluid)
                local recipes = self.fluidRecipes[fluid.name] or {}
                recipes[recipe] = fluid.amount
                self.itemRecipes[fluid.name] = recipes
            end)
        end)

        local itemRecipeCount = 0
        for _, tbl in pairs(self.itemRecipes) do
            for _ in pairs(tbl) do
                itemRecipeCount = itemRecipeCount + 1
            end
        end
        print('Loaded', itemRecipeCount, 'item recipes.')

        local fluidRecipeCount = 0
        for _, tbl in pairs(self.fluidRecipes) do
            for _ in pairs(tbl) do
                fluidRecipeCount = fluidRecipeCount + 1
            end
        end
        print('Loaded', fluidRecipeCount, 'fluid recipes.')
    end
}

return cookbook