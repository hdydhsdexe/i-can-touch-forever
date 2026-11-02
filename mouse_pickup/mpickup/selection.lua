local M = {}

-- These are the base game's touch-interactable pickup variants. Empty pedestals
-- and ending/transition objects are deliberately not interactive targets.
local variants = {}
for _, id in ipairs({10,20,30,40,50,51,52,53,54,55,56,57,58,60,69,70,90,100,300,350,360,390}) do
    variants[id] = true
end

function M.supported(p, bagRaised, player)
    local poop = p.Variant == 42 and (bagRaised or (player and player:GetPlayerType() == 25
        and (p.SubType == 0 or p.SubType == 1)))
    return (variants[p.Variant] or poop) and p.Visible and p:Exists() and not p:IsDead()
        and not (p.Variant == 100 and p.SubType == 0)
        and not p:GetSprite():IsPlaying("Collect")
end

function M.bounds(p)
    local sprite = p:GetSprite()
    local base = Isaac.WorldToScreen(p.Position + p.PositionOffset) + p.SpriteOffset + sprite.Offset
    if Game():GetRoom():IsMirrorWorld() then
        base.X = Isaac.GetScreenWidth() - base.X
    end
    local pedestal = p.Variant == 100
    local halfWidth = math.max(p.Size, pedestal and 16 or 12) * math.abs(p.SpriteScale.X)
    local height = (pedestal and 42 or 26) * math.abs(p.SpriteScale.Y)
    return {x=base.X, y=base.Y-height/2+4, w=halfWidth, h=height/2}
end

function M.above(a, b)
    if a.SortingLayer ~= b.SortingLayer then return a.SortingLayer > b.SortingLayer end
    local ay, by = a.Position.Y + a.DepthOffset, b.Position.Y + b.DepthOffset
    if ay ~= by then return ay > by end
    -- J460 draws the lower entity index on top when layer and depth tie.
    return a.Index < b.Index
end

function M.choose(pickups, mouse, bounds, bagRaised, player)
    local best, bestBox
    for _, entity in ipairs(pickups) do
        local p = entity:ToPickup()
        if p and M.supported(p, bagRaised, player) then
            local box = bounds(p)
            if math.abs(mouse.X-box.x) <= box.w and math.abs(mouse.Y-box.y) <= box.h
                and (not best or M.above(p, best)) then
                best, bestBox = p, box
            end
        end
    end
    return best, bestBox
end

function M.newButton()
    local armed = false
    return function(down, enabled)
        if not enabled then armed = false; return false end
        if not down then armed = true; return false end
        local click = armed
        armed = false
        return click
    end
end

return M
