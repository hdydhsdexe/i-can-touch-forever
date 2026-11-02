local rules=dofile('mouse_pickup/mpickup/rules.lua')
local Actors=dofile('mouse_pickup/mpickup/actors.lua')
GetPtrHash=function(p) return p.id end
EntityFlag={FLAG_HELD=1<<57,FLAG_THROWN=1<<58,FLAG_NO_KNOCKBACK=1<<26,FLAG_NO_PHYSICS_KNOCKBACK=1<<30}
local count=0
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function player(id,kind)
    local p={id=id,kind=kind,ControllerIndex=0,alive=true,EntityCollisionClass=4,
        GridCollisionClass=5,Visible=true,PositionOffset={X=0,Y=0},Velocity={X=0,Y=0},flags=0}
    function p:GetPlayerType() return self.kind end
    function p:GetOtherTwin() return self.twin end
    function p:GetSubPlayer() return self.sub end
    function p:IsCoopGhost() return self.ghost end
    function p:Exists() return self.alive end
    function p:IsDead() return self.dead end
    function p:HasCollectible(id) return (id == 619 and self.birthright) or (self.items and (self.items[id] or 0)>0) end
    function p:GetCollectibleNum(id) return self.items and self.items[id] or 0 end
    function p:GetEffects() return {HasNullEffect=function(_,id) return self.effects and self.effects[id] end} end
    function p:GetMainTwin() return self.main or self end
    function p:HasEntityFlags(flags) return self.flags & flags ~= 0 end
    function p:GetEntityFlags() return self.flags end
    return p
end
local list
Isaac={GetPlayer=function(i) return list[i+1] end}
local game={GetNumPlayers=function() return #list end}
local function fixture()
    local j,e=player(1,19),player(2,20)
    j.twin,e.twin=e,j; list={j,e}
    return Actors.new(rules),j,e
end
test('single character remains available without a switch label',function()
    local a=fixture(); list={player(3,0)}
    local c=a.resolve(game); assert(c.player==list[1] and not c.members[2] and not c.label)
    a.switch(); assert(a.resolve(game).revision==c.revision)
end)
test('Tainted Forgotten separates controller and recipient and rejects all airborne states',function()
    local a,b,s=fixture(); b.kind=35; s.kind=40; list={s,b}
    local c=a.resolve(game)
    assert(c.player==b and c.control==s and c.members[2]==s and c.available and not c.switchable)
    assert(c.color[1]==0.65)
    a.switch(); assert(a.resolve(game).revision==c.revision)
    for _,flag in pairs(EntityFlag) do
        b.flags=flag; local blocked=a.resolve(game)
        assert(not blocked.available and blocked.revision~=c.revision)
        b.flags=0; c=a.resolve(game); assert(c.available)
    end
    b.Visible=false; assert(not a.resolve(game).available); b.Visible=true
    b.Velocity.X=0.1; assert(not a.resolve(game).available); b.Velocity.X=0
    b.PositionOffset.Y=-1; assert(not a.resolve(game).available); b.PositionOffset.Y=0
    b.EntityCollisionClass=0; assert(not a.resolve(game).available); b.EntityCollisionClass=4
    b.GridCollisionClass=3; assert(not a.resolve(game).available)
    b.CanFly=true; assert(a.resolve(game).available)
    a.recall(s); assert(not a.resolve(game).available)
    b.flags=EntityFlag.FLAG_HELD; assert(not a.resolve(game).available)
    b.flags=0; assert(a.resolve(game).available)
    a.recall(b); a.newRoom(); assert(a.resolve(game).available)
    a.recall(b); b.kind=37; b.twin=nil; list={b}
    assert(a.resolve(game).available, 'a form change cannot retain a stale Recall lock')
end)
test('Birthright Lazarus follows native main identity, not enumeration or character type',function()
    local a,live,dead=fixture(); live.kind=29; dead.kind=38; live.birthright=true
    live.main=live; dead.main=live; dead.EntityCollisionClass=0
    list={dead,live}; local c=a.resolve(game)
    assert(c.player==live and c.members[2]==dead and c.available and not c.switchable)
    a.switch(); assert(a.resolve(game).revision==c.revision)
    live.main=dead; dead.main=dead; dead.EntityCollisionClass=4; live.EntityCollisionClass=0
    local next=a.resolve(game)
    assert(next.player==dead and next.available and next.revision~=c.revision)
    assert(next.color[1]==1 and next.color[2]==1 and next.color[3]==1)
    live.EntityCollisionClass=4; assert(not a.resolve(game).available)
    live.main=live; assert(not a.resolve(game))
end)
test('twins default to Jacob regardless of enumeration and switch both ways',function()
    local a,j,e=fixture(); list={e,j}
    local c=a.resolve(game); assert(c.player==j and c.members[2]==e and c.label=='JACOB')
    a.switch(); local next=a.resolve(game)
    assert(next.player==e and next.members[1]==j and next.label=='ESAU' and next.revision~=c.revision)
    list={j,e}; assert(a.resolve(game).revision==next.revision)
    a.switch(); assert(a.resolve(game).player==j)
end)
test('same controller never merges unrelated players or a third player',function()
    local a,j,e=fixture(); list={j,e,player(3,0)}; assert(not a.resolve(game))
    list={player(4,0),player(5,0)}; assert(not a.resolve(game))
end)
test('pair must be reciprocal, present, alive and on the same controller',function()
    local a,j,e=fixture()
    e.twin=nil; assert(not a.resolve(game)); e.twin=j
    e.ControllerIndex=1; assert(not a.resolve(game)); e.ControllerIndex=0
    e.ghost=true; assert(not a.resolve(game)); e.ghost=false
    e.dead=true; assert(not a.resolve(game)); e.dead=false
    e.alive=false; assert(not a.resolve(game)); e.alive=true
    j.sub=player(7,17); assert(not a.resolve(game)); j.sub=nil
    list={j}; assert(not a.resolve(game))
    list={j,player(8,20)}; assert(not a.resolve(game))
end)
test('unrelated special pairs and incomplete Forgotten remain disabled',function()
    local a,j,e=fixture()
    for _,types in ipairs({{29,38},{16,17},{37,39}}) do
        j.kind,e.kind=types[1],types[2]; assert(not a.resolve(game))
    end
    list={j}; j.kind=16; assert(not a.resolve(game))
end)
test('Forgotten follows the enumerated active form and never switches via middle',function()
    local a=fixture()
    local body,soul=player(10,16),player(11,17)
    body.sub=soul; soul.alive=false; list={body}
    local c=a.resolve(game)
    assert(c.player==body and c.control==body and c.members[2]==soul and not c.switchable)
    assert(c.color[1]==0.65 and c.color[2]==0.65 and c.color[3]==0.65)
    a.switch(); assert(a.resolve(game).revision==c.revision)
    body.sub=nil; soul.sub=body; soul.alive=true; body.alive=false; list={soul}
    local next=a.resolve(game)
    assert(next.player==soul and next.control==soul and next.revision~=c.revision)
    assert(next.color[1]==0.3 and next.color[2]==0.65 and next.color[3]==1)
    soul.sub=nil; assert(not a.resolve(game))
end)
test('single Tainted Lazarus and both Jacob states remain white and invalidate on form change',function()
    local a=fixture(); local p=player(20,29); list={p}
    local old=a.resolve(game)
    for _,kind in ipairs({38,37,39}) do
        p.kind=kind
        local c=a.resolve(game)
        assert(c.player==p and c.available and not c.switchable and c.revision~=old.revision)
        assert(c.color[1]==1 and c.color[2]==1 and c.color[3]==1)
        old=c
    end
end)
test('child entities cannot impersonate a single character or a supported pair',function()
    local a,j,e=fixture(); e.Parent=j; assert(not a.resolve(game))
    list={player(30,0)}; list[1].Parent=j; assert(not a.resolve(game))
end)
test('selection persists across resolves but identity or type changes invalidate requests',function()
    local a,j,e=fixture(); a.resolve(game); a.switch()
    local old=a.resolve(game)
    assert(a.resolve(game).player==e and a.resolve(game).revision==old.revision)
    e.id=20; local changed=a.resolve(game)
    assert(changed.player==j and changed.revision~=old.revision)
    list={j}; j.twin=nil; j.kind=0
    local single=a.resolve(game); assert(single.player==j and single.revision~=changed.revision)
    j.kind=1; assert(a.resolve(game).revision~=single.revision)
end)
test('invalid group and game reset clear selection without reusing a revision',function()
    local a,j,e=fixture(); a.resolve(game); a.switch(); local old=a.resolve(game)
    list={j,e,player(3,0)}; assert(not a.resolve(game))
    list={j,e}; local c=a.resolve(game); assert(c.player==j and c.revision~=old.revision)
    a.switch(); old=a.resolve(game); a.reset()
    c=a.resolve(game); assert(c.player==j and c.revision~=old.revision)
end)
test('native child effects require parent, role and effect marker and ignore enumeration order',function()
    for _,case in ipairs({{14,667,nil,1,0.8,0.25},{20,nil,121,1,0,0},{16,nil,120,0.65,0.65,0.65}}) do
        local a=Actors.new(rules); local p,child=player(50,0),player(51,case[1])
        child.Parent=p; p.items={[case[2] or 0]=1}; child.effects={[case[3] or 0]=true}; list={child,p}
        local c=a.resolve(game); assert(c.player==p and #c.members==2 and c.switchable)
        a.switch(); c=a.resolve(game); assert(c.player==child and c.control==child)
        assert(c.color[1]==case[4] and c.color[2]==case[5] and c.color[3]==case[6])
        list={p,child}; a.newRoom(); assert(a.resolve(game).revision==c.revision)
        child.dead=true; c=a.resolve(game); assert(c.player==p and not c.switchable)
        child.dead=false; assert(a.resolve(game).player==p)
        a.switch(); child.InitSeed=123; assert(a.resolve(game).player==p)
        if case[3] then child.effects={}; assert(not a.resolve(game)) end
    end
end)
test('extra effects, repeated summons, wrong parent and special bases remain disabled',function()
    local a=Actors.new(rules); local p,c=player(60,0),player(61,14); p.items={[667]=1}; c.Parent=p; list={p,c}
    assert(a.resolve(game)); p.items[667]=2; assert(not a.resolve(game)); p.items[667]=1
    p.items[703]=1; assert(not a.resolve(game)); p.items[703]=nil
    for _,kind in ipairs({16,17,19,20,35,37,39,40,41}) do p.kind=kind; assert(not a.resolve(game)) end
    p.kind=0; c.Parent=player(62,0); assert(not a.resolve(game)); c.Parent=p
    list={p,c,player(63,14)}; assert(not a.resolve(game))
end)
test('Strawman removal and death return to main; restart and continue rebuild selection',function()
    local a=Actors.new(rules); local p,c=player(70,0),player(71,14); p.items={[667]=1}; c.Parent=p; list={p,c}
    a.resolve(game); a.switch(); assert(a.resolve(game).player==c)
    list={p}; local single=a.resolve(game); assert(single.player==p and not single.switchable)
    list={p,c}; a.resolve(game); a.switch(); a.reset(); assert(a.resolve(game).player==p)
    p.items={}; assert(not a.resolve(game)); list={p}; assert(a.resolve(game).player==p)
end)
test('Esau Jr follows null effect and never exposes a middle selection',function()
    local a=Actors.new(rules); local p=player(80,0); p.items={[703]=1}; list={p}
    local c=a.resolve(game); assert(c.color[2]==1 and not c.switchable)
    a.switch(); assert(a.resolve(game).revision==c.revision)
    local alternate=player(81,0); alternate.effects={[100]=true}; list={alternate}
    c=a.resolve(game); assert(c.player==alternate and c.color[2]==0 and #c.candidates==1)
    alternate.items={[667]=1}; assert(not a.resolve(game))
end)
test('stacked twins use Jacob Esau Strawman order for either owner and any enumeration',function()
    for _,esauOwner in ipairs({false,true}) do
        local a,j,e=fixture(); local child=player(90,14)
        local owner=esauOwner and e or j; owner.items={[667]=1}; child.Parent=owner
        list={child,e,j}; local c=a.resolve(game)
        assert(c.player==j and #c.members==3 and #c.candidates==3 and c.owner==owner)
        a.switch(); c=a.resolve(game); assert(c.player==e and c.color[2]==0)
        a.switch(); c=a.resolve(game); assert(c.player==child and c.color[2]==0.8 and c.color[3]==0.25)
        list={e,child,j}; a.newRoom(); assert(a.resolve(game).revision==c.revision)
        a.switch(); assert(a.resolve(game).player==j)
        a.switch(); child.dead=true; c=a.resolve(game); assert(c.player==j and #c.candidates==2 and #c.members==3)
        child.dead=false; a.resolve(game); a.switch(); a.switch(); child.InitSeed=20
        assert(a.resolve(game).player==j)
    end
end)

test('stacked Forgotten protects the hidden form and resets selected Strawman on native form change',function()
    local a=Actors.new(rules); local p,sub,child=player(91,16),player(92,17),player(93,14)
    p.sub=sub; p.items={[667]=1}; child.Parent=p; list={child,p}
    local c=a.resolve(game); assert(c.player==p and #c.members==3 and #c.candidates==2 and c.color[1]==0.65)
    a.switch(); c=a.resolve(game); assert(c.player==child)
    p.kind=17; sub.kind=16
    local next=a.resolve(game); assert(next.player==p and next.color[1]==0.3 and next.revision~=c.revision)
    a.switch(); assert(a.resolve(game).player==child)
    sub.items={[667]=1}; assert(not a.resolve(game)); sub.items=nil
    p.sub=nil; assert(not a.resolve(game))
end)

test('stacked Lazarus tracks foreground disappearance and rejects Birthright and further effects',function()
    local a=Actors.new(rules); local live,dead,child=player(94,29),player(95,38),player(96,14)
    live.items={[667]=1}; child.Parent=live; list={child,live}
    assert(a.resolve(game).player==live); a.switch(); local old=a.resolve(game)
    list={dead}; local c=a.resolve(game); assert(c.player==dead and c.revision~=old.revision and not c.switchable)
    list={child,live}; c=a.resolve(game); assert(c.player==live)
    live.birthright=true; assert(not a.resolve(game)); live.birthright=false
    live.items[703]=1; assert(not a.resolve(game)); live.items[703]=nil
    child.effects={[121]=true}; assert(not a.resolve(game)); child.effects=nil
    live.items[667]=2; assert(not a.resolve(game))
end)

test('stacked ownership changes invalidate selection and unproven members never join',function()
    local a,j,e=fixture(); local child=player(97,14); j.items={[667]=1}; child.Parent=j; list={j,e,child}
    a.resolve(game); a.switch(); local old=a.resolve(game)
    j.items=nil; e.items={[667]=1}; child.Parent=e
    local c=a.resolve(game); assert(c.player==j and c.revision~=old.revision)
    child.Parent=j; assert(not a.resolve(game)); child.Parent=e
    child.items={[667]=1}; assert(not a.resolve(game)); child.items=nil
    child.ControllerIndex=1; assert(not a.resolve(game)); child.ControllerIndex=0
    list={j,e,child,player(98,0)}; assert(not a.resolve(game))
    list={j,e}; a.resolve(game); a.switch(); assert(a.resolve(game).player==e)
    a.reset(); assert(a.resolve(game).player==j)
end)
test('stacked soul Forgotten orders both twins and resolves generic Parent wrappers to players',function()
    for _,esauOwner in ipairs({false,true}) do
        local a,j,e=fixture(); local child=player(100,16)
        local owner=esauOwner and e or j
        child.Parent={id=owner.id}; child.effects={[120]=true}; list={child,e,j}
        local c=a.resolve(game); assert(c.owner==owner and c.effect=='stack-soul-forgotten' and #c.members==3)
        a.switch(); assert(a.resolve(game).player==e)
        a.switch(); c=a.resolve(game); assert(c.player==child and c.color[1]==0.65)
        list={e,j,child}; a.newRoom(); assert(a.resolve(game).revision==c.revision)
        a.switch(); assert(a.resolve(game).player==j)
        child.Parent={id=(esauOwner and j or e).id}
        local changed=a.resolve(game); assert(changed.player==j and changed.owner~=owner and changed.revision~=c.revision)
    end
end)

test('Forgotten soul Jacob protects the inactive form and native switch resets the selection',function()
    local a=Actors.new(rules); local p,sub,child=player(101,16),player(102,17),player(103,20)
    p.sub=sub; child.Parent={id=p.id}; child.effects={[121]=true}; list={child,p}
    local c=a.resolve(game); assert(#c.members==3 and #c.candidates==2 and c.color[1]==0.65)
    a.switch(); c=a.resolve(game); assert(c.player==child and c.color[2]==0)
    p.kind=17; sub.kind=16
    local next=a.resolve(game); assert(next.player==p and next.color[1]==0.3 and next.revision~=c.revision)
    p.birthright=true; assert(a.resolve(game).player==p)
    child.Parent=sub; assert(not a.resolve(game))
end)

test('both Lazarus soul effects follow the transferred native Parent and reject Birthright',function()
    for _,kind in ipairs({16,20}) do
        local a=Actors.new(rules); local live,dead,child=player(104,29),player(105,38),player(106,kind)
        child.Parent={id=live.id}; child.effects={[kind==16 and 120 or 121]=true}; list={child,live}
        a.resolve(game); a.switch(); local old=a.resolve(game)
        list={dead,child}; assert(not a.resolve(game), 'stale Parent is not a foreground relationship')
        child.Parent={id=dead.id}; local c=a.resolve(game)
        assert(c.player==dead and c.owner==dead and c.revision~=old.revision and c.color[2]==1)
        a.switch(); old=a.resolve(game); list={child,live}; child.Parent=live
        assert(a.resolve(game).player==live and a.resolve(game).revision~=old.revision)
        live.birthright=true; assert(not a.resolve(game))
    end
end)

test('soul stack death expiry replacement and resets never preserve a child selection',function()
    for _,change in ipairs({'death','expiry','seed','reset'}) do
        local a,j,e=fixture(); local child=player(107,16); child.Parent=j; child.effects={[120]=true}; list={j,e,child}
        a.resolve(game); a.switch(); a.switch(); local old=a.resolve(game)
        if change=='death' then child.dead=true elseif change=='expiry' then list={e,j}
        elseif change=='seed' then child.InitSeed=777 else a.reset() end
        local c=a.resolve(game); assert(c.player==j and c.revision~=old.revision)
        if change=='death' then assert(#c.members==3 and #c.candidates==2) end
    end
end)

test('unverified soul stacks reject markers ownership extra effects and conflicting roles',function()
    local a,j,e=fixture(); local child=player(108,16); child.Parent=j; child.effects={[120]=true}; list={j,e,child}
    assert(a.resolve(game))
    for _,effects in ipairs({{}, {[121]=true}, {[120]=true,[121]=true}, {[120]=true,[100]=true}}) do
        child.effects=effects; assert(not a.resolve(game))
    end
    child.effects={[120]=true}; child.Parent=nil; assert(not a.resolve(game)); child.Parent=j
    child.ControllerIndex=1; assert(not a.resolve(game)); child.ControllerIndex=0
    j.items={[667]=1}; assert(not a.resolve(game)); j.items={[703]=1}; assert(not a.resolve(game)); j.items=nil
    list={child,j,e,player(109,0)}; assert(not a.resolve(game)); list={j,e,child}
    child.kind=20; child.effects={[121]=true}; child.twin=j; assert(not a.resolve(game)); child.twin=nil
    j.kind=16; j.twin=nil; j.sub=player(110,17); child.kind=16; child.effects={[120]=true}; list={j,child}
    child.sub=j; assert(not a.resolve(game))
end)
test('same-role twins keep original Esau before marked soul Esau for either owner',function()
    for _,esauOwner in ipairs({false,true}) do
        local a,j,e=fixture(); local soul=player(120,20)
        soul.Parent={id=(esauOwner and e or j).id}; soul.effects={[121]=true}; list={soul,e,j}
        local c=a.resolve(game); assert(c.player==j and not c.diamond and #c.members==3)
        a.switch(); c=a.resolve(game); assert(c.player==e and not c.diamond and c.color[2]==0)
        a.switch(); c=a.resolve(game); assert(c.player==soul and c.diamond and c.color[2]==0)
        list={e,soul,j}; a.newRoom(); assert(a.resolve(game).revision==c.revision and a.resolve(game).diamond)
        a.switch(); assert(a.resolve(game).player==j and not a.resolve(game).diamond)
    end
end)

test('same-role Forgotten selects only the summoned body and follows original native forms',function()
    for _,birthright in ipairs({false,true}) do
        local a=Actors.new(rules); local p,sub,soul=player(121,16),player(122,17),player(123,16)
        p.sub=sub; p.birthright=birthright; sub.alive=false
        soul.Parent={id=p.id}; soul.effects={[120]=true}; list={soul,p}
        local c=a.resolve(game); assert(#c.members==3 and #c.candidates==2 and not c.diamond)
        a.switch(); c=a.resolve(game); assert(c.player==soul and c.diamond and c.color[1]==0.65)
        p.kind,sub.kind=17,16; local next=a.resolve(game)
        assert(next.player==p and not next.diamond and next.color[1]==0.3 and next.revision~=c.revision)
        a.switch(); assert(a.resolve(game).player==soul and a.resolve(game).diamond)
        soul.sub=player(124,17); assert(not a.resolve(game), 'unprobed temporary soul is not exposed')
    end
end)

test('same-role identity and ownership changes invalidate marked choices',function()
    for _,change in ipairs({'seed','replace','parent','death','expiry','reset'}) do
        local a,j,e=fixture(); local soul=player(125,20); soul.Parent=j; soul.effects={[121]=true}; list={j,e,soul}
        a.resolve(game); a.switch(); a.switch(); local old=a.resolve(game)
        if change=='seed' then soul.InitSeed=9 elseif change=='replace' then soul.id=126
        elseif change=='parent' then soul.Parent=e elseif change=='death' then soul.dead=true
        elseif change=='expiry' then list={e,j} else a.reset() end
        local c=a.resolve(game); assert(c.player==j and not c.diamond and c.revision~=old.revision)
    end
end)

test('same-role groups reject rewired native relationships repeated summons and misleading types',function()
    local a,j,e=fixture(); local soul=player(127,20); soul.Parent=j; soul.effects={[121]=true}; list={j,e,soul}
    assert(a.resolve(game)); e.twin=soul; assert(not a.resolve(game)); e.twin=j
    soul.Parent=nil; assert(not a.resolve(game)); soul.Parent=player(128,19); assert(not a.resolve(game)); soul.Parent=j
    soul.effects={}; assert(not a.resolve(game)); soul.effects={[121]=true}
    e.effects={[121]=true}; assert(not a.resolve(game)); e.effects=nil
    local extra=player(129,20); extra.Parent=j; extra.effects={[121]=true}; list={j,e,soul,extra}; assert(not a.resolve(game))
    list={j,e,soul}; j.items={[667]=1}; assert(not a.resolve(game)); j.items={[703]=1}; assert(not a.resolve(game))
end)

test('previous soul combinations keep their plain cursor appearance',function()
    local a,j,e=fixture(); local soul=player(130,16); soul.Parent=j; soul.effects={[120]=true}; list={j,e,soul}
    a.resolve(game); a.switch(); a.switch(); assert(not a.resolve(game).diamond)
    j.kind=16; j.twin=nil; j.sub=player(131,17); soul.kind=20; soul.effects={[121]=true}; list={soul,j}
    a.resolve(game); a.switch(); assert(not a.resolve(game).diamond)
end)
print(count..' actor tests passed (simulated)')
