local compat = dofile("mouse_pickup/mpickup/eid.lua")
-- Optional: exercise the installed EID's actual overlay API without the game.
local eidSource
if arg and arg[1] then
    local file = assert(io.open(arg[1], "r"))
    eidSource = file:read("a"); file:close()
end
local count = 0
local function test(name, fn)
    fn()
    count = count+1
    print("PASS EID: "..name)
end
local function fixture(variant)
    local game = {Challenge=0}
    local player = {Position={},CanFly=false}
    local item = {Type=5,Variant=variant or 100,SubType=1,Visible=true,Position={},OptionsPickupIndex=0,
        Exists=function(self) return not self.removed end,IsDead=function(self) return self.dead end,
        IsShopItem=function(self) return self.shop end}
    local eid = {Config={DisplayPillInfoShop=true,DisplayCardInfoShop=true,DisplaySoulstoneInfoShop=true,
        ["DisplayPillInfoOptions?"]=true,["DisplayCardInfoOptions?"]=true,
        DisplayObstructedPillInfo=true,DisplayObstructedCardInfo=true,DisplayObstructedSoulstoneInfo=true,
        EnableEntityDescriptions=true},InlineIcons={QuestionMark="?"},isRepentance=true,builds=0,clears=0}
    function eid:hasDescription(p) return not p.noDescription end
    function eid:IsItemHidden(p) return p.hidden end
    function eid:requiredForCollectionPage() return true end
    function eid:getDescriptionEntry(key) return "localized:"..key end
    function eid:getEntityData(p, key) return p[key] end
    function eid:HasPathToPosition() return self.path end
    function eid:ShouldShowPillAsIdentified() return self.identified end
    function eid:getDescriptionObj(t,v,s,p)
        self.builds=self.builds+1
        return {Entity=p,Name="name:"..s,Description="effect:"..s,ObjVariant=v,ObjSubType=s}
    end
    function eid:getDescriptionObjByEntity(p) return self:getDescriptionObj(p.Type,p.Variant,p.SubType,p) end
    function eid:mergeDescriptionObjects(desc, custom)
        for k,v in pairs(custom) do desc[k]=v end
        return desc
    end
    function eid:displayPermanentText(desc) self.isDisplayingPermanent=true; self.permanentDisplayTextObj=desc end
    function eid:hidePermanentText() self.isDisplayingPermanent=false; self.permanentDisplayTextObj=nil end
    function eid:ResetDescCache() self.clears=self.clears+1 end
    EID=eid
    if eidSource then
        for _,name in ipairs({"displayPermanentText","hidePermanentText"}) do
            local source = assert(eidSource:match("(function EID:"..name.."%(.-\nend)"), name.." not found")
            assert(load(source, "installed EID:"..name))()
        end
    end
    local api=compat.new(game)
    local function update() api.update(item,player); return eid.permanentDisplayTextObj end
    return api,eid,item,player,update,game
end

test("optional dependency and late loading", function()
    local api,eid,item,player=fixture()
    EID=nil; api.update(item,player); api.reset()
    EID={}; api.update(item,player)
    EID=eid; api.update(item,player)
    assert(eid.permanentDisplayTextObj.Entity==item)
end)
test("hover overrides nearby description and exit refreshes normal selection", function()
    local api,eid,item,_,update=fixture()
    eid.lastDescriptionEntity={}
    assert(update().Entity==item and eid.lastDescriptionEntity==item)
    api.update(nil)
    assert(not eid.isDisplayingPermanent and eid.permanentDisplayTextObj==nil)
    assert(eid.ForceRefreshCache and eid.lastDescriptionEntity==nil)
end)
test("switching targets and cycling subtype rebuild the current description", function()
    local api,eid,item,player,update=fixture()
    assert(update().ObjSubType==1)
    item.SubType=2; assert(update().ObjSubType==2)
    local other={Type=5,Variant=350,SubType=7,Visible=true,Exists=item.Exists,IsDead=item.IsDead}
    api.update(other,player)
    assert(eid.permanentDisplayTextObj.Entity==other and eid.permanentDisplayTextObj.ObjSubType==7)
    assert(eid.clears==3 and #eid.CachedIndicators==0)
end)
test("invalid, hidden and undescribed entities release the overlay", function()
    for _,field in ipairs({"removed","dead","noDescription"}) do
        local _,eid,item,_,update=fixture()
        update(); item[field]=true; update(); assert(not eid.isDisplayingPermanent)
    end
    local _,eid,item,_,update=fixture()
    update(); item.Visible=false; update(); assert(not eid.isDisplayingPermanent)
end)
test("blind collectibles never request an identifying description", function()
    local _,eid,item,_,update=fixture()
    item.hidden=true
    local desc=update(); assert(desc.Icon=="?" and not desc.Name and eid.builds==0)
    eid.Config.HideUncollectedItemDescriptions=true
    assert(update().Description=="localized:CollectionPageInfo")
end)
test("unidentified normal and horse pills use localized unknown text", function()
    local _,eid,item,_,update=fixture(70)
    for _,color in ipairs({1,2049}) do
        item.SubType=color
        local desc=update()
        assert(desc.Description=="localized:unidentifiedPill" and not desc.Name and eid.builds==0)
    end
    eid.identified=true; assert(update().ObjSubType==2049)
end)
test("shop, options and obstruction rules cover pills, cards and soulstones", function()
    for _,case in ipairs({{70,1,"Pill","Pill"},{300,1,"Card","Card"},{300,81,"Soulstone","Card"}}) do
        local _,eid,item,player,update=fixture(case[1])
        item.SubType=case[2]; eid.identified=true
        item.shop=true; eid.Config["Display"..case[3].."InfoShop"]=false
        assert(update().Icon=="?" and eid.builds==0)
        item.shop=false; item.OptionsPickupIndex=1; eid.Config["Display"..case[4].."InfoOptions?"]=false
        assert(update().Icon=="?" and eid.builds==0)
        item.OptionsPickupIndex=0; eid.Config["DisplayObstructed"..case[3].."Info"]=false
        assert(update().Icon=="?" and eid.builds==0)
        player.CanFly=true; eid.Config.DisableObstructionOnFlight=true
        assert(update().ObjSubType==case[2])
        player.CanFly=false; eid.path=true; assert(update().ObjSubType==case[2])
        eid.path=false; item.EID_DontHide=true; assert(update().ObjSubType==case[2])
    end
end)
test("entity descriptions and Cantripped cards retain their content", function()
    local _,_,item,_,update,game=fixture(300)
    item.EID_Description="custom"; assert(update().Description=="custom")
    item.EID_Description={Name="custom name",Description="custom effect"}
    assert(update().Name=="custom name")
    item.EID_Description=nil; game.Challenge=43; item.SubType=32769
    local desc=update(); assert(desc.ObjVariant==100 and desc.ObjSubType==1)
end)
test("foreign permanent text is neither overwritten nor cleared", function()
    local api,eid,_,_,update=fixture()
    local foreign={Description="other mod"}
    eid:displayPermanentText(foreign); update(); api.reset()
    assert(eid.permanentDisplayTextObj==foreign)
    eid:hidePermanentText(); update()
    eid:displayPermanentText(foreign); update(); api.reset()
    assert(eid.permanentDisplayTextObj==foreign and eid.isDisplayingPermanent)
end)
test("EID replacement and repeated reset do not leave owned text behind", function()
    local api,eid,item,player,update=fixture()
    update(); EID=nil; api.update(item,player); api.reset(); api.reset()
    assert(not eid.isDisplayingPermanent)
end)
EID=nil
print(count.." EID tests passed")
if eidSource then print("PASS installed EID overlay API used for all EID tests") end
