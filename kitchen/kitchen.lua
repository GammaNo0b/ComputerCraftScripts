---@class Item
---@field name string
---@field count integer

---@class Fluid
---@field name string
---@field amount integer

---@class Schedule
---@field result Item|Fluid
---@field recipe Recipe<R>
---@field amount integer
---@field crafting integer
---@field craft fun(self: Schedule, craftCompleteHandler: fun()): boolean
---@field toString fun(self: Schedule): string

local cookbook = require('cookbook')

local storage = require('storage')

local catalysts = require('catalyst')

local tree = require('utils.tree')

---@class Kitchen
---@field root Node<Schedule>|nil
local kitchen = {
    root = nil
}

---@generic R: Recipe<R>
---@param result Item|Fluid the result of the recipe
---@param recipe Recipe<R> the recipe
---@param amount integer the number of resources needed
---@return Schedule schedule
function kitchen.makeSchedule(result, recipe, amount)
    ---@type Schedule
    local schedule = {
        result = result,
        recipe = recipe,
        amount = amount,
        crafting = 0,
        craft = function(self, craftCompleteHandler)
            local required = self.amount - self.crafting
            local trycrafts = math.ceil(required / (self.result.count or self.result.amount))
            local crafts = catalysts.craft(self.recipe, trycrafts, storage, function(item)
                if self.result.count and self.result.name == item.name then
                    self.amount = self.amount - item.count
                    self.crafting = self.crafting - item.count
                    if self.amount <= 0 then
                        craftCompleteHandler()
                        return true
                    end
                end
                return false
            end, function(fluid)
                if self.result.amount and self.result.name == fluid.name then
                    self.amount = self.amount - fluid.amount
                    self.crafting = self.crafting - fluid.amount
                    if self.amount <= 0 then
                        craftCompleteHandler()
                        return true
                    end
                end
                return false
            end)
            self.crafting = self.crafting + crafts * (self.result.count or self.result.amount)
            return crafts > 0
        end,
        toString = function(self)
            return self.result.name .. ' * ' .. self.amount .. ' [' .. self.crafting .. ']'
        end
    }
    return schedule
end

---Find recipe for item.
---@param item string
---@return Recipe<R>|nil recipe
---@return integer amount
local function findItemRecipe(item)
    local recipes = cookbook.itemRecipes[item]
    if not recipes then return nil, 0 end
    for recipe, amount in pairs(recipes) do
        return recipe, amount
    end
    return nil, 0
end

---Find recipe for item.
---@param fluid string
---@return Recipe<R>|nil recipe
---@return integer amount
local function findFluidRecipe(fluid)
    local recipes = cookbook.fluidRecipes[fluid]
    if not recipes then return nil, 0 end
    for recipe, amount in pairs(recipes) do
        return recipe, amount
    end
    return nil, 0
end

---@class ItemResource
---@field available integer
---@field locations ItemLocation[]

---@class FluidResource
---@field available integer
---@field locations FluidLocation[]

---Builds a recipe tree for the given recipe.
---@param node Node<Schedule>
---@param itemResources table<string, ItemResource>
---@param fluidResources table<string, FluidResource>
---@param itemsMissing table<string, integer>
---@param fluidsMissing table<string, integer>
---@return boolean success
local function _buildRecipeTree(node, itemResources, fluidResources, itemsMissing, fluidsMissing)
    ---@type Schedule
    local schedule = node.value
    return schedule.recipe:forEachIngredient(function(item)
        local resources = itemResources[item.name]
        if not resources then
            local locations, amount = storage.findItem(item.name)
            resources = {
                available = amount,
                locations = locations
            }
            itemResources[item.name] = resources
        end
        local required = math.ceil(schedule.amount / (schedule.result.count or schedule.result.amount)) * item.count
        local usable = math.min(resources.available, required)
        resources.available = resources.available - usable
        local craft = required - usable
        if craft > 0 then
            local recipe, amount = findItemRecipe(item.name)
            if recipe then
                ---@type Schedule
                local subschedule = kitchen.makeSchedule({
                    name = item.name,
                    count = amount
                }, recipe, craft)
                local child = node:add(subschedule)
                return _buildRecipeTree(child, itemResources, fluidResources, itemsMissing, fluidsMissing)
            else
                itemsMissing[item.name] = (itemsMissing[item.name] or 0) + craft
                return false
            end
        end
        return true
    end, function(fluid)
        local resources = fluidResources[fluid.name]
        if not resources then
            local locations, amount = storage.findFluid(fluid.name)
            resources = {
                available = amount,
                locations = locations
            }
            fluidResources[fluid.name] = resources
        end
        local required = math.ceil(schedule.amount / (schedule.result.count or schedule.result.amount)) * fluid.amount
        local usable = math.min(resources.available, required)
        resources.available = resources.available - usable
        local craft = required - usable
        if craft > 0 then
            local recipe, amount = findFluidRecipe(fluid.name)
            if recipe then
                ---@type Schedule
                local subschedule = kitchen.makeSchedule({
                    name = fluid.name,
                    amount = amount
                }, recipe, craft)
                local child = node:add(subschedule)
                return _buildRecipeTree(child, itemResources, fluidResources, itemsMissing, fluidsMissing)
            else
                fluidsMissing[fluid.name] = (fluidsMissing[fluid.name] or 0) + craft
                return false
            end
        end
        return true
    end)
end

---Builds a recipe tree for the given item.
---@param item Item
---@return boolean success
---@return table<string, integer> itemsMissing
---@return table<string, integer> fluidsMissing
local function buildRecipeTree(item)
    local recipe, amount = findItemRecipe(item.name)
    if not recipe then
        return false, { [item.name] = item.count }, {}
    end
    local root = tree.root(kitchen.makeSchedule({name = item.name, count = amount}, recipe, item.count))
    local itemsMissing = {}
    local fluidsMissing = {}
    local success = _buildRecipeTree(root, {}, {}, itemsMissing, fluidsMissing)
    if success then
        kitchen.root = root
    end
    return success, itemsMissing, fluidsMissing
end

---Initializes the kitchen.
function kitchen.init()
    cookbook:readCookbook(function(data)
        return catalysts.parseRecipe(data, cookbook.parser)
    end)
end

---Prints the current crafting tree.
function kitchen.print()
    if kitchen.root then
        kitchen.root:print(function(schedule)
            return schedule:toString()
        end)
    else
        print('Not crafting.')
    end
end

---Schedules the given item to be crafted.
---@param item Item
function kitchen.schedule(item)
    if kitchen.root then
        print('Already crafting item.')
        return
    end

    local success, itemsMissing, fluidsMissing = buildRecipeTree(item)
    if success then
        kitchen.print()
    else
        print('Items missing:')
        for name, count in pairs(itemsMissing) do
            print(' ', name, ':', count)
        end
        print('Fluids missing:')
        for name, count in pairs(fluidsMissing) do
            print(' ', name, ':', count)
        end
    end
end

---Tries to craft items from the crafting tree.
---@return integer tasks new crafting tasks
function kitchen.craft()
    local tasks = 0
    if kitchen.root then
        kitchen.root:forEachNode(function(node)
            ---@type Schedule
            local schedule = node.value
            schedule:craft(function()
                if node:isRoot() then
                    kitchen.root = nil
                else
                    node:remove()
                end
            end)
            return true
        end)
    end
    return tasks
end

---Collects outputs from the catalysts.
function kitchen.collect()
    catalysts.collect(storage)
end

return kitchen