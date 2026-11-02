local M = {}

function M.new(rules)
    local signature, available, choices, selected
    local revision = 0
    local recalling
    local changing
    local A = {}

    function A.reset()
        signature, available, choices, selected = nil, false, 0, 1
        revision = revision + 1
        recalling = nil
        changing = nil
    end

    function A.resolve(game)
        local group = rules.group(game)
        if not group then
            if signature then A.reset() end
            return nil
        end
        local p = group.player
        if changing then
            local frame = game:GetFrameCount()
            local id = GetPtrHash(p)
            if id ~= changing.id then changing.id = id; changing.stable = frame end
            if (changing.stable and frame >= changing.stable + 2 or frame >= changing.expires)
                and p:IsExtraAnimationFinished() then changing = nil
            else group.available = false end
        end
        if recalling then
            if GetPtrHash(p) ~= recalling or p:GetPlayerType() ~= 35 or p:HasEntityFlags(EntityFlag.FLAG_HELD) then recalling = nil
            else group.available = false end
        end
        local function identity(member)
            return tostring(GetPtrHash(member))..":"..tostring(member.InitSeed)..":"..member:GetPlayerType()
        end
        local members, candidates = {}, {}
        for _, member in ipairs(group.members) do members[#members+1] = identity(member) end
        table.sort(members)
        for _, candidate in ipairs(group.candidates) do candidates[#candidates+1] = identity(candidate) end
        local current = table.concat(members,";").."/"..table.concat(candidates,";")
            .."/"..identity(group.control).."/"..tostring(group.available).."/"..tostring(group.effect)
            .."/"..(group.owner and identity(group.owner) or "")
        if current ~= signature then
            selected = 1
            revision = revision + 1
            signature, available, choices = current, group.available, #group.candidates
        end
        if selected > 1 then group.player = group.candidates[selected]; group.control = group.player end
        group.diamond = group.markedSoul and GetPtrHash(group.player) == GetPtrHash(group.markedSoul) or false
        group.label = not group.effect and group.switchable and (selected == 2 and "ESAU" or "JACOB") or nil
        local playerKind = group.player:GetPlayerType()
        if group.effect == "strawman" and selected > 1
            or group.strawman and GetPtrHash(group.player) == GetPtrHash(group.strawman) then group.color = {1, 0.8, 0.25}
        elseif playerKind == 16 or playerKind == 35 then group.color = {0.65, 0.65, 0.65}
        elseif playerKind == 17 then group.color = {0.3, 0.65, 1}
        elseif playerKind == 20 or group.effect == "jr-esau" then group.color = {1, 0, 0}
        else group.color = {1, 1, 1} end
        group.revision = revision
        return group
    end

    function A.switch()
        if choices and choices > 1 and available then selected = selected % choices + 1; revision = revision + 1 end
    end

    function A.recall(p)
        if p:GetPlayerType() == 40 then p = p:GetOtherTwin() end
        if p and p:GetPlayerType() == 35 then recalling = GetPtrHash(p) end
    end

    function A.useJr(p, game)
        changing = {id=GetPtrHash(p), expires=game:GetFrameCount()+60}
        revision = revision + 1
    end

    function A.newRoom()
        recalling = nil
    end

    return A
end

return M
