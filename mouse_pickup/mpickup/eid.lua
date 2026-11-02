local M = {}

local function question(eid, item, text)
    return {Entity=item, Icon=eid.InlineIcons.QuestionMark, Description=text or ""}
end

local function describe(eid, item, player, game)
    local config = eid.Config
    if item.Variant == 100 and eid:IsItemHidden(item) then
        local text = config.HideUncollectedItemDescriptions and eid:requiredForCollectionPage(item.SubType)
            and eid:getDescriptionEntry("CollectionPageInfo") or nil
        return question(eid, item, text)
    end
    if item.Variant == 70 or item.Variant == 300 then
        if eid:getEntityData(item, "EID_DontHide") ~= true then
            local kind = item.Variant == 70 and "Pill" or "Card"
            local soulstone = kind == "Card" and item.SubType >= 81 and item.SubType <= 97
            local shopKind = soulstone and "Soulstone" or kind
            local hidden = item:IsShopItem() and not config["Display"..shopKind.."InfoShop"]
                or eid.isRepentance and item.OptionsPickupIndex > 0 and not config["Display"..kind.."InfoOptions?"]
            if not hidden and not config["DisplayObstructed"..shopKind.."Info"]
                and not (config.DisableObstructionOnFlight and player.CanFly) then
                hidden = not eid:HasPathToPosition(player.Position, item.Position)
            end
            if hidden then return question(eid, item) end
        end
        if item.Variant == 70 and not eid:ShouldShowPillAsIdentified(item.SubType) then
            -- Permanent text uses printDescription directly, so do not use the
            -- "UnidentifiedPill" sentinel handled only by EID's normal queue.
            return question(eid, item, eid:getDescriptionEntry("unidentifiedPill"))
        end
    end
    local desc = eid:getDescriptionObjByEntity(item)
    local custom = config.EnableEntityDescriptions and eid:getEntityData(item, "EID_Description")
    if custom then
        if type(custom) == "table" then desc = eid:mergeDescriptionObjects(desc, custom)
        else desc.Description = custom end
    elseif item.Variant == 300 and game.Challenge == 43 and item.SubType > 32768 then
        desc = eid:getDescriptionObj(5, 100, item.SubType-32768, item)
    end
    return desc
end

function M.new(game)
    local owner, owned
    local api = {}

    function api.reset()
        -- Another mod or EID itself may have replaced the permanent text.
        if owner and owner.permanentDisplayTextObj == owned then
            if owner == _G.EID then owner:hidePermanentText()
            else
                -- EID's API refers to the global EID, even when called on self.
                owner.permanentDisplayTextObj, owner.isDisplayingPermanent = nil, false
            end
            if owner.lastDescriptionEntity == owned.Entity then owner.lastDescriptionEntity = nil end
            owner.ForceRefreshCache = true
        end
        owner, owned = nil, nil
    end

    function api.update(item, player)
        local eid = _G.EID
        if owner and (owner ~= eid or owner.permanentDisplayTextObj ~= owned) then api.reset() end
        if not item or not eid or type(eid.displayPermanentText) ~= "function"
            or type(eid.hasDescription) ~= "function" or type(eid.getDescriptionObjByEntity) ~= "function"
            or not item:Exists() or item:IsDead() or not item.Visible or not eid:hasDescription(item) then
            api.reset()
            return
        end
        -- Leave unrelated permanent overlays (including EID warnings) alone.
        if eid.isDisplayingPermanent and eid.permanentDisplayTextObj ~= owned then return end
        local desc = describe(eid, item, player, game)
        if not desc then api.reset(); return end
        -- EID appends render cache entries even for permanent descriptions.
        eid:ResetDescCache()
        eid.CachedIndicators = {}
        owner, owned = eid, desc
        eid.lastDescriptionEntity = item
        eid:displayPermanentText(desc)
    end

    return api
end

return M
