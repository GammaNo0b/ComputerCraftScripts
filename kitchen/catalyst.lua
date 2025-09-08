---@class Catalyst<R> : { name: string, recipe: R|nil, itemResultHandler: (fun(item: Item): boolean), fluidResultHandler: (fun(fluid: Fluid): boolean), parseRecipe: (fun(data: any, parser: Parser): R|nil), craft: (fun(recipe: R, amount: integer, storage: Storage): integer, string), output :(fun(storage: Storage)) }
local Catalyst = {}

---@type table<string, Catalyst<Recipe>>
local catalysts = {}

for _, catalyst in pairs({
    require('catalysts.crafter'),
    require('catalysts.cuttingboard'),
    require('catalysts.fryingpan'),
    require('catalysts.cookingpot'),
    require('catalysts.mixer'),
    require('catalysts.spout'),
    require('catalysts.mill')
}) do
    catalysts[catalyst.name] = --[[@as Catalyst<Recipe>]] catalyst
end

---Parses the given recipe.
---@param data any
---@param parser Parser
---@return Recipe|nil recipe
local function parseRecipe(data, parser)
    if not data then return nil end
    local catalyst = catalysts[data.type]
    if not catalyst then return nil end
    return catalyst.parseRecipe(data, parser)
end

---Crafts the given recipe amount times.
---@param recipe Recipe<Recipe>
---@param amount integer
---@param storage Storage
---@param itemResultHandler fun(item: Item): boolean
---@param fluidResultHandler fun(fluid: Fluid): boolean
---@return integer crafts How often the recipe will be crafted.
---@return string message
local function craft(recipe, amount, storage, itemResultHandler, fluidResultHandler)
    ---@type Catalyst<Recipe>
    local catalyst = catalysts[recipe.type]
    if not catalyst then
        return 0, 'Unknown catalyst \'' .. recipe.type .. '\'.'
    end

    catalyst.itemResultHandler = itemResultHandler
    catalyst.fluidResultHandler = fluidResultHandler
    return catalyst.craft(recipe, amount, storage)
end

---Collects the output from all catalysts.
---@param storage Storage
local function collect(storage)
    for _, catalyst in pairs(catalysts) do
        catalyst.output(storage)
    end
end

return {
    parseRecipe = parseRecipe,
    craft = craft,
    collect = collect
}