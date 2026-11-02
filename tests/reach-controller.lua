-- Execute the production entry point with the real reach module.
local handlers={}
local mod,json=dofile('tests/support/storage.lua')()
package.preload.json=function() return json end
ModCallbacks={MC_PRE_PICKUP_COLLISION=1,MC_POST_UPDATE=2,MC_POST_RENDER=3,
    MC_PRE_GAME_EXIT=4,MC_POST_NEW_ROOM=5,MC_POST_GAME_STARTED=6,MC_INPUT_ACTION=7,MC_POST_KNIFE_INIT=8,MC_POST_KNIFE_UPDATE=9,MC_USE_ITEM=14}
function mod:AddCallback(id,fn) handlers[id]=fn end
function mod:AddPriorityCallback(id,priority,fn) handlers[id]=fn end
RegisterMod=function() return mod end
local spikes,raised,down=false,false,false
local ordinary,bagged=0,0
local player={Position={X=20,Y=20},Size=10,GridCollisionClass=5,CanFly=false,
    GetPlayerType=function() return 0 end,
    HasTrinket=function() return false end,HasCollectible=function() return false end}
local room={GetGridSize=function() return 5 end,GetGridWidth=function() return 5 end,
    GetGridPosition=function(_,i) return {X=i*40+20,Y=20} end,
    GetGridIndex=function(_,p) return math.floor(p.X/40) end,
    IsPositionInRoom=function() return true end,GetGridCollision=function() return 0 end,
    GetGridEntity=function(_,i) if spikes and i==2 then return {State=0,GetType=function() return 8 end} end end}
Game=function() return {GetRoom=function() return room end,GetFrameCount=function() return 1 end} end
local item={Position={X=180,Y=20},Size=10}
local selection=dofile("mouse_pickup/mpickup/selection.lua")
selection.supported=function() return true end
selection.choose=function() return item,{x=0,y=0,w=10,h=10} end
local collect={reset=function() end,step=function() end,finish=function() end,busy=function() return false end,
    collision=function() end,begin=function() ordinary=ordinary+1 end}
local bag={reset=function() end,step=function() end,finish=function() end,busy=function() return false end,
    raised=function() return raised end,blocked=function() end,collision=function() end,input=function() end,
    spawned=function() end,begin=function() bagged=bagged+1 end}
include=function(path) return ({["mpickup/selection"]=selection,["mpickup/reach"]=dofile("mouse_pickup/mpickup/reach.lua"),
    ["mpickup/actors"]=dofile("mouse_pickup/mpickup/actors.lua"),
    ["mpickup/collect"]=function() return collect end,["mpickup/bag"]=function() return bag end,
    ["mpickup/eid"]=dofile("mouse_pickup/mpickup/eid.lua"),
    ["mpickup/config"]=dofile("mouse_pickup/mpickup/config.lua"),
    ["mpickup/mcm"]=dofile("mouse_pickup/mpickup/mcm.lua"),
    ["mpickup/rules"]={group=function() return {player=player,control=player,members={player},candidates={player},available=true,switchable=false} end,enabled=function() return true end,
        blocked=function() end,cost=function() return "RMB" end},["mpickup/development"]=false})[path] end
local label
Isaac={FindByType=function() return {} end,WorldToScreen=function(p) return p end,
    RenderText=function(text) if text=="BLOCKED" then label=text end end}
GetPtrHash=function(p) return p end
Input={IsMouseBtnPressed=function(id) return id==1 and down end,GetMousePosition=function() return {X=0,Y=0} end}
Mouse={MOUSE_BUTTON_2=1,MOUSE_BUTTON_3=2}; EntityType={ENTITY_PICKUP=5}
dofile("mouse_pickup/main.lua")
local function queue()
    handlers[5](); down=false; handlers[3](); down=true; handlers[3]()
end
for _,mode in ipairs({false,true}) do
    raised=mode; spikes=true; player.CanFly=false; label=nil
    local before=ordinary+bagged
    queue(); handlers[2](); assert(ordinary+bagged==before and label=="BLOCKED")
    player.CanFly=true; queue(); player.CanFly=false; handlers[2](); assert(ordinary+bagged==before)
    spikes=false; queue(); spikes=true; handlers[2](); assert(ordinary+bagged==before)
    player.CanFly=true; queue(); handlers[2](); assert(ordinary+bagged==before+1)
end
assert(ordinary==1 and bagged==1)
print("PASS real reach/controller: both modes reject spikes, lost flight and same-frame hazards; flight allows each once")
