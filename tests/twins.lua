-- Real entry point, actor resolver, reach, transactions and EID; simulated engine.
local mt={}
local function vec(x,y) return setmetatable({X=x,Y=y},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y) end
mt.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y) end
mt.__mul=function(a,b) return vec(a.X*b,a.Y*b) end
mt.__index={Distance=function(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2) end}
Vector=setmetatable({Zero=vec(0,0)},{__call=function(_,x,y) return vec(x,y) end})
GetPtrHash=function(e) return e end
Mouse={MOUSE_BUTTON_2=1,MOUSE_BUTTON_3=2}
EntityType={ENTITY_PICKUP=5}; EntityFlag={FLAG_NO_QUERY=1,FLAG_HELD=1<<57,FLAG_THROWN=1<<58,
    FLAG_NO_KNOCKBACK=1<<26,FLAG_NO_PHYSICS_KNOCKBACK=1<<30}
ButtonAction={ACTION_SHOOTUP=4,ACTION_SHOOTDOWN=5,ACTION_SHOOTLEFT=6,ACTION_SHOOTRIGHT=7}
InputHook={GET_ACTION_VALUE=2,IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1}
ModCallbacks={MC_PRE_PICKUP_COLLISION=1,MC_POST_UPDATE=2,MC_POST_RENDER=3,
    MC_PRE_GAME_EXIT=4,MC_POST_NEW_ROOM=5,MC_POST_GAME_STARTED=6,MC_INPUT_ACTION=7,
    MC_POST_KNIFE_INIT=8,MC_POST_KNIFE_UPDATE=9,MC_POST_PICKUP_INIT=10,
    MC_POST_BOMB_INIT=11,MC_POST_NPC_INIT=12,MC_POST_EFFECT_INIT=13,MC_USE_ITEM=14}
local function player(kind,x)
    local p={kind=kind,Position=vec(x,20),Size=10,ControllerIndex=0,ControlsEnabled=true,
        GridCollisionClass=5,CanFly=false,coins=20,state=0,card=0,Visible=true,
        EntityCollisionClass=4,PositionOffset=vec(0,0),Velocity=vec(0,0),flags=0}
    function p:GetPlayerType() return self.kind end
    function p:GetOtherTwin() return self.twin end
    function p:GetSubPlayer() return self.sub end
    function p:GetMainTwin() return self.main or self end
    function p:HasEntityFlags(flags) return self.flags & flags ~= 0 end
    function p:GetEntityFlags() return self.flags end
    function p:IsCoopGhost() return false end
    function p:Exists() return not self.removed end
    function p:IsDead() return self.dead end
    function p:IsExtraAnimationFinished() return not self.extra end
    function p:GetItemState() return self.state end
    function p:HasCollectible(id) return (id==710 and self.hasBag) or (id==619 and self.birthright) or (self.items and (self.items[id] or 0)>0) end
    function p:GetCollectibleNum(id) return self.items and self.items[id] or 0 end
    function p:GetEffects() return {HasNullEffect=function(_,id) return self.effects and self.effects[id] end} end
    function p:HasTrinket() return false end
    function p:GetNumCoins() return self.coins end
    function p:GetCard(slot) return slot==0 and self.card or 0 end
    function p:GetPill() return 0 end
    return p
end
local function pickup(v,s,x)
    local e={Type=5,Variant=v or 20,SubType=s or 1,Position=vec(x or 220,20),
        TargetPosition=vec(x or 220,20),Velocity=vec(0,0),Size=10,GridCollisionClass=5,
        Wait=0,Price=0,OptionsPickupIndex=0,Visible=true,SortingLayer=1,Index=1,DepthOffset=0,flags=0}
    function e:ToPickup() return self end
    function e:Exists() return not self.removed end
    function e:IsDead() return false end
    function e:IsShopItem() return self.Price~=0 end
    function e:GetSprite() return {IsPlaying=function() return false end} end
    function e:HasEntityFlags(f) return self.flags & f ~= 0 end
    function e:AddEntityFlags(f) self.flags=self.flags | f end
    function e:ClearEntityFlags(f) self.flags=self.flags & ~f end
    return e
end
local function fixture()
    local f={handlers={},down={},labels={},frame=10}
    f.j,f.e=player(19,20),player(20,60); f.j.twin,f.e.twin=f.e,f.j
    f.players={f.j,f.e}; f.item=pickup(); f.items={f.item}
    local room={GetGridSize=function() return 7 end,GetGridWidth=function() return 7 end,
        GetGridPosition=function(_,i) return vec(i*40+20,20) end,
        GetGridIndex=function(_,p) return math.floor(p.X/40) end,
        IsPositionInRoom=function() return true end,GetGridCollision=function() return 0 end,
        GetGridEntity=function(_,i) if f.spikes and i==3 then return {State=0,GetType=function() return 8 end} end end,
        GetFrameCount=function() return 10 end,IsClear=function() return not f.combat end,
        GetAliveEnemiesCount=function() return 0 end,IsMirrorWorld=function() return false end}
    local game={GetRoom=function() return room end,GetFrameCount=function() return f.frame end,
        GetNumPlayers=function() return #f.players end,IsPaused=function() return f.paused end}
    Game=function() return game end
    Isaac={GetPlayer=function(i) return f.players[i+1] end,
        FindByType=function(t) return t==5 and f.items or {} end,WorldToScreen=function(p) return p end,
        RenderText=function(label,x,y,r,g,b,a) f.labels[label]={x=x,y=y,r=r,g=g,b=b,a=a} end}
    Input={IsMouseBtnPressed=function(id) return f.down[id] or false end,
        GetMousePosition=function() return vec(220,20) end}
    local mod,json=dofile('tests/support/storage.lua')()
    f.mod=mod
    package.loaded.json=nil
    package.preload.json=function() return json end
    function mod:AddCallback(id,fn) f.handlers[id]=fn end
    function mod:AddPriorityCallback(id,priority,fn) self:AddCallback(id,fn) end
    RegisterMod=function() return mod end
    include=function(path)
        if path=='mpickup/development' then return false end
        local module=dofile('mouse_pickup/'..path..'.lua')
        if path=='mpickup/config' then
            return {new=function(...)
                f.config=module.new(...)
                return f.config
            end}
        end
        if path=='mpickup/collect' or path=='mpickup/bag' then
            local instance=module(); f[path:match('[^/]+$')]=instance
            return function() return instance end
        end
        if path=='mpickup/selection' then module.bounds=function() return {x=220,y=20,w=12,h=12} end end
        return module
    end
    EID=nil; ModConfigMenu=nil
    Sprite=function()
        return {Load=function() end,SetFrame=function() end,
            Render=function(self,pos) f.diamond={color=self.Color,x=pos.X,y=pos.Y} end}
    end
    Color=function(r,g,b,a) return {R=r,G=g,B=b,A=a} end
    dofile('mouse_pickup/main.lua')
    function f:render()
        self.labels={}; self.diamond=nil; self.handlers[3]()
        assert(not self.labels['JACOB [MMB]'] and not self.labels['ESAU [MMB]'], 'no character text beside cursor')
    end
    function f:cursor(gb)
        local c=self.labels['+']
        return c and c.r==1 and c.g==gb and c.b==gb and c.a==0.8 and c.x==217 and c.y==14
    end
    function f:update() self.frame=self.frame+1; self.handlers[2]() end
    function f:press(button)
        self.down[button]=false; self:render(); self.down[button]=true; self:render()
    end
    function f:release() self.down={}; self:render() end
    function f:collision(item,p) return self.handlers[1](nil,item,p) end
    f:render()
    return f
end
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
test('Jacob default, middle hold once, release to switch back, no implicit pickup',function()
    local f=fixture(); assert(f:cursor(1))
    f:press(2); assert(f:cursor(0))
    for i=1,5 do f:render(); f:update() end
    assert(f:cursor(0) and not f.collect.busy() and f.item.Position.X==220)
    f:press(2); assert(f:cursor(1))
end)
test('cursor color works without a target, single players stay white, status colors stay independent',function()
    local f=fixture()
    local function status(text,r,g,b)
        for _,label in ipairs({'[',']',text}) do
            local c=f.labels[label]; assert(c and c.r==r and c.g==g and c.b==b and c.a==1)
        end
    end
    status('RMB',0.3,1,0.5)
    f:press(2); assert(f:cursor(0)); status('RMB',0.3,1,0.5)
    f.item.Price=5; f:render(); assert(f:cursor(0)); status('5c',1,0.8,0.25)
    f.item.Wait=10; f:render(); assert(f:cursor(0)); status('WAIT',1,0.35,0.3)
    f.items={}; f:render(); assert(f:cursor(0) and not f.labels['['])
    f:press(2); assert(f:cursor(1))
    f.players={f.j}; f.j.kind=0; f.j.twin=nil; f:render(); assert(f:cursor(1))
    f:press(2); assert(f:cursor(1))
end)
test('right click uses selected twin and keeps both players in place',function()
    for _,esau in ipairs({false,true}) do
        local f=fixture(); if esau then f:press(2) end
        f:press(1); f:render(); f:update()
        local p=esau and f.e or f.j; local other=esau and f.j or f.e
        assert(f.collect.busy() and f.item.Position.X==p.Position.X)
        assert(f:collision(f.item,other)==true and f:collision(f.item,p)==nil)
        assert(f:collision(f.item,p)==true)
        f:update(); assert(f.item.Position.X==220 and not f.collect.busy())
        assert(f.j.Position.X==20 and f.e.Position.X==60)
        f:render(); f:update(); assert(not f.collect.busy())
    end
end)
test('switch cancels queued click and simultaneous buttons never collect',function()
    local f=fixture(); f:press(1); f:press(2); f:update()
    assert(not f.collect.busy() and f.item.Position.X==220)
    f:release(); f.down[1],f.down[2]=true,true; f:render(); f:update()
    assert(f:cursor(1) and not f.collect.busy())
    f:release(); f:press(1); f:update(); assert(f.item.Position.X==20)
end)
test('switch cancels an in-flight attempt and restores the target',function()
    local f=fixture(); f:press(1); f:update(); assert(f.collect.busy())
    f:press(2); assert(not f.collect.busy() and f.item.Position.X==220 and f.item.TargetPosition.X==220)
    f:update(); assert(not f.collect.busy())
end)
test('blocked selected twin never borrows the other flight or balance',function()
    local f=fixture(); f.spikes=true; f.e.CanFly=true; f.frame=f.frame+1
    f:press(1); assert(f.labels.BLOCKED); f:update(); assert(not f.collect.busy())
    f:press(2); f:press(1); f:update(); assert(f.item.Position.X==60)
    f.collect.finish(); f.spikes=false; f.e.coins=0; f.item.Price=5
    f:release(); f:press(1); assert(f.labels['NO COINS']); f:update(); assert(not f.collect.busy())
end)
test('lost flight between click and execution cancels without fallback',function()
    local f=fixture(); f.spikes=true; f.e.CanFly=true; f:press(2); f:press(1)
    f.e.CanFly=false; f:update(); assert(not f.collect.busy() and f.item.Position.X==220)
end)
test('click during pickup cooldown does not retry while held after cooldown',function()
    local f=fixture(); f.item.Wait=10; f:press(1); assert(f.labels.WAIT)
    f.item.Wait=0; f:update(); f:render(); f:update()
    assert(not f.collect.busy() and f.item.Position.X==220)
    f:press(1); f:update(); assert(f.collect.busy())
end)
test('pause, combat, menu and room transitions cancel and require fresh presses',function()
    for _,gate in ipairs({'paused','combat','menu','room'}) do
        local f=fixture(); f:press(2); f:press(1)
        if gate=='menu' then ModConfigMenu={IsVisible=true}
        elseif gate=='room' then f.handlers[5]() else f[gate]=true end
        f:render(); f:update(); assert(not f.collect.busy())
        f.paused,f.combat=false,false; ModConfigMenu=nil
        f:render(); f:update(); assert(not f.collect.busy())
        f:release(); assert(f:cursor(0))
        f:press(1); f:update(); assert(f.item.Position.X==60)
    end
end)
test('game restart resets selection, new room preserves it',function()
    local f=fixture(); f:press(2); f.handlers[5](); f:release(); assert(f:cursor(0))
    f.handlers[6](); f:release(); assert(f:cursor(1))
end)
test('middle held through a disabled state requires release before switching',function()
    local f=fixture(); f.paused=true; f:press(2)
    f.paused=false; f:render(); assert(f:cursor(1))
    f:press(2); assert(f:cursor(0))
end)
test('new player, death or changed pair cancels queued requests',function()
    for _,change in ipairs({'coop','death','type','relation','entity'}) do
        local f=fixture(); f:press(1)
        if change=='coop' then f.players[3]=player(0,100)
        elseif change=='death' then f.e.dead=true
        elseif change=='type' then f.e.kind=40
        elseif change=='relation' then f.e.twin=nil
        else local e=player(20,60); e.twin=f.j; f.j.twin=e; f.players[2]=e end
        f:update(); assert(not f.collect.busy() and f.item.Position.X==220)
    end
end)
test('identity invalidation at collision vetoes the stale native contact',function()
    local f=fixture(); f:press(1); f:update(); f.e.dead=true
    assert(f:collision(f.item,f.j)==true and not f.collect.busy() and f.item.Position.X==220)
end)
test('partner cannot chain-collect a swap but retains unrelated natural pickups',function()
    local f=fixture(); f.item.Variant=300; f.item.SubType=2; f.e.card=1
    f:press(2); f:press(1); f:update(); assert(f:collision(f.item,f.e)==nil)
    local old=pickup(300,1,60); old.SpawnerEntity=f.e; f.handlers[10](nil,old)
    assert(old.Position.X==220 and old.TargetPosition.X==220)
    assert(f:collision(old,f.j)==true)
    local unrelated=pickup(300,1,20); unrelated.SpawnerEntity=f.j
    f.handlers[10](nil,unrelated)
    assert(unrelated.Position.X==20 and f:collision(unrelated,f.j)==nil)
    f:update(); assert(f:collision(old,f.j)==nil)
end)
test('partner cannot chain-collect chest products during the contact pass',function()
    local f=fixture(); f.item.Variant=50; f:press(1); f:update()
    assert(f:collision(f.item,f.j)==nil)
    local loot=pickup(20,1,20); loot.SpawnerEntity=f.item; f.handlers[10](nil,loot)
    assert(loot.Position.X==220 and f:collision(loot,f.e)==true)
end)
test('bag state and native input belong only to the selected holder',function()
    local f=fixture(); f.e.state=710; f.e.hasBag=true
    f:press(2); f:press(1); f:update(); assert(f.bag.busy() and not f.collect.busy())
    assert(f.handlers[7](nil,f.e,2,7)==1 and f.handlers[7](nil,f.j,2,7)==nil)
    f:press(2); assert(not f.bag.busy() and f.item.Position.X==220)
    assert(f.handlers[7](nil,f.e,2,7)==nil)
end)
test('partner raised bag blocks displacement and is rechecked at execution',function()
    local f=fixture(); f.e.state=710; f.e.hasBag=true
    f:press(1); assert(f.labels['OTHER BAG']); f:update(); assert(not f.collect.busy())
    f.e.state=0; f:release(); f:press(1); f.e.state=710; f:update()
    assert(not f.collect.busy() and f.item.Position.X==220)
    f.e.state=0; f:release(); f:press(1); f:update(); assert(f.collect.busy())
    f.e.state=710; assert(f:collision(f.item,f.j)==true)
    assert(not f.collect.busy() and f.item.Position.X==220)
end)
test('switching a bag transaction restores isolated materials and owned knives',function()
    local f=fixture(); f.e.state=710; f.e.hasBag=true
    local neighbor=pickup(20,2); neighbor.Index=2; f.items[2]=neighbor
    f:press(2); f:press(1); f:update(); assert(neighbor.flags==1)
    local knife={Type=8,Variant=4,SpawnerEntity=f.e,Exists=function() return true end}
    function knife:Remove() self.removed=true end
    f.handlers[8](nil,knife); f:press(2)
    assert(neighbor.flags==0 and knife.removed and not f.bag.busy())
end)
test('EID obstruction context follows selected twin and releases on unsupported group',function()
    local f=fixture(); f.item.Variant=300; local origin
    EID={Config={DisplayCardInfoShop=true,['DisplayCardInfoOptions?']=true},InlineIcons={QuestionMark='?'},
        hasDescription=function() return true end,getEntityData=function() end,
        HasPathToPosition=function(_,pos) origin=pos; return true end,
        getDescriptionObjByEntity=function(_,item) return {Entity=item} end,
        ResetDescCache=function() end,
        displayPermanentText=function(self,desc) self.permanentDisplayTextObj=desc; self.isDisplayingPermanent=true end,
        hidePermanentText=function(self) self.permanentDisplayTextObj=nil; self.isDisplayingPermanent=false end}
    f:render(); assert(origin==f.j.Position)
    f:press(2); assert(origin==f.e.Position and EID.permanentDisplayTextObj.Entity==f.item)
    f.players[3]=player(0,100); f:render(); assert(not EID.isDisplayingPermanent)
end)
local function character(kind, birthright)
    local f=fixture()
    f.j.kind=kind; f.j.twin=nil; f.e.twin=nil; f.players={f.j}
    if kind==16 or kind==17 then
        f.j.sub=f.e; f.e.kind=kind==16 and 17 or 16
    elseif kind==35 then
        f.e.kind=40; f.j.twin=f.e; f.e.twin=f.j; f.players={f.j,f.e}
    elseif birthright then
        f.e.kind=kind==29 and 38 or 29; f.j.birthright=true
        f.j.twin=f.e; f.e.twin=f.j; f.j.main=f.j; f.e.main=f.j
        f.e.EntityCollisionClass=0; f.players={f.j,f.e}
    end
    f:release()
    return f
end
test('new character cursors and native recipients follow their specified roles',function()
    for _,kind in ipairs({16,17,35,29,38,37,39}) do
        local f=character(kind,kind==29 or kind==38)
        local color=f.labels['+']; assert(color and color.a==0.8)
        if kind==16 or kind==35 then assert(color.r==0.65 and color.g==0.65 and color.b==0.65)
        elseif kind==17 then assert(color.r==0.3 and color.g==0.65 and color.b==1)
        else assert(f:cursor(1)) end
        f:press(2); f:press(1); f:update()
        assert(f.collect.busy() and f.item.Position.X==f.j.Position.X)
        assert(f:collision(f.item,f.e)==true and f:collision(f.item,f.j)==nil)
        assert(f.j.Position.X==20 and f.e.Position.X==60)
    end
end)
test('Forgotten form changes cancel queued and native collision requests, then require a new click',function()
    for _,inflight in ipairs({false,true}) do
        local f=character(16); f:press(1)
        if inflight then f:update(); assert(f.collect.busy()) end
        f.j.kind=17; f.e.kind=16
        if inflight then assert(f:collision(f.item,f.j)==true) else f:update() end
        assert(not f.collect.busy() and f.item.Position.X==220)
        f:render(); f:update(); assert(not f.collect.busy())
        f:press(1); f:update(); assert(f.collect.busy())
    end
end)
test('Birthright Flip changes the foreground even when types and identities stay the same',function()
    local f=character(29,true); f:press(1); f:update(); assert(f.collect.busy())
    f.j.main=f.e; f.e.main=f.e; f.j.EntityCollisionClass=0; f.e.EntityCollisionClass=4
    assert(f:collision(f.item,f.j)==true and f.item.Position.X==220)
    f:render(); f:update(); assert(not f.collect.busy())
    f:press(1); f:update()
    assert(f.collect.busy() and f.item.Position.X==60 and f:collision(f.item,f.j)==true)
    assert(f:collision(f.item,f.e)==nil)
end)
test('Tainted Forgotten blocks held, thrown and recalling bodies including stationary endpoints',function()
    for _,flag in ipairs({EntityFlag.FLAG_HELD,EntityFlag.FLAG_THROWN,EntityFlag.FLAG_NO_KNOCKBACK}) do
        local f=character(35); f:press(1); f:update(); assert(f.collect.busy())
        f.j.flags=flag
        assert(f:collision(f.item,f.j)==true and f.item.Position.X==220)
        f:render(); assert(not f.labels['+'])
        f.j.flags=0; f:render(); f:update(); assert(not f.collect.busy())
        f:press(1); f:update(); assert(f.collect.busy())
    end
end)
test('Recall callback cancels before native flags appear and clears on carrying or room transition',function()
    local f=character(35); f:press(1); f:update()
    f.handlers[14](nil,714,nil,f.e); f:render()
    assert(not f.collect.busy() and f.item.Position.X==220 and not f.labels['+'])
    f.j.flags=EntityFlag.FLAG_HELD; f:render(); f.j.flags=0
    f:render(); f:update(); assert(not f.collect.busy())
    f:press(1); f:update(); assert(f.collect.busy())
    f.handlers[14](nil,714,nil,f.j); f.handlers[5](); f:release(); assert(f.labels['+'])
end)
test('Tainted Forgotten uses soul controls but body terrain, balance and bag ownership',function()
    local f=character(35); f.spikes=true; f.e.CanFly=true; f:update()
    f:press(1); f:update(); assert(not f.collect.busy() and f.labels.BLOCKED)
    f.spikes=false; f.j.coins=0; f.item.Price=5; f:update()
    f:press(1); f:update(); assert(not f.collect.busy() and f.labels['NO COINS'])
    f.item.Price=0; f.e.ControlsEnabled=false
    f:press(1); f:update(); assert(not f.collect.busy() and not f.labels['+'])
    f.e.ControlsEnabled=true; f.j.extra=true
    f:press(1); f:update(); assert(not f.collect.busy() and not f.labels['+'])
    f.j.extra=false; f.j.hasBag=true; f.j.state=710
    f:press(1); f:update(); assert(f.bag.busy())
    assert(f.handlers[7](nil,f.e,InputHook.IS_ACTION_PRESSED,ButtonAction.ACTION_SHOOTRIGHT)==nil)
    assert(f.handlers[7](nil,f.j,InputHook.IS_ACTION_PRESSED,ButtonAction.ACTION_SHOOTRIGHT)==true)
end)
test('new character transitions clear EID, preserve colors across rooms and reset on new runs',function()
    local f=character(16)
    EID={Config={},InlineIcons={},hasDescription=function() return true end,
        IsItemHidden=function() return false end,getEntityData=function() end,
        getDescriptionObjByEntity=function(_,p) return {Entity=p,Description='hover'} end,
        ResetDescCache=function() end,
        displayPermanentText=function(_,desc) EID.permanentDisplayTextObj=desc; EID.isDisplayingPermanent=true end,
        hidePermanentText=function() EID.isDisplayingPermanent=false; EID.permanentDisplayTextObj=nil end}
    f:render(); assert(EID.isDisplayingPermanent)
    f.j.kind=17; f.e.kind=16; f:update(); assert(not EID.isDisplayingPermanent)
    f:release(); assert(f.labels['+'].b==1 and f.labels['+'].r==0.3)
    f.handlers[5](); f:release(); assert(f.labels['+'].r==0.3)
    f.j.kind=16; f.e.kind=17; f.handlers[6](); f:release(); assert(f.labels['+'].r==0.65)
end)
local function effect(kind)
    local f=fixture(); f.j.kind=0; f.j.twin=nil; f.e.twin=nil; f.e.Parent=f.j; f.e.kind=kind
    if kind==14 then f.j.items={[667]=1} else f.e.effects={[kind==20 and 121 or 120]=true} end
    f:release(); return f
end
test('item recipients preserve selection across reorder and room and reset on continue',function()
    for _,kind in ipairs({14,20,16}) do
        local f=effect(kind); assert(f:cursor(1)); f:press(2)
        f.players={f.e,f.j}; f.handlers[5](); f:release(); f:press(1); f:update()
        assert(f.item.Position.X==f.e.Position.X and f:collision(f.item,f.j)==true)
        f.handlers[6](nil,true); f:release(); assert(f:cursor(1))
        f:press(1); f:update(); assert(f.item.Position.X==f.j.Position.X)
    end
end)
test('summon death disappearance and replacement cancel contact and require a fresh right press',function()
    for _,change in ipairs({'death','disappear','seed'}) do
        local f=effect(20); f:press(2); f:press(1); f:update(); assert(f.collect.busy())
        if change=='death' then f.e.dead=true elseif change=='disappear' then f.players={f.j} else f.e.InitSeed=10 end
        assert(f:collision(f.item,f.e)==true and not f.collect.busy() and f.item.Position.X==220)
        f:render(); f:update(); assert(not f.collect.busy())
        f:press(1); f:update(); assert(f.collect.busy() and f.item.Position.X==f.j.Position.X)
    end
end)
test('all protected members are isolated from chest loot but unrelated walking pickups stay native',function()
    local f=effect(14); local extra=player(0,120)
    f.item.Variant=50; assert(f.collect.begin(f.item,f.j,{f.j,f.e,extra}))
    assert(f.collect.collision(f.item,f.j)==nil)
    local loot=pickup(20,1,20); loot.SpawnerEntity=f.item; f.collect.spawned(loot)
    assert(f.collect.collision(loot,f.e)==true and f.collect.collision(loot,extra)==true)
    assert(f.collect.collision(pickup(20,1,60),f.e)==nil)
end)
test('item recipient uses its own balance flight and bag, while another member bag blocks',function()
    local f=effect(14); f:press(2); f.j.CanFly=true; f.spikes=true; f:update()
    f:press(1); f:update(); assert(not f.collect.busy() and f.labels.BLOCKED)
    f.spikes=false; f.e.coins=0; f.item.Price=5; f:press(1); f:update(); assert(not f.collect.busy())
    f.item.Price=0; f.j.hasBag=true; f.j.state=710; f:press(1); f:update(); assert(f.labels['OTHER BAG'])
    f.j.state=0; f.e.hasBag=true; f.e.state=710; f:press(1); f:update(); assert(f.bag.busy())
end)
test('Esau Jr use cancels before flags change and repeated foreground switches rearm right click',function()
    local f=fixture(); f.j.kind=0; f.j.twin=nil; f.j.items={[703]=1}; f.players={f.j}; f:release()
    for i=1,3 do
        f:press(1); f:update(); assert(f.collect.busy())
        f.handlers[14](nil,703,nil,f.players[1]); assert(not f.collect.busy() and f.item.Position.X==220)
        local next=player(0,40+i*5); next.items={[703]=1}; next.effects={[100]=i%2==1}; f.players={next}
        for step=1,4 do f:update(); f:render() end
        assert(not f.collect.busy() and f:cursor(i%2==1 and 0 or 1))
        f:press(2); assert(f:cursor(i%2==1 and 0 or 1))
    end
end)
local function stacked(kind)
    local f=kind==19 and fixture() or character(kind)
    f.child=player(14,100); f.child.Parent=f.j; f.j.items={[667]=1}
    f.players[#f.players+1]=f.child; f:release()
    return f
end

test('stacked twins cycle three colors and route contact only to the selected native member',function()
    local f=stacked(19)
    for i,p in ipairs({f.j,f.e,f.child}) do
        if i>1 then f:press(2) end
        local c=f.labels['+']; assert(c and c.a==0.8)
        if i==1 then assert(f:cursor(1)) elseif i==2 then assert(f:cursor(0)) else assert(c.g==0.8 and c.b==0.25) end
        f:press(1); f:update(); assert(f.collect.busy() and f.item.Position.X==p.Position.X)
        for _,member in ipairs(f.players) do if member~=p then assert(f:collision(f.item,member)==true) end end
        assert(f:collision(f.item,p)==nil); f:update(); assert(f.item.Position.X==220)
    end
    f:press(2); assert(f:cursor(1))
end)

test('stacked form changes cancel queued and inflight requests and never retry a held button',function()
    for _,kind in ipairs({16,29}) do
        for _,inflight in ipairs({false,true}) do
            local f=stacked(kind); f:press(2); f:press(1)
            if inflight then f:update(); assert(f.collect.busy()) end
            f.j.kind=kind==16 and 17 or 38
            if kind==16 then f.e.kind=16 else f.players={player(38,40)} end
            if inflight then assert(f:collision(f.item,f.child)==true) else f:update() end
            f:render(); f:update(); assert(not f.collect.busy() and f.item.Position.X==220)
            f:press(1); f:update(); assert(f.collect.busy())
        end
    end
end)

test('all stacked companions block bags and protect replacement loot while normal walking remains native',function()
    local f=stacked(19); f:press(2); f:press(2)
    for _,member in ipairs({f.j,f.e}) do
        member.hasBag=true; member.state=710; f:press(1); f:update()
        assert(f.labels['OTHER BAG'] and not f.collect.busy()); member.state=0
    end
    f.item.Variant=50; f:press(1); f:update(); assert(f.collect.busy())
    assert(f:collision(f.item,f.child)==nil)
    local loot=pickup(20,1,100); loot.SpawnerEntity=f.item; f.collect.spawned(loot)
    for _,member in ipairs({f.j,f.e}) do
        assert(f:collision(loot,member)==true and f:collision(pickup(20,1,member.Position.X),member)==nil)
    end
end)

test('stacked child balance flight bag and room selection are independent of both native twins',function()
    local f=stacked(19); f:press(2); f:press(2)
    f.j.CanFly=true; f.e.CanFly=true; f.spikes=true; f:update()
    f:press(1); f:update(); assert(not f.collect.busy() and f.labels.BLOCKED)
    f.spikes=false; f.child.coins=0; f.item.Price=5; f:press(1); f:update(); assert(f.labels['NO COINS'])
    f.item.Price=0; f.handlers[5](); f:release(); assert(f.labels['+'].g==0.8)
    f.child.hasBag=true; f.child.state=710; f:press(1); f:update(); assert(f.bag.busy())
    f.handlers[6](nil,true); f.child.state=0; f:release(); assert(f:cursor(1))
    f:press(2); f:press(2); f.paused=true; f:render(); assert(not f.labels['+'])
    f.paused=false; f:render(); assert(f.labels['+'].g==0.8 and not f.bag.busy())
end)

test('stacked child death removal and relationship changes restore displacement and reset EID',function()
    for _,change in ipairs({'death','remove','parent','seed','birthright'}) do
        local f=stacked(29); f:press(2); f:press(1); f:update(); assert(f.collect.busy())
        if change=='death' then f.child.dead=true
        elseif change=='remove' then f.players={f.j}; f.j.items=nil
        elseif change=='parent' then f.child.Parent=player(0,180)
        elseif change=='seed' then f.child.InitSeed=77
        else f.j.birthright=true end
        assert(f:collision(f.item,f.child)==true and f.item.Position.X==220 and not f.collect.busy())
        f:render(); f:update(); assert(not f.collect.busy())
    end
end)
local function soulStack(kind,childKind)
    local f=kind==19 and fixture() or character(kind)
    f.child=player(childKind,100); f.child.Parent=f.j
    f.child.effects={[childKind==16 and 120 or 121]=true}
    f.players[#f.players+1]=f.child; f:release()
    return f
end

test('four soul stacks route native contact and protect every nonrecipient including hidden forms',function()
    for _,case in ipairs({{19,16},{16,20},{29,16},{29,20}}) do
        local f=soulStack(case[1],case[2]); f:press(2); if case[1]==19 then f:press(2) end
        local c=f.labels['+']; assert(c.a==0.8 and (case[2]==16 and c.r==0.65 or case[2]==20 and c.g==0))
        f:press(1); f:update(); assert(f.item.Position.X==f.child.Position.X)
        for _,member in ipairs({f.j,f.e}) do assert(f:collision(f.item,member)==true) end
        assert(f:collision(f.item,f.child)==nil); f:update(); assert(f.item.Position.X==220)
        assert(f.j.Position.X==20 and f.child.Position.X==100)
    end
end)

test('native foreground transfers cancel queued and displaced soul stack contacts with held right gated',function()
    for _,case in ipairs({{16,20},{29,16},{29,20}}) do
        for _,inflight in ipairs({false,true}) do
            local f=soulStack(case[1],case[2]); f:press(2); f:press(1)
            if inflight then f:update(); assert(f.collect.busy()) end
            if case[1]==16 then f.j.kind=17; f.e.kind=16
            else
                local next=player(38,40); f.child.Parent=next; f.players={f.child,next}; f.j=next
            end
            f:update(); f:render(); f:update()
            assert(not f.collect.busy() and f.item.Position.X==220)
            if case[1]==16 then assert(f.labels['+'].r==0.3) else assert(f:cursor(1)) end
            f:press(1); f:update(); assert(f.collect.busy() and f.item.Position.X==f.j.Position.X)
        end
    end
end)

test('soul stack expiry death seed replacement and invalid combinations restore then require fresh input',function()
    for _,change in ipairs({'expiry','death','seed','parent','extra','birthright'}) do
        local f=soulStack(29,20); f:press(2); f:press(1); f:update()
        if change=='expiry' then f.players={f.j} elseif change=='death' then f.child.dead=true
        elseif change=='seed' then f.child.InitSeed=77 elseif change=='parent' then f.child.Parent=f.e
        elseif change=='extra' then f.j.items={[703]=1} else f.j.birthright=true end
        assert(f:collision(f.item,f.child)==true and f.item.Position.X==220 and not f.collect.busy())
        f.j.items=nil; f.j.birthright=false; f.child.Parent=f.j; f.child.dead=false
        f:render(); f:update(); assert(not f.collect.busy())
        f:press(1); f:update(); assert(f.collect.busy() and f.item.Position.X==f.j.Position.X)
    end
end)

test('soul stack members each block bags and child keeps independent terrain balance and bag ownership',function()
    local f=soulStack(19,16); f:press(2); f:press(2)
    for _,member in ipairs({f.j,f.e}) do
        member.hasBag=true; member.state=710; f:press(1); f:update()
        assert(f.labels['OTHER BAG'] and not f.collect.busy()); member.state=0
    end
    f.j.CanFly=true; f.e.CanFly=true; f.spikes=true; f:update()
    f:press(1); f:update(); assert(f.labels.BLOCKED and not f.collect.busy())
    f.spikes=false; f.child.coins=0; f.item.Price=5; f:press(1); f:update(); assert(f.labels['NO COINS'])
    f.item.Price=0; f.child.hasBag=true; f.child.state=710; f:press(1); f:update(); assert(f.bag.busy())
end)

test('soul stack foreground and expiry changes release the old EID overlay immediately',function()
    for _,change in ipairs({'form','expiry','parent'}) do
        local f=soulStack(29,20)
        EID={Config={},InlineIcons={},hasDescription=function() return true end,
            IsItemHidden=function() return false end,getEntityData=function() end,
            getDescriptionObjByEntity=function(_,p) return {Entity=p,Description='hover'} end,
            ResetDescCache=function() end,
            displayPermanentText=function(_,desc) EID.permanentDisplayTextObj=desc; EID.isDisplayingPermanent=true end,
            hidePermanentText=function() EID.isDisplayingPermanent=false; EID.permanentDisplayTextObj=nil end}
        f:render(); assert(EID.isDisplayingPermanent)
        if change=='form' then
            local next=player(38,40); f.child.Parent=next; f.players={next,f.child}
        elseif change=='expiry' then f.players={f.j} else f.child.Parent=f.e end
        f:update(); assert(not EID.isDisplayingPermanent and not EID.permanentDisplayTextObj)
    end
end)

test('soul stacks preserve reordered selection while paused and rebuild on room expiry restart or continue',function()
    for _,continued in ipairs({false,true}) do
        local f=soulStack(19,16); f:press(2); f:press(2)
        f.players={f.child,f.e,f.j}; f:release(); assert(f.labels['+'].r==0.65)
        f.paused=true; f:render(); assert(not f.labels['+']); f.paused=false; f:render(); assert(f.labels['+'].r==0.65)
        f.handlers[6](nil,continued); f:release(); assert(f:cursor(1))
        f:press(2); f:press(2); f:press(1); f.players={f.j,f.e}; f.handlers[5](); f:update()
        f:render(); assert(f:cursor(1) and not f.collect.busy() and f.item.Position.X==220)
    end
end)
test('same-role soul cursors mark only summoned recipients without recoloring pickup status',function()
    for _,case in ipairs({{19,20},{16,16}}) do
        local f=soulStack(case[1],case[2]); assert(not f.diamond)
        if case[1]==19 then f:press(2); assert(f:cursor(0) and not f.diamond) end
        f:press(2); local c=f.labels['+']; local d=f.diamond
        assert(d and d.x==220 and d.y==20 and d.color.R==c.r and d.color.G==c.g and d.color.B==c.b and d.color.A==0.8)
        assert(c.x==217 and c.y==14 and f.labels.RMB.g==1 and f.labels['['].r==0.3)
        f.item.Price=5; f:render(); assert(f.diamond and f.labels['5c'].r==1 and f.labels['5c'].g==0.8)
        f.item.Wait=10; f:render(); assert(f.diamond and f.labels.WAIT.g==0.35)
        f.items={}; f:render(); assert(f.diamond and f.labels['+'] and not f.labels['['])
        f:press(2); assert(not f.diamond)
    end
end)

test('same-role souls isolate every recipient and retain independent movement and abilities',function()
    for _,case in ipairs({{19,20},{16,16}}) do
        for selection=1,(case[1]==19 and 3 or 2) do
            local f=soulStack(case[1],case[2]); local choices=case[1]==19 and {f.j,f.e,f.child} or {f.j,f.child}
            for i=2,selection do f:press(2) end
            f:press(1); f:update(); assert(f.collect.busy())
            for _,member in ipairs({f.j,f.e,f.child}) do
                assert(f:collision(f.item,member)==(member~=choices[selection] and true or nil))
            end
            f:update(); assert(f.item.Position.X==220 and f.j.Position.X==20 and f.child.Position.X==100)
        end
        local f=soulStack(case[1],case[2]); f:press(2); if case[1]==19 then f:press(2) end
        f.j.CanFly=true; f.e.CanFly=true; f.spikes=true; f:update(); f:press(1); f:update()
        assert(f.labels.BLOCKED and not f.collect.busy())
        f.spikes=false; f.item.Price=5; f.child.coins=0; f:press(1); f:update()
        assert(f.labels['NO COINS'] and not f.collect.busy())
    end
end)

test('same-role lifecycle changes restore queued and displaced targets and never retry held right',function()
    for _,kind in ipairs({19,16}) do
        for _,change in ipairs({'death','expiry','seed','parent','form'}) do
            for _,inflight in ipairs({false,true}) do
                local f=soulStack(kind,kind==19 and 20 or 16); f:press(2); if kind==19 then f:press(2) end
                f:press(1); if inflight then f:update(); assert(f.collect.busy()) end
                if change=='death' then f.child.dead=true
                elseif change=='expiry' then f.players=kind==19 and {f.j,f.e} or {f.j}
                elseif change=='seed' then f.child.InitSeed=44
                elseif change=='parent' then f.child.Parent=f.e
                elseif kind==16 then f.j.kind=17; f.e.kind=16
                else f.e.twin=f.child end
                f:update(); f:render(); f:update()
                assert(not f.collect.busy() and f.item.Position.X==220 and not f.diamond)
                f.child.Parent=f.j; f.e.twin=kind==19 and f.j or nil
                f:render(); f:update(); assert(not f.collect.busy())
                f:press(1); f:update(); assert(f.collect.busy() and f.item.Position.X==f.j.Position.X)
            end
        end
    end
end)

test('same-role nonrecipients including hidden form block bags and selected soul owns the swing',function()
    for _,case in ipairs({{19,20},{16,16}}) do
        local f=soulStack(case[1],case[2]); f:press(2); if case[1]==19 then f:press(2) end
        for _,member in ipairs({f.j,f.e}) do
            member.hasBag=true; member.state=710; f:press(1); f:update()
            assert(f.labels['OTHER BAG'] and not f.collect.busy()); member.state=0
        end
        f.child.hasBag=true; f.child.state=710; f:press(1); f:update(); assert(f.bag.busy())
    end
end)

test('same-role selection survives reorder room and pause but restart and continue reset it',function()
    for _,continued in ipairs({false,true}) do
        for _,case in ipairs({{19,20},{16,16}}) do
            local f=soulStack(case[1],case[2]); f:press(2); if case[1]==19 then f:press(2) end
            f.players=case[1]==19 and {f.child,f.e,f.j} or {f.child,f.j}
            f.handlers[5](); f:release(); assert(f.diamond)
            f.paused=true; f:render(); assert(not f.diamond and not f.labels['+'])
            f.paused=false; f:render(); assert(f.diamond)
            f.handlers[6](nil,continued); f:release(); assert(not f.diamond)
            if case[1]==19 then assert(f:cursor(1)) else assert(f.labels['+'].r==0.65) end
        end
    end
end)
test('same-role shape and ownership changes release the old EID overlay before new input',function()
    for _,kind in ipairs({16,19}) do
        local f=soulStack(kind,kind==19 and 20 or 16)
        EID={Config={},InlineIcons={},hasDescription=function() return true end,
            IsItemHidden=function() return false end,getEntityData=function() end,
            getDescriptionObjByEntity=function(_,p) return {Entity=p,Description='hover'} end,
            ResetDescCache=function() end,
            displayPermanentText=function(_,desc) EID.permanentDisplayTextObj=desc; EID.isDisplayingPermanent=true end,
            hidePermanentText=function() EID.isDisplayingPermanent=false; EID.permanentDisplayTextObj=nil end}
        f:press(2); if kind==19 then f:press(2) end
        assert(EID.isDisplayingPermanent and f.diamond)
        if kind==16 then f.j.kind=17; f.e.kind=16 else f.child.Parent=f.e end
        f:update(); assert(not EID.isDisplayingPermanent and not EID.permanentDisplayTextObj)
    end
end)
test('MCM pickup bindings route each allowed button once and show the matching green hint',function()
    for key,name in ipairs({'RMB','MMB','M4','M5'}) do
        local f=fixture(); f.config.set('pickupButton',key); f:release()
        assert(f.labels[name] and f.labels[name].g==1)
        if key~=1 then f:press(1); f:update(); assert(not f.collect.busy()) end
        f:press(key); f:update(); assert(f.collect.busy() and f.item.Position.X==(key==2 and 60 or 20))
        for _=1,5 do f:render(); f:update() end
        assert(not f.collect.busy() and f.item.Position.X==220)
    end
end)

test('MCM switch bindings preserve recipients on edit and retain simultaneous switch priority',function()
    for key=1,4 do
        local f=fixture(); f:press(2); assert(f:cursor(0))
        f.config.set('switchButton',key); f:release(); assert(f:cursor(0))
        local pick=f.config.get('pickupButton')
        f.down[key],f.down[pick]=true,true; f:render(); f:update()
        assert(f:cursor(1) and not f.collect.busy() and f.item.Position.X==220)
        for _=1,4 do f:render(); f:update() end
        assert(f:cursor(1) and not f.collect.busy())
        f:release(); f:press(key); assert(f:cursor(0))
    end
end)

test('MCM binding edits immediately cancel queued and displaced targets and require release',function()
    for _,inflight in ipairs({false,true}) do
        local f=fixture(); f:press(2); f:press(1)
        if inflight then f:update(); assert(f.collect.busy()) end
        f.down[3]=true; f.config.set('pickupButton',3)
        assert(not f.collect.busy() and f.item.Position.X==220 and f.item.TargetPosition.X==220)
        f:render(); f:update(); assert(f:cursor(0) and not f.collect.busy())
        f:release(); f:press(1); f:update(); assert(not f.collect.busy())
        f:press(3); f:update(); assert(f.collect.busy() and f.item.Position.X==60)
    end
end)

test('MCM disabled master switch cancels both inputs and requires fresh presses on reenable',function()
    local f=fixture(); f:press(1); f:update(); assert(f.collect.busy())
    f.config.set('enabled',false)
    assert(not f.collect.busy() and f.item.Position.X==220)
    f.down[2]=true; f:render(); f:update(); assert(not next(f.labels))
    f.config.set('enabled',true); f:render(); f:update()
    assert(f:cursor(1) and not f.collect.busy())
    f:release(); f:press(2); assert(f:cursor(0))
    f:press(1); f:update(); assert(f.item.Position.X==60)
end)

test('MCM opening between render and update cancels the queue and disarms both held buttons',function()
    local f=fixture(); f:press(1); f.down[2]=true
    ModConfigMenu={IsVisible=true}; f:update()
    assert(not f.collect.busy() and f.item.Position.X==220)
    ModConfigMenu.IsVisible=false; f:render(); f:update()
    assert(f:cursor(1) and not f.collect.busy())
    f:release(); f:press(2); assert(f:cursor(0))
end)

test('MCM opening immediately before native contact restores the pickup and vetoes stale collision',function()
    local f=fixture(); f:press(1); f:update(); assert(f.item.Position.X==20)
    ModConfigMenu={IsVisible=true}
    assert(f:collision(f.item,f.j)==true)
    assert(not f.collect.busy() and f.item.Position.X==220 and f.item.TargetPosition.X==220)
    ModConfigMenu=nil; f:render(); f:update(); assert(not f.collect.busy())
    local unrelated=pickup(20,1,20)
    f.config.set('enabled',false); assert(f:collision(unrelated,f.j)==nil)
end)

test('MCM disabling or rebinding a bag restores isolated materials and owned knives',function()
    for _,change in ipairs({'enabled','pickupButton','menu'}) do
        local f=fixture(); f.e.state=710; f.e.hasBag=true
        local neighbor=pickup(20,2); neighbor.Index=2; f.items[2]=neighbor
        f:press(2); f:press(1); f:update(); assert(f.bag.busy() and neighbor.flags==1)
        local knife={Type=8,Variant=4,SpawnerEntity=f.e,Exists=function() return true end}
        function knife:Remove() self.removed=true end
        f.handlers[8](nil,knife)
        if change=='menu' then ModConfigMenu={IsVisible=true}; f.handlers[9](nil,knife)
        elseif change=='enabled' then f.config.set(change,false)
        else f.config.set(change,3) end
        assert(not f.bag.busy() and neighbor.flags==0 and knife.removed and f.item.Position.X==220)
        assert(f.handlers[7](nil,f.e,2,7)==nil)
    end
end)

test('MCM display settings independently hide visuals without disabling pickups or changing costs',function()
    for _,key in ipairs({'showCursor','showBox','showStatus'}) do
        local f=fixture(); f.config.set(key,false); f:release()
        assert((f.labels['+']==nil)==(key=='showCursor'))
        assert((f.labels['[']==nil)==(key=='showBox'))
        assert((f.labels.RMB==nil)==(key=='showStatus'))
        f:press(1); f:update(); assert(f.collect.busy())
    end
    local f=fixture(); f.config.set('pickupButton',4); f.item.Price=5; f:release()
    assert(f.labels['5c'] and f.labels['5c'].g==0.8)
    f.config.set('showCursor',false); f.config.set('showBox',false); f.config.set('showStatus',false)
    f:release(); assert(not next(f.labels)); f:press(4); f:update(); assert(f.collect.busy())
end)

test('MCM cursor setting hides and restores the summoned recipient diamond without resetting selection',function()
    local f=soulStack(19,20); f:press(2); f:press(2); assert(f.diamond)
    f.config.set('showCursor',false); f:render(); assert(not f.diamond and not f.labels['+'] and f.labels.RMB)
    f.config.set('showCursor',true); f:render(); assert(f.diamond)
end)

test('MCM EID toggle releases its overlay immediately and never clears another owner',function()
    local f=fixture(); f.item.Variant=100; f.item.SubType=1
    EID={Config={},InlineIcons={},hasDescription=function() return true end,
        IsItemHidden=function() return false end,getEntityData=function() end,
        getDescriptionObjByEntity=function(_,p) return {Entity=p,Description='hover'} end,
        ResetDescCache=function() end,
        displayPermanentText=function(_,desc) EID.permanentDisplayTextObj=desc; EID.isDisplayingPermanent=true end,
        hidePermanentText=function() EID.permanentDisplayTextObj=nil; EID.isDisplayingPermanent=false end}
    f:render(); assert(EID.isDisplayingPermanent)
    f.config.set('eidHover',false); assert(not EID.isDisplayingPermanent)
    f:render(); assert(not EID.isDisplayingPermanent and f.labels.RMB)
    f.config.set('eidHover',true); f:render(); assert(EID.isDisplayingPermanent)
    local other={Description='another mod'}; EID.permanentDisplayTextObj=other
    f.config.set('eidHover',false); assert(EID.permanentDisplayTextObj==other and EID.isDisplayingPermanent)
    f.config.set('eidHover',true); f:render(); assert(EID.permanentDisplayTextObj==other)
end)

test('MCM late registration survives room and game callbacks without duplicating the settings',function()
    local f=fixture(); ModConfigMenu=dofile('tests/support/menu.lua')(true)
    f:render(); assert(ModConfigMenu.registrations==8)
    ModConfigMenu.options[2].OnChange(4); f:release(); assert(f.labels.M5)
    f.handlers[5](); f:release(); assert(f.labels.M5 and ModConfigMenu.registrations==8)
    f.handlers[6](); f:release(); assert(f.labels.M5 and ModConfigMenu.registrations==8)
    ModConfigMenu=nil; f:release(); f:press(4); f:update(); assert(f.collect.busy())
end)

test('MCM preferences reload for the selected save slot when starting or continuing',function()
    local f=fixture(); f.config.set('pickupButton',3); f.mod:slot(2)
    f.handlers[6](nil,false); f:release(); assert(f.labels.RMB)
    f.config.set('showBox',false); f.mod:slot(1)
    f.handlers[6](nil,true); f:release(); assert(f.labels.M4 and f.labels['['])
    f:press(3); f:update(); assert(f.collect.busy())
end)

print(count..' actor integration tests passed (simulated engine, NOT native gameplay)')
