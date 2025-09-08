---List of inventory peripherals
---@type table<integer, string>
local storages = {
    'farmersdelight:pantry_3',
    'farmersdelight:pantry_4',
    'farmersdelight:pantry_5',
    'farmersdelight:pantry_0',
    'farmersdelight:pantry_1',
    'farmersdelight:pantry_2'
}

---Tanks for each fluid.
---@type table<string, string>
local tanks = {
    ['minecraft:water'] = 'create:fluid_tank_0',
    ['minecraft:milk'] = 'create:fluid_tank_3',
    ['create:honey'] = 'create:fluid_tank_4',
    ['create:chocolate'] = 'create:fluid_tank_8',
    ['create:tea'] = 'create:fluid_tank_10'
}

---@class Storage
local storage = {}

---@class ItemLocation
---@field peripheral table
---@field slot integer
---@field getStack fun(self: ItemLocation): Item
---@field isEmpty fun(self: ItemLocation): boolean
---@field move fun(self: ItemLocation, peripheral_to: string, slot_to?: integer, amount?: integer): integer

---@class FluidLocation
---@field peripheral table
---@field tank integer
---@field getFluid fun(self: FluidLocation): Fluid
---@field isEmpty fun(self: FluidLocation): boolean
---@field move fun(self: FluidLocation, peripheral_to: string, amount: integer): integer

---Creates a new Item Location
---@param peripheral table
---@param slot integer
---@return ItemLocation
function storage.itemlocation(peripheral, slot)
    return {
        peripheral = peripheral,
        slot = slot,
        getStack = function(self)
            return self.peripheral.getItemDetail(self.slot)
        end,
        isEmpty = function(self)
            return not self:getStack()
        end,
        move = function(self, peripheral_to, slot_to, amount)
            return self.peripheral.pushItems(peripheral_to, self.slot, amount, slot_to)
        end
    }
end

---Creates a new Fluid Location
---@param peripheral table
---@param tank integer
---@return FluidLocation
function storage.fluidlocation(peripheral, tank)
    return {
        peripheral = peripheral,
        tank = tank,
        getFluid = function(self)
            return self.peripheral.tanks()[self.tank]
        end,
        isEmpty = function(self)
            return not self:getFluid()
        end,
        move = function(self, peripheral_to, amount)
            local fluid = self:getFluid()
            if not fluid then return 0 end
            return self.peripheral.pushFluid(peripheral_to, amount, fluid.name)
        end
    }
end

---Returns a list of Item Locations storing items with the given name.
---@param name string
---@param amount? integer
---@return ItemLocation[] locations
---@return integer count
function storage.findItem(name, amount)
    ---@type ItemLocation[]
    local locations = {}
    local i = 1
    local count = 0
    for _, n in ipairs(storages) do
        local p = peripheral.wrap(n)
        if p then
            local content = p.list()
            for slot, item in pairs(content) do
                if item.name == name then
                    locations[i] = storage.itemlocation(p, slot)
                    i = i + 1
                    count = count + item.count
                    if amount then
                        amount = amount - item.count
                        if amount <= 0 then
                            return locations, count
                        end
                    end
                end
            end
        end
    end
    return locations, count
end

---Returns a list of Fluid Locations storing fluids with the given name.
---@param name string
---@param amount? integer
---@return FluidLocation[] locations
---@return integer count
function storage.findFluid(name, amount)
    local tank = tanks[name]
    if not tank then
        return {}, 0
    end

    local p = peripheral.wrap(tank)
    if not p then
        return {}, 0
    end

    ---@type FluidLocation[]
    local locations = {}
    local i = 1
    local count = 0
    for slot, fluid in pairs(p.tanks()) do
        if fluid.name == name then
            locations[i] = storage.fluidlocation(p, slot)
            i = i + 1
            count = count + fluid.amount
            if amount then
                amount = amount - fluid.amount
                if amount <= 0 then
                    return locations, count
                end
            end
        end
    end
    return locations, count
end

---Inserts amount of the item at the given location and returns the rest.
---@param location ItemLocation
---@param amount? integer
---@return integer rest
function storage.insertItem(location, amount)
    if not amount then
        local item = location:getStack()
        if not item then
            return 0
        end
        amount = item.count
    end
    for _, n in ipairs(storages) do
        if peripheral.isPresent(n) then
            amount = amount - location:move(n, nil, amount)
            if amount <= 0 then break end
        end
    end
    return amount
end

---Inserts amount of the fluid at the given location and returns the rest.
---@param location FluidLocation
---@param amount? integer
---@return integer rest
function storage.insertFluid(location, amount)
    local fluid = location:getFluid()
    if not fluid then
        return 0
    end
    amount = amount or fluid.amount

    local tank = tanks[fluid.name]
    if not tank then
        return amount
    end

    return amount - location:move(tank, amount)
end

---Moves all items specified by the given item location in the given peripheral.
---@param locations ItemLocation[]
---@param peripheral_to string
---@param slot_to? integer
---@param amount? integer
---@return integer rest
function storage.extractItem(locations, peripheral_to, slot_to, amount)
    for _, location in ipairs(locations) do
        local extracted = location:move(peripheral_to, slot_to, amount)
        if amount then
            amount = amount - extracted
            if amount <= 0 then break end
        end
    end
    return amount or 0
end

---Moves all fluids specified by the given fluid locations in the given peripheral.
---@param locations FluidLocation[]
---@param peripheral_to string
---@param amount integer
---@return integer rest
function storage.extractFluid(locations, peripheral_to, amount)
    for _, location in ipairs(locations) do
        amount = amount - location:move(peripheral_to, amount)
        if amount <= 0 then break end
    end
    return amount
end

return storage