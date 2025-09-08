---@class Node<T> : { value:T, parent_index: integer, children: Node<T>[], parent: Node<T>|nil, isEmpty: (fun(self: Node<T>): boolean), isRoot: (fun(self: Node<T>): boolean), add: (fun(self: Node<T>, value: T): Node), remove: (fun(self: Node<T>): T), forEachNode: (fun(self: Node<T>, action: fun(node: Node<T>): boolean): boolean), forEachLeave: (fun(self: Node<T>, action: fun(node: Node<T>): boolean): boolean), print: (fun(self: Node<T>, stringifier: (fun(value: T): string), indent?: string)) }

local tree = {}

---Creates and returns a new root node.
---@generic T
---@param value T
---@return Node<T>
function tree.root(value)
    ---@type Node<T>
    local node = {
        value = value,
        children = {},
        parent = nil,
        parent_index = 0,
        isEmpty = function(self)
            return #self.children <= 0
        end,
        isRoot = function(self)
            return not self.parent
        end,
        add = function(self, value)
            local child = tree.root(value)
            local i = 0
            for j in ipairs(self.children) do i = j end
            self.children[i + 1] = child
            child.parent_index = i + 1
            child.parent = self
            return child
        end,
        remove = function(self)
            if self.parent then
                self.parent.children[self.parent_index] = nil
            end
            return self.value
        end,
        forEachNode = function(self, action)
            for _, child in pairs(self.children) do
                if not child:forEachNode(action) then
                    return false
                end
            end

            if not action(self) then
                return false
            end

            return true
        end,
        forEachLeave = function(self, action)
            if #self.children > 0 then
                for _, child in pairs(self.children) do
                    if not child:forEachLeave(action) then
                        return false
                    end
                end
                return true
            else
                return action(self)
            end
        end,
        print = function(self, stringifier, indent)
            indent = indent or ''

            print(indent .. stringifier(self.value))

            indent = indent .. '  '
            for _, child in pairs(self.children) do
                child:print(stringifier, indent)
            end
        end
    }

    return node
end

return tree