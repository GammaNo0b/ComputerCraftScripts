local input_peripheral = 'create:deployer_4'
local output_peripheral = 'create:chute_0'

---@class FryingRecipe : Recipe
---@field result Item
---@field ingredient string
---@field forEachResult fun(self: FryingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: FryingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean

---@class FryingPan : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local fryingpan = {
    name = 'frying',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return FryingRecipe|nil recipe
function fryingpan.parseRecipe(data, parser)
    if not data then return nil end

    local result = parser.parseItem(data.result)
    if not result then return nil end

    local ingredient = parser.parseString(data.ingredient)
    if not ingredient then return nil end

    ---@type FryingRecipe
    local recipe = {
        type = fryingpan.name,
        result = result,
        ingredient = ingredient,
        forEachIngredient = function(self, itemAction, fluidAction)
            return itemAction({name = self.ingredient, count = 1})
        end,
        forEachResult = function(self, itemAction, fluidAction)
            itemAction(self.result)
        end
    }
    return recipe
end

---@param storage Storage
---@return boolean cleared
function fryingpan.clear(storage)
    local location = storage.itemlocation(peripheral.wrap(input_peripheral), 1)
    storage.insertItem(location)
    return location:isEmpty()
end

---@param recipe FryingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function fryingpan.craft(recipe, amount, storage)
    local content = peripheral.call(input_peripheral, 'getItemDetail', 1)
    if content then
        return 0, 'Already frying items.'
    end

    local ingredient_locations, count = storage.findItem(recipe.ingredient, amount)
    if count <= 0 then
        return 0, 'Missing ingredients.'
    elseif count < amount then
        amount = count
    end

    amount = amount - storage.extractItem(ingredient_locations, input_peripheral, 1, amount)
    if amount <= 0 then
        return amount, 'Missing ingredients.'
    end

    return amount, 'Item frying.'
end

---@param storage Storage
function fryingpan.output(storage)
    local output = peripheral.wrap(output_peripheral)
    for slot, item in pairs(output.list()) do
        local stored = item.count - storage.insertItem(storage.itemlocation(output, slot), item.count)
        if stored > 0 and fryingpan.itemResultHandler({name = item.name, count = stored}) then
            fryingpan.itemResultHandler = function(_) return false end
        end
    end
end

return fryingpan