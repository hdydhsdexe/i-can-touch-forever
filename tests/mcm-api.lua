-- Optional contract check using external MCM sources and the game's JSON codec.
-- Usage: lua tests/mcm-api.lua json.lua chinese-modconfig.lua pure-modconfig.lua
if not arg[1] or not arg[2] or not arg[3] then
    print('SKIP actual MCM API/JSON contract: supply JSON, Chinese and Pure source paths')
    return
end
local json=dofile(arg[1])
local Config=dofile('mouse_pickup/mpickup/config.lua')
local Menu=dofile('mouse_pickup/mpickup/mcm.lua')
local saved,writes,logs=nil,0,0
Isaac={DebugString=function() logs=logs+1 end}
local mod={HasData=function() return saved~=nil end,LoadData=function() return saved end,
    SaveData=function(_,text) saved=text; writes=writes+1 end}
local config=Config.new(mod,json); config.load()
config.set('enabled',false); config.set('pickupButton',4); config.set('language','zh')
assert(saved:find('"version"',1,true) and saved:find('"settings"',1,true))
local decoded=json.decode(saved)
assert(decoded.version==1 and not decoded.settings.enabled and decoded.settings.pickupButton==4)
local restarted=Config.new(mod,json); restarted.load()
assert(not restarted.get('enabled') and restarted.get('pickupButton')==4 and restarted.get('language')=='zh')
saved='{broken'; restarted.load(); assert(restarted.get('enabled') and logs==1)
print('PASS actual game JSON codec: config encoding, false values, restart, corrupt-save fallback')

local function read(path)
    local file=assert(io.open(path,'rb')); local text=file:read('*a'); file:close(); return text
end
for index=2,3 do
    local source=read(arg[index])
    local chinese=index==2
    ModConfigMenu={OptionType={BOOLEAN=4,NUMBER=5}, MenuData={}}
    local start=assert(source:find('function ModConfigMenu.GetCategoryIDByName(',1,true))
    local finish=assert(source:find('function ModConfigMenu.AddText(',start,true))
    -- Run the real category/subcategory/AddSetting functions, without engine startup or rendering.
    assert(load(source:sub(start,finish-1),'@MCM registration API'))()
    if chinese then
        ModConfigMenu.i18n='Chinese'
        start=assert(source:find('function ModConfigMenu.SetCategoryNameTranslate(',1,true))
        finish=assert(source:find('function ModConfigMenu.SetSubcategoryNameTranslate(',start,true))
        assert(load(source:sub(start,finish-1),'@MCM Chinese translation API'))()
    end
    local mcm=ModConfigMenu
    -- Upgrade in a running Lua session must replace the old category.
    mcm.AddSetting('Mouse Pickup', nil, {Type=4})
    local adapter=Menu.new(config); adapter.update(); adapter.update()
    assert(#mcm.MenuData==1 and mcm.MenuData[1].Name=='I can touch forever!')
    local sub=mcm.MenuData[1].Subcategories
    assert(#sub==1 and #sub[1].Options==8)
    local options=sub[1].Options
    for _,setting in ipairs(options) do
        assert(type(setting.Display())=='string' and type(setting.Info())=='table')
        assert(type(setting.CurrentSetting())==(setting.Type==4 and 'boolean' or 'number'))
    end
    options[1].OnChange(true); assert(config.get('enabled') and json.decode(saved).settings.enabled)
    local before=writes
    options[2].OnChange(2)
    assert(options[2].CurrentSetting()==2 and options[3].CurrentSetting()==4 and writes==before+1)
    if chinese then
        assert(mcm.MenuData[1].NameTranslate=='I can touch forever!')
        options[8].OnChange(3); adapter.update()
        assert(mcm.MenuData[1].NameTranslate=='I can touch forever!' and options[1].Display()=='Enable Mouse Pickup: On')
        options[8].OnChange(2); adapter.update(); assert(mcm.MenuData[1].NameTranslate=='I can touch forever!')
    else
        assert(options[1].Display()=='Enable Mouse Pickup: On')
        assert(options[8].Minimum==3 and options[8].Maximum==3 and options[8].CurrentSetting()==3)
    end
    local reload=Menu.new(config); reload.update()
    assert(#mcm.MenuData==1 and #mcm.MenuData[1].Subcategories[1].Options==8)
    reload.remove(); assert(#mcm.MenuData==0)
    config.set('pickupButton',4)
    print('PASS actual '..(chinese and 'Chinese v10034' or 'Pure')..' registration API: 8 rows, values, saves, swap, language, reload, removal')
end
ModConfigMenu=nil
print('3 actual JSON/MCM API contract scenarios passed (NOT native engine or rendered UI)')
