local mt={}
mt.__index={Distance=function(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2) end}
local function vec(x,y) return setmetatable({X=x,Y=y},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y) end
mt.__mul=function(a,b) return vec(a.X*b,a.Y*b) end
Vector=setmetatable({Zero=vec(0,0)},{__call=function(_,x,y) return vec(x,y) end})
ButtonAction={ACTION_SHOOTUP=4,ACTION_SHOOTDOWN=5,ACTION_SHOOTLEFT=6,ACTION_SHOOTRIGHT=7}
InputHook={GET_ACTION_VALUE=2,IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1}
EntityFlag={FLAG_NO_QUERY=1}
GetPtrHash=function(e) return e end
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function entity(v,s)
    local e={Type=5,Variant=v or 20,SubType=s or 1,Wait=0,Price=0,OptionsPickupIndex=0,
        Position=vec(150,20),TargetPosition=vec(155,25),Velocity=vec(2,3),GridCollisionClass=5,
        alive=true,flags=0,collect=false}
    function e:Exists() return self.alive end
    function e:ToPickup() return self end
    function e:IsDead() return false end
    function e:IsShopItem() return self.shop end
    function e:GetSprite() return {IsPlaying=function() return self.collect end} end
    function e:HasEntityFlags(f) return self.flags & f ~= 0 end
    function e:AddEntityFlags(f) self.flags=self.flags | f end
    function e:ClearEntityFlags(f) self.flags=self.flags & ~f end
    function e:Remove() self.alive=false end
    return e
end
local function fixture()
    local p={Position=vec(10,20),state=710,has=true}
    function p:GetItemState() return self.state end
    function p:HasCollectible() return self.has end
    local item,other=entity(),entity()
    local list,knives={item,other},{}
    Isaac={FindByType=function(t) return t==5 and list or knives end}
    Game=function() return {GetRoom=function() return {
        GetGridSize=function() return 1 end,GetGridPosition=function() return vec(500,300) end,
        IsPositionInRoom=function() return true end,IsMirrorWorld=function() return false end,
        GetClampedPosition=function(_,v,margin) return vec(math.max(margin,math.min(500-margin,v.X)),math.max(margin,math.min(400-margin,v.Y))) end} end} end
    return dofile('mouse_pickup/mpickup/bag.lua')(),p,item,other,list,knives
end
test('held bag state requires actual ownership, for any character',function()
    local b,p=fixture(); assert(b.raised(p)); p.has=false; assert(not b.raised(p))
    p.has=true; p.state=34; assert(not b.raised(p)); assert(not b.raised(nil))
end)
test('materials exclude chests, collectibles, trinkets and troll bombs',function()
    local b=fixture()
    for _,v in ipairs({10,20,30,40,70,90,300}) do assert(b.material(entity(v,1))) end
    assert(b.material(entity(42,0)))
    for _,v in ipairs({50,69,100,350}) do assert(b.blocked(entity(v))=='NOT MATERIAL') end
    for _,s in ipairs({3,5,6}) do assert(not b.material(entity(40,s))) end
    assert(not b.material(entity(20,99)))
end)
test('wait, shop stock and paid deals cannot start bag transactions',function()
    local b,p,item=fixture()
    item.Wait=1; assert(not b.begin(item,p)); item.Wait=0
    for _,price in ipairs({5,-1}) do item.Price=price; assert(b.blocked(item)=='SHOP ITEM'); assert(not b.begin(item,p)) end
    item.Price=-1000; item.shop=true; assert(not b.begin(item,p))
    item.shop=false; assert(b.begin(item,p)); b.finish()
end)
test('one native shooting pulse with no active-item or movement input',function()
    local b,p,item=fixture(); assert(b.begin(item,p))
    assert(not b.begin(item,p))
    assert(b.input(p,2,7)==1 and b.input(p,0,7)==true)
    assert(b.input(p,2,4)==0 and b.input(p,0,4)==false)
    assert(b.input(p,2,99)==nil and b.input({},2,7)==nil)
    b.step(); assert(b.input(p,2,7)==0)
    b.finish(); assert(b.input(p,2,7)==nil)
    assert(p.Position.X==10 and p.Position.Y==20)
end)
test('all four directions place only the chosen material in native reach',function()
    for _,spec in ipairs({{150,20,7,50,20},{-150,20,6,-30,20},{10,150,5,10,60},{10,-150,4,10,-20}}) do
        local b,p,item=fixture(); item.Position=vec(spec[1],spec[2]); assert(b.begin(item,p))
        assert(b.input(p,2,spec[3])==1 and item.Position.X==spec[4] and item.Position.Y==spec[5]); b.finish()
    end
end)
test('overlapping and newly spawned materials stay outside bag radius query',function()
    local b,p,item,other,list=fixture(); assert(b.begin(item,p))
    assert(other.flags==1 and item.flags==0 and b.collision(item)==true and b.collision(other)==nil)
    local born=entity(); list[#list+1]=born; b.spawned(born); assert(born.flags==1)
    item.collect=true; b.step()
    assert(not b.busy() and other.flags==0 and born.flags==0)
    assert(item.Position.X==150 and item.TargetPosition.X==155 and item.Velocity.X==2 and item.GridCollisionClass==5)
end)
test('preexisting exclusion flags and unrelated flags survive cleanup',function()
    local b,p,item,other=fixture(); other.flags=3; b.begin(item,p); b.finish(); assert(other.flags==3)
    other.flags=2; b.begin(item,p); b.finish(); assert(other.flags==2)
end)
test('all option siblings remain queryable and are restored on cancellation',function()
    local b,p,item,other,list=fixture()
    item.OptionsPickupIndex=123; other.OptionsPickupIndex=123; other.Position=vec(45,20)
    local far=entity(); far.OptionsPickupIndex=123; far.Position=vec(400,200); list[#list+1]=far
    assert(b.begin(item,p)); assert(other.flags==0 and far.flags==0)
    assert(other.Position.X==500 and far.Position.X==500)
    b.finish(); assert(other.Position.X==45 and other.TargetPosition.X==155 and other.GridCollisionClass==5 and far.Position.X==400)
    Game=function() return {GetRoom=function() return {
        GetGridSize=function() return 1 end,GetGridPosition=function() return p.Position end,
        IsPositionInRoom=function() return true end} end} end
    assert(not b.begin(item,p) and item.Position.X==150 and other.Position.X==45 and not b.busy())
end)
test('option parking uses perpendicular clearance rather than distance along a long swing',function()
    local b,p,item,other=fixture(); item.OptionsPickupIndex=123; other.OptionsPickupIndex=123
    local positions={vec(1000,20),vec(10,120)}
    Game=function() return {GetRoom=function() return {
        GetGridSize=function() return 2 end,GetGridPosition=function(_,i) return positions[i+1] end,
        IsPositionInRoom=function() return true end} end} end
    assert(b.begin(item,p)); assert(other.Position.X==10 and other.Position.Y==120)
    b.finish(); assert(other.Position.X==150)
end)
test('engine-removed option sibling is not restored or resurrected',function()
    local b,p,item,other=fixture(); item.OptionsPickupIndex=123; other.OptionsPickupIndex=123
    other.Position=vec(40,20); b.begin(item,p); other:Remove(); item.collect=true; b.step()
    assert(not b.busy() and not other.alive)
end)
test('timeout and repeated cancellation restore all temporary state',function()
    local b,p,item,other=fixture(); b.begin(item,p)
    for _=1,12 do b.step() end
    assert(not b.busy() and item.Position.X==150 and other.flags==0)
    b.begin(item,p); b.reset(); b.reset()
    assert(item.TargetPosition.Y==25 and item.Velocity.Y==3 and other.flags==0)
end)
test('lowered or lost bag stops the pending input and restores target',function()
    local b,p,item,other=fixture(); b.begin(item,p); p.state=0
    assert(b.input(p,2,7)==0); b.step(); assert(not b.busy() and other.flags==0)
    p.state=710; b.begin(item,p); p.has=false; b.step(); assert(not b.busy())
end)
test('existing player swing is not replaced; transaction swing is removed on finish',function()
    local b,p,item,other,list,knives=fixture()
    local old=entity(); old.Type=8; old.Variant=4; old.SpawnerEntity=p; knives[1]=old
    assert(not b.begin(item,p)); knives[1]=nil; assert(b.begin(item,p))
    local own=entity(); own.Type=8; own.Variant=4; own.SpawnerEntity=p; b.spawned(own)
    local foreign=entity(); foreign.Type=8; foreign.Variant=4; foreign.SpawnerEntity={}; b.spawned(foreign)
    b.finish(); assert(not own.alive and foreign.alive and old.alive)
end)
test('deleted targets and neighbors clean up without resurrecting entities',function()
    local b,p,item,other=fixture(); b.begin(item,p); item:Remove(); other:Remove(); b.step(); assert(not b.busy())
end)
test('bag lift animation exception retains all other gameplay gates',function()
    local rules=dofile('mouse_pickup/mpickup/rules.lua')
    local p={ControlsEnabled=true,IsDead=function() return false end,IsExtraAnimationFinished=function() return false end}
    local paused,clear=false,true
    local room={IsClear=function() return clear end,GetAliveEnemiesCount=function() return 0 end,GetFrameCount=function() return 3 end}
    local game={IsPaused=function() return paused end,GetRoom=function() return room end}
    assert(not rules.enabled(game,p,false) and rules.enabled(game,p,true))
    paused=true; assert(not rules.enabled(game,p,true)); paused=false; clear=false; assert(not rules.enabled(game,p,true))
end)
test('poop without eligible player context is selectable only while the bag is raised',function()
    local selection=dofile('mouse_pickup/mpickup/selection.lua')
    local item=entity(42,0); item.Visible=true
    assert(not selection.supported(item,false) and selection.supported(item,true))
end)
test('high range material follows the owned swing instead of fixed player distance',function()
    local b,p,item=fixture(); p.TearRange=1000; assert(b.begin(item,p))
    local knife=entity(); knife.Type=8; knife.Variant=4; knife.SpawnerEntity=p
    knife.Position=vec(220,20); knife.Scale=3; knife.Size=20
    b.spawned(knife); b.step()
    assert(item.Position.X==220 and item.Position.Y==20,'target must follow actual bag position')
    knife.Position=vec(260,20); b.step(); assert(item.Position.X==260)
    b.finish(); assert(p.TearRange==1000 and item.Position.X==150)
end)
test('mirror horizontal pulse is reversed without changing world-space placement',function()
    for _,spec in ipairs({{150,20,6,50,20},{-150,20,7,-30,20},{10,150,5,10,60},{10,-150,4,10,-20}}) do
        local b,p,item=fixture()
        Game=function() return {GetRoom=function() return {IsMirrorWorld=function() return true end} end} end
        item.Position=vec(spec[1],spec[2]); assert(b.begin(item,p))
        assert(b.input(p,2,spec[3])==1 and item.Position.X==spec[4] and item.Position.Y==spec[5])
        b.finish()
    end
end)
test('knife update follows only this transaction and never moves a consumed target',function()
    local b,p,item=fixture(); b.begin(item,p)
    local foreign=entity(); foreign.Position=vec(999,20)
    b.knifeUpdated(foreign); assert(item.Position.X==50)
    local own=entity(); own.Type=8; own.Variant=4; own.SpawnerEntity=p; own.Position=vec(230,20)
    b.spawned(own); b.knifeUpdated(own); assert(item.Position.X==230)
    item.collect=true; own.Position=vec(300,20); b.knifeUpdated(own); assert(item.Position.X==230)
    b.finish(); b.knifeUpdated(own); assert(item.Position.X==150)
end)
test('transaction bag head endpoint stays inside the room at extreme vertical range',function()
    local b,p,item=fixture(); p.TearRange=4000; b.begin(item,p)
    local head=entity(); head.Type=8; head.Variant=4; head.SubType=4; head.SpawnerEntity=p
    head.Position=vec(100,200); head.Velocity=vec(0,-1000); b.spawned(head); b.knifeUpdated(head)
    assert(item.Position.Y==200 and head.Position.Y==200 and head.Velocity.Y==-180 and p.TearRange==4000)
    b.finish(); assert(item.Position.X==150 and not head:Exists())
end)
print(count .. ' bag tests passed (simulated lifecycle, NOT native crafting)')
