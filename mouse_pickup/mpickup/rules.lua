local M = {}
local paired = {[16]=true,[17]=true,[19]=true,[20]=true,[35]=true,[40]=true}

local function same(a, b)
    return a and b and GetPtrHash(a) == GetPtrHash(b)
end

local function alive(p)
    return p and p:Exists() and not p:IsDead() and not p:IsCoopGhost()
end

local function context(p, other, control, switchable, available, effect)
    return {player=p, control=control, members={p, other},
        candidates=switchable and {p, other} or {p},
        switchable=switchable, available=available, effect=effect}
end

local function ordinary(p)
    local kind = p:GetPlayerType()
    return kind >= 0 and kind <= 40 and not paired[kind] and kind ~= 29 and kind ~= 38
        and kind ~= 37 and kind ~= 39 and not p:GetSubPlayer() and not p:GetOtherTwin()
end

-- Only the probed bases and single companion effects may form a stacked group.
local function stackedCompanion(game)
    if game:GetNumPlayers() > 3 then return nil end
    local bases, child = {}, nil
    for i=0,game:GetNumPlayers()-1 do
        local member = Isaac.GetPlayer(i)
        if member.Parent then
            local role = member:GetPlayerType()
            if child or role ~= 14 and role ~= 16 and role ~= 20 then return nil end
            child = member
        else bases[#bases+1] = member end
    end
    local p = bases[1]
    if not p then return nil end
    local kind, other, sub = p:GetPlayerType(), bases[2], p:GetSubPlayer()
    if other then
        if kind == 20 and other:GetPlayerType() == 19 then p, other = other, p; kind = 19 end
        if #bases ~= 2 or kind ~= 19 or other:GetPlayerType() ~= 20
            or not alive(other) or other:GetSubPlayer() or p:GetSubPlayer()
            or not same(p:GetOtherTwin(), other) or not same(other:GetOtherTwin(), p)
            or p.ControllerIndex ~= other.ControllerIndex then return nil end
    elseif kind == 16 or kind == 17 then
        if not sub or sub:GetPlayerType() ~= (kind == 16 and 17 or 16)
            or p:GetOtherTwin() or sub:GetOtherTwin() or sub.ControllerIndex ~= p.ControllerIndex then return nil end
    elseif kind == 29 or kind == 38 then
        if sub or p:GetOtherTwin() or p:HasCollectible(619) then return nil end
    else return nil end
    if not alive(p) then return nil end
    local members, candidates = {p}, {p}
    if other then members[#members+1] = other; candidates[#candidates+1] = other end
    if sub then members[#members+1] = sub end
    local copies, owner = 0, nil
    for _, member in ipairs(members) do
        local number = member:GetCollectibleNum(667)
        copies = copies + number
        if number > 0 then owner = member end
        if member:HasCollectible(703) or member:GetEffects():HasNullEffect(100)
            or member:GetEffects():HasNullEffect(120) or member:GetEffects():HasNullEffect(121) then return nil end
    end
    local effect = "stack-strawman"
    if child then
        local role = child:GetPlayerType()
        local bone, twin = child:GetEffects():HasNullEffect(120), child:GetEffects():HasNullEffect(121)
        if role == 14 and copies == 1 and not bone and not twin then
            if not same(child.Parent, owner) then return nil end
        elseif role == 16 and bone and not twin and copies == 0 and (kind == 19 or kind == 16 or kind == 17 or kind == 29 or kind == 38) then
            effect, owner = "stack-soul-forgotten", child.Parent
        elseif role == 20 and twin and not bone and copies == 0 and (kind == 19 or kind == 16 or kind == 17 or kind == 29 or kind == 38) then
            effect, owner = "stack-soul-jacob", child.Parent
        else return nil end
        if not same(owner, p) and not same(owner, other) then return nil end
        -- Parent is an Entity wrapper; keep the matched player for identity reads.
        owner = same(owner, p) and p or other
        if child.ControllerIndex ~= p.ControllerIndex
            or child:GetSubPlayer() or child:GetOtherTwin() or child:HasCollectible(667)
            or child:HasCollectible(703) or child:GetEffects():HasNullEffect(100) then return nil end
        members[#members+1] = child
        if alive(child) then candidates[#candidates+1] = child end
    elseif copies ~= 1 then return nil end
    return {player=p, control=p, members=members, candidates=candidates,
        switchable=#candidates>1, available=true, effect=effect,
        strawman=effect=="stack-strawman" and child or nil, owner=owner,
        markedSoul=(kind==19 and effect=="stack-soul-jacob"
            or (kind==16 or kind==17) and effect=="stack-soul-forgotten") and child or nil}
end

function M.group(game)
    local stacked = stackedCompanion(game)
    if stacked then return stacked end
    local count = game:GetNumPlayers()
    if count ~= 1 and count ~= 2 then return nil end
    local p = Isaac.GetPlayer(0)
    if count == 2 then
        local other = Isaac.GetPlayer(1)
        if p.Parent or other.Parent then
            if p.Parent then p, other = other, p end
            if not alive(p) or p.Parent or not same(other.Parent, p) or not ordinary(p)
                or other:GetSubPlayer() or other:GetOtherTwin() or other.ControllerIndex ~= p.ControllerIndex
                or p:HasCollectible(703) or p:GetEffects():HasNullEffect(100)
                or other:HasCollectible(703) or other:HasCollectible(667) then return nil end
            local kind, straw = other:GetPlayerType(), p:GetCollectibleNum(667)
            local effect
            if kind == 14 and straw == 1 then effect = "strawman"
            elseif kind == 20 and straw == 0 and other:GetEffects():HasNullEffect(121) then effect = "soul-jacob"
            elseif kind == 16 and straw == 0 and other:GetEffects():HasNullEffect(120) then effect = "soul-forgotten"
            else return nil end
            return context(p, other, p, alive(other), true, effect)
        end
    end
    if not alive(p) or p.Parent then return nil end
    local kind = p:GetPlayerType()
    if count == 1 and (kind == 16 or kind == 17) then
        local sub = p:GetSubPlayer()
        -- The inactive form is a sub-player, not a second enumerated player.
        -- Its Exists()/health need not match the active form.
        if not sub or sub:GetPlayerType() ~= (kind == 16 and 17 or 16)
            or sub.ControllerIndex ~= p.ControllerIndex or p:GetOtherTwin()
            or sub:GetOtherTwin() then return nil end
        if p:HasCollectible(667) or p:HasCollectible(703) then return nil end
        return context(p, sub, p, false, true)
    end
    if count == 2 then
        local other = Isaac.GetPlayer(1)
        if not alive(other) or other.Parent or same(p, other) then return nil end
        if p:HasCollectible(667) or other:HasCollectible(667)
            or p:HasCollectible(703) or other:HasCollectible(703) then return nil end
        if p:GetSubPlayer() or other:GetSubPlayer()
            or p.ControllerIndex ~= other.ControllerIndex then return nil end
        local twin, back = p:GetOtherTwin(), other:GetOtherTwin()
        if not twin or not back or GetPtrHash(twin) ~= GetPtrHash(other)
            or GetPtrHash(back) ~= GetPtrHash(p) then return nil end
        local otherKind = other:GetPlayerType()
        if kind == 20 and otherKind == 19 then p, other = other, p; kind, otherKind = 19, 20 end
        if kind == 19 and otherKind == 20 then
            return context(p, other, p, true, true)
        end
        if kind == 40 and otherKind == 35 then p, other = other, p; kind, otherKind = 35, 40 end
        if kind == 35 and otherKind == 40 then
            -- Native held/thrown flags also cover the zero-velocity endpoints.
            -- Recall sets both knockback flags; motion/height alone is insufficient.
            local moving = EntityFlag.FLAG_HELD | EntityFlag.FLAG_THROWN
                | EntityFlag.FLAG_NO_KNOCKBACK | EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK
            local grounded = p:GetEntityFlags() & moving == 0 and p.Visible and p.EntityCollisionClass == 4
                and p.PositionOffset.X == 0 and p.PositionOffset.Y == 0
                and p.Velocity.X*p.Velocity.X + p.Velocity.Y*p.Velocity.Y < 0.0001
                and p.GridCollisionClass == (p.CanFly and 3 or 5)
            return context(p, other, other, false, grounded)
        end
        if ((kind == 29 and otherKind == 38) or (kind == 38 and otherKind == 29))
            and (p:HasCollectible(619) or other:HasCollectible(619)) then
            -- In the native probe GetMainTwin follows the foreground after Flip;
            -- the background hologram has no entity collision, even when visible.
            local main = p:GetMainTwin()
            if not same(main, other:GetMainTwin()) then return nil end
            if same(main, other) then p, other = other, p
            elseif not same(main, p) then return nil end
            return context(p, other, p, false, p.EntityCollisionClass == 4 and other.EntityCollisionClass == 0)
        end
        return nil
    end
    if paired[kind] or p:GetSubPlayer() or p:GetOtherTwin() then return nil end
    if p:HasCollectible(703) or p:GetEffects():HasNullEffect(100) then
        if not ordinary(p) or p:HasCollectible(667) then return nil end
        -- Esau Jr retains the original player type; native null effect 100
        -- identifies the alternate. Only the foreground is exposed in the room.
        return context(p, nil, p, false, true, p:GetEffects():HasNullEffect(100) and "jr-esau" or "jr-main")
    end
    if p:HasCollectible(667) then
        if not ordinary(p) or p:GetCollectibleNum(667) ~= 1 then return nil end
        return context(p, nil, p, false, true, "strawman")
    end
    return context(p, nil, p, false, true)
end

-- Keep the native comparison harness interface; selection lives in actors.lua.
function M.player(game)
    local group = M.group(game)
    if group and group.available then return group.player, group.members[2] end
end

function M.enabled(game, p, bagRaised)
    if not p or game:IsPaused() or p:IsDead() or not p.ControlsEnabled
        or (p:IsExtraAnimationFinished() == false and not bagRaised) then return false end
    if ModConfigMenu and ModConfigMenu.IsVisible then return false end
    local room = game:GetRoom()
    return room:GetFrameCount() > 1 and room:IsClear() and room:GetAliveEnemiesCount() == 0
end

function M.blocked(p, item)
    if item.Wait > 0 then return "WAIT" end
    if item.Price > 0 and p:GetNumCoins() < item.Price then return "NO COINS" end
    if item.Variant == 51 and item.SubType == 1 then return "NEEDS BOMB" end
    if item.Variant == 20 and item.SubType == 6 then return "NEEDS BOMB" end
    -- Capacity, deals, chest locks and character-specific effects remain native.
end

function M.cost(item)
    if item.Price > 0 then return tostring(item.Price) .. "c" end
    if item.Price < 0 and item.Price ~= -1000 then return "! HP COST" end
    if item.Variant == 52 or item.Variant == 54 then return "! DAMAGE" end
    if item.Variant == 60 or item.Variant == 57 then return "! KEY" end
    if item.Variant == 53 then return "! KEY / HP" end
    return "RMB"
end

return M
