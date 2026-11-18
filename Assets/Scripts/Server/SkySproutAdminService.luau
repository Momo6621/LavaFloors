local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Profiles=require(script.Parent.SkySproutProfiles)
local Config=require(RS.SkySproutConfig)
local OWNER_USER_ID=1568010897
local S={States={},Bans={},Buckets={},Audit={}}
local A,stats,tell
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function hum(p)return p.Character and p.Character:FindFirstChildOfClass("Humanoid")end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
function S.IsOwnerId(id)return type(id)=="number"and id==OWNER_USER_ID end
function S.IsOwner(p)return typeof(p)=="Instance"and p:IsA("Player")and p.Parent==Players and S.IsOwnerId(p.UserId)end
local function state(p)local s=S.States[p];if not s then s={God=false,Fly=false,Noclip=false,Direction=Vector3.zero,LastMove=0,Collisions={}};S.States[p]=s end;return s end
local function attrs(p,s)
 p:SetAttribute("OwnerGod",s.God);p:SetAttribute("OwnerFlying",s.Fly);p:SetAttribute("OwnerNoclip",s.Noclip)
 p:SetAttribute("OwnerSpeed",s.Speed);p:SetAttribute("OwnerJump",s.Jump)
end
local function collide(p,s,on)
 local ch=p.Character;if not ch then return end
 if on then for _,v in ch:GetDescendants()do if v:IsA("BasePart")then s.Collisions[v]=true;v.CollisionGroup="SkyboundOwnerGhost"end end
 else for v in s.Collisions do if v.Parent then v.CollisionGroup=A.Fighters[p]and"ArenaFighter"or"TowerVisitor"end end;s.Collisions={}end
end
local function stopFlight(p,s)
 s.Fly=false;s.Noclip=false;s.Direction=Vector3.zero
 if s.Velocity then s.Velocity:Destroy();s.Velocity=nil end;if s.Attachment then s.Attachment:Destroy();s.Attachment=nil end
 local h=hum(p);if h then h.PlatformStand=false;h.JumpPower=A.Fighters[p]and 0 or(s.Jump or 40)end
 local r=root(p);if r then r.AssemblyLinearVelocity=Vector3.zero end;collide(p,s,false)
end
function S.ClearPowers(p)
 local s=S.States[p];if not s then return end
 stopFlight(p,s);s.God=false;s.Speed=nil;s.Jump=nil
 if s.Shield then s.Shield:Destroy();s.Shield=nil end
 local h=hum(p);if h then h.JumpPower=A.Fighters[p]and 0 or 40 end;attrs(p,s)
end
function S.ProfileLoaded(p,d)
 p:SetAttribute("SkyboundOwner",S.IsOwner(p))
 if S.IsOwner(p)then d.BestFloor=Config.MaxFloor end
end
function S.Speed(p)
 local s=S.States[p];return S.IsOwner(p)and s and s.Speed or nil
end
function S.BlockGameplay(p,action)
 local s=S.States[p];if not S.IsOwner(p)or not s then return false end
 if action=="Queue"or action=="Boss"then S.ClearPowers(p);return false end
 return s.Fly and action~="Sync"and action~="RPGSync"and action~="RegionSync"and action~="CancelTravel"
end
function S.Snapshot(p)
 local s=state(p);local list={};for _,v in Players:GetPlayers()do table.insert(list,{Name=v.Name,Id=v.UserId})end
 table.sort(list,function(a,b)return a.Id<b.Id end)
 return {Role="Owner",UserId=p.UserId,God=s.God,Fly=s.Fly,Noclip=s.Noclip,Speed=s.Speed or Config.WalkSpeed,Jump=s.Jump or 40,Players=list}
end
local function ready(p)
 local h=hum(p);return h and h.Health>0 and root(p)and p:GetAttribute("ArenaMode")=="Lobby"and not p:GetAttribute("RPGRaid")and not p:GetAttribute("TowerTraveling")and not A.Fighters[p]
end
local function fly(p,s,on)
 if not on then stopFlight(p,s);return end
 if s.Fly then return end
 if A.World then A.World.Dismount(p)end;local r=root(p);local h=hum(p)
 local attachment=Instance.new("Attachment");attachment.Name="OwnerFlightAttachment";attachment.Parent=r
 local velocity=Instance.new("LinearVelocity");velocity.Name="OwnerFlightVelocity";velocity.Attachment0=attachment;velocity.RelativeTo=Enum.ActuatorRelativeTo.World;velocity.MaxForce=10000000;velocity.VectorVelocity=Vector3.zero;velocity.Parent=r
 s.Attachment=attachment;s.Velocity=velocity;s.Fly=true;s.Direction=Vector3.zero;s.LastMove=os.clock();h.PlatformStand=true
end
function S.Move(p,direction)
 if not S.IsOwner(p)then return false end
 local s=S.States[p];if not s or not s.Fly or not ready(p)or typeof(direction)~="Vector3"then return false end
 if not(finite(direction.X)and finite(direction.Y)and finite(direction.Z))or direction.Magnitude>1.05 then return false end
 if os.clock()-(s.LastAccepted or 0)<.035 then return false end
 s.LastAccepted=os.clock();s.LastMove=os.clock();s.Direction=direction;return true
end
function S.Execute(p,command,value)
 if not S.IsOwner(p)then return {Ok=false,Message="Not authorized."}end
 if type(command)~="string"or #command>32 then return {Ok=false,Message="Invalid command."}end
 local now=os.clock();local b=S.Buckets[p]or{N=12,T=now};S.Buckets[p]=b;b.N=math.min(12,b.N+(now-b.T)*5);b.T=now
 if b.N<1 then return {Ok=false,Message="Please wait a moment."}end;b.N-=1
 local session=Profiles.Sessions[p];if not session then return {Ok=false,Message="Profile is loading."}end
 local d=session.Data;local s=state(p);local message
 local function invalid(text)return {Ok=false,Message=text}end
 if command=="State"then return {Ok=true,Message="Owner: "..p.Name,State=S.Snapshot(p)}end
 if command=="Kick"or command=="BanServer"or command=="UnbanServer"then
  if not finite(value)or value%1~=0 or value<=0 or value==OWNER_USER_ID then return invalid("Enter another player's numeric user ID.")end
  if command=="UnbanServer"then S.Bans[value]=nil;message="Server ban removed for "..value
  else
   local target=Players:GetPlayerByUserId(value);if not target then return invalid("That player is not in this server.")end
   if command=="BanServer"then S.Bans[value]=true end
   target:Kick(command=="BanServer"and"Removed from this server by the game owner."or"Removed by the game owner.");message="Removed "..target.Name
  end
 elseif command=="ClearPowers"then S.ClearPowers(p);message="Testing powers reset."
 else
  if not ready(p)then return invalid("Use character tools after your encounter or travel finishes.")end
  if command=="Floor"then
   if not finite(value)or value%1~=0 or value<1 or value>Config.MaxFloor then return invalid("Choose floor 1–20.")end
   S.ClearPowers(p);d.BestFloor=Config.MaxFloor;A.Tower.TravelTimes[p]=0
   local ok,why=A.Tower.Travel(p,value,true);if not ok then return invalid(why or"Travel interrupted.")end;message="Travelled to floor "..value
  elseif command=="Region"then
   local f=p:GetAttribute("VisitFloor")or 1;local floor=A.Tower.Floors[f]
   if type(value)~="string"or not floor.Waystones:FindFirstChild(value)then return invalid("Region: Town, Meadow, Forest, Lake, Highlands or Ruins.")end
   if not A.World then return invalid("Regions are off in the party game.")end
   S.ClearPowers(p);d.Waystones[tostring(f)]=d.Waystones[tostring(f)]or{};d.Waystones[tostring(f)][value]=true;A.World.TravelTimes[p]=0
   if not A.World.Travel(p,value)then return invalid("Region travel is unavailable during combat.")end;message="Travelled to "..value
  elseif command=="Heal"then local h=hum(p);h.Health=h.MaxHealth;local rpg=A.RPG and A.RPG.States[p];if rpg then rpg.Energy=100;rpg.Charge=100;rpg.Stun=0 end;message="Health, energy and relic charge restored."
  elseif command=="God"then
   if type(value)~="boolean"then return invalid("God mode needs on/off.")end
   s.God=value;if s.Shield then s.Shield:Destroy();s.Shield=nil end
   if value then local shield=Instance.new("ForceField");shield.Name="OwnerProtection";shield.Visible=false;shield.Parent=p.Character;s.Shield=shield end;message="God mode "..(value and"on"or"off")
  elseif command=="Fly"or command=="Noclip"then
   if type(value)~="boolean"then return invalid("Flight/noclip needs on/off.")end
   if command=="Fly"then fly(p,s,value)else if value then fly(p,s,true)end;s.Noclip=value;collide(p,s,value)end;message=command.." "..(value and"on"or"off")
  elseif command=="Speed"or command=="Jump"then
   if not finite(value)or value%1~=0 or value<1 or value>150 then return invalid("Choose a whole number from 1 to 150.")end
   if command=="Speed"then s.Speed=value else s.Jump=value;hum(p).JumpPower=value end;message=command.." set to "..value
  elseif command=="Coins"or command=="XP"then
   if not finite(value)or value%1~=0 or value<0 or value>10000000 then return invalid("Choose a whole amount from 0 to 10,000,000.")end
   if command=="Coins"then d.Coins=math.min(100000000,d.Coins+value)elseif A.RPG then A.RPG.AwardXP(p,value)end;message="Added "..value.." "..command
  elseif command=="UnlockRoutes"then
   d.BestFloor=Config.MaxFloor;for f=1,Config.MaxFloor do d.Waystones[tostring(f)]={Town=true,Meadow=true,Forest=true,Lake=true,Highlands=true,Ruins=true}end;message="All floors and waystones available."
  elseif command=="MaxProgress"then
   d.BestFloor=Config.MaxFloor;d.XP=200000
   for f=1,Config.MaxFloor do local k=tostring(f);d.BossClears[k]=true;d.Stories[k]={Step=f<3 and 5 or 6,Complete=true,Rewarded=true,HuntCount=3};d.Hunts[k]=3;d.Waystones[k]={Town=true,Meadow=true,Forest=true,Lake=true,Highlands=true,Ruins=true}end
   for _,skin in Config.Skins do if not skin.Premium then d.Owned[skin.Id]=true end end;message="Your character progression is maxed."
  elseif command=="Respawn"then S.ClearPowers(p);task.spawn(function()p:LoadCharacterAsync()end);message="Respawning."
  else return invalid("Unknown command.")end
 end
 attrs(p,s);stats(p);if A.RPG then A.RPG.Sync(p)end;A.Tower.Sync(p);if A.World then A.World.Sync(p)end
 table.insert(S.Audit,{UserId=p.UserId,Command=command,At=os.time()});if #S.Audit>100 then table.remove(S.Audit,1)end
 return {Ok=true,Message=message,State=S.Snapshot(p)}
end
function S.Start(arena,pushStats,notice)
 A=arena;stats=pushStats;tell=notice
 local physics=game:GetService("PhysicsService");pcall(function()physics:RegisterCollisionGroup("SkyboundOwnerGhost")end)
 for _,group in {"Default","TowerVisitor","ArenaFighter","SkyboundOwnerGhost"}do physics:CollisionGroupSetCollidable("SkyboundOwnerGhost",group,false)end
 local remote=Instance.new("RemoteFunction");remote.Name="SkyboundOwnerAdmin";remote.OnServerInvoke=function(p,command,value)local ok,r=xpcall(function()return S.Execute(p,command,value)end,debug.traceback);if ok then return r end;warn("Owner command failed: "..r);return {Ok=false,Message="Command failed; no admin rights were changed."}end;remote.Parent=RS
 local motion=Instance.new("RemoteEvent");motion.Name="SkyboundOwnerMotion";motion.OnServerEvent:Connect(S.Move);motion.Parent=RS
 local function added(p)
  if S.Bans[p.UserId]then p:Kick("Removed from this server by the game owner.");return end
  p:SetAttribute("SkyboundOwner",S.IsOwner(p));if not S.IsOwner(p)then return end
  p.CharacterAdded:Connect(function()S.ClearPowers(p)end)
  for _,key in {"ArenaMode","RPGRaid","TowerTraveling"}do p:GetAttributeChangedSignal(key):Connect(function()if p:GetAttribute("ArenaMode")~="Lobby"or p:GetAttribute("RPGRaid")or p:GetAttribute("TowerTraveling")then S.ClearPowers(p)end end)end
 end
 Players.PlayerAdded:Connect(added);for _,p in Players:GetPlayers()do added(p)end
 Players.PlayerRemoving:Connect(function(p)S.ClearPowers(p);S.States[p]=nil;S.Buckets[p]=nil end)
 game:GetService("RunService").Heartbeat:Connect(function()
  for p,s in S.States do if S.IsOwner(p)then
   local h=hum(p);local r=root(p)
   if s.Fly then
    if not ready(p)or not h or not r or not s.Velocity or not s.Velocity.Parent then S.ClearPowers(p)
    else
     local dir=os.clock()-s.LastMove<.35 and s.Direction or Vector3.zero;local floor=A.Tower.Floors[p:GetAttribute("VisitFloor")or 1];local y=floor:GetAttribute("Y");local cap=floor:GetAttribute("MaxExploreHeight")or 190
     if r.Position.Y>y+cap-12 and dir.Y>0 or r.Position.Y<y+3 and dir.Y<0 then dir=Vector3.new(dir.X,0,dir.Z)end
     s.Velocity.VectorVelocity=dir*(s.Speed or 90);h.PlatformStand=true;if s.Noclip then collide(p,s,true)end
    end
   end
  end end
 end)
end
return S
