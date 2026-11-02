-- Move only the chosen entity through one natural collision pass. Never grant
-- inventory or open chests manually: those operations bypass native rules.
return function()
    local M = {}
    local pending
    local restocks, tick = {}, 0

    local function same(a, b)
        return a and b and GetPtrHash(a) == GetPtrHash(b)
    end

    function M.busy() return pending ~= nil end

    function M.restore()
        if not pending then return end
        local p = pending.pickup
        if p:Exists() then
            p.Position = pending.position
            p.Velocity = pending.velocity
            p.TargetPosition = pending.targetPosition
        end
    end

    function M.finish()
        if pending and pending.collided and pending.restock and pending.pickup:Exists() then
            local p = pending.pickup
            -- An active-item exchange reuses the purchased pedestal for the old
            -- active: it is a successful purchase even though it still exists.
            pending.exchanged = p.Variant == 100 and pending.variant == 100
                and p.SubType ~= pending.subtype and not p:IsShopItem()
        end
        if pending and pending.collided and pending.restock and
            (pending.exchanged or not pending.pickup:Exists() or pending.pickup:IsDead() or pending.pickup.SubType == 0
                or pending.pickup:GetSprite():IsPlaying("Collect")) then
            pending.expires = tick + 90
            restocks[#restocks+1] = pending
        end
        M.restore()
        pending = nil
    end

    function M.reset()
        M.finish()
        restocks = {}
    end

    function M.step()
        tick = tick + 1
        for i=#restocks,1,-1 do if restocks[i].expires < tick then table.remove(restocks,i) end end
        if not pending then return end
        pending.age = pending.age + 1
        -- Bound the attempt; never wait indefinitely for a pickup to become legal.
        if pending.collided or pending.age >= 3 then M.finish() end
    end

    function M.begin(pickup, player, members)
        if pending or not pickup:Exists() or pickup:IsDead() then return false end
        local replacements = {}
        for slot=0,1 do
            if pickup.Variant == 350 then
                replacements[#replacements+1] = {350, player:GetTrinket(slot)}
            elseif pickup.Variant == 300 or pickup.Variant == 70 then
                replacements[#replacements+1] = {300, player:GetCard(slot)}
                replacements[#replacements+1] = {70, player:GetPill(slot)}
            end
        end
        pending = {
            pickup = pickup, player = player, members = members or {}, protected = {},
            replacements = replacements,
            variant = pickup.Variant, subtype = pickup.SubType,
            position = Vector(pickup.Position.X, pickup.Position.Y),
            velocity = Vector(pickup.Velocity.X, pickup.Velocity.Y),
            targetPosition = Vector(pickup.TargetPosition.X, pickup.TargetPosition.Y),
            contact = Vector(player.Position.X, player.Position.Y),
            container = (pickup.Variant >= 50 and pickup.Variant <= 60) or pickup.Variant == 69
                or pickup.Variant == 360 or pickup.Variant == 390 or pickup:IsShopItem(),
            restock = pickup:IsShopItem() and player:HasCollectible(376),
            collided = false, age = 0,
        }
        pickup.Position = Vector(player.Position.X, player.Position.Y)
        pickup.TargetPosition = Vector(player.Position.X, player.Position.Y)
        pickup.Velocity = Vector.Zero
        return true
    end

    function M.collision(pickup, collider)
        if not pending then return end
        if same(pickup, pending.pickup) then
            if not same(collider, pending.player) then return true end
            if pending.collided then return true end
            pending.collided = true
            -- nil lets all other mods and the native collision handler run.
        elseif same(collider, pending.player) then
            -- Do not chain-collect newly spawned loot or an item dropped by a
            -- replacement during this one collision pass.
            return true
        else
            for _, member in ipairs(pending.members) do
                if same(collider, member) then
                    for _, entity in ipairs(pending.protected) do
                        if same(pickup, entity) then return true end
                    end
                    break
                end
            end
        end
    end

    function M.spawned(entity)
        -- Pocket/trinket swaps spawn the old item with the player as source.
        -- Match only inventory held before this collision, once per held copy.
        if pending and pending.collided and entity.Type == 5 and same(entity.SpawnerEntity, pending.player) then
            local offset = entity.Position - pending.contact
            if offset.X*offset.X + offset.Y*offset.Y <= 48*48 then
                for i, held in ipairs(pending.replacements) do
                    if held[2] ~= 0 and entity.Variant == held[1] and entity.SubType == held[2] then
                        entity.Position = Vector(pending.position.X, pending.position.Y)
                        entity.TargetPosition = Vector(pending.position.X, pending.position.Y)
                        entity.Velocity = Vector.Zero
                        pending.protected[#pending.protected+1] = entity
                        table.remove(pending.replacements, i)
                        return
                    end
                end
            end
        end
        -- Restock births occur after the consumed pickup has been removed and
        -- omit the spawner. Keep only a short, one-use match for that purchase's
        -- displaced contact point; room/reset callbacks discard all matches.
        for i=#restocks,1,-1 do
            local record=restocks[i]
            local offset=entity.Position-record.contact
            if entity.Type==5 and not entity.SpawnerEntity
                and offset.X*offset.X+offset.Y*offset.Y <= 48*48 then
                -- Native Restock snaps the displaced contact to a nearby tile.
                -- Discard that offset for every purchase, including passives and
                -- actives bought into an empty slot; never accumulate it.
                entity.Position=Vector(record.position.X,record.position.Y)
                entity.TargetPosition=Vector(record.position.X,record.position.Y)
                entity.Velocity=Vector.Zero
                if record.exchanged and record.pickup:Exists() then
                    -- Reserve the sale position for stock; put the exchanged
                    -- active on a nearby free tile, respecting room obstacles.
                    local old=record.pickup
                    old.Position=Game():GetRoom():FindFreePickupSpawnPosition(record.position,40,true)
                    old.TargetPosition=Vector(old.Position.X,old.Position.Y)
                    old.Velocity=Vector.Zero
                end
                table.remove(restocks,i)
                return
            end
        end
        if not pending or not pending.collided then return end
        -- Chests can morph into pedestals; the same entity is initialized again.
        if same(entity, pending.pickup) then M.restore(); return end
        local fromPickup = same(entity.SpawnerEntity, pending.pickup)
        -- Native chest pedestals and Restock omit their spawner reference. Only
        -- translate pickup births at the contact point during this transaction.
        local anonymousLoot = pending.container and entity.Type == 5 and not entity.SpawnerEntity
        if not fromPickup and not anonymousLoot then return end
        local offset = entity.Position - pending.contact
        if offset.X*offset.X + offset.Y*offset.Y > 48*48 then return end
        local delta = pending.position - pending.contact
        if entity.Type == 5 then pending.protected[#pending.protected+1] = entity end
        entity.Position = entity.Position + delta
        if entity.Type == 5 then entity.TargetPosition = Vector(entity.Position.X, entity.Position.Y) end
    end

    return M
end
