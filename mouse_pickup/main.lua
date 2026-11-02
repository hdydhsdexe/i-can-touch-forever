local mod = RegisterMod("Mouse Pickup", 1)
local game = Game()
local collect = include("mpickup/collect")()
local bag = include("mpickup/bag")()
local selection = include("mpickup/selection")
local Reach = include("mpickup/reach")
local reach = Reach.new()
local rules = include("mpickup/rules")
local actors = include("mpickup/actors").new(rules)
local eid = include("mpickup/eid").new(game)
local button = selection.newButton()
local switchButton = selection.newButton()
local hovered, box, queued, active
local contextRevision
local development = include("mpickup/development")
local soulCursor

local function reset()
    eid.reset()
    collect.reset()
    bag.reset()
    reach.reset()
    hovered, box, queued, active = nil, nil, nil, nil
    button = selection.newButton()
    switchButton = selection.newButton()
end

local function cancel()
    collect.finish()
    bag.finish()
    queued, active = nil, nil
end

local function suspend()
    cancel()
    eid.reset()
    hovered, box = nil, nil
    button(false, false)
    switchButton(false, false)
end

local config = include("mpickup/config").new(mod, require("json"), function(values, previous)
    if values.enabled ~= previous.enabled or values.pickupButton ~= previous.pickupButton
        or values.switchButton ~= previous.switchButton then suspend() end
    if not values.eidHover then eid.reset() end
end)
config.load()
local mcm = include("mpickup/mcm").new(config)
mcm.update()

local function inputEnabled()
    return config.get("enabled") and not (ModConfigMenu and ModConfigMenu.IsVisible)
end

local function otherBag(current)
    for _, member in ipairs(current.members) do
        if GetPtrHash(member) ~= GetPtrHash(current.player) and (bag.raised(member) or bag.swinging(member)) then return true end
    end
end

-- Check identity before native collision/input callbacks too: updates and
-- renders do not necessarily run between a character change and a collision.
local function context()
    if not inputEnabled() then suspend() end
    local current = actors.resolve(game)
    local revision = current and current.revision
    if revision ~= contextRevision then
        cancel()
        reach.reset()
        eid.reset()
        hovered, box = nil, nil
        button = selection.newButton()
        contextRevision = revision
    end
    if active and (not current or not current.available or otherBag(current)) then cancel() end
    return current
end

local function playableContext(current, bagRaised)
    return inputEnabled() and current and current.available and rules.enabled(game, current.control, bagRaised)
        and (current.player == current.control or current.player:IsExtraAnimationFinished() or bagRaised)
end

local function status(p, item, force, bagRaised, current)
    -- A partner's native bag query can consume a displaced pickup without a
    -- player collision callback. Wait until that bag is lowered and idle.
    if otherBag(current) then return "OTHER BAG" end
    if bagRaised then
        local blocked = bag.blocked(item)
        if blocked then return blocked end
    end
    local room = game:GetRoom()
    reach.refresh(room, p, game:GetFrameCount(), force)
    if not reach.canTouch(room, p, item) then return "BLOCKED" end
    return rules.blocked(p, item)
end

mod:AddPriorityCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, -10000, function(_, pickup, collider)
    if active then
        context()
        if not active then return true end
    end
    local blocked = bag.collision(pickup)
    if blocked ~= nil then return blocked end
    return collect.collision(pickup, collider)
end)
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, entity, hook, action)
    if active then context() end
    return bag.input(entity, hook, action)
end)
mod:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, function(_, entity)
    if active then context() end
    bag.spawned(entity)
end)
mod:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, entity)
    if active then context() end
    bag.knifeUpdated(entity)
end)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, function(_, item, _, player)
    if item == 714 then actors.recall(player)
    elseif item == 703 then actors.useJr(player, game)
    else return end
    context()
end)
for _, callback in ipairs({ModCallbacks.MC_POST_PICKUP_INIT, ModCallbacks.MC_POST_BOMB_INIT,
    ModCallbacks.MC_POST_NPC_INIT, ModCallbacks.MC_POST_EFFECT_INIT}) do
    mod:AddPriorityCallback(callback, -10000, function(_, entity)
        if active then context() end
        collect.spawned(entity)
        bag.spawned(entity)
    end)
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    local current = context()
    local p = current and current.player
    local bagRaised = bag.raised(p)
    local playable = playableContext(current, bagRaised)
    if not playable then suspend() end
    collect.step()
    if playable then bag.step() end
    if not collect.busy() and not bag.busy() then active = nil end
    local request = queued
    queued = nil
    if not request then return end
    local item = request.item
    if playable and request.revision == current.revision and request.bag == bagRaised
        and not collect.busy() and not bag.busy()
        and selection.supported(item, bagRaised, p) and not status(p, item, true, bagRaised, current) then
        local started
        if bagRaised then started = bag.begin(item, p)
        else started = collect.begin(item, p, current.members) end
        if started then active = request end
    end
end)

-- Publish the hover before EID's default-priority render callback.
mod:AddPriorityCallback(ModCallbacks.MC_POST_RENDER, -100, function()
    mcm.update()
    if development and not _G.MousePickupNativeDone then eid.reset(); return end
    local current = context()
    local p = current and current.player
    local bagRaised = bag.raised(p)
    local playable = playableContext(current, bagRaised)
    if switchButton(Input.IsMouseBtnPressed(config.get("switchButton")), playable and current.switchable) then
        cancel()
        actors.switch()
        current = context()
        p = current.player
        bagRaised = bag.raised(p)
        playable = playableContext(current, bagRaised)
        reach.reset()
        eid.reset()
        button = selection.newButton()
    end
    if not playable then suspend() end
    local enabled = playable and not collect.busy() and not bag.busy() and not queued
    local click = button(Input.IsMouseBtnPressed(config.get("pickupButton")), enabled)
    if not enabled then hovered, box = nil, nil; eid.reset(); return end
    local mouse = Isaac.WorldToScreen(Input.GetMousePosition(true))
    hovered, box = selection.choose(Isaac.FindByType(EntityType.ENTITY_PICKUP), mouse, selection.bounds, bagRaised, p)
    if config.get("eidHover") then eid.update(hovered, p) else eid.reset() end
    local color = current.color
    if config.get("showCursor") then
        Isaac.RenderText("+", mouse.X-3, mouse.Y-6, color[1], color[2], color[3], 0.8)
    end
    if config.get("showCursor") and current.diamond then
        if not soulCursor then
            soulCursor = Sprite()
            soulCursor:Load("gfx/ui/mouse_pickup_soul.anm2", true)
            soulCursor:SetFrame("Idle", 0)
        end
        soulCursor.Color = Color(color[1], color[2], color[3], 0.8)
        soulCursor:Render(mouse)
    end
    if not hovered then return end
    local blocked = status(p, hovered, false, bagRaised, current)
    local cost = bagRaised and "BAG" or rules.cost(hovered)
    local r, g, b = 0.3, 1, 0.5
    if blocked then r, g, b = 1, 0.35, 0.3
    elseif cost ~= "RMB" and cost ~= "BAG" then r, g, b = 1, 0.8, 0.25 end
    if cost == "RMB" then cost = ({"RMB", "MMB", "M4", "M5"})[config.get("pickupButton")] end
    if config.get("showBox") then
        Isaac.RenderText("[", box.x-box.w-5, box.y-6, r, g, b, 1)
        Isaac.RenderText("]", box.x+box.w, box.y-6, r, g, b, 1)
    end
    if config.get("showStatus") then
        Isaac.RenderText(blocked or cost, box.x-box.w, box.y-box.h-12, r, g, b, 1)
    end
    if click and not blocked then queued = {item=hovered, bag=bagRaised, revision=current.revision} end
end)

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function() reset(); actors.reset() end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function() reset(); actors.newRoom() end)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function() reset(); actors.reset(); config.load() end)
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, unloaded)
        if unloaded == mod then reset(); mcm.remove() end
    end)
end

-- The development harness is absent from release packages.
if development then include("tests/native")(mod, collect, rules, selection, Reach, development, bag) end
