local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local C=require(RS.SkySproutConfig)
local Rules=require(script.Parent.SkySproutRules)
local Profiles=require(script.Parent.SkySproutProfiles)
local A={Queue={},Fighters={},Matches={},NextId=0}
local event
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function hum(p)return p.Character and p.Character:FindFirstChildOfClass("Humanoid")end
local function tell(p,t)if p.Parent then event:FireClient(p,"Notice",t)end end
local function data(p)local s=Profiles.Sessions[p];return s and s.Data end
local function setMode(p,mode)p:SetAttribute("ArenaMode",mode)end
local function stats(p)
 local d=data(p);if not d then return end
 p:SetAttribute("UnlockedFloor",d.BestFloor);p:SetAttribute("GloveStyle",d.Skin);for _,skin in ipairs(C.Skins)do p:SetAttribute("Owns"..skin.Id,d.Owned[skin.Id]==true)end
 p:SetAttribute("HatStyle",d.Hat or "");for _,h in ipairs(C.Hats)do p:SetAttribute("OwnsHat"..h.Id,d.OwnedHats and d.OwnedHats[h.Id]==true)end
 p:SetAttribute("Crowns",d.Crowns or 0);p:SetAttribute("Floor",Rules.floor(d.Points));p:SetAttribute("Points",d.Points);p:SetAttribute("Coins",d.Coins)
 local ls=p:FindFirstChild("leaderstats")
 if ls then
  local function set(name,v)local s=ls:FindFirstChild(name);if s then s.Value=v end end
  set("Level",A.RPG and A.RPG.Level(d)or 1);set("Access",d.BestFloor);set("Wins",d.Wins);set("👑 Crowns",d.Crowns or 0);set("💰 Coins",d.Coins)
 end
end
local function color(p)
 local d=data(p);for _,s in ipairs(C.Skins)do if d and s.Id==d.Skin then return s.Color end end
 return C.Skins[1].Color
end
local function equip(p)
 local ch=p.Character;if not ch then return end
 for _,name in ipairs({"ArenaGloves","LeftGlove"})do local old=ch:FindFirstChild(name);if old then old:Destroy()end end
 local bag=p:FindFirstChildOfClass("Backpack");if bag and bag:FindFirstChild("ArenaGloves")then bag.ArenaGloves:Destroy()end
 local gloves=Instance.new("Folder");gloves.Name="ArenaGloves"
 for _,side in ipairs({"Right","Left"})do
  local hand=ch:FindFirstChild(side.."Hand")or ch:FindFirstChild(side.." Arm")
  if hand then
   local g=Instance.new("Part");g.Name=side.."Glove";g.Shape=Enum.PartType.Ball;g.Size=Vector3.new(1.25,1.25,1.45)
   local style;for _,s in ipairs(C.Skins)do if data(p)and s.Id==data(p).Skin then style=s end end
   local aurora=style~=nil and style.Sparkle==true
   g.Color=color(p);g.Material=style and style.Material and Enum.Material[style.Material]or Enum.Material.SmoothPlastic;g.CanCollide=false;g.CanTouch=false;g.CanQuery=false;g.Massless=true
   g.CFrame=hand.CFrame*CFrame.new(0,hand.Name:find("Hand")and -.1 or -.75,0);g.Parent=gloves
   local w=Instance.new("WeldConstraint");w.Part0=hand;w.Part1=g;w.Parent=g
   if aurora then local fx=Instance.new("ParticleEmitter");fx.Name="AuroraSparkle";fx.Texture="rbxasset://textures/particles/sparkles_main.dds";fx.Color=ColorSequence.new(Color3.fromRGB(105,224,255),Color3.fromRGB(196,140,255));fx.LightEmission=1;fx.Rate=6;fx.Lifetime=NumberRange.new(.4,.8);fx.Speed=NumberRange.new(.5,1.5);fx.Size=NumberSequence.new(.25,0);fx.Parent=g end
   local cuff=Instance.new("Part");cuff.Name=side.."Cuff";cuff.Size=Vector3.new(.92,.3,.92);cuff.Color=Color3.fromRGB(26,43,60)
   cuff.Material=Enum.Material.SmoothPlastic;cuff.CanCollide=false;cuff.CanTouch=false;cuff.CanQuery=false;cuff.Massless=true
   cuff.CFrame=g.CFrame*CFrame.new(0,.55,0);cuff.Parent=gloves
   local weld=Instance.new("WeldConstraint");weld.Part0=hand;weld.Part1=cuff;weld.Parent=cuff
  end
 end
 gloves.Parent=ch
end
local function move(p,pos,look)
 local r=root(p);local h=hum(p)
 if r then r.Anchored=false;r.AssemblyLinearVelocity=Vector3.zero;r.CFrame=CFrame.lookAt(pos,look or(pos+Vector3.new(0,0,-1)))end
 if h then h.WalkSpeed=C.WalkSpeed;h.JumpPower=0;h.UseJumpPower=true;h.AutoRotate=true;h.Health=h.MaxHealth end
end
local function collision(p,group)
 if p.Character then for _,d in ipairs(p.Character:GetDescendants())do if d:IsA("BasePart")then d.CollisionGroup=group end end end
end
local function lobby(p)
 A.Fighters[p]=nil;p:SetAttribute("ArenaFloor",nil);setMode(p,"Lobby");p:SetAttribute("OpponentId",0);p:SetAttribute("HP",100);p:SetAttribute("Stamina",100);p:SetAttribute("Blocking",false)
 collision(p,"TowerVisitor");if A.Tower then A.Tower.Return(p)else move(p,Vector3.new(0,4,118))end
end
local function part(parent,name,size,pos,col,mat)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=size;p.Position=pos;p.Color=col;p.Material=mat or Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
local function ring(m)
 local folder=Instance.new("Folder");folder.Name="Match_"..m.Id;folder:SetAttribute("Floor",m.Floor)
 local v=m.Center
 part(folder,"Canvas",Vector3.new(52,.3,52),v-Vector3.new(0,.1,0),Color3.fromRGB(34,57,80))
 for _,sign in ipairs({-1,1})do
  part(folder,"Edge",Vector3.new(52,.12,.5),v+Vector3.new(0,.12,sign*25),Color3.fromRGB(128,244,207))
  part(folder,"Edge",Vector3.new(.5,.12,52),v+Vector3.new(sign*25,.12,0),Color3.fromRGB(128,244,207))
  for _,sign2 in ipairs({-1,1})do
   part(folder,"Corner",Vector3.new(.8,4,.8),v+Vector3.new(sign*26,2,sign2*26),Color3.fromRGB(230,174,99))
  end
 end
 local center=part(folder,"CenterMark",Vector3.new(8,.1,8),v+Vector3.new(0,.1,0),Color3.fromRGB(48,84,106));center.Shape=Enum.PartType.Cylinder;center.Size=Vector3.new(.1,8,8);center.Orientation=Vector3.new(0,0,90)
 folder.Parent=workspace.SkySprout.Matches;m.Model=folder
end
local function frame(p,f)
 p:SetAttribute("HP",math.ceil(f.HP));p:SetAttribute("Stamina",math.floor(f.Stamina));p:SetAttribute("Blocking",f.Block);p:SetAttribute("Stunned",os.clock()<(f.Stun or 0))
 local h=hum(p)
 if h then h.WalkSpeed=(f.Match.Phase~="Fight"or os.clock()<(f.Stun or 0))and 0 or(f.Block and C.BlockSpeed or C.WalkSpeed);h.JumpPower=0 end
end
local function update(m)
 for _,p in ipairs(m.Players)do if p.Parent then
 event:FireClient(p,"Match",{Phase=m.Phase,Floor=m.Floor,Round=m.Round,ToWin=m.ToWin,Remaining=math.max(0,math.ceil((m.Deadline or 0)-os.clock())),Scores={m.Scores[1],m.Scores[2]},Names={m.Players[1].DisplayName,m.Players[2].DisplayName},Ids={m.Players[1].UserId,m.Players[2].UserId}})
 end end
end
function A.Finish(m,winner,reason)
 if m.Done then return end;m.Done=true;m.Phase="Finished"
 for i,p in ipairs(m.Players)do
  local d=data(p)
  local beforePoints=d and d.Points or 0;local beforeCoins=d and d.Coins or 0
  if d and winner then Rules.result(d,p==winner,m.Engaged);stats(p)end
  if p.Parent then event:FireClient(p,"Result",{Outcome=winner and(winner==p and"VICTORY"or"DEFEAT")or"DRAW",Reason=reason,RankDelta=d and d.Points-beforePoints or 0,CoinDelta=d and d.Coins-beforeCoins or 0,Floor=d and Rules.floor(d.Points)or 1,Promoted=false})end
  
  if p.Parent then tell(p,(winner and(winner==p and"VICTORY"or"DEFEAT")or"DRAW").." • "..reason)
  end
 end
 update(m)
 task.delay(4,function()
  for _,p in ipairs(m.Players)do if A.Fighters[p]and A.Fighters[p].Match==m then lobby(p)end end
  if m.Model then m.Model:Destroy()end;A.Matches[m.Id]=nil
 end)
end
local beginRound
function A.RoundOver(m,winner,reason)
 if m.Done or m.Phase~="Fight"then return end
 m.Phase="Break"
 if winner then local idx=m.Players[1]==winner and 1 or 2;m.Scores[idx]+=1
  if m.Scores[idx]>=m.ToWin then A.Finish(m,winner,reason);return end
 end
 for _,p in ipairs(m.Players)do local f=A.Fighters[p];if f then f.Block=false;frame(p,f)end;tell(p,reason..(winner and" • Round to "..winner.DisplayName or" • Round drawn"))end
 update(m);task.delay(C.RoundBreak,function()if not m.Done then beginRound(m)end end)
end
beginRound=function(m)
 if m.Done then return end
 for _,p in ipairs(m.Players)do if not(p.Parent and root(p)and hum(p)and hum(p).Health>0)then
  local other=m.Players[1]==p and m.Players[2]or m.Players[1];A.Finish(m,m.Engaged and other or nil,"Opponent unavailable");return end end
 m.Round+=1;m.Phase="Countdown";m.Deadline=os.clock()+C.Countdown
 for i,p in ipairs(m.Players)do
  local pos=m.Center+Vector3.new(i==1 and -9 or 9,3.5,0)
  move(p,pos,m.Center+Vector3.new(0,3.5,0))
  local f={Match=m,HP=C.Health,Stamina=C.Stamina,Block=false,Stun=0,NextAttack=0,NextDash=0,Invulnerable=0,Combo=0,LastPunch=0,Busy=0}
  A.Fighters[p]=f;p:SetAttribute("ArenaFloor",m.Floor);collision(p,"ArenaFighter");setMode(p,"Match");p:SetAttribute("OpponentId",m.Players[3-i].UserId);frame(p,f)
 end
 update(m)
 task.delay(C.Countdown,function()if not m.Done and m.Phase=="Countdown"then m.Phase="Fight";m.Deadline=os.clock()+C.RoundSeconds;update(m)end end)
end
function A.CanQueue(p)
 local h=hum(p);local d=data(p);local now=os.clock();local mode=p:GetAttribute("ArenaMode")
 if not(d and root(p)and h and h.Health>0)or A.Fighters[p]or p:GetAttribute("RPGRaid")or p:GetAttribute("TowerTraveling")or(mode~="Lobby"and mode~="Queue")then return false end
 local st=A.RPG and A.RPG.States[p]
 return not st or(now>=(st.CombatUntil or 0)and now>=st.Stun and now>=st.Next)
end
local function createMatch(p,q)
 if not A.CanQueue(p)or not A.CanQueue(q)then return false end
 local floor=math.min(data(p).BestFloor,data(q).BestFloor)
 local used={};for _,m in pairs(A.Matches)do if m.Floor==floor then used[m.Slot]=true end end
 local slot;for n=1,4 do if not used[n]then slot=n;break end end
 if not slot then return false end
 A.Queue[p]=nil;A.Queue[q]=nil;A.NextId+=1
 local m={Id=A.NextId,Players={p,q},Scores={0,0},Floor=floor,Slot=slot,Round=0,ToWin=floor%5==0 and 2 or 1,Engaged=false,Center=Vector3.new(slot<=2 and -36 or 36,C.BaseHeight+(floor-1)*C.FloorHeight,(slot%2==1)and -36 or 36)}
 A.Matches[m.Id]=m;ring(m);beginRound(m);return true
end
local function broadcast(m,kind,payload)
 for _,who in ipairs(m.Players)do if who.Parent then event:FireClient(who,kind,payload)end end
end
local function attack(p,f,heavy)
 local now=os.clock();local baseSpec=heavy and C.Heavy or C.Punch
 local style=require(RS.SkySproutRPGConfig).Styles[data(p).Style]
 local spec=table.clone(baseSpec);spec.Cooldown*=style.Speed;spec.Range+=style.Range-9;spec.Damage=math.floor(spec.Damage*style.Damage)
 if f.Match.Phase~="Fight"or f.Block or now<f.Stun or now<f.NextAttack or now<f.Busy or f.Stamina<spec.Cost then return end
 f.Stamina-=spec.Cost;f.NextAttack=now+spec.Cooldown;f.Busy=now+spec.Windup
 if not heavy then f.Combo=now-f.LastPunch<1 and f.Combo%3+1 or 1;f.LastPunch=now end
 local combo=f.Combo;local m=f.Match
 broadcast(m,"Attack",{UserId=p.UserId,Heavy=heavy,Combo=combo,Cooldown=spec.Cooldown})
 task.delay(spec.Windup,function()
  if A.Fighters[p]~=f or m.Done or m.Phase~="Fight"or os.clock()<f.Stun then return end
  local other=m.Players[1]==p and m.Players[2]or m.Players[1];local target=A.Fighters[other]
  local r=root(p);local o=root(other);if not(target and r and o)then return end
  local delta=o.Position-r.Position;local flat=Vector3.new(delta.X,0,delta.Z)
  if flat.Magnitude>spec.Range or math.abs(delta.Y)>5 or(flat.Magnitude>.1 and r.CFrame.LookVector:Dot(flat.Unit)<.15)or os.clock()<target.Invulnerable then return end
  m.Engaged=true;if A.RPG then A.RPG.RecordPvPHit(p)end
  local facing=flat.Magnitude<.1 or o.CFrame.LookVector:Dot(-flat.Unit)>0
  local blocked=target.Block and facing
  local damage=heavy and spec.Damage or(combo==3 and C.Punch.FinisherDamage or spec.Damage)
  if blocked then
   target.Stamina=math.max(0,target.Stamina-(heavy and 30 or 13))
   if heavy or target.Stamina==0 then target.Block=false;target.Stun=os.clock()+.8;damage=heavy and 16 or 4;tell(other,"GUARD BROKEN")
   else damage=2 end
  else target.Stun=os.clock()+.16 end
  target.HP=math.max(0,target.HP-damage);frame(other,target)
  if flat.Magnitude>.1 then o.AssemblyLinearVelocity=flat.Unit*(heavy and 24 or 9)+Vector3.new(0,2,0)end
  broadcast(m,"Impact",{UserId=other.UserId,Attacker=p.UserId,Damage=damage,Blocked=blocked,GuardBreak=blocked and not target.Block})
  if target.HP<=0 then local d=data(p);if d then d.Knockouts+=1 end;A.RoundOver(m,p,"Knockout")end
 end)
end
local function practice(p,heavy)
 local now=os.clock();if now<(p:GetAttribute("PracticeNext")or 0)then return end
 p:SetAttribute("PracticeNext",now+(heavy and 1.25 or .4))
 local r=root(p);if not r then return end
 event:FireClient(p,"Attack",{UserId=p.UserId,Heavy=heavy,Combo=(p:GetAttribute("PracticeHits")or 0)%3+1,Cooldown=heavy and C.Heavy.Cooldown or C.Punch.Cooldown})
 for _,b in ipairs(A.Tower and A.Tower.GetBags(p)or{})do if b:IsA("BasePart")then
 local delta=b.Position-r.Position
 if delta.Magnitude<9 and r.CFrame.LookVector:Dot(delta.Unit)>0 then
  local n=(p:GetAttribute("PracticeHits")or 0)+1;p:SetAttribute("PracticeHits",n);if A.Tower then A.Tower.RecordTraining(p)end;event:FireClient(p,"Practice",{Heavy=heavy,Count=n,Target=b})
  local orig=b.Color;b.Color=Color3.fromRGB(255,220,119);task.delay(.15,function()if b.Parent then b.Color=orig end end)
  return
 end end end
 tell(p,"Stand near a training bag and face it to practise.")
end
function A.HandleAction(p,action,value)
 if type(action)~="string"or not data(p)then return end
 local now=os.clock();local bucket=A.Buckets[p]or{N=30,T=now};A.Buckets[p]=bucket
 bucket.N=math.min(30,bucket.N+(now-bucket.T)*20);bucket.T=now
 if bucket.N<1 then return end;bucket.N-=1
 if A.Admin and A.Admin.BlockGameplay(p,action)then return end
 if action=="CancelTravel"then if A.Transit then A.Transit.Cancel(p,value)end;return end
 local f=A.Fighters[p]
 if A.World and p:GetAttribute("Mounted")and(action=="Punch"or action=="Heavy"or action=="Kick"or(action=="Block"and value==true)or action=="Queue"or action=="Dash"or action=="Skill1"or action=="Skill2"or action=="Awaken"or action=="Boss")then A.World.Dismount(p)end
 if A.Lava and A.Lava.HandleAction(p,action,value)then return end
 if A.RPG and A.RPG.HandleAction(p,action,value)then return end
 if A.Contracts and A.Contracts.HandleAction(p,action,value)then return end
 if A.Story and A.Story.HandleAction(p,action,value)then return end
 if A.World and A.World.HandleAction(p,action,value)then return end
 if action=="Kick"then action="Heavy"end
 if action=="Sync"then stats(p);if f then update(f.Match)end;if A.Tower then A.Tower.Sync(p)end;return end
 if action=="Travel"or action=="QuestSync"or action=="ClaimQuest"then if A.Tower then A.Tower.HandleAction(p,action,value)end;return end
 if action=="Queue"then
  if f or C.PartyMode then return end
  if A.Queue[p]then A.Queue[p]=nil;setMode(p,"Lobby");tell(p,"Queue cancelled.")
  else if not A.CanQueue(p)then tell(p,"Finish combat or travel before joining PvP.");return end
  A.Queue[p]=now;setMode(p,"Queue");tell(p,"Looking for another player near your floor…")end
 elseif action=="Skin"then
  if f or type(value)~="string"then return end
  local ok,msg=Rules.skin(data(p),value,A.Pass~=nil and A.Pass.Owns(p));if ok then stats(p);equip(p)end;tell(p,msg)
 elseif action=="Hat"then
  if type(value)~="string"then return end
  local ok,msg=Rules.hat(data(p),value);if ok then stats(p);if A.OnHat then A.OnHat(p)end end;tell(p,msg)
 elseif action=="Punch"or action=="Heavy"then
  if C.PartyMode and not f then return end
  if f then attack(p,f,action=="Heavy")else practice(p,action=="Heavy")end
 elseif action=="Block"then
  if f and type(value)=="boolean"then
   if not value then f.Block=false elseif f.Match.Phase=="Fight"and now>=f.Stun and now>=f.Busy and f.Stamina>0 then f.Block=true end
  end
 elseif action=="Dash"and f then
  if f.Match.Phase~="Fight"or now<f.Stun or now<f.Busy or now<f.NextDash or f.Stamina<C.Dash.Cost then return end
  if typeof(value)~="Vector3"or value.X~=value.X or value.Z~=value.Z or math.abs(value.X)>1.01 or math.abs(value.Z)>1.01 then return end
  local r=root(p);if not r then return end
  local dir=Vector3.new(value.X,0,value.Z);if dir.Magnitude<.1 then dir=-r.CFrame.LookVector else dir=dir.Unit end
  f.Stamina-=C.Dash.Cost;f.Block=false;f.Invulnerable=now+C.Dash.Invulnerability;f.NextDash=now+C.Dash.Cooldown;f.Busy=now+C.Dash.Duration
  local attachment=Instance.new("Attachment");attachment.Parent=r
  local velocity=Instance.new("LinearVelocity");velocity.Attachment0=attachment;velocity.MaxForce=100000;velocity.VectorVelocity=dir*C.Dash.Speed;velocity.Parent=r
  game:GetService("Debris"):AddItem(velocity,C.Dash.Duration);game:GetService("Debris"):AddItem(attachment,C.Dash.Duration+.02)
  broadcast(f.Match,"Dodge",{UserId=p.UserId,Cooldown=C.Dash.Cooldown})
 end
end
function A.RelicSkill(p,slot)
 local f=A.Fighters[p];if not f or f.Match.Phase~="Fight"or os.clock()<f.Stun or os.clock()<f.Busy or f.Stamina<25 then return false end
 f.Stamina-=25;f.Busy=os.clock()+.4;f.Block=false
 local other=f.Match.Players[1]==p and f.Match.Players[2]or f.Match.Players[1]
 local target=A.Fighters[other];local r=root(p);local o=root(other)
 if not(target and r and o)then return false end
 local delta=o.Position-r.Position;local flat=Vector3.new(delta.X,0,delta.Z)
 if flat.Magnitude>(slot==1 and 24 or 14)or math.abs(delta.Y)>6 or os.clock()<target.Invulnerable or(slot==1 and flat.Magnitude>.1 and r.CFrame.LookVector:Dot(flat.Unit)<.7)then return false end
 local blocked=target.Block;local damage=blocked and 3 or(slot==1 and 15 or 20)
 target.HP=math.max(0,target.HP-damage);target.Stun=os.clock()+.2;f.Match.Engaged=true;frame(other,target)
 broadcast(f.Match,"Impact",{UserId=other.UserId,Attacker=p.UserId,Damage=damage,Blocked=blocked})
 if target.HP<=0 then A.RoundOver(f.Match,p,"Relic knockout")end
 return true
end
function A.Start()
 if A.Started then return end;A.Started=true;A.Buckets={}
 event=RS:FindFirstChild("ArenaEvent")or Instance.new("RemoteEvent");event.Name="ArenaEvent";event.Parent=RS
 event.OnServerEvent:Connect(A.HandleAction)
 local physics=game:GetService("PhysicsService");pcall(function()physics:RegisterCollisionGroup("TowerVisitor")end);pcall(function()physics:RegisterCollisionGroup("ArenaFighter")end);physics:CollisionGroupSetCollidable("TowerVisitor","ArenaFighter",false);physics:CollisionGroupSetCollidable("ArenaFighter","ArenaFighter",false);physics:CollisionGroupSetCollidable("TowerVisitor","TowerVisitor",false)
 A.Transit=require(script.Parent.SkySproutTransit);A.Transit.Start(event)
 A.Tower=require(script.Parent.SkySproutTowerService);A.Tower.Start(A,event,stats,tell)
 if not C.PartyMode then
  A.RPG=require(script.Parent.SkySproutRPGService);A.RPG.Start(A,event,stats,tell)
  A.Story=require(script.Parent.SkySproutStoryService);A.Story.Start(A,event,stats,tell)
  A.Contracts=require(script.Parent.SkySproutContractsService);A.Contracts.Start(A,event,stats,tell)
  A.Wilds=require(script.Parent.SkySproutWildsService);A.Wilds.Start(A,event,stats)
  A.World=require(script.Parent.SkySproutWorldService);A.World.Start(A,event,tell)
  A.Portals=require(script.Parent.SkySproutPortalService);A.Portals.Start(A,event,tell)
 end
 A.Admin=require(script.Parent.SkySproutAdminService);A.Admin.Start(A,stats,tell)
 A.Lava=require(script.Parent.SkySproutLavaService);A.Lava.Start(A,event,stats,tell)
 A.Pass=require(script.Parent.SkySproutPassService);A.Pass.Start(A,tell)
 A.Shop=require(script.Parent.SkySproutShopService);A.Shop.Start(A,stats,tell)
 local function character(p,ch)
  ch.DescendantAdded:Connect(function(d)if d:IsA("BasePart")then d.CollisionGroup=A.Fighters[p]and"ArenaFighter"or"TowerVisitor"elseif d:IsA("Script")and d.Name=="Health"then d.Disabled=true end end)
  local h=ch:WaitForChild("Humanoid");ch:WaitForChild("HumanoidRootPart");h.MaxHealth=100;h.Health=100
  task.wait(.25)
  local regen=ch:FindFirstChild("Health");if regen and regen:IsA("Script")then regen.Disabled=true end
  if not p.Parent then return end
  local f=A.Fighters[p];if f then
   local m=f.Match;local other=m.Players[1]==p and m.Players[2]or m.Players[1];A.Finish(m,m.Engaged and other or nil,"Opponent reset")
  end
  A.Queue[p]=nil;if A.RPG then A.RPG.Reset(p)end;lobby(p);equip(p)
  h.Died:Connect(function()
   A.Queue[p]=nil
   local active=A.Fighters[p]
   if active then local m=active.Match;A.Finish(m,m.Engaged and(m.Players[1]==p and m.Players[2]or m.Players[1])or nil,"Opponent reset")end
  end)
 end
 local function added(p)
  setMode(p,"Loading");local s=Profiles.load(p)
  if not s then p:Kick("Your saved profile is still open. Please rejoin shortly.");return end
  if not p.Parent then Profiles.save(p,true);return end
  A.Admin.ProfileLoaded(p,s.Data)
  local ls=Instance.new("Folder");ls.Name="leaderstats";ls.Parent=p
  for _,k in ipairs(C.PartyMode and{"👑 Crowns","💰 Coins"}or{"Level","Access","Wins","👑 Crowns"})do local v=Instance.new("IntValue");v.Name=k;v.Parent=ls end
  stats(p);p.CharacterAdded:Connect(function(ch)character(p,ch)end)
  if p.Character then task.spawn(character,p,p.Character)end
 end
 Players.PlayerAdded:Connect(added);for _,p in ipairs(Players:GetPlayers())do task.spawn(added,p)end
 Players.PlayerRemoving:Connect(function(p)
  A.Queue[p]=nil;A.Buckets[p]=nil;local f=A.Fighters[p]
  if f then local m=f.Match;local other=m.Players[1]==p and m.Players[2]or m.Players[1];A.Finish(m,m.Engaged and other or nil,"Opponent left")end
  A.Fighters[p]=nil;Profiles.save(p,true)
 end)
 local elapsed=0;local pairTime=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;pairTime+=dt
  for p,f in pairs(A.Fighters)do
   if not f.Match.Done and f.Match.Phase=="Fight"then
    f.Stamina=math.clamp(f.Stamina+(f.Block and -5 or(os.clock()>f.Busy and 12 or 0))*dt,0,100)
    if f.Stamina<=0 then f.Block=false end
    local r=root(p);local m=f.Match
    if r and(math.abs(r.Position.X-m.Center.X)>25 or math.abs(r.Position.Z-m.Center.Z)>25 or r.Position.Y<m.Center.Y-3 or r.Position.Y>m.Center.Y+14)then A.RoundOver(m,m.Players[1]==p and m.Players[2]or m.Players[1],"Ring out")end
   end
   if elapsed>=.1 then frame(p,f)end
  end
  if elapsed>=.1 then elapsed=0 end
  if pairTime<.5 then return end;pairTime=0
  local list={};for p,t in pairs(A.Queue)do if p.Parent and data(p)and root(p)then table.insert(list,{p=p,t=t})else A.Queue[p]=nil end end
  table.sort(list,function(a,b)return a.t<b.t end)
  for i,a in ipairs(list)do if A.Queue[a.p]then for j=i+1,#list do local b=list[j]
   if A.Queue[b.p]and math.abs(Rules.floor(data(a.p).Points)-Rules.floor(data(b.p).Points))<=(os.clock()-a.t>20 and 2 or 1)then
    if createMatch(a.p,b.p)then break end
   end
  end end end
  for _,m in pairs(A.Matches)do
   if not m.Done then
    if m.Phase=="Fight"and os.clock()>=m.Deadline then
     local a=A.Fighters[m.Players[1]];local b=A.Fighters[m.Players[2]]
     if a and b then local winner;if a.HP~=b.HP then winner=a.HP>b.HP and m.Players[1]or m.Players[2]end;A.RoundOver(m,winner,"Time")end
    end
    update(m)
   end
  end
 end)
 print(C.PartyMode and"Party mode ready — lobby + Lava Rush only."or"Skybound Arena ready — PvP matchmaking online.")
end
return A
