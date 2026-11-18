local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local C=require(game.ReplicatedStorage.SkySproutConfig)
local Rules=require(script.Parent.SkySproutRules)
local P={Sessions={}}
local store
local token=game.JobId
local LEASE=180
if not RunService:IsStudio() then store=game:GetService("DataStoreService"):GetDataStore(C.SaveName) end
function P.load(player)
    if not store then
        local s={Data=Rules.new(),Memory=true,LastSave=os.clock(),Busy=false,LeaseUntil=math.huge}
        P.Sessions[player]=s; return s
    end
    local record
    for attempt=1,4 do
        local ok,result=pcall(function()
            return store:UpdateAsync("u_"..player.UserId,function(old)
                if old and old.Lease and old.Lease.Token~=token and (old.Lease.Until or 0)>os.time() then return nil end
                return {Data=Rules.clean(old and old.Data),Lease={Token=token,Until=os.time()+LEASE}}
            end)
        end)
        if ok and result then record=result; break end
        task.wait(attempt*2)
    end
    if not record then return nil end
    local s={Data=Rules.clean(record.Data),LastSave=os.clock(),Busy=false,LeaseUntil=record.Lease.Until}
    P.Sessions[player]=s
    return s
end
function P.save(player,release)
    local s=P.Sessions[player]
    if not s then return false end
    if s.Memory then if release then P.Sessions[player]=nil end; return true end
    local deadline=os.clock()+12
    while s.Busy and os.clock()<deadline do task.wait(.1) end
    if s.Busy then return false end
    s.Busy=true
    local snapshot=Rules.clean(s.Data)
    local saved=false
    for attempt=1,3 do
        local ok,result=pcall(function()
            return store:UpdateAsync("u_"..player.UserId,function(old)
                if not old or not old.Lease or old.Lease.Token~=token then return nil end
                return {Data=snapshot,Lease=not release and {Token=token,Until=os.time()+LEASE} or nil}
            end)
        end)
        if ok and result then saved=true; s.LastSave=os.clock(); s.LeaseUntil=os.time()+LEASE; break end
        task.wait(attempt)
    end
    s.Busy=false
    if not saved then warn("SkySprout: profile save failed for "..player.UserId) end
    if release then P.Sessions[player]=nil end
    return saved
end
task.spawn(function()
    while task.wait(40) do
        for player,s in pairs(P.Sessions) do
            if player.Parent==Players and not s.Closing then
                if not s.Memory and os.time()>s.LeaseUntil-35 then
                    s.Closing=true; player:Kick("Your save connection expired. Please rejoin to protect your progress.")
                elseif os.clock()-s.LastSave>35 then task.spawn(P.save,player,false) end
            end
        end
    end
end)
game:BindToClose(function()
    local pending=0
    for player,s in pairs(P.Sessions) do
        if not s.Closing then s.Closing=true; pending+=1; task.spawn(function() P.save(player,true); pending-=1 end) end
    end
    local deadline=os.clock()+25
    while pending>0 and os.clock()<deadline do task.wait(.1) end
end)
return P
