local M = {}
local defaults = {enabled=true, pickupButton=1, switchButton=2, showCursor=true,
    showBox=true, showStatus=true, eidHover=true, language="auto"}
local buttons = {[1]=true, [2]=true, [3]=true, [4]=true}
local languages = {auto=true, zh=true, en=true}

local function valid(key, value)
    if key == "pickupButton" or key == "switchButton" then return buttons[value] == true end
    if key == "language" then return languages[value] == true end
    return type(value) == "boolean"
end

function M.new(mod, json, changed)
    local values = {}
    local api = {}

    function api.get(key) return values[key] end

    function api.load()
        local saved
        if mod:HasData() then
            local ok, data = pcall(json.decode, mod:LoadData())
            if ok and type(data) == "table" and data.version == 1 and type(data.settings) == "table" then
                saved = data.settings
            else
                Isaac.DebugString("Mouse Pickup: invalid configuration; using defaults.")
            end
        end
        local previous = values
        values = {}
        for key, default in pairs(defaults) do
            values[key] = default
            if saved and valid(key, saved[key]) then values[key] = saved[key] end
        end
        if values.pickupButton == values.switchButton then
            values.pickupButton, values.switchButton = defaults.pickupButton, defaults.switchButton
        end
        if changed then changed(values, previous) end
    end

    function api.set(key, value)
        if defaults[key] == nil or not valid(key, value) or values[key] == value then return false end
        local previous = {}
        for name, current in pairs(values) do previous[name] = current end
        if key == "pickupButton" and value == values.switchButton then
            values.switchButton = values.pickupButton
        elseif key == "switchButton" and value == values.pickupButton then
            values.pickupButton = values.switchButton
        end
        values[key] = value
        if changed then changed(values, previous) end
        mod:SaveData(json.encode({version=1, settings=values}))
        return true
    end

    return api
end

return M
