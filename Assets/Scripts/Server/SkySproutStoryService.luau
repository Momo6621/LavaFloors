local Profiles=require(script.Parent.SkySproutProfiles)
local C=require(game.ReplicatedStorage.SkySproutConfig)
local S={Times={}}
local A,event,stats,tell
local function data(p)local v=Profiles.Sessions[p];return v and v.Data end
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
function S.Route(f)
 if f==1 then return {
  {Floor=1,Token="Market",Text="Collect the gateward supplies at the market."},
  {Floor=1,Token="Hunt",Text="Clear three ruin watchers from Floor 1’s wilds."},
  {Floor=1,Token="Summit",Text="Find the first crest on the Stone Dojo stage."},
  {Floor=1,Token="Report",Text="Return to Wayfinder Mira beside the quest board."},
 }end
 if f==2 then return {
  {Floor=1,Token="Hunt",Text="Return to Floor 1 and clear three watchers from the old road."},
  {Floor=1,Token="Cache",Text="Return to Floor 1 and recover Mira's garden chart."},
  {Floor=2,Token="Summit",Text="Climb Floor 2's cliff bridges and collect the crest."},
  {Floor=2,Token="Report",Text="Report to Mira on Floor 2 before challenging its guardian."},
 }end
 return {
  {Floor=f-2,Token="Cache",Text="Visit Floor "..(f-2).." and recover the old district's chart."},
  {Floor=f-1,Token="Hunt",Text="Clear three ruin watchers on Floor "..(f-1).." before collecting supplies."},
  {Floor=f-1,Token="Market",Text="Travel to Floor "..(f-1).." and collect expedition supplies."},
  {Floor=f,Token="Summit",Text="Return to Floor "..f.." and reach its stage crest."},
  {Floor=f,Token="Report",Text="Bring the chart, supplies and crest to Mira on Floor "..f.."."},
 }
end
function S.IsReady(d,f)
 return f<d.BestFloor or d.BossClears[tostring(f)]==true or(d.Stories[tostring(f)]and d.Stories[tostring(f)].Complete==true)or false
end
function S.Snapshot(d)
 local f=math.clamp(d.ActiveStory or d.BestFloor,1,d.BestFloor)
 local prior=d.Stories[tostring(f)]
 if prior and prior.Complete and d.BossClears[tostring(f)]and f<d.BestFloor then f=d.BestFloor;d.ActiveStory=f end
 local route=S.Route(f);local q=d.Stories[tostring(f)]
 local nextStep=q and route[q.Step]
 local snapshot={Home=f,Started=q~=nil,Complete=q and q.Complete or false,Step=q and math.min(q.Step,#route)or 0,Total=#route,
  Title=f==1 and"An Adventurer's First Crest"or("Expedition to "..C.FloorNames[f]),XP=100+f*25,Coins=40+f*5}
 if q and q.Complete and f==C.MaxFloor and d.BossClears[tostring(f)]then snapshot.Text="Tower conquered. Revisit the districts, help friends, or challenge PvP.";snapshot.TargetFloor=f;snapshot.Token="Report"
 elseif q and q.Complete then snapshot.Text="Route complete. Defeat Floor "..f.."'s guardian to climb.";snapshot.TargetFloor=f;snapshot.Token="Boss"
 elseif nextStep then snapshot.Text=nextStep.Text..(nextStep.Token=="Hunt"and(" ("..(q.HuntCount or 0).." / 3)")or"");snapshot.TargetFloor=nextStep.Floor;snapshot.Token=nextStep.Token
 else snapshot.Text="Speak to Wayfinder Mira on Floor "..f.." to begin its expedition.";snapshot.TargetFloor=f;snapshot.Token="Report"end
 if A and A.Tower then
  local floor=A.Tower.Floors[snapshot.TargetFloor]
  local names={Report="Wayfinder",Cache="GardenCache",Market="MarketSupplies",Summit="StageCrest"}
  local target=floor and(snapshot.Token=="Boss"and floor.Landscape:FindFirstChild("GuardianGate")or(snapshot.Token=="Hunt"and floor.Wilds:FindFirstChild("HuntWaypoint"))or floor.Story:FindFirstChild(names[snapshot.Token]or"Wayfinder"))
  if target then snapshot.TargetPosition=target.Position end
 end
 assert(snapshot.TargetFloor<=d.BestFloor,"Story route targets a locked floor")
 return snapshot
end
function S.Sync(p)
 local d=data(p);if not d then return end
 event:FireClient(p,"Story",S.Snapshot(d))
end
local function canInteract(p,pr)
 local d=data(p);local r=root(p);local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not(d and r and h and h.Health>0 and pr.Parent and pr.Parent:IsA("BasePart"))or A.Fighters[p]or p:GetAttribute("RPGRaid")then return false end
 local f=pr:GetAttribute("Floor")
 if type(f)~="number"or f>d.BestFloor or f~=(p:GetAttribute("VisitFloor")or 1)then return false end
 if (r.Position-pr.Parent.Position).Magnitude>pr.MaxActivationDistance+3 then return false end
 local now=os.clock();if now<(S.Times[p]or 0)then return false end;S.Times[p]=now+.3
 return true
end
function S.Interact(p,pr)
 if not canInteract(p,pr)then return false end
 local d=data(p);local token=pr:GetAttribute("StoryToken");local here=pr:GetAttribute("Floor")
 if token=="Report"then
  local active=d.ActiveStory;local q=active and d.Stories[tostring(active)]
  local nextStep=q and S.Route(active)[q.Step]
  if active==here and nextStep and nextStep.Token=="Report"then
   q.Step+=1;q.Complete=true
   if not q.Rewarded then q.Rewarded=true;d.Coins+=40+here*5;A.RPG.AwardXP(p,100+here*25);stats(p)end
   tell(p,"EXPEDITION COMPLETE • Guardian challenge ready. Your floor access still depends on defeating it.");S.Sync(p);return true
  end
  d.ActiveStory=here
  if not d.Stories[tostring(here)]then d.Stories[tostring(here)]={Step=1,Complete=false,Rewarded=false,HuntCount=0};tell(p,"MIRA • Follow the expedition route, then return before taking on the guardian.")end
  S.Sync(p);event:FireClient(p,"OpenQuests");return true
 end
 local f=d.ActiveStory;local q=f and d.Stories[tostring(f)];local nextStep=q and S.Route(f)[q.Step]
 if not nextStep or q.Complete or nextStep.Floor~=here or nextStep.Token~=token then tell(p,"Follow your expedition's current objective in Quests.");return false end
 q.Step+=1;tell(p,"EXPEDITION UPDATED • "..(S.Route(f)[q.Step].Text));S.Sync(p);return true
end
function S.RecordHunt(p,floor)
 local d=data(p);local home=d and d.ActiveStory;local q=home and d.Stories[tostring(home)]
 local step=q and S.Route(home)[q.Step]
 if not step or q.Complete or step.Token~="Hunt"or step.Floor~=floor or floor>d.BestFloor or p:GetAttribute("VisitFloor")~=floor then return false end
 q.HuntCount=math.min(3,(q.HuntCount or 0)+1)
 if q.HuntCount>=3 then q.Step+=1;q.HuntCount=0;tell(p,"ROAD CLEARED • "..S.Route(home)[q.Step].Text)end
 S.Sync(p);return true
end
function S.HandleAction(p,action)
 if action=="StorySync"then S.Sync(p);return true end
 if action=="StartStory"then
  local f=A.Tower.Floors[p:GetAttribute("VisitFloor")or 1]
  if f and f:FindFirstChild("Story")then local ok=S.Interact(p,f.Story.Wayfinder:FindFirstChildOfClass("ProximityPrompt"));if not ok then tell(p,"Walk over to Wayfinder Mira beside the quest board. Use Track Objective to locate her.")end end
  return true
 end
 return false
end
function S.Start(arena,remote,pushStats,notice)
 A=arena;event=remote;stats=pushStats;tell=notice
 for _,floor in A.Tower.Floors do local folder=floor:FindFirstChild("Story");if folder then for _,pr in folder:GetDescendants()do
  if pr:IsA("ProximityPrompt")and pr:GetAttribute("StoryToken")then pr.Triggered:Connect(function(p)S.Interact(p,pr)end)end
 end end end
 game.Players.PlayerRemoving:Connect(function(p)S.Times[p]=nil end)
end
return S
