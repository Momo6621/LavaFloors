local Players=game:GetService("Players")
local Profiles=require(script.Parent.SkySproutProfiles)
local D=require(game.ReplicatedStorage.SkySproutContracts)
local K={Nodes={},Times={}}
local A,event,stats,tell
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function eligible(p,f,peace)
 local s=Profiles.Sessions[p];local r=root(p);local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not(s and r and h and h.Health>0)or f>s.Data.BestFloor or(p:GetAttribute("VisitFloor")or 1)~=f or A.Fighters[p]or p:GetAttribute("RPGRaid")or p:GetAttribute("TowerTraveling")then return false end
 local st=A.RPG.States[p]
 if peace and st and(os.clock()<(st.CombatUntil or 0)or os.clock()<st.Stun)then return false end
 return true,s.Data
end
local function record(d,f,id)
 d.Contracts=d.Contracts or{};local k=tostring(f);d.Contracts[k]=d.Contracts[k]or{}
 return d.Contracts[k][id]
end
local function position(f,token)
 local floor=A.Tower.Floors[f]
 if token=="Hunt"then return floor:GetAttribute("WildsCenter")+Vector3.new(0,3,0)end
 local node=K.Nodes[f]and K.Nodes[f][token]
 return node and node.Position
end
function K.Snapshot(p)
 local f=p:GetAttribute("VisitFloor")or 1;local session=Profiles.Sessions[p];if not session or f>session.Data.BestFloor then return end
 local entries={}
 for _,id in D.IDs do
  local spec=D.Get(f,id);local q=record(session.Data,f,id);local step=q and q.Step or 1
  local token=q and spec.Stops[step]or nil;local ready=q and not q.Complete and step>#spec.Stops or false
  if ready then token="Board"end
  local objective=not q and spec.Description or(q.Complete and"Contract complete. Continue your climb."or(ready and"Report to the town contract board."or(id=="Patrol"and("Defeat ruin watchers: "..q.Count.." / 3")or(spec.Verb:sub(1,1):upper()..spec.Verb:sub(2).." the "..spec.Item.." at the "..({"woodland","highland","lakeside"})[step].." station."))))
  table.insert(entries,{Id=id,Floor=f,Title=spec.Title,Text=objective,Started=q~=nil,Complete=q and q.Complete or false,Ready=ready,Step=math.min(step,#spec.Stops+1),Total=#spec.Stops+1,Count=q and q.Count or 0,Coins=spec.Coins,XP=spec.XP,TargetFloor=f,TargetPosition=token and position(f,token),Token=token})
 end
 return {Floor=f,Entries=entries}
end
function K.Sync(p)local snapshot=K.Snapshot(p);if snapshot then event:FireClient(p,"Contracts",snapshot)end end
function K.Accept(p,id)
 if type(id)~="string"or not D.Get(p:GetAttribute("VisitFloor")or 1,id)then return false end
 local f=p:GetAttribute("VisitFloor")or 1;local ok,d=eligible(p,f,true);if not ok then return false end
 if record(d,f,id)then K.Sync(p);return false end
 d.Contracts[tostring(f)][id]={Step=1,Count=0,Complete=false,Rewarded=false}
 tell(p,"CONTRACT ACCEPTED • "..D.Get(f,id).Title);K.Sync(p);return true
end
function K.Claim(p,id)
 local f=p:GetAttribute("VisitFloor")or 1;local spec=type(id)=="string"and D.Get(f,id)
 local ok,d=eligible(p,f,true);if not ok or not spec then return false end
 local board=K.Nodes[f]and K.Nodes[f].Board;local q=record(d,f,id)
 if not board or not q or q.Complete or q.Rewarded or q.Step<=#spec.Stops then return false end
 if(root(p).Position-board.Position).Magnitude>17 then tell(p,"Return to the town contract board to report.");return false end
 q.Complete=true;q.Rewarded=true;d.Coins+=spec.Coins;A.RPG.AwardXP(p,spec.XP);stats(p)
 tell(p,"CONTRACT COMPLETE • +"..spec.Coins.." coins • +"..spec.XP.." XP")
 K.Sync(p);return true
end
function K.Interact(p,pr)
 if typeof(pr)~="Instance"or not pr:IsA("ProximityPrompt")then return false end
 local f=pr:GetAttribute("ContractFloor");local token=pr:GetAttribute("ContractToken")
 if type(f)~="number"or type(token)~="string"or not(K.Nodes[f]and K.Nodes[f][token]==pr.Parent)then return false end
 local ok,d=eligible(p,f,true);if not ok or(root(p).Position-pr.Parent.Position).Magnitude>pr.MaxActivationDistance+3 then return false end
 if os.clock()<(K.Times[p]or 0)then return false end;K.Times[p]=os.clock()+.35
 if token=="Board"then
  for _,id in D.IDs do K.Claim(p,id)end
  K.Sync(p);event:FireClient(p,"OpenQuests");return true
 end
 local q=record(d,f,"Survey");local spec=D.Get(f,"Survey")
 if not q then tell(p,"Accept this floor's regional trail contract in Quests first.");return false end
 if q.Complete or spec.Stops[q.Step]~=token then tell(p,"Follow the current station in your regional contract.");return false end
 q.Step+=1;K.Sync(p);tell(p,q.Step>#spec.Stops and"ROUTE COMPLETE • Return to the town contract board."or"REGIONAL STATION COMPLETE • Track the next station in Quests.");return true
end
function K.RecordHunt(p,f)
 local ok,d=eligible(p,f,false);if not ok then return false end
 local center=A.Tower.Floors[f]:GetAttribute("WildsCenter")
 if not center or(root(p).Position-center).Magnitude>50 then return false end
 local q=record(d,f,"Patrol");if not q or q.Complete or q.Step~=1 then return false end
 q.Count=math.min(3,q.Count+1);if q.Count==3 then q.Step=2;tell(p,"PATROL COMPLETE • Report to the town contract board.")end
 K.Sync(p);return true
end
function K.HandleAction(p,action,value)
 if action=="ContractSync"then K.Sync(p);return true
 elseif action=="ContractAccept"then K.Accept(p,value);return true
 elseif action=="ContractClaim"then K.Claim(p,value);return true end
 return false
end
function K.Start(arena,remote,pushStats,notice)
 A=arena;event=remote;stats=pushStats;tell=notice
 for f,floor in A.Tower.Floors do
  K.Nodes[f]={}
  for _,pr in floor.Contracts:GetDescendants()do if pr:IsA("ProximityPrompt")then
   K.Nodes[f][pr:GetAttribute("ContractToken")]=pr.Parent
   pr.Triggered:Connect(function(p)K.Interact(p,pr)end)
  end end
 end
 local function added(p)p:GetAttributeChangedSignal("VisitFloor"):Connect(function()task.defer(K.Sync,p)end)end
 Players.PlayerAdded:Connect(added);for _,p in Players:GetPlayers()do added(p)end
 Players.PlayerRemoving:Connect(function(p)K.Times[p]=nil end)
end
return K
