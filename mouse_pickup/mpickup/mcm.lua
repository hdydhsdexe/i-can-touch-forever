local M = {}
local category = "I can touch forever!"
local buttonNames = {"RMB", "MMB", "M4", "M5"}
local languageValues = {"auto", "zh", "en"}
local options = {
    {"enabled", "Enable Mouse Pickup", "启用鼠标拾取",
        "Enable mouse pickup, recipient switching and hover overlays.", "启用鼠标拾取、领取者切换和悬停显示。"},
    {"pickupButton", "Pickup button", "拾取按键",
        "Choose RMB, MMB, M4 or M5. A conflict swaps the two bindings.", "选择右键、中键、鼠标键4或5。与切换键冲突时自动交换。"},
    {"switchButton", "Switch recipient button", "切换领取者按键",
        "Only switches supported recipient groups. A conflict swaps the two bindings.", "仅切换支持的领取者组。与拾取键冲突时自动交换。"},
    {"showCursor", "Show cursor", "显示光标",
        "Show the crosshair and summoned recipient diamond. Pickup stays enabled.", "显示十字光标和魂石领取者菱形；隐藏后仍可拾取。"},
    {"showBox", "Show target brackets", "显示目标选框",
        "Show brackets around the selected target. Pickup stays enabled.", "显示选中目标的方括号；隐藏后仍可拾取。"},
    {"showStatus", "Show status", "显示状态提示",
        "Show the pickup button, cost or blocking reason. Pickup stays enabled.", "显示拾取按键、费用或阻挡原因；隐藏后仍可拾取。"},
    {"eidHover", "EID hover descriptions", "EID悬停联动",
        "Show hovered targets in EID when installed. Leaves other permanent text alone.", "安装EID时显示鼠标目标说明；保留其他固定提示的优先权。"},
    {"language", "Menu language", "菜单语言",
        "Chinese text requires Mod Config Menu Chinese. Pure displays English.", "自动跟随菜单语言，也可选择中文或英文。Pure版固定显示英文。"}
}

function M.new(config)
    local registered = setmetatable({}, {__mode="k"})
    local api = {}

    local function chinese(mcm)
        return mcm.i18n == "Chinese" and config.get("language") ~= "en"
    end

    function api.update()
        local mcm = _G.ModConfigMenu
        if type(mcm) ~= "table" or type(mcm.AddSetting) ~= "function" or type(mcm.OptionType) ~= "table"
            or not mcm.OptionType.BOOLEAN or not mcm.OptionType.NUMBER then return end
        if not registered[mcm] then
            -- Replace only our own category when the mod's Lua is reloaded.
            if type(mcm.RemoveCategory) == "function" then
                mcm.RemoveCategory("Mouse Pickup") -- Remove our pre-rename category on Lua reload.
                mcm.RemoveCategory(category)
            end
            for _, option in ipairs(options) do
                local key = option[1]
                local binding = key == "pickupButton" or key == "switchButton"
                local language = key == "language"
                mcm.AddSetting(category, nil, {
                    Type=(binding or language) and mcm.OptionType.NUMBER or mcm.OptionType.BOOLEAN,
                    Minimum=language and mcm.i18n ~= "Chinese" and 3 or 1, Maximum=binding and 4 or 3,
                    Default=binding and (key == "pickupButton" and 1 or 2)
                        or (language and (mcm.i18n == "Chinese" and 1 or 3) or true),
                    CurrentSetting=function()
                        if language then
                            if mcm.i18n ~= "Chinese" then return 3 end
                            for i, value in ipairs(languageValues) do if value == config.get(key) then return i end end
                        end
                        return config.get(key)
                    end,
                    Display=function()
                        local zh = chinese(mcm)
                        local value = config.get(key)
                        if binding then value = buttonNames[value]
                        elseif language then
                            if mcm.i18n ~= "Chinese" then value = "English (Pure)"
                            elseif value == "auto" then value = zh and "自动" or "Auto"
                            elseif value == "zh" then value = "中文"
                            else value = "English" end
                        else value = value and (zh and "开" or "On") or (zh and "关" or "Off") end
                        return option[zh and 3 or 2] .. ": " .. value
                    end,
                    Info=function() return {option[chinese(mcm) and 5 or 4]} end,
                    OnChange=function(value)
                        if language then
                            if mcm.i18n ~= "Chinese" then return end
                            value = languageValues[value]
                        end
                        config.set(key, value)
                    end
                })
            end
            registered[mcm] = true
        end
        local name = category
        if registered[mcm] ~= name then
            if type(mcm.SetCategoryNameTranslate) == "function" then mcm.SetCategoryNameTranslate(category, name) end
            registered[mcm] = name
        end
    end

    function api.remove()
        local mcm = _G.ModConfigMenu
        if mcm and registered[mcm] and type(mcm.RemoveCategory) == "function" then
            mcm.RemoveCategory(category)
            registered[mcm] = nil
        end
    end

    return api
end

return M
