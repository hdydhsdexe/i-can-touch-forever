local M = {}

function M.passable(collision, gridClass, flying)
    if collision == 4 then return false end -- room walls always bound the search
    if collision == 0 or collision == 5 then return true end
    if flying or gridClass == 0 or gridClass == 3 then return true end
    if collision == 1 then return gridClass == 6 or gridClass == 4 end
    return false
end

function M.flood(cells, width, count, start, canStep)
    local seen, queue, head = {}, {}, 1
    if not cells[start] then return seen end
    seen[start], queue[1] = true, start
    while head <= #queue do
        local i = queue[head]
        head = head + 1
        local x = i % width
        local function visit(n)
            if n >= 0 and n < count and cells[n] and not seen[n]
                and (not canStep or canStep(i,n)) then
                seen[n] = true; queue[#queue+1] = n
            end
        end
        if x > 0 then visit(i-1) end
        if x < width-1 then visit(i+1) end
        visit(i-width); visit(i+width)
    end
    return seen
end

-- Hazard geometry is inflated by the player's radius. Checking whole segments
-- also catches hazards between grid centers and unsafe edge-touch shortcuts.
local function clearSegment(hazards, a, b)
    for _,h in ipairs(hazards) do
        local dx,dy=b.X-a.X,b.Y-a.Y
        if h.square then
            local lo,hi=0,1
            for _,axis in ipairs({{a.X,dx,h.x},{a.Y,dy,h.y}}) do
                if axis[2]==0 then
                    if math.abs(axis[1]-axis[3])>h.radius then lo,hi=1,0; break end
                else
                    local u=(axis[3]-h.radius-axis[1])/axis[2]
                    local v=(axis[3]+h.radius-axis[1])/axis[2]
                    lo=math.max(lo,math.min(u,v)); hi=math.min(hi,math.max(u,v))
                end
            end
            if lo<=hi then return false end
        else
            local length=dx*dx+dy*dy
            local t=length>0 and math.max(0,math.min(1,((h.x-a.X)*dx+(h.y-a.Y)*dy)/length)) or 0
            local x,y=a.X+t*dx-h.x,a.Y+t*dy-h.y
            if x*x+y*y<=h.radius*h.radius then return false end
        end
    end
    return true
end

local function capabilities(player)
    local callus=player:HasTrinket(14)
    local socks=player:HasCollectible(571)
    local flatFile=player:HasTrinket(151)
    return player.CanFly or callus or socks or flatFile,
        player.CanFly or callus or socks, player.CanFly or flatFile
end

-- Only hostile damaging creep variants; white/black slowing creep and player
-- creep are not treated as damage. Other mods' custom hazards are not inferred.
local damagingCreep = {[22]=true,[23]=true,[24]=true}

function M.new()
    local C = {cells={}, reached={}, hazards={}, checked=-100, start=-1, count=0, width=0}
    function C.reset()
        C.cells, C.reached, C.hazards, C.checked, C.start = {}, {}, {}, -100, -1
    end
    function C.refresh(room, player, frame, force)
        local start = room:GetGridIndex(player.Position)
        local spikes,creep,spikedRocks=capabilities(player)
        local count,width=room:GetGridSize(),room:GetGridWidth()
        if not force and frame==C.checked and start==C.start and count==C.count and width==C.width
            and player.CanFly==C.flying and player.GridCollisionClass==C.gridClass
            and player.Size==C.size and spikes==C.spikes and creep==C.creep and spikedRocks==C.spikedRocks
            and player.Position.X==C.x and player.Position.Y==C.y then return end
        local hazards,positions={},{}
        local function hazard(pos,radius,square)
            hazards[#hazards+1]={x=pos.X,y=pos.Y,radius=radius+player.Size,square=square}
        end
        for i=0,count-1 do
            local pos=room:GetGridPosition(i)
            positions[i]=pos
            local grid=room:GetGridEntity(i)
            if grid then
                local kind=grid:GetType()
                -- Fixed spikes can be permanently lowered. Cycling spikes must
                -- remain blocked even during their off phase.
                if (not spikes and ((kind==8 and grid.State~=1) or kind==9))
                    or (not spikedRocks and kind==25 and grid.State~=2)
                    or (not player.CanFly and kind==14 and grid:GetVariant()==1) then hazard(pos,20,true) end
            end
        end
        for _,e in ipairs(Isaac.FindByType(33)) do
            if e:Exists() and not e:IsDead() and e.HitPoints>1 then hazard(e.Position,e.Size,false) end
        end
        if not creep then
            for _,e in ipairs(Isaac.FindByType(1000)) do
                if damagingCreep[e.Variant] and e:Exists() and not e:IsDead() then
                    hazard(e.Position,e.Size,false)
                end
            end
        end
        C.hazards=hazards
        for i=0,count-1 do
            C.cells[i]=room:IsPositionInRoom(positions[i],0)
                and M.passable(room:GetGridCollision(i),player.GridCollisionClass,player.CanFly)
                and clearSegment(hazards,positions[i],positions[i])
        end
        if positions[start] and clearSegment(hazards,player.Position,positions[start]) then
            C.reached=M.flood(C.cells,width,count,start,function(a,b)
                return clearSegment(hazards,positions[a],positions[b])
            end)
        else C.reached={} end
        C.checked,C.start,C.count,C.width=frame,start,count,width
        C.flying,C.gridClass,C.size=player.CanFly,player.GridCollisionClass,player.Size
        C.spikes,C.creep,C.spikedRocks=spikes,creep,spikedRocks
        C.x,C.y=player.Position.X,player.Position.Y
    end
    function C.canTouch(room, player, pickup)
        local target = room:GetGridIndex(pickup.Position)
        if C.reached[target] and clearSegment(C.hazards,room:GetGridPosition(target),pickup.Position) then return true end
        -- The center need not be walkable: a pickup resting at an edge can be
        -- touched from an adjacent tile. Inset that tile by the player's radius.
        local radius = player.Size + pickup.Size
        local extent = math.max(0, 20-player.Size)
        local x, y = target % C.width, math.floor(target/C.width)
        for dy = -1, 1 do
            for dx = -1, 1 do
                local nx, ny = x+dx, y+dy
                local i = ny*C.width+nx
                if nx >= 0 and nx < C.width and ny >= 0 and i < C.count and C.reached[i] then
                    local pos = room:GetGridPosition(i)
                    local contact={X=math.max(pos.X-extent,math.min(pos.X+extent,pickup.Position.X)),
                        Y=math.max(pos.Y-extent,math.min(pos.Y+extent,pickup.Position.Y))}
                    local px,py=pickup.Position.X-contact.X,pickup.Position.Y-contact.Y
                    if px*px+py*py < radius*radius and clearSegment(C.hazards,pos,contact) then return true end
                end
            end
        end
        return false
    end
    return C
end

return M
