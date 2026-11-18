local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local C=require(game.ReplicatedStorage.SkySproutConfig)
local Profiles=require(script.Parent.SkySproutProfiles)
local W={Discovered={},Sprinting={},TravelTimes={},MountTimes={},MountHeights={}}
local A,event,tell
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function eligible(p)
 local s=Profiles.Sessions[p];local r=root(p);local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 return s and r and h and h.Health>0 and not A.Fighters[p]and not p:GetAttribute("RPGRaid")and not p:GetAttribute("TowerTraveling"),s and s.Data
end
local function known(p,f)
 local session=Profiles.Sessions[p];if not session then return {Town=true}end
 local d=session.Data;d.Waystones=d.Waystones or{};local key=tostring(f)
 d.Waystones[key]=d.Waystones[key]or{Town=true};d.Waystones[key].Town=true
 W.Discovered[p]=W.Discovered[p]or{};W.Discovered[p][f]=d.Waystones[key]
 return d.Waystones[key]
end
function W.Sync(p)
 local ok,d=eligible(p);if not d then return end
 local f=p:GetAttribute("VisitFloor")or 1;local floor=A.Tower.Floors[f];if not floor then return end
 local discovered=known(p,f);local nodes={}
 for _,w in floor.Waystones:GetChildren()do table.insert(nodes,{Id=w.Name,Name=w:GetAttribute("RegionName"),Position=w:GetAttribute("TravelPosition"),Known=discovered[w.Name]==true})end
 table.sort(nodes,function(a,b)if a.Id=="Town"then return true elseif b.Id=="Town"then return false end;return a.Name<b.Name end)
 event:FireClient(p,"Regions",{Floor=f,Radius=floor:GetAttribute("Radius"),EntryRadius=floor:GetAttribute("EntryBoundsRadius"),Nodes=nodes})
end
function W.CanSprint(p)
 local ok=eligible(p);local s=A.RPG.States[p]
 return ok and W.Sprinting[p]==true and s and os.clock()>(s.CombatUntil or 0)and os.clock()>s.Stun and not s.Block and os.clock()>s.Next
end
function W.Dismount(p)
 if not p:GetAttribute("Mounted")then return end
 p:SetAttribute("Mounted",false)
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if h then h.HipHeight=W.MountHeights[p]or h.HipHeight-3;h.WalkSpeed=C.WalkSpeed end
 W.MountHeights[p]=nil
end
function W.Mount(p)
 if p:GetAttribute("Mounted")then W.Dismount(p);return true end
 local ok=eligible(p);local s=A.RPG.States[p];local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not ok or not s or not h or h.FloorMaterial==Enum.Material.Air or p:GetAttribute("ArenaMode")~="Lobby"
  or os.clock()<(s.CombatUntil or 0)or os.clock()<s.Stun or s.Block or os.clock()<s.Next then tell(p,"Mount on solid ground after combat.");return false end
 local f=A.Tower.Floors[p:GetAttribute("VisitFloor")or 1]
 if not f or root(p).Position.Y>f:GetAttribute("Y")+45 then tell(p,"Explore the trails on your mount; climb obstacles on foot.");return false end
 if os.clock()<(W.MountTimes[p]or 0)then return false end
 W.MountTimes[p]=os.clock()+2;W.MountHeights[p]=h.HipHeight;h.HipHeight+=3;h.WalkSpeed=78
 p:SetAttribute("Mounted",true);p:SetAttribute("PVETargetLocked",false);tell(p,"Skystrider summoned • V / D-pad up to dismount.");return true
end
function W.Speed(p)
 if A.Admin then local speed=A.Admin.Speed(p);if speed then return speed end end
 if p:GetAttribute("Mounted")then return 78 end
 return W.CanSprint(p)and 42 or C.WalkSpeed
end
function W.Travel(p,id)
 if type(id)~="string"or #id>24 then return false end
 local ok,d=eligible(p);if not ok then return false end
 local f=p:GetAttribute("VisitFloor")or 1;local floor=A.Tower.Floors[f];local node=floor and floor.Waystones:FindFirstChild(id)
 if not node or f>d.BestFloor or not known(p,f)[id]then tell(p,"Explore that region to discover its waystone first.");return false end
 local s=A.RPG.States[p];if s and(os.clock()<(s.CombatUntil or 0)or os.clock()<s.Stun or os.clock()<s.Next)then tell(p,"Waystones become available after combat.");return false end
 if os.clock()<(W.TravelTimes[p]or 0)then return false end;W.TravelTimes[p]=os.clock()+3
 local position=node:GetAttribute("TravelPosition");local ch=p.Character
 W.Dismount(p);W.Sprinting[p]=false
 local ticket=A.Transit.Begin(p,{Floor=f,Name=node:GetAttribute("RegionName"),Kind="Waystone"})
 pcall(function()p:RequestStreamAroundAsync(position,2)end)
 local session=Profiles.Sessions[p];local latest=session and session.Data;local now=os.clock();local state=A.RPG.States[p]
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not(A.Transit.Current(p,ticket)and p.Character==ch and root(p)and h and h.Health>0 and latest and f<=latest.BestFloor and p:GetAttribute("VisitFloor")==f)
  or A.Fighters[p]or p:GetAttribute("RPGRaid")or(state and(now<(state.CombatUntil or 0)or now<state.Stun or now<state.Next))then A.Transit.Finish(p,ticket,false,"Travel interrupted.");return false end
 local r=root(p);r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
 p.Character:PivotTo(CFrame.new(position))
 A.Transit.Finish(p,ticket,true);tell(p,"WAYSTONE • "..node:GetAttribute("RegionName"));W.Sync(p);return true
end
function W.HandleAction(p,action,value)
 if action=="Mount"then W.Mount(p);return true
 elseif action=="RegionSync"then W.Sync(p);return true
 elseif action=="RegionTravel"then W.Travel(p,value);return true
 elseif action=="Sprint"then if type(value)=="boolean"then W.Sprinting[p]=value end;return true end
 return false
end
function W.Start(arena,remote,notice)
 A=arena;event=remote;tell=notice
 for f,floor in A.Tower.Floors do for _,w in floor.Waystones:GetChildren()do
  w:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(p)
   local ok,d=eligible(p);local r=root(p)
   if not ok or f>d.BestFloor or p:GetAttribute("VisitFloor")~=f or(r.Position-w.Position).Magnitude>16 then return end
   known(p,f)[w.Name]=true;W.Sync(p);event:FireClient(p,"OpenRegions")
  end)
 end end
 local function added(p)
  p:GetAttributeChangedSignal("VisitFloor"):Connect(function()W.Dismount(p);W.Sprinting[p]=false;task.defer(W.Sync,p)end)
  p.CharacterAdded:Connect(function()p:SetAttribute("Mounted",false);W.MountHeights[p]=nil;W.Sprinting[p]=false end)
  for _,attr in {"RPGRaid","ArenaMode","TowerTraveling"}do p:GetAttributeChangedSignal(attr):Connect(function()if p:GetAttribute("RPGRaid")or p:GetAttribute("ArenaMode")~="Lobby"or p:GetAttribute("TowerTraveling")then W.Dismount(p)end end)end
 end
 Players.PlayerAdded:Connect(added);for _,p in Players:GetPlayers()do added(p)end
 Players.PlayerRemoving:Connect(function(p)W.Discovered[p]=nil;W.Sprinting[p]=nil;W.TravelTimes[p]=nil;W.MountTimes[p]=nil;W.MountHeights[p]=nil end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.5 then return end;elapsed=0
  for _,p in Players:GetPlayers()do
   local ok,d=eligible(p);local f=p:GetAttribute("VisitFloor")or 1;local floor=A.Tower.Floors[f]
   if p:GetAttribute("Mounted")then local st=A.RPG.States[p];if not ok or not st or os.clock()<(st.CombatUntil or 0)or os.clock()<st.Stun or(floor and root(p).Position.Y>floor:GetAttribute("Y")+48)then W.Dismount(p)end end
   if ok and floor and f<=d.BestFloor then
    local pos=root(p).Position;local discovered=known(p,f);local current,closest="Gateward Town",math.huge;local changed=false
    for _,w in floor.Waystones:GetChildren()do local dist=(pos-w.Position).Magnitude
     if dist<closest then closest=dist;current=w:GetAttribute("RegionName")end
     if dist<28 and not discovered[w.Name]then discovered[w.Name]=true;changed=true;tell(p,"WAYSTONE DISCOVERED • "..w:GetAttribute("RegionName").." • Open Map [M] to return here.")end
    end
    if f==1 then
     local distance=Vector2.new(pos.X,pos.Z).Magnitude
     if distance>1640 then current=distance>2700 and"Bedrock Ward • Outer District"or"Bedrock Ward • Inner District"end
    end
    p:SetAttribute("RegionName",current);if changed then W.Sync(p)end
   end
  end
 end)
end
return W
