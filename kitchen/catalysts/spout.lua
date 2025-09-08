local spout_peripheral = 'create:spout_0'
local depot_peripheral = 'create:depot_4'

---@class SpoutingRecipe : Recipe
---@field result string
---@field ingredient string
---@field fluid Fluid
---@field forEachResult fun(self: SpoutingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: SpoutingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean

---@class Spout : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local spout = {
    name = 'filling',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return SpoutingRecipe|nil recipe
function spout.parseRecipe(data, parser)
    if not data then return nil end

    local result = parser.parseString(data.result)
    if not result then return nil end

    local ingredient = parser.parseString(data.ingredient)
    if not ingredient then return nil end

    local fluid = parser.parseFluid(data.fluid)
    if not fluid then return nil end

    ---@type SpoutingRecipe
    local recipe = {
        type = spout.name,
        result = result,
        ingredient = ingredient,
        fluid = fluid,
        forEachIngredient = function(self, itemAction, fluidAction)
            return itemAction({name = self.ingredient, count = 1}) and fluidAction(self.fluid)
        end,
        forEachResult = function(self, itemAction, fluidAction)
            itemAction({name = self.result, count = 1})
        end
    }
    return recipe
end

---@param recipe SpoutingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function spout.craft(recipe, amount, storage)
    if peripheral.call(depot_peripheral, 'getItemDetail', 1) or #(peripheral.call(spout_peripheral, 'tanks') or {}) > 0 then
        return 0, 'Already filling items.'
    end

    -- gather ingredient
    local ingredient_locations, count = storage.findItem(recipe.ingredient, amount)
    if count <= 0 then
        return 0, 'Missing ingredient.'
    elseif count < amount then
        amount = count
    end

    -- gather fluid
    local fluid_locations
    local required = recipe.fluid.amount * amount
    fluid_locations, count = storage.findFluid(recipe.fluid.name, required)
    amount = math.floor(math.min(1000, required, count) / recipe.fluid.amount)
    if amount <= 0 then
        return 0, 'Missing fluids.'
    end

    -- insert ingredients
    storage.extractItem(ingredient_locations, depot_peripheral, 1, amount)
    storage.extractFluid(fluid_locations, spout_peripheral, recipe.fluid.amount * amount)

    return amount, 'Item filling.'
end

---@param storage Storage
function spout.output(storage)
    local inventory = peripheral.wrap(depot_peripheral)
    for slot, item in pairs(inventory.list()) do
        if slot > 1 then
            local stored = item.count - storage.insertItem(storage.itemlocation(inventory, slot) - item.count)
            if stored > 0 and spout.itemResultHandler({name = item.name, count = stored}) then
                spout.itemResultHandler = function(_) return false end
            end
        end
    end
end

return spout