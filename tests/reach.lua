local Reach=dofile("mouse_pickup/mpickup/reach.lua")
local tests=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name..": "..tostring(err)) end
    tests=tests+1; print("PASS "..name)
end
local function scene()
    local grids,entities={},{}
    local room={
        GetGridSize=function() return 49 end, GetGridWidth=function() return 7 end,
        GetGridIndex=function(_,p) return math.floor(p.Y/40)*7+math.floor(p.X/40) end,
        GetGridPosition=function(_,i) return {X=(i%7)*40+20,Y=math.floor(i/7)*40+20} end,
        IsPositionInRoom=function(_,p) return p.X>=0 and p.X<280 and p.Y>=0 and p.Y<280 end,
        GetGridEntity=function(_,i) return grids[i] end,
        GetGridCollision=function(_,i) return grids[i] and grids[i].collision or 0 end,
    }
    local trinkets,items={},{}
    local player={Position={X=20,Y=140},Size=10,CanFly=false,GridCollisionClass=5,
        HasTrinket=function(_,id) return trinkets[id] or false end,
        HasCollectible=function(_,id) return items[id] or false end}
    Isaac={FindByType=function(t)
        local found={}; for _,e in ipairs(entities) do if e.Type==t then found[#found+1]=e end end
        return found
    end}
    local function grid(i,kind,state,collision)
        grids[i]={State=state or 0,collision=collision or 0,
            GetType=function() return kind end,GetVariant=function() return 0 end}
    end
    local target={Position={X=140,Y=140},Size=10}
    local cache=Reach.new()
    local function allowed(frame,force) cache.refresh(room,player,frame or 0,force~=false); return cache.canTouch(room,player,target) end
    local function ring(kind,state)
        for _,i in ipairs({16,17,18,23,25,30,31,32}) do grid(i,kind,state) end
    end
    return {room=room,p=player,t=target,c=cache,grids=grids,entities=entities,items=items,trinkets=trinkets,
        grid=grid,ring=ring,allowed=allowed}
end
test("spike ring blocks a grounded player despite zero grid collision",function()
    local s=scene(); s.ring(8); assert(not s.allowed())
end)
test("safe detour and an opened ring remain reachable",function()
    local s=scene(); s.ring(8); s.grids[23]=nil; assert(s.allowed())
end)
test("flight and Callus allow spikes, losing either invalidates immediately",function()
    local s=scene(); s.ring(8); assert(not s.allowed())
    s.p.CanFly=true; assert(s.allowed(1,false)); s.p.CanFly=false; assert(not s.allowed(2,false))
    s.trinkets[14]=true; assert(s.allowed(3,false)); s.trinkets[14]=false; assert(not s.allowed(4,false))
end)
test("invulnerability, mantle and health do not permit spikes",function()
    local s=scene(); s.ring(8); s.p.GetDamageCooldown=function() return 100 end
    s.p.GetHearts=function() return 24 end; s.items[313]=true; assert(not s.allowed())
end)
test("periodic spikes remain dangerous while retracted",function()
    local s=scene(); s.ring(9,1); assert(not s.allowed())
    s.trinkets[151]=true; assert(s.allowed())
end)
test("disabled fixed spikes and removed hazards permit passage",function()
    local s=scene(); s.ring(8,1); assert(s.allowed())
    s.ring(8,0); assert(not s.allowed()); for i in pairs(s.grids) do s.grids[i]=nil end; assert(s.allowed())
end)
local function entity(kind,variant,x,y,size)
    return {Type=kind,Variant=variant,Position={X=x,Y=y},Size=size or 20,HitPoints=10,CollisionDamage=1,
        Exists=function() return true end,IsDead=function() return false end}
end
test("fire barrier blocks flight as well as walking and disappears when extinguished",function()
    local s=scene(); for y=20,260,40 do s.entities[#s.entities+1]=entity(33,0,100,y) end
    assert(not s.allowed()); s.p.CanFly=true; assert(not s.allowed())
    for _,e in ipairs(s.entities) do e.HitPoints=1 end; assert(s.allowed())
end)
test("hostile creep respects flight, Callus and Socks but not Flat File",function()
    local s=scene(); for y=20,260,40 do s.entities[#s.entities+1]=entity(1000,22,100,y) end
    assert(not s.allowed()); s.trinkets[151]=true; assert(not s.allowed())
    s.trinkets[14]=true; assert(s.allowed()); s.trinkets[14]=nil
    s.items[571]=true; assert(s.allowed()); s.items[571]=nil
    s.p.CanFly=true; assert(s.allowed())
end)
test("friendly creep and harmless slowing effects do not block",function()
    local s=scene(); for _,v in ipairs({25,26,46,54}) do s.entities[#s.entities+1]=entity(1000,v,100,140) end
    assert(s.allowed())
end)
test("hazards between grid centers block traversal",function()
    local s=scene(); for y=0,280,10 do s.entities[#s.entities+1]=entity(33,0,80,y,2) end
    assert(not s.allowed())
end)
test("pickup center and edge cannot bypass a dangerous contact area",function()
    local s=scene(); s.grid(24,8); assert(not s.allowed())
    s.t.Position.X=121; assert(not s.allowed())
    s.t.Position.X=108; assert(s.allowed())
end)
test("forced refresh catches new hazards in the same frame",function()
    local s=scene(); assert(s.allowed()); s.ring(8); assert(not s.allowed())
end)
test("spiked rocks cannot be bypassed by grid phasing alone",function()
    local s=scene(); s.ring(25); s.p.GridCollisionClass=3; assert(not s.allowed())
    s.p.CanFly=true; assert(s.allowed())
end)
test("Socks protect floor spikes, not a phased spiked rock",function()
    local s=scene(); s.ring(8); s.items[571]=true; assert(s.allowed())
    s.ring(25); s.p.GridCollisionClass=3; assert(not s.allowed())
    s.trinkets[14]=true; assert(not s.allowed())
    s.trinkets[151]=true; assert(s.allowed())
end)
test("moving or appearing fire invalidates on the next update",function()
    local s=scene(); assert(s.allowed(0,false))
    for y=20,260,40 do s.entities[#s.entities+1]=entity(33,0,100,y) end
    assert(not s.allowed(1,false))
    for _,e in ipairs(s.entities) do e.Position.X=260 end
    assert(s.allowed(2,false))
end)
test("an unsafe starting position cannot authorize distant pickups",function()
    local s=scene(); s.grid(21,8); assert(not s.allowed())
end)
test("walls still bound flight and phasing while a bridged pit opens the route",function()
    local s=scene(); for i=3,48,7 do s.grid(i,15,0,4) end
    s.p.CanFly=true; s.p.GridCollisionClass=0; assert(not s.allowed())
    for i=3,48,7 do s.grid(i,7,0,1) end
    assert(s.allowed()); s.p.CanFly=false; s.p.GridCollisionClass=5; assert(not s.allowed())
    for i=3,48,7 do s.grid(i,7,0,0) end; assert(s.allowed())
end)
test("red poop remains hazardous while broken because it regrows",function()
    local s=scene(); s.ring(14)
    for _,g in pairs(s.grids) do g.GetVariant=function() return 1 end; g.State=1000 end
    s.p.GridCollisionClass=3; s.trinkets[14]=true; assert(not s.allowed())
    s.p.CanFly=true; assert(s.allowed())
end)
test("capability and size changes invalidate within the same frame",function()
    local s=scene(); s.ring(8); assert(not s.allowed(0,false))
    s.items[571]=true; assert(s.allowed(0,false))
    s.items[571]=nil; assert(not s.allowed(0,false))
    s.grids[23]=nil; assert(s.allowed(0,true))
    s.p.Size=22; assert(not s.allowed(0,false))
end)
print(tests.." reach tests passed (simulated logic)")
