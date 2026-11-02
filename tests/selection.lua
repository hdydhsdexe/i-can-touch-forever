local mt = {}
local function vec(x,y) return setmetatable({X=x,Y=y},mt) end
mt.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y) end
Vector=vec
local mirror,width,scroll=false,640,0
Game=function() return {GetRoom=function() return {IsMirrorWorld=function() return mirror end} end} end
Isaac={WorldToScreen=function(p) return vec(p.X+scroll,p.Y) end,GetScreenWidth=function() return width end}
local selection=dofile('mouse_pickup/mpickup/selection.lua')
local sprite={Offset=vec(3,0),IsPlaying=function() return false end}
local item={Variant=20,SubType=1,Position=vec(100,200),PositionOffset=vec(5,0),
    SpriteOffset=vec(2,0),SpriteScale=vec(1,1),Size=10,Visible=true,Index=1,SortingLayer=0,DepthOffset=0,
    Exists=function() return true end,IsDead=function() return false end,GetSprite=function() return sprite end,
    ToPickup=function(self) return self end}
assert(selection.bounds(item).x==110)
mirror=true
assert(selection.bounds(item).x==530,'mirror bounds must follow the visible pickup')
assert(selection.choose({item},vec(530,191),selection.bounds)==item)
assert(not selection.choose({item},vec(110,191),selection.bounds),'unmirrored location must not select the pickup')
width=800; scroll=-30
assert(selection.bounds(item).x==720,'viewport resize and camera scroll must be reflected once')
mirror=false
assert(selection.bounds(item).x==80,'leaving mirror world restores ordinary projection')
assert(item.Position.X==100 and item.PositionOffset.X==5,'projection must not mutate world coordinates')
print('PASS selection: mirror bounds, hit testing, sprite offsets, resize, scroll and exit')
