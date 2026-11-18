local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local C=require(game.ReplicatedStorage.SkySproutConfig)
local Profiles=require(script.Parent.SkySproutProfiles)
local Rules=require(script.Parent.SkySproutRules)
local T={Bags={},Floors={},TravelTimes={},PromptTimes={}}
local Arena,event,pushStats,tell
local rewards={Explore=30,Courier=40,Training=25}
local function data(p)local s=Profiles.Sessions[p];return s and s.Data end
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function quest(d,f)
 d.FloorQuests=d.FloorQuests or{}
 local key=tostring(f)
 if not d.FloorQuests[key]then d.FloorQuests[key]={Seals={},Claimed={},Parcel=false,Delivered=false,Training=0}end
 return d.FloorQuests[key]
end
function T.Sync(p)
 local d=data(p);if not d then return end
 local floor=p:GetAttribute("VisitFloor")or 1;local q=quest(d,floor);local seals=0
 for i=1,3 do if q.Seals[tostring(i)]then seals+=1 end end
 event:FireClient(p,"Quests",{Floor=floor,Name=C.FloorNames[floor],Seals=q.Seals,Parcel=q.Parcel and not q.Delivered,
  Entries={
   {Id="Explore",Title="District Cartographer",Description="Find the three glowing discovery seals.",Progress=seals,Target=3,Reward=rewards.Explore,Claimed=q.Claimed.Explore==true},
   {Id="Courier",Title="Market Courier",Description=q.Parcel and"Deliver your parcel to the mint beacon at the market."or"Collect a parcel at the courier desk, then deliver it to the market.",Progress=q.Delivered and 1 or 0,Target=1,Reward=rewards.Courier,Claimed=q.Claimed.Courier==true},
   {Id="Training",Title="Warm Up",Description="Land three punches or heavy hits on the training bags.",Progress=q.Training,Target=3,Reward=rewards.Training,Claimed=q.Claimed.Training==true},
  }})
 if Arena and Arena.Story then Arena.Story.Sync(p)end
 if Arena and Arena.Contracts then Arena.Contracts.Sync(p)end
end
local function place(p,floor,pos)
 local r=root(p);if not r then return false end
 local location=pos or T.Floors[floor]:GetAttribute("Spawn")
 r.AssemblyLinearVelocity=Vector3.zero;r.AssemblyAngularVelocity=Vector3.zero
 local look=T.Floors[floor]:GetAttribute("SpawnLookAt")
 p.Character:PivotTo(CFrame.lookAt(location,typeof(look)=="Vector3"and Vector3.new(look.X,location.Y,look.Z)or location+Vector3.new(0,0,-1)))
 local h=p.Character:FindFirstChildOfClass("Humanoid");if h then h.WalkSpeed=C.WalkSpeed;h.JumpPower=40;h.UseJumpPower=true;h.AutoRotate=true end
 p:SetAttribute("VisitFloor",floor);p:SetAttribute("ReturnFloor",floor)
 if floor>1 or Vector2.new(location.X,location.Z).Magnitude<T.Floors[floor]:GetAttribute("Radius")-80 then p:SetAttribute("TowerEntered",true)end
 return true
end
local function travelReady(p,internal)
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not(root(p)and h and h.Health>0)then return false,"Not spawned"end
 if internal then return true end
 if p:GetAttribute("RPGRaid")or Arena.Fighters[p]then return false,"Finish your encounter before travelling."end
 local st=Arena.RPG and Arena.RPG.States[p];local now=os.clock()
 if st and(now<(st.CombatUntil or 0)or now<st.Stun or now<st.Next)then return false,"Travel becomes available after combat."end
 return true
end
function T.Travel(p,floor,internal,arrival)
 local d=data(p)
 if not d or type(floor)~="number"or floor~=floor or floor%1~=0 or not T.Floors[floor]then return false,"Unknown floor."end
 if floor>d.BestFloor then tell(p,"LOCKED • Defeat guardians to unlock floor "..floor..". Your access ends at floor "..d.BestFloor..".");return false,"Locked"end
 if not internal and(p:GetAttribute("TowerTraveling")or os.clock()<(T.TravelTimes[p]or 0))then return false,"Travel cooling down"end
 local ok,reason=travelReady(p,internal);if not ok then tell(p,reason);return false,reason end
 local destination=arrival=="Ward"and floor==1 and T.Floors[1]:GetAttribute("EntrySpawn")or T.Floors[floor]:GetAttribute("Spawn")
 local ch=p.Character
 T.TravelTimes[p]=os.clock()+1.5
 if Arena.World then Arena.World.Dismount(p);Arena.World.Sprinting[p]=false end
 local destinationName=arrival=="Ward"and"Bedrock Ward"or require(game.ReplicatedStorage.SkySproutWorldThemes)[floor].Name
 local ticket=Arena.Transit.Begin(p,{Floor=floor,Name=destinationName,Kind="Floor"})
 pcall(function()p:RequestStreamAroundAsync(destination,2)end)
 ok,reason=travelReady(p,internal);d=data(p)
 if not(Arena.Transit.Current(p,ticket)and p.Character==ch and d and floor<=d.BestFloor and ok)then Arena.Transit.Finish(p,ticket,false,reason or"Travel interrupted.");return false,reason or"Travel interrupted"end
 if not place(p,floor,destination)then Arena.Transit.Finish(p,ticket,false,"Not spawned.");return false,"Not spawned"end
 Arena.Transit.Finish(p,ticket,true)
 pushStats(p);T.Sync(p);event:FireClient(p,"Travelled",{Floor=floor,Name=arrival=="Ward"and"Bedrock Ward"or C.FloorNames[floor]})
 return true
end
function T.Return(p)
 local d=data(p);if not d then return end
 local destination=math.clamp(p:GetAttribute("ReturnFloor")or p:GetAttribute("VisitFloor")or 1,1,d.BestFloor)
 local entry=T.Floors[1]:GetAttribute("EntrySpawn")
 if destination==1 and not p:GetAttribute("TowerEntered")and entry and not C.SkipTowerApproach then
  if place(p,1,entry)then pushStats(p);T.Sync(p);event:FireClient(p,"Travelled",{Floor=1,Name="Bedrock Ward • Tower approach"})end
 else
  local first=not p:GetAttribute("TowerEntered")
  T.Travel(p,destination,true)
  if first and p:GetAttribute("TowerEntered")then tell(p,"WELCOME TO "..C.GameTitle:upper()..(C.PartyMode and" • Climb the lava tower with everyone — rounds start automatically!"or" • Hop into 🔥 Lava Rush right here, or find Mira in town!"))end
 end
end
function T.RecordTraining(p)
 local d=data(p);if not d or Arena.Fighters[p]then return end
 local floor=p:GetAttribute("VisitFloor")or 1
 local q=quest(d,floor);q.Training=math.min(3,q.Training+1);T.Sync(p)
end
function T.GetBags(p)return T.Bags[p:GetAttribute("VisitFloor")or 1]or{}end
function T.Claim(p,id)
 local d=data(p);if not d or Arena.Fighters[p]or type(id)~="string"or not rewards[id]then return false end
 local floor=p:GetAttribute("VisitFloor")or 1
 if floor>d.BestFloor then return false end
 local q=quest(d,floor);if q.Claimed[id]then tell(p,"Quest already claimed on this floor.");return false end
 local seals=0;for i=1,3 do if q.Seals[tostring(i)]then seals+=1 end end
 local complete=(id=="Explore"and seals==3)or(id=="Courier"and q.Delivered)or(id=="Training"and q.Training>=3)
 if not complete then tell(p,"Finish this district quest first.");return false end
 q.Claimed[id]=true;d.Coins+=rewards[id];if Arena.RPG then Arena.RPG.AwardXP(p,rewards[id]*2)end;pushStats(p);T.Sync(p)
 tell(p,"QUEST COMPLETE • +"..rewards[id].." coins. Defeat guardians to unlock the next floor.")
 event:FireClient(p,"QuestReward",{Coins=rewards[id],Id=id})
 return true
end
function T.Interact(p,pr)
 local d=data(p);local r=root(p)
 if not(d and r and pr.Parent and pr.Parent:IsA("BasePart"))or Arena.Fighters[p]then return false end
 local floor=pr:GetAttribute("Floor")
 if type(floor)~="number"or floor>d.BestFloor or floor~=(p:GetAttribute("VisitFloor")or 1)then return false end
 if(r.Position-pr.Parent.Position).Magnitude>pr.MaxActivationDistance+3 then return false end
 if os.clock()<(T.PromptTimes[p]or 0)then return false end;T.PromptTimes[p]=os.clock()+.25
 local action=pr:GetAttribute("TowerAction");local q=quest(d,floor)
 if action=="Floors"then event:FireClient(p,"OpenFloors");return true
 elseif action=="Quests"then T.Sync(p);event:FireClient(p,"OpenQuests");return true
 elseif action=="Queue"then Arena.HandleAction(p,"Queue");return true
 elseif action=="Seal"then
  local id=pr:GetAttribute("Value");if not(id=="1"or id=="2"or id=="3")then return false end
  if q.Seals[id]then tell(p,"You already discovered this seal.");return false end
  q.Seals[id]=true;tell(p,"Discovery seal "..id.." / 3 found. Check your district quests.")
 elseif action=="Pickup"then
  if q.Delivered or q.Claimed.Courier then tell(p,"This floor's delivery is already complete.");return false end
  q.Parcel=true;tell(p,"Parcel collected. Follow the east path to the market's mint beacon.")
 elseif action=="Deliver"then
  if q.Delivered then return false end
  if not q.Parcel then tell(p,"Pick up a parcel from the courier desk first.");return false end
  q.Parcel=false;q.Delivered=true;tell(p,"Parcel delivered! Claim Market Courier in Quests.")
 else return false end
 T.Sync(p);return true
end
function T.HandleAction(p,action,value)
 if action=="Travel"then return T.Travel(p,value)
 elseif action=="QuestSync"then T.Sync(p)
 elseif action=="ClaimQuest"then return T.Claim(p,value)end
end
function T.Start(arena,remote,stats,notice)
 Arena=arena;event=remote;pushStats=stats;tell=notice
 for _,f in ipairs(workspace.SkySprout.Floors:GetChildren())do
  local n=f:GetAttribute("Floor");T.Floors[n]=f;T.Bags[n]={}
  for _,d in ipairs(f:GetDescendants())do
   if d:IsA("BasePart")and d:GetAttribute("TrainingBag")then table.insert(T.Bags[n],d)
   elseif d:IsA("ProximityPrompt")and d:GetAttribute("TowerAction")then d.Triggered:Connect(function(p)T.Interact(p,d)end)end
  end
 end
 Players.PlayerRemoving:Connect(function(p)T.TravelTimes[p]=nil;T.PromptTimes[p]=nil end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.35 then return end;elapsed=0
  for _,p in ipairs(Players:GetPlayers())do
   local d=data(p);local r=root(p)
   if d and r and not Arena.Fighters[p]and p:GetAttribute("ArenaMode")~="Loading"and not p:GetAttribute("TowerTraveling")then
    local f=p:GetAttribute("VisitFloor")or 1;local region=T.Floors[f]
    if not region or f>d.BestFloor then T.Return(p)
    else
     local y=region:GetAttribute("Y");local radius=region:GetAttribute("EntryBoundsRadius")or region:GetAttribute("Radius")
     local xz=Vector2.new(r.Position.X,r.Position.Z).Magnitude
     local outside=r.Position.Y<y-8 or r.Position.Y>y+(region:GetAttribute("MaxExploreHeight")or 270)or xz>radius+32
     if outside then
      local entry=f==1 and not p:GetAttribute("TowerEntered")and region:GetAttribute("EntrySpawn")or nil
      place(p,f,entry);tell(p,"Returned to floor "..f..". Higher floors unlock by defeating guardians.")
     else
      if f==1 and not p:GetAttribute("TowerEntered")and xz<1500 and math.abs(r.Position.Y-y)<24 then
       p:SetAttribute("TowerEntered",true);T.Sync(p);tell(p,"WELCOME TO "..C.GameTitle:upper().." • Find Mira in the town to begin your climb.")
      end
      for _,m in pairs(Arena.Matches)do
       if not m.Done and m.Floor==f and math.abs(r.Position.X-m.Center.X)<27 and math.abs(r.Position.Z-m.Center.Z)<27 then
        local pos=Vector3.new(r.Position.X,y+3.6,m.Center.Z>0 and 7 or -7);place(p,f,pos);tell(p,"Active duel • watch from the walkway.");break
       end
      end
     end
    end
   end
  end
 end)
 for _,label in workspace:GetDescendants()do
  if label:IsA("TextLabel")and label:GetAttribute("ShowsGameTitle")then
   local rest=label.Text:match("^[^\n]*(\n.*)$")or"";label.Text=C.GameTitle:upper()..rest
  end
 end
 print(C.GameTitle..(C.PartyMode and" lobby ready."or" tower ready: exploration, quests, and server-checked floor access."))
end
return T
