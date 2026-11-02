-- Stand-in for the engine's JSON/storage APIs. Encoding itself is not under test.
return function()
    local objects, slots, slot, serial = {}, {}, 1, 0
    local mod = {writes=0, logs={}}
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = copy(item) end
        return result
    end
    local json = {}
    function json.encode(value)
        serial = serial+1
        local text = "test-json-" .. serial
        objects[text] = copy(value)
        return text
    end
    function json.decode(text)
        assert(objects[text] ~= nil, "invalid test JSON")
        return copy(objects[text])
    end
    function mod:HasData() return slots[slot] ~= nil end
    function mod:LoadData() return slots[slot] or "" end
    function mod:SaveData(text) slots[slot] = text; self.writes = self.writes+1 end
    function mod:slot(value) slot = value end
    function mod:seed(value) slots[slot] = json.encode(value) end
    return mod, json
end
