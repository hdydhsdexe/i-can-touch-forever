local selection = dofile("mouse_pickup/mpickup/selection.lua")
local reach = dofile("mouse_pickup/mpickup/reach.lua")
local rules = dofile("mouse_pickup/mpickup/rules.lua")
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err)) end
    count = count+1; print("PASS " .. name)
end
local function pickup(index, y)
    return {Variant=20, SubType=1, Index=index, Position={X=0,Y=y or 0}, DepthOffset=0,
        ToPickup=function(self) return self end,
        IsShopItem=function() return false end,
        SortingLayer=2, Visible=true, Exists=function() return true end, IsDead=function() return false end,
        GetSprite=function() return {IsPlaying=function() return false end} end}
end
local function bounds() return {x=0,y=0,w=12,h=12} end
test("poop nuggets require Tainted Blue Baby or a raised bag", function()
    local item=pickup(1); item.Variant=42
    local kind=25
    local player={GetPlayerType=function() return kind end}
    for _,subtype in ipairs({0,1}) do
        item.SubType=subtype
        assert(selection.supported(item,false,player))
        assert(selection.choose({item},{X=0,Y=0},bounds,false,player)==item)
        assert(not selection.supported(item,false))
        kind=0; assert(not selection.supported(item,false,player))
        assert(selection.supported(item,true,player)); kind=25
    end
    item.SubType=2; assert(not selection.supported(item,false,player))
    item.SubType=0; item.Visible=false; assert(not selection.supported(item,false,player))
end)

test("poop top target is not skipped for a lower usable target", function()
    local a,b=pickup(1),pickup(2); a.Variant=42; a.SubType=0; a.Wait=20
    local player={GetPlayerType=function() return 25 end}
    assert(selection.choose({b,a},{X=0,Y=0},bounds,false,player)==a)
    assert(rules.blocked(player,a)=="WAIT")
end)
test("overlap selects visual top, even when unusable", function()
    local a, b = pickup(2), pickup(1)
    b.Wait=99
    assert(selection.choose({b,a}, {X=0,Y=0}, bounds) == b)
end)
test("generic engine entity is cast before reading pickup-only fields", function()
    local item=pickup(1); item.Wait=0; item.Price=0
    local entity={ToPickup=function() return item end}
    local selected=selection.choose({entity},{X=0,Y=0},bounds)
    assert(selected==item and rules.blocked({},selected)==nil)
end)
test("render depth dominates entity order", function()
    local a, b = pickup(1,20), pickup(2,0)
    assert(selection.choose({a,b}, {X=0,Y=0}, bounds) == a)
    b.DepthOffset=30
    assert(selection.choose({a,b}, {X=0,Y=0}, bounds) == b)
end)
test("outside target, invisible, empty pedestal, ending chest rejected", function()
    local p=pickup(1)
    assert(not selection.choose({p}, {X=13,Y=0}, bounds))
    p.Visible=false; assert(not selection.supported(p)); p.Visible=true
    p.Variant=100; p.SubType=0; assert(not selection.supported(p))
    p.Variant=340; assert(not selection.supported(p))
end)
test("one click per press and fresh press after pause", function()
    local edge=selection.newButton()
    assert(not edge(true,true)); assert(not edge(false,true))
    assert(edge(true,true)); assert(not edge(true,true))
    assert(not edge(false,false)); assert(not edge(true,true))
    assert(not edge(false,true)); assert(edge(true,true))
end)
test("flood routes around obstruction without wrapping rows", function()
    local cells={}
    for i=0,24 do cells[i]=true end
    cells[7]=false; cells[12]=false
    assert(reach.flood(cells,5,25,11)[13])
    cells[2]=false; cells[17]=false; cells[22]=false
    assert(not reach.flood(cells,5,25,11)[13])
    local wrapped={[4]=true,[5]=true}
    assert(not reach.flood(wrapped,5,10,4)[5])
end)
test("sealed island and diagonal corners remain blocked", function()
    local cells={[0]=true,[4]=true,[8]=true}
    assert(not reach.flood(cells,3,9,0)[4])
end)
test("flight and collision classes respect walls", function()
    assert(not reach.passable(1,5,false))
    assert(not reach.passable(3,5,false))
    assert(reach.passable(1,5,true) and reach.passable(3,5,true))
    assert(reach.passable(3,3,false) and reach.passable(1,6,false))
    assert(not reach.passable(4,0,true))
    assert(reach.passable(5,5,false))
end)
test("price labels distinguish free items and one-heart deals", function()
    assert(rules.cost({Price=-1000,Variant=100}) == "RMB")
    assert(rules.cost({Price=-1,Variant=100}) == "! HP COST")
    assert(rules.cost({Price=15,Variant=100}) == "15c")
end)
test("single-player restrictions reject unpaired twins, ghosts and unrelated co-op", function()
    GetPtrHash=function(p) return p end
    local kind, players, ghost = 0, 1, false
    local p={HasCollectible=function() return false end,GetCollectibleNum=function() return 0 end,
        GetEffects=function() return {HasNullEffect=function() return false end} end,
        GetPlayerType=function() return kind end,GetSubPlayer=function() end,
        GetOtherTwin=function() end,IsCoopGhost=function() return ghost end,
        Exists=function() return true end,IsDead=function() return false end}
    Isaac={GetPlayer=function() return p end}
    local game={GetNumPlayers=function() return players end}
    assert(rules.player(game)==p)
    for _,id in ipairs({16,17,19,20,35,40}) do kind=id; assert(not rules.player(game)) end
    for _,id in ipairs({29,38,37,39}) do kind=id; assert(rules.player(game)==p) end
    kind=0; players=2; assert(not rules.player(game))
    players=1; ghost=true; assert(not rules.player(game))
end)
test("combat, pause, menu, transition and loss of control block input", function()
    local paused, clear, enemies, roomAge, animation = false,true,0,2,true
    local room={IsClear=function() return clear end,GetAliveEnemiesCount=function() return enemies end,
        GetFrameCount=function() return roomAge end}
    local game={IsPaused=function() return paused end,GetRoom=function() return room end}
    local p={ControlsEnabled=true,IsDead=function() return false end,IsExtraAnimationFinished=function() return animation end}
    assert(rules.enabled(game,p))
    paused=true; assert(not rules.enabled(game,p)); paused=false
    clear=false; assert(not rules.enabled(game,p)); clear=true
    enemies=1; assert(not rules.enabled(game,p)); enemies=0
    roomAge=1; assert(not rules.enabled(game,p)); roomAge=2
    animation=false; assert(not rules.enabled(game,p)); animation=true
    p.ControlsEnabled=false; assert(not rules.enabled(game,p)); p.ControlsEnabled=true
    ModConfigMenu={IsVisible=true}; assert(not rules.enabled(game,p)); ModConfigMenu=nil
end)
test("cache invalidates on terrain and ability changes; click forces freshness", function()
    local collisions = {[0]=0,[1]=3,[2]=0}
    local calls = 0
    local room = {
        GetGridIndex=function(_,p) return math.floor(p.X/40) end,
        GetGridSize=function() return 3 end, GetGridWidth=function() return 3 end,
        GetGridPosition=function(_,i) return {X=i*40+20,Y=20} end,
        IsPositionInRoom=function() return true end,
        GetGridEntity=function() end,
        GetGridCollision=function(_,i) calls=calls+1; return collisions[i] end,
    }
    local player={Position={X=20,Y=20},Size=10,GridCollisionClass=5,CanFly=false,
        HasTrinket=function() return false end,HasCollectible=function() return false end}
    local p={Position={X=100,Y=20},Size=10}
    Isaac.FindByType=function() return {} end
    local c=reach.new()
    c.refresh(room,player,0,false); assert(not c.canTouch(room,player,p))
    c.refresh(room,player,0,false); assert(calls==3)
    collisions[1]=0; c.refresh(room,player,1,true); assert(c.canTouch(room,player,p))
    collisions[1]=1; c.refresh(room,player,2,true); assert(not c.canTouch(room,player,p))
    player.CanFly=true; c.refresh(room,player,3,false); assert(c.canTouch(room,player,p))
    player.CanFly=false; c.refresh(room,player,4,false); assert(not c.canTouch(room,player,p))
    c.reset(); collisions[1]=0; c.refresh(room,player,0,false); assert(c.canTouch(room,player,p))
end)
test("touching edge permitted without reaching across a whole obstacle", function()
    local c=reach.new(); c.width=3; c.count=3; c.reached={[0]=true}
    local room={GetGridIndex=function(_,p) return math.floor(p.X/40) end,
        GetGridPosition=function(_,i) return {X=i*40+20,Y=20} end}
    local player={Size=10}
    assert(c.canTouch(room,player,{Position={X=41,Y=20},Size=10}))
    assert(not c.canTouch(room,player,{Position={X=60,Y=20},Size=10}))
    assert(not c.canTouch(room,player,{Position={X=100,Y=20},Size=10}))
end)

local vectorMT = {__index={}}
local function vec(x,y) return setmetatable({X=x,Y=y},vectorMT) end
vectorMT.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y) end
vectorMT.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y) end
Vector=setmetatable({Zero=vec(0,0)},{__call=function(_,x,y) return vec(x,y) end})
GetPtrHash=function(e) return e.id end
test("poop timeout and interrupted contact restore position, anchor and velocity", function()
    for _,subtype in ipairs({0,1}) do
        for _,stop in ipairs({"timeout","finish","reset"}) do
            local c=dofile("mouse_pickup/mpickup/collect.lua")()
            local item=pickup(1); item.id=1; item.Variant=42; item.SubType=subtype
            item.Position=vec(90,80); item.TargetPosition=vec(100,85); item.Velocity=vec(2,3)
            local player={id=2,Position=vec(10,20)}
            assert(c.begin(item,player)); assert(c.collision({id=3},player)==true)
            if stop=="timeout" then c.step(); c.step(); c.step() else c[stop]() end
            assert(not c.busy() and item:Exists())
            assert(item.Position.X==90 and item.Position.Y==80)
            assert(item.TargetPosition.X==100 and item.TargetPosition.Y==85)
            assert(item.Velocity.X==2 and item.Velocity.Y==3)
        end
    end
end)
test("native transaction retains contact until native handler completes", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Position=vec(90,80); item.Velocity=vec(2,3)
    item.TargetPosition=vec(100,80)
    local p={id=2,Position=vec(10,20)}
    assert(c.begin(item,p)); assert(item.Position.X==10 and c.busy())
    assert(not c.begin(item,p))
    assert(c.collision(item,{id=3})==true)
    assert(c.collision(item,p)==nil)
    assert(item.Position.X==10 and item.TargetPosition.X==10)
    assert(c.collision(item,p)==true)
    assert(c.collision({id=4},p)==true)
    c.step(); assert(not c.busy()); assert(c.collision({id=4},p)==nil)
    assert(item.Position.X==90 and item.Velocity.X==2 and item.TargetPosition.X==100)
end)
test("rejected or cancelled transaction restores without deleting", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Position=vec(90,80); item.Velocity=vec(2,3)
    item.TargetPosition=vec(90,80)
    c.begin(item,{id=2,Position=vec(10,20)})
    c.finish(); assert(item.Position.X==90 and item.Velocity.Y==3)
    c.finish()
end)
test("no collision attempt times out and restores its anchor", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Position=vec(90,80); item.Velocity=vec(2,3); item.TargetPosition=vec(90,80)
    c.begin(item,{id=2,Position=vec(10,20)})
    c.step(); assert(c.busy()); c.step(); assert(c.busy()); c.step(); assert(not c.busy())
    assert(item.Position.X==90 and item.TargetPosition.X==90)
end)
test("only the chosen pickup's children are relocated to its original position", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Position=vec(90,80); item.Velocity=vec(0,0); item.TargetPosition=vec(90,80)
    local player={id=2,Position=vec(10,20)}
    c.begin(item,player); c.collision(item,player)
    local child={id=3,Type=5,SpawnerEntity=item,Position=vec(11,20),TargetPosition=vec(11,20)}
    c.spawned(child); assert(child.Position.X==91 and child.Position.Y==80 and child.TargetPosition.X==91)
    local unrelated={id=4,SpawnerEntity=player,Position=vec(11,20),TargetPosition=vec(11,20)}
    c.spawned(unrelated); assert(unrelated.Position.X==11)
    c.finish(); c.spawned(child); assert(child.Position.X==91)
end)
test("native anonymous chest loot and Restock return to the original contact point", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Variant=60; item.Position=vec(90,80); item.Velocity=vec(0,0); item.TargetPosition=vec(90,80)
    local player={id=2,Position=vec(10,20)}
    c.begin(item,player); c.collision(item,player)
    local loot={id=3,Type=5,Position=vec(11,20),TargetPosition=vec(11,20)}
    c.spawned(loot); assert(loot.Position.X==91 and loot.Position.Y==80)
    local remote={id=4,Type=5,Position=vec(300,20),TargetPosition=vec(300,20)}
    c.spawned(remote); assert(remote.Position.X==300)
    c.spawned(item); assert(item.Position.X==90 and item.TargetPosition.X==90)
    c.finish()
end)
test("delayed Restock is restored once and discarded on room reset", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Variant=100; item.Position=vec(90,80); item.Velocity=vec(0,0); item.TargetPosition=vec(90,80)
    item.IsShopItem=function() return true end
    local alive=true
    item.Exists=function() return alive end
    local player={id=2,Position=vec(10,20),HasCollectible=function() return true end}
    c.begin(item,player); c.collision(item,player); alive=false; c.step()
    local stock={id=3,Type=5,Variant=10,Position=vec(11.25,17.5),TargetPosition=vec(10,20),Velocity=vec(0.1,0.2)}
    c.step(); c.spawned(stock); assert(stock.Position.X==90 and stock.TargetPosition.X==90)
    assert(stock.Position.Y==80 and stock.TargetPosition.Y==80 and stock.Velocity.X==0 and stock.Velocity.Y==0)
    stock.Position=vec(10,20); c.spawned(stock); assert(stock.Position.X==10)
    alive=true; item.Position=vec(90,80)
    c.begin(item,player); c.collision(item,player); alive=false; c.step(); c.reset()
    c.spawned(stock); assert(stock.Position.X==10)
end)

test("Restock after active exchange reserves sale position and moves old active aside", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Variant=100; item.SubType=34
    item.Position=vec(420,280); item.TargetPosition=vec(420,280); item.Velocity=vec(0,0)
    local shop=true
    item.IsShopItem=function() return shop end
    local player={id=2,Position=vec(160,280),HasCollectible=function() return true end}
    c.begin(item,player); c.collision(item,player)
    item.SubType=105; shop=false; c.spawned(item); c.step()
    assert(item.Position.X==420)
    local stock={id=3,Type=5,Position=vec(160,280),TargetPosition=vec(0,0)}
    Game=function() return {GetRoom=function() return {
        FindFreePickupSpawnPosition=function(_,position,step,avoid)
            assert(position.X==420 and step==40 and avoid)
            assert(stock.Position.X==420 and stock.TargetPosition.X==420)
            return vec(460,280)
        end}
    end} end
    c.spawned(stock)
    assert(stock.Position.X==420 and item.Position.X==460 and item.TargetPosition.X==460)
    stock.Position=vec(160,280); c.spawned(stock); assert(stock.Position.X==160)
    Game=nil
end)

test("vetoed active shop purchase does not register delayed Restock", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Variant=100; item.SubType=34
    item.Position=vec(420,280); item.TargetPosition=vec(420,280); item.Velocity=vec(0,0)
    item.IsShopItem=function() return true end
    local player={id=2,Position=vec(160,280),HasCollectible=function() return true end}
    c.begin(item,player); c.collision(item,player); c.step()
    local unrelated={id=3,Type=5,Position=vec(160,280)}
    c.spawned(unrelated); assert(unrelated.Position.X==160 and item.Position.X==420)
end)

test("repeated Restock ignores spawn rounding and keeps the first fractional sale position", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local current=pickup(10); current.id=10; current.Type=5; current.Variant=100
    current.Position=vec(421.375,283.625); current.TargetPosition=vec(421.375,283.625); current.Velocity=vec(0,0)
    current.IsShopItem=function() return true end
    for i=1,5 do
        local player={id=2,Position=vec(160+i*1.25,280-i*2.5),HasCollectible=function() return true end}
        assert(c.begin(current,player)); c.collision(current,player)
        current.Exists=function() return false end; c.step()
        local nextItem=pickup(10+i); nextItem.id=10+i; nextItem.Type=5; nextItem.Variant=100
        nextItem.Position=vec(160,280); nextItem.TargetPosition=vec(0,0); nextItem.Velocity=vec(0.1,0.2)
        nextItem.IsShopItem=function() return true end
        c.spawned(nextItem)
        assert(nextItem.Position.X==421.375 and nextItem.Position.Y==283.625)
        assert(nextItem.TargetPosition.X==421.375 and nextItem.TargetPosition.Y==283.625)
        assert(nextItem.Velocity.X==0 and nextItem.Velocity.Y==0)
        current=nextItem
    end
end)

test("full pocket exchanges return only the replaced item to the selected tile", function()
    for _,spec in ipairs({{300,300},{70,70},{300,70},{70,300},{350,350}}) do
        local c=dofile("mouse_pickup/mpickup/collect.lua")()
        local item=pickup(1); item.id=1; item.Variant=spec[1]; item.SubType=2
        item.Position=vec(421.375,283.625); item.TargetPosition=vec(421.375,283.625); item.Velocity=vec(0,0)
        local player={id=2,Position=vec(160,280),
            GetCard=function(_,slot) return spec[2]==300 and slot==0 and 1 or 0 end,
            GetPill=function(_,slot) return spec[2]==70 and slot==0 and 1 or 0 end,
            GetTrinket=function(_,slot) return spec[2]==350 and slot==0 and 1 or 0 end}
        c.begin(item,player); c.collision(item,player)
        local drop={id=3,Type=5,Variant=spec[2],SubType=1,SpawnerEntity=player,
            Position=vec(161,280),TargetPosition=vec(0,0),Velocity=vec(2,1)}
        c.spawned(drop)
        assert(drop.Position.X==421.375 and drop.Position.Y==283.625)
        assert(drop.TargetPosition.X==421.375 and drop.Velocity.X==0)
        -- Do not relocate another same-type item once the exchange is matched.
        drop.Position=vec(160,280); c.spawned(drop); assert(drop.Position.X==160)
        c.finish()
    end
end)

test("unrelated births and drops outside a collision are not pocket exchanges", function()
    local c=dofile("mouse_pickup/mpickup/collect.lua")()
    local item=pickup(1); item.id=1; item.Variant=300; item.SubType=2
    item.Position=vec(420,280); item.TargetPosition=vec(420,280); item.Velocity=vec(0,0)
    local player={id=2,Position=vec(160,280),GetCard=function() return 1 end,GetPill=function() return 0 end}
    local drop={id=3,Type=5,Variant=300,SubType=1,SpawnerEntity=player,Position=vec(160,280)}
    c.begin(item,player); c.spawned(drop); assert(drop.Position.X==160)
    c.collision(item,player)
    drop.SubType=3; c.spawned(drop); assert(drop.Position.X==160)
    drop.SubType=1; drop.SpawnerEntity={id=99}; c.spawned(drop); assert(drop.Position.X==160)
    drop.SpawnerEntity=player; drop.Position=vec(300,280); c.spawned(drop); assert(drop.Position.X==300)
    c.finish(); drop.Position=vec(160,280); c.spawned(drop); assert(drop.Position.X==160)
end)

for _, n in ipairs({300,1000}) do
    local items={}
    for i=1,n do items[i]=pickup(i) end
    local started=os.clock()
    for _=1,1000 do assert(selection.choose(items,{X=0,Y=0},bounds)==items[1]) end
    print(string.format("BENCH simulated %d pickups: %.3f ms/selection (1000 iterations)",n,(os.clock()-started)))
end
print(string.format("%d tests passed (%s; simulated logic, NOT native gameplay)",count,_VERSION))
