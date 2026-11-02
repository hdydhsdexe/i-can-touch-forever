-- Drive one native swing; the engine owns the contents, capacity and recipe.
return function()
    local M, pending = {}, nil
    local limits = {[10]=12,[20]=7,[30]=4,[90]=4}
    local bombs = {[1]=true,[2]=true,[4]=true,[7]=true}
    local directions = {Vector(0,-1),Vector(0,1),Vector(-1,0),Vector(1,0)}
    local actions = {ButtonAction.ACTION_SHOOTUP,ButtonAction.ACTION_SHOOTDOWN,
        ButtonAction.ACTION_SHOOTLEFT,ButtonAction.ACTION_SHOOTRIGHT}

    function M.raised(p)
        return p and p:GetItemState() == 710 and p:HasCollectible(710)
    end

    function M.material(item)
        local v, s = item.Variant, item.SubType
        if limits[v] then return s >= 1 and s <= limits[v] end
        if v == 40 then return bombs[s] == true end
        if v == 42 then return s == 0 or s == 1 end
        return (v == 70 or v == 300) and s > 0
    end

    function M.blocked(item)
        if not M.material(item) then return "NOT MATERIAL" end
        -- Bag swings cannot buy shop stock or pay for deals.
        if item:IsShopItem() or (item.Price ~= 0 and item.Price ~= -1000) then return "SHOP ITEM" end
    end

    local function same(a,b) return a and b and GetPtrHash(a)==GetPtrHash(b) end
    function M.swinging(p)
        for _, knife in ipairs(Isaac.FindByType(8,4)) do
            if same(knife.SpawnerEntity,p) or same(knife.Parent,p) then return true end
        end
        return false
    end
    local function consumed(item)
        return not item:Exists() or item:IsDead() or item:GetSprite():IsPlaying("Collect")
    end
    local function park(record)
        local item=record.pickup
        item.Position=record.parked
        item.TargetPosition=Vector(item.Position.X,item.Position.Y)
        item.Velocity=Vector.Zero
        item.GridCollisionClass=0
    end
    local function restore(record)
        local item=record.pickup
        if item:Exists() then
            item.Position=record.position
            item.TargetPosition=record.targetPosition
            item.Velocity=record.velocity
            item.GridCollisionClass=record.gridCollision
        end
    end
    local function isolate(item)
        if not pending or item.Type ~= 5 or same(item,pending.pickup) then return end
        item=item:ToPickup()
        -- Native option cancellation must still be able to query alternatives.
        -- Park every sibling off the swing's line, including distant ones
        -- that a high-range bag can reach. They must remain queryable.
        if pending.options > 0 and item.OptionsPickupIndex == pending.options then
            local record={pickup=item,position=Vector(item.Position.X,item.Position.Y),
                targetPosition=Vector(item.TargetPosition.X,item.TargetPosition.Y),
                velocity=Vector(item.Velocity.X,item.Velocity.Y),gridCollision=item.GridCollisionClass,
                parked=pending.safePosition}
            pending.parked[#pending.parked+1]=record
            park(record)
            return
        end
        if not item:HasEntityFlags(EntityFlag.FLAG_NO_QUERY) then
            item:AddEntityFlags(EntityFlag.FLAG_NO_QUERY)
            pending.hidden[#pending.hidden+1] = item
        end
    end
    function M.busy() return pending ~= nil end
    function M.finish()
        if not pending then return end
        restore(pending)
        for _,record in ipairs(pending.parked) do restore(record) end
        for _, other in ipairs(pending.hidden) do
            if other:Exists() then other:ClearEntityFlags(EntityFlag.FLAG_NO_QUERY) end
        end
        -- Only remove the swing created for this transaction, including any
        -- extra bag knives created by native synergies while input was pulsed.
        for _, knife in ipairs(pending.knives) do if knife:Exists() then knife:Remove() end end
        pending = nil
    end
    M.reset = M.finish

    function M.begin(item,p)
        if pending or not M.raised(p) or not item:Exists() or consumed(item)
            or item.Wait > 0 or M.blocked(item) then return false end
        -- Never take ownership of a swing the player already started.
        if M.swinging(p) then return false end
        local delta = item.Position-p.Position
        local direction = math.abs(delta.X) >= math.abs(delta.Y) and (delta.X >= 0 and 4 or 3)
            or (delta.Y >= 0 and 2 or 1)
        local safePosition
        if item.OptionsPickupIndex > 0 then
            -- Clearance perpendicular to the whole swing line is independent
            -- of range; distance from the player alone is not safe.
            local room, distance = Game():GetRoom(), 64
            for i=0,room:GetGridSize()-1 do
                local pos=room:GetGridPosition(i)
                local d=direction <= 2 and math.abs(pos.X-p.Position.X) or math.abs(pos.Y-p.Position.Y)
                if room:IsPositionInRoom(pos,20) and d>distance then safePosition=pos; distance=d end
            end
            if not safePosition then return false end
        end
        pending = {pickup=item,player=p,position=Vector(item.Position.X,item.Position.Y),
            targetPosition=Vector(item.TargetPosition.X,item.TargetPosition.Y),
            velocity=Vector(item.Velocity.X,item.Velocity.Y),gridCollision=item.GridCollisionClass,
            direction=direction,age=0,hidden={},knives={},parked={},
            options=item.OptionsPickupIndex,safePosition=safePosition}
        for _, other in ipairs(Isaac.FindByType(5)) do isolate(other) end
        item.GridCollisionClass = 0
        item.Position = p.Position+directions[direction]*40
        item.TargetPosition = Vector(item.Position.X,item.Position.Y)
        item.Velocity = Vector.Zero
        return true
    end

    function M.input(entity,hook,action)
        if not pending or not same(entity,pending.player) then return end
        for i, shoot in ipairs(actions) do
            if action == shoot then
                local direction = pending.direction
                local room = Game():GetRoom()
                if room:IsMirrorWorld() and direction >= 3 then direction = 7-direction end
                local pressed = pending.age == 0 and M.raised(pending.player) and i == direction
                if hook == InputHook.GET_ACTION_VALUE then return pressed and 1 or 0 end
                return pressed
            end
        end
    end
    function M.spawned(entity)
        if not pending then return end
        if entity.Type==8 and entity.Variant==4 and same(entity.SpawnerEntity,pending.player) then
            pending.knives[#pending.knives+1]=entity
        elseif entity.Type==5 then isolate(entity) end
    end
    function M.collision(item)
        if pending and same(item,pending.pickup) then return true end
    end
    local function followSwing()
        local item,player=pending.pickup,pending.player
        local position=player.Position+directions[pending.direction]*40
        local distance=-1
        for _,knife in ipairs(pending.knives) do
            if knife:Exists() then
                local d=knife.Position:Distance(player.Position)
                if d>distance then position=knife.Position; distance=d end
            end
        end
        item.Position=Vector(position.X,position.Y)
        item.TargetPosition=Vector(position.X,position.Y)
        item.Velocity=Vector.Zero
    end
    function M.knifeUpdated(knife)
        if not pending or consumed(pending.pickup) then return end
        for _,owned in ipairs(pending.knives) do
            if same(knife,owned) then
                -- The native bag head (subtype 4) decelerates from its initial
                -- velocity. Keep this transaction's endpoint inside the room:
                -- pickups outside the room can disappear from native queries.
                if knife.SubType==4 then
                    local endpoint=Game():GetRoom():GetClampedPosition(knife.Position+knife.Velocity,20)
                    knife.Velocity=endpoint-knife.Position
                end
                followSwing(); return
            end
        end
    end
    function M.step()
        if not pending then return end
        pending.age = pending.age+1
        if consumed(pending.pickup) or pending.age >= 12 or not M.raised(pending.player) then
            M.finish(); return
        end
        for _,record in ipairs(pending.parked) do if record.pickup:Exists() then park(record) end end
        followSwing()
    end
    return M
end
