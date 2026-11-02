-- Exercise the real callback wiring with separate render/update rates.
local handlers, priorities = {}, {}
local mod, json = dofile('tests/support/storage.lua')()
package.preload.json=function() return json end
ModCallbacks={MC_PRE_PICKUP_COLLISION=1,MC_POST_UPDATE=2,MC_POST_RENDER=3,
    MC_PRE_GAME_EXIT=4,MC_POST_NEW_ROOM=5,MC_POST_GAME_STARTED=6,MC_INPUT_ACTION=7,MC_POST_KNIFE_INIT=8,MC_POST_KNIFE_UPDATE=9,MC_USE_ITEM=14}
function mod:AddCallback(id,fn) handlers[id]=fn end
function mod:AddPriorityCallback(id,priority,fn) handlers[id]=fn; priorities[id]=priority end
RegisterMod=function() return mod end
local down, playable, begins, busy = false, true, 0, false
local collect={finish=function() busy=false end,reset=function() busy=false end,step=function() busy=false end,
    busy=function() return busy end,collision=function() end,
    begin=function() begins=begins+1; busy=true end}
local raised, bagBegins, bagBusy, bagBlocked = false,0,false,nil
local updatedKnife
local bag={raised=function() return raised end,blocked=function() return bagBlocked end,
    busy=function() return bagBusy end,begin=function() bagBegins=bagBegins+1; bagBusy=true end,
    finish=function() bagBusy=false end,reset=function() bagBusy=false end,step=function() bagBusy=false end,
    input=function() end,spawned=function() end,collision=function() end,
    knifeUpdated=function(entity) updatedKnife=entity end}
local item={}
local selection=dofile('mouse_pickup/mpickup/selection.lua')
selection.choose=function() return item,{x=0,y=0,w=10,h=10} end
selection.supported=function() return true end
local reachable=true
local reach={new=function() return {refresh=function() end,canTouch=function() return reachable end,reset=function() end} end}
local initialPlayer={GetPlayerType=function() return 0 end}
GetPtrHash=function(p) return p end
local rules={player=function() return initialPlayer end,enabled=function() return playable end,
    blocked=function() end,cost=function() return 'RMB' end}
rules.group=function() local p=rules.player(); return {player=p,control=p,members={p},candidates={p},available=true,switchable=false} end
include=function(path)
    return ({['mpickup/collect']=function() return collect end,['mpickup/bag']=function() return bag end,['mpickup/selection']=selection,
        ['mpickup/reach']=reach,['mpickup/rules']=rules,['mpickup/eid']=dofile('mouse_pickup/mpickup/eid.lua'),
        ['mpickup/actors']=dofile('mouse_pickup/mpickup/actors.lua'),
        ['mpickup/config']=dofile('mouse_pickup/mpickup/config.lua'),
        ['mpickup/mcm']=dofile('mouse_pickup/mpickup/mcm.lua'),
        ['mpickup/development']=false})[path]
end
Game=function() return {GetRoom=function() return {} end,GetFrameCount=function() return 1 end} end
Input={IsMouseBtnPressed=function(id) return id==1 and down end,GetMousePosition=function() return {X=0,Y=0} end}
Isaac={WorldToScreen=function(p) return p end,FindByType=function() return {} end,RenderText=function() end}
Mouse={MOUSE_BUTTON_2=1,MOUSE_BUTTON_3=2}; EntityType={ENTITY_PICKUP=5}
dofile('mouse_pickup/main.lua')
local knife={}; handlers[9](nil,knife); assert(updatedKnife==knife,'knife updates reach the bag transaction')
local render, update = handlers[3],handlers[2]
render(); down=true; render(); render(); update()
assert(begins==1, 'an extra render must not cancel the queued click')
render(); update(); render(); update()
assert(begins==1, 'holding must not repeat')
down=false; render(); down=true; render(); playable=false; render(); playable=true; update()
assert(begins==1, 'pausing must cancel a pending click')
render(); update(); assert(begins==1, 'resume while held must not fire')
down=false; render(); down=true; render(); update()
assert(begins==2, 'fresh press must work after resume')
update(); raised=true; down=false; render(); down=true; render(); render(); update()
assert(bagBegins==1 and begins==2, 'raised bag routes only to bag transaction')
render(); update(); render(); update()
assert(bagBegins==1, 'held right button must not repeat bag pickup')
down=false; render(); down=true; render(); raised=false; update()
assert(bagBegins==1 and begins==2, 'lowering after click cancels instead of ordinary pickup')
down=false; render(); down=true; render(); raised=true; update()
assert(bagBegins==1 and begins==2, 'raising after ordinary click cancels instead of bag pickup')
bagBlocked='NOT MATERIAL'; down=false; render(); down=true; render(); update()
assert(bagBegins==1 and begins==2, 'non-material never falls back to normal pickup')
bagBlocked=nil; down=false; render(); down=true; render(); playable=false; update()
assert(bagBegins==1, 'update gate cancels bag click when gameplay becomes disabled')
playable=true; raised=false; down=false; render(); down=true; render(); update()
assert(begins==3 and bagBegins==1, 'lowered bag restores normal right click')
update(); raised=true; down=false; render(); down=true; render(); reachable=false; update()
assert(bagBegins==1, 'terrain changes between click and update cancel bag pickup')
reachable=true; down=false; render(); down=true; render(); handlers[5](); update()
assert(bagBegins==1, 'room transition clears queued bag click')
print('PASS controller: render/update cadence, hold, pause cancellation, resume rearm')
print('PASS controller: bag routing, hold, mode changes, non-material, update cancellation, normal pickup')
-- Use the real selector for poop to verify player context at both entry points.
local realSelection=dofile('mouse_pickup/mpickup/selection.lua')
local kind=25
local player={GetPlayerType=function() return kind end}
rules.player=function() return player end
item={Variant=42,SubType=0,Visible=true,Exists=function() return true end,
    IsDead=function() return false end,GetSprite=function() return {IsPlaying=function() return false end} end,
    ToPickup=function(self) return self end}
selection.supported=realSelection.supported
selection.choose=realSelection.choose
selection.bounds=function() return {x=0,y=0,w=10,h=10} end
Isaac.FindByType=function() return {item} end
raised=false; handlers[5](); down=false; render(); down=true; render(); kind=0; update()
assert(begins==3,'character change must cancel queued poop pickup')
kind=25; down=false; render(); down=true; render(); update()
assert(begins==4,'Tainted Blue Baby can queue and collect poop')
render(); update(); render(); update(); assert(begins==4,'holding must not repeat poop pickup')
down=false; render(); down=true; render(); raised=true; update()
assert(begins==4 and bagBegins==1,'raising bag cancels queued ordinary poop pickup')
down=false; render(); down=true; render(); update()
assert(bagBegins==2,'raised bag routes poop to bag')
print('PASS controller: poop player context, character change, hold and bag mode switch')

-- Load EID after Mouse Pickup, as can happen with a different mod load order.
EID={Config={},InlineIcons={},hasDescription=function() return true end,
    IsItemHidden=function() return false end,getEntityData=function() end,
    getDescriptionObjByEntity=function(_,p) return {Entity=p,Description='hover'} end,
    ResetDescCache=function() end,
    displayPermanentText=function(_,desc) EID.permanentDisplayTextObj=desc; EID.isDisplayingPermanent=true end,
    hidePermanentText=function() EID.permanentDisplayTextObj=nil; EID.isDisplayingPermanent=false end}
item.Variant=100; item.SubType=1; raised=false; down=false; update(); render()
assert(priorities[3]<0, 'hover must be published before EID renders at default priority')
assert(EID.permanentDisplayTextObj.Entity==item, 'EID loaded later receives the real hover')
reachable=false; render()
assert(EID.permanentDisplayTextObj.Entity==item, 'blocked pickups still allow inspection')
playable=false; render(); assert(not EID.isDisplayingPermanent, 'disabled controls release EID')
playable=true; render(); handlers[5]()
assert(not EID.isDisplayingPermanent, 'new room clears EID hover')
render(); handlers[4](); assert(not EID.isDisplayingPermanent, 'game exit clears EID hover')
render(); handlers[6](); assert(not EID.isDisplayingPermanent, 'new game clears EID hover')
render(); Isaac.FindByType=function() return {} end; render()
assert(not EID.isDisplayingPermanent and EID.ForceRefreshCache, 'moving off targets restores EID')
EID=nil
print('PASS controller: EID priority, late loading, blocked inspection, pause, room, exit, restart and hover exit')
