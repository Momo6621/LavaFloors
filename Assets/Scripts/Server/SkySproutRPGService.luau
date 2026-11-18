local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local D=require(RS.SkySproutRPGConfig)
local G=require(RS.SkySproutGuardianConfig)
local Themes=require(RS.SkySproutWorldThemes)
local C=require(RS.SkySproutConfig)
local Profiles=require(script.Parent.SkySproutProfiles)
local R={Encounters={},States={}}
local A,event,stats,tell,world
local function data(p)local s=Profiles.Sessions[p];return s and s.Data end
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function hum(p)return p.Character and p.Character:FindFirstChildOfClass("Humanoid")end
local function state(p)
 if not R.States[p]then R.States[p]={Energy=100,Charge=0,Awake=0,Next=0,Dash=0,Inv=0,Stun=0,Block=false,History="",Last=0,Skills={0,0},Combo=0,CombatUntil=0}end
 return R.States[p]
end
function R.Level(d)return math.min(50,1+math.floor(math.sqrt((d.XP or 0)/80)))end
function R.Sync(p)
 local d=data(p);if not d then return end
 local s=state(p);local lv=R.Level(d)
 p:SetAttribute("InCombat",os.clock()<(s.CombatUntil or 0)or A.Fighters[p]~=nil or p:GetAttribute("RPGRaid")==true)
 local ls=p:FindFirstChild("leaderstats");if ls then ls.Level.Value=lv end
 p:SetAttribute("RPGLevel",lv);p:SetAttribute("XP",d.XP);p:SetAttribute("CombatStyle",d.Style);p:SetAttribute("Relic",d.Relic);p:SetAttribute("RelicCharge",math.floor(s.Charge));p:SetAttribute("RelicAwake",os.clock()<s.Awake)
 p:SetAttribute("RPGStamina",math.floor(s.Energy));p:SetAttribute("BossCleared",d.BossClears[tostring(p:GetAttribute("VisitFloor")or 1)]==true)
 local h=hum(p)
 if h and not A.Fighters[p]then
  p:SetAttribute("Stunned",os.clock()<s.Stun)
  h.MaxHealth=100+(lv-1)*4;p:SetAttribute("RPGHP",math.ceil(h.Health));p:SetAttribute("RPGMaxHP",h.MaxHealth)
 end
end
function R.AwardXP(p,amount)
 local d=data(p);if not d then return end
 local before=R.Level(d);d.XP=math.min(200000,d.XP+amount)
 if R.Level(d)>before then tell(p,"LEVEL UP • Character level "..R.Level(d));local h=hum(p);if h and not A.Fighters[p]then h.MaxHealth=100+(R.Level(d)-1)*4;h.Health=h.MaxHealth end end
 R.Sync(p)
end
local function part(parent,name,size,cf,col)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=col;p.Material=Enum.Material.Slate;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.Parent=parent;return p
end
local function enemy(enc,pos,boss,index)
 local f=enc.Floor;local m=Instance.new("Model");m.Name=boss and D.Guardians[f]or"Guardian Disciple"
 local scale=boss and 1.55+f*.015 or .85
 local theme=Themes[f];local col=theme.Accent:Lerp(theme.Roof,.5)
 local body=part(m,"HumanoidRootPart",Vector3.new(4,5,3)*scale,CFrame.new(pos+Vector3.new(0,4,0)),col);m.PrimaryPart=body
 local head=part(m,"Head",Vector3.new(2.6,2.3,2.5)*scale,body.CFrame*CFrame.new(0,3.5*scale,0),theme.Ground:Lerp(Color3.new(1,1,1),.35))
 if boss then
  m:SetAttribute("GuardianTheme",theme.Id);m:SetAttribute("Phase",1)
  if theme.Id=="Halloween"or theme.Id=="Haunted"then head.Shape=Enum.PartType.Ball;head.Color=theme.Accent
   part(m,"LanternStem",Vector3.new(.65,.8,.65)*scale,head.CFrame*CFrame.new(0,1.4*scale,0),Color3.fromRGB(83,103,61))
  elseif theme.Id=="Tech"or theme.Id=="Cyber"or theme.Id=="Clockwork"then
   local visor=part(m,"SignalVisor",Vector3.new(3,.55,.3)*scale,head.CFrame*CFrame.new(0,.1,-1.3*scale),theme.Accent);visor.Material=Enum.Material.Neon
  elseif theme.Id=="Pirate"or theme.Id=="Storm"then
   part(m,"AdmiralHat",Vector3.new(4,.7,3.4)*scale,head.CFrame*CFrame.new(0,1.3*scale,0),Color3.fromRGB(35,43,53))
   part(m,"HatCrest",Vector3.new(1,1,.35)*scale,head.CFrame*CFrame.new(0,1.9*scale,-.4*scale),theme.Accent)
  else
   for _,side in {-1,0,1}do local spike=part(m,"CrownSigil",Vector3.new(.5,side==0 and 1.8 or 1.1,.5)*scale,head.CFrame*CFrame.new(side*.9*scale,1.7*scale,0),theme.Accent);spike.Material=Enum.Material.Neon end
  end
 end
 for _,side in {-1,1}do
  part(m,"Arm",Vector3.new(2,5,2)*scale,body.CFrame*CFrame.new(side*3*scale,-.2*scale,0),col:Lerp(Color3.fromRGB(242,200,111),.3))
  part(m,"Leg",Vector3.new(1.7,3.5,2)*scale,body.CFrame*CFrame.new(side*1.1*scale,-3.5*scale,0),col)
  local eye=part(m,"Eye",Vector3.new(.55,.4,.25)*scale,body.CFrame*CFrame.new(side*.6*scale,3.65*scale,-1.3*scale),Color3.fromRGB(140,245,236));eye.Material=Enum.Material.Neon
 end
 local core=part(m,"Core",Vector3.new(1.5,1.5,.4)*scale,body.CFrame*CFrame.new(0,.7,-1.6*scale),Color3.fromRGB(255,209,131));core.Material=Enum.Material.Neon
 local hp=boss and (320+f*60)*(1+.55*(enc.Joined-1))or 45+f*7
 local b=Instance.new("BillboardGui");b.Size=UDim2.fromOffset(boss and 230 or 150,50);b.StudsOffset=Vector3.new(0,7*scale,0);b.MaxDistance=160;b.AlwaysOnTop=false;b.Parent=body
 local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundColor3=Color3.fromRGB(27,44,58);text.BackgroundTransparency=.2;text.TextColor3=Color3.fromRGB(235,240,220);text.Font=Enum.Font.GothamBold;text.TextSize=boss and 15 or 12;text.Parent=b
 m:SetAttribute("CombatNPC",true);m:SetAttribute("NPCFloor",f);m:SetAttribute("HP",hp);m:SetAttribute("MaxHP",hp);game:GetService("CollectionService"):AddTag(m,"SkyboundCombatNPC")
 m.Parent=enc.Model
 local e={Model=m,Root=body,HP=hp,MaxHP=hp,Boss=boss,Next=os.clock()+2,Stun=0,Phase=1,Home=pos,Index=index or 1,Text=text,Dead=false}
 table.insert(enc.Enemies,e);return e
end
local function participants(enc)
 local a={}
 for p in pairs(enc.Players)do local r=root(p);local h=hum(p)
  if p.Parent and h and h.Health>0 and r and p:GetAttribute("VisitFloor")==enc.Floor and not A.Fighters[p]and (r.Position-enc.Center).Magnitude<67 then table.insert(a,p)end
 end
 return a
end
local function warning(enc,pos,kind,radius,dir,duration,damage,hitOnce,pattern,order)
 if enc.Done then return end
 local shape=part(enc.Model,"AttackWarning",kind=="Line"and Vector3.new(8,.14,radius)or Vector3.new(.14,radius*2,radius*2),CFrame.new(pos.X,enc.Center.Y+.3,pos.Z),Color3.fromRGB(255,132,101))
 shape.Material=Enum.Material.Neon;shape.Transparency=.55;shape.CanQuery=false;shape.CastShadow=false
 shape:SetAttribute("Warning",true);shape:SetAttribute("EssentialCombatWarning",true);shape:SetAttribute("Pattern",pattern or kind)
 if order then
  shape:SetAttribute("StrikeOrder",order)
  local b=Instance.new("BillboardGui");b.Name="StrikeOrder";b.Size=UDim2.fromOffset(40,28);b.StudsOffset=Vector3.new(0,1,0);b.MaxDistance=90;b.Parent=shape
  local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=tostring(order);t.Font=Enum.Font.GothamBold;t.TextSize=22;t.TextColor3=Color3.new(1,1,1);t.TextStrokeTransparency=.3;t.Parent=b
 end
 if kind=="Line"then shape.CFrame=CFrame.lookAt(shape.Position,shape.Position+dir)*CFrame.new(0,0,-radius/2)
 else shape.Shape=Enum.PartType.Cylinder;shape.CFrame*=CFrame.Angles(0,0,math.pi/2)end
 if kind=="Ring"then
  local safe=part(enc.Model,"SafeCenter",Vector3.new(.18,radius*.94,radius*.94),CFrame.new(pos.X,enc.Center.Y+.4,pos.Z)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(128,244,207));safe.Shape=Enum.PartType.Cylinder;safe.Material=Enum.Material.Neon;safe.Transparency=.2;safe.CanQuery=false;safe.CastShadow=false;safe:SetAttribute("EssentialCombatWarning",true);Debris:AddItem(safe,duration+.25)
 end
 Debris:AddItem(shape,duration+.25)
 task.delay(duration,function()
  if enc.Done or not shape.Parent then return end
  shape.Color=Color3.fromRGB(255,220,151);shape.Transparency=.15
  for _,p in participants(enc)do local r=root(p);local s=state(p);local h=hum(p)
   local flat=Vector3.new(r.Position.X-pos.X,0,r.Position.Z-pos.Z);local inside
   if kind=="Line"then local v=shape.CFrame:PointToObjectSpace(r.Position);inside=math.abs(v.X)<4 and math.abs(v.Z)<radius/2
   elseif kind=="Ring"then inside=flat.Magnitude<radius and flat.Magnitude>radius*.48
   else inside=flat.Magnitude<radius end
   if inside and os.clock()>s.Inv and math.abs(r.Position.Y-enc.Center.Y)<10 and(not hitOnce or not hitOnce[p])then
    if hitOnce then hitOnce[p]=true end
    local amount=damage
    if s.Block then amount=math.ceil(amount*.3);s.Energy=math.max(0,s.Energy-24);if s.Energy==0 then s.Block=false;s.Stun=os.clock()+.7 end end
    h:TakeDamage(amount);event:FireAllClients("Impact",{UserId=p.UserId,Damage=amount,Blocked=s.Block,GuardBreak=s.Energy==0})
   end
  end
 end)
end
function R.Pattern(enc,e,target,forced)
 local r=root(target);if not r or enc.Done or e.Dead or not e.Root.Parent then return end
 local kind=forced or(e.Boss and G.Select(enc.Floor,enc.Pattern,e.Phase)or((e.Index+enc.Pattern)%3==0 and"Line"or((e.Index+enc.Pattern)%3==1 and"Circle"or"Ring")))
 if not G.Cues[kind]then return end
 local pos=e.Root.Position;local destination=r.Position
 local delta=Vector3.new(destination.X-pos.X,0,destination.Z-pos.Z);local dir=delta.Magnitude>.1 and delta.Unit or Vector3.new(0,0,1)
 local delay=e.Boss and(e.Phase==2 and 1.05 or 1.3)or .95
 local damage=e.Boss and(16+math.floor(enc.Floor*.7))or 8
 local grouped={};local count=0;local total=delay
 local function strike(at,shape,radius,direction,time,order)
  count+=1;total=math.max(total,time)
  warning(enc,at,shape,radius,direction,time,damage,grouped,kind,order)
 end
 if kind=="Cross"then
  local perpendicular=Vector3.new(-dir.Z,0,dir.X)
  strike(destination-dir*18,"Line",36,dir,delay,1)
  strike(destination-perpendicular*18,"Line",36,perpendicular,delay,1)
 elseif kind=="Sweep"then
  for i=1,3 do
   local rotated=CFrame.fromAxisAngle(Vector3.yAxis,(i-2)*.58):VectorToWorldSpace(dir)
   strike(pos,"Line",42,rotated,delay+(i-1)*.32,i)
  end
 elseif kind=="Barrage"then
  local side=Vector3.new(-dir.Z,0,dir.X)
  for i=1,3 do strike(destination+side*(i-2)*14,"Circle",8,dir,delay+(i-1)*.32,i)end
 elseif kind=="Line"then strike(pos,"Line",44,dir,delay)
 elseif kind=="Ring"then strike(pos,"Ring",e.Boss and 19 or 7,dir,delay)
 else strike(destination,"Circle",e.Boss and 13 or 7,dir,delay)end
 if e.Boss then
  e.Model:SetAttribute("AttackPattern",kind);e.Model:SetAttribute("Phase",e.Phase)
  for _,p in participants(enc)do event:FireClient(p,"BossCue",{Text=G.Cues[kind],Duration=total,Pattern=kind,Phase=e.Phase})end
 end
 enc.Pattern+=1
 return {Kind=kind,Warnings=count,Duration=total,Windup=delay,Damage=damage}
end
local function finish(enc)
 if enc.Done then return end;enc.Done=true
 for _,p in participants(enc)do local d=data(p)
  if d and(enc.Players[p].Damage>0 or enc.Players[p].Support>0)then
   local first=not d.BossClears[tostring(enc.Floor)]
   if first then
    d.BossClears[tostring(enc.Floor)]=true;d.BestFloor=math.max(d.BestFloor,math.min(C.MaxFloor,enc.Floor+1));d.Coins+=100+enc.Floor*10
    R.AwardXP(p,180+enc.Floor*40)
    tell(p,enc.Floor<C.MaxFloor and("GUARDIAN CLEARED • Floor "..(enc.Floor+1).." unlocked!")or"TOWER CONQUERED • The Crown Warden has fallen!")
   else d.Coins+=20;R.AwardXP(p,35);tell(p,"Guardian defeated • +20 coins • +35 XP")end
   stats(p);R.Sync(p);if A.Story then A.Story.Sync(p)end;event:FireClient(p,"BossVictory",{Floor=enc.Floor,Next=d.BestFloor,First=first})
  end
 end
 for p in pairs(enc.Players)do if p.Parent then p:SetAttribute("RPGRaid",false);event:FireClient(p,"BossState",{Active=false})end end
 task.delay(3,function()if enc.Model.Parent then enc.Model:Destroy()end;if R.Encounters[enc.Floor]==enc then R.Encounters[enc.Floor]=nil end end)
end
local function hurt(p,enc,e,damage,launch)
 if e.Dead or enc.Done or not enc.Players[p]then return end
 e.HP=math.max(0,e.HP-damage);e.Model:SetAttribute("HP",e.HP);enc.Players[p].Damage+=damage
 local s=state(p);s.Charge=math.min(100,s.Charge+7)
 e.Stun=os.clock()+(launch and .75 or .2)
 event:FireAllClients("NPCImpact",{Target=e.Root,Damage=damage,Launch=launch})
 if e.HP<=0 then
  e.Dead=true;e.Model:Destroy()
  if e.Boss then finish(enc)else
   local d=data(p);if d then d.Hunts[tostring(enc.Floor)]=math.min(3,(d.Hunts[tostring(enc.Floor)]or 0)+1)end
   R.AwardXP(p,12+enc.Floor*2)
  end
 end
end
function R.Leave(p)
 for _,enc in pairs(R.Encounters)do
  if enc.Players[p]then enc.Players[p]=nil;if p.Parent then event:FireClient(p,"BossState",{Active=false})end end
 end
 p:SetAttribute("RPGRaid",false)
end
function R.Challenge(p,f,pr)
 local d=data(p);local r=root(p);local h=hum(p)
 if not(d and r and h and h.Health>0)or A.Fighters[p]or type(f)~="number"or f%1~=0 or f<1 or f>C.MaxFloor or f>d.BestFloor or p:GetAttribute("VisitFloor")~=f then return false end
 if A.Story and not A.Story.IsReady(d,f)then tell(p,"Complete Mira’s expedition route on this floor before challenging its guardian. Open Quests for your next destination.");A.Story.Sync(p);return false end
 local floor=A.Tower.Floors[f];local gate=floor.Landscape.GuardianGate
 if (r.Position-gate.Position).Magnitude>15 then return false end
 local enc=R.Encounters[f]
 if enc and enc.Done then tell(p,"The guardian court is resetting.");return false end
 if enc and enc.Players[p]then return false end
 if enc and #participants(enc)>=4 then tell(p,"This guardian party is full (4 players).");return false end
 A.Queue[p]=nil;p:SetAttribute("ArenaMode","Lobby")
 if not enc then
  local model=Instance.new("Folder");model.Name="Guardian_"..f;model.Parent=world
  enc={Floor=f,Center=floor:GetAttribute("BossCenter"),Players={},Enemies={},Model=model,Pattern=0,Joined=0,Started=os.clock(),Done=false,Wave="Disciples"}
  R.Encounters[f]=enc
 end
 enc.Joined+=1;enc.Players[p]={Damage=0,Support=0};p:SetAttribute("RPGRaid",true)
 h.MaxHealth=100+(R.Level(d)-1)*4;h.Health=h.MaxHealth;local s=state(p);s.Energy=100;s.Block=false;s.Charge=math.max(50,s.Charge)
 p.Character:PivotTo(CFrame.lookAt(enc.Center+Vector3.new((enc.Joined-2.5)*6,3,22),enc.Center))
 if enc.Joined==1 then for i=1,3 do enemy(enc,enc.Center+Vector3.new((i-2)*12,0,-4),false,i)end
 elseif enc.Boss and not enc.Boss.Dead then enc.Boss.MaxHP+=math.floor((320+f*60)*.55);enc.Boss.HP+=math.floor((320+f*60)*.55);enc.Boss.Model:SetAttribute("HP",enc.Boss.HP);enc.Boss.Model:SetAttribute("MaxHP",enc.Boss.MaxHP)end
 tell(p,"GUARDIAN CHALLENGE • Defeat the disciples, then the guardian. Up to 4 players can join.");R.Sync(p);return true
end
local function attack(p,key)
 local d=data(p);local r=root(p);local h=hum(p);if not(d and r and h and h.Health>0)then return end
 local s=state(p);local now=os.clock();local style=D.Styles[d.Style]
 local heavy=key=="H";local cost=heavy and 20 or(key=="K"and 10 or 6);local cooldown=(heavy and .85 or(key=="K"and .52 or .34))*style.Speed
 if now<s.Next or now<s.Stun or s.Block or s.Energy<cost then return end
 s.Next=now+cooldown;s.Energy-=cost;s.History=now-s.Last<1.15 and(s.History..(heavy and"K"or key)):sub(-4)or key;s.Last=now
 s.Combo=s.History=="PPPP"and 4 or #s.History
 local chain=d.Style=="Gale"and"PPPP"or"PPP"
 local finisher=s.History:sub(-#chain)==chain or s.History:sub(-3)=="KKK"
 local launch=s.History:sub(-2)=="PK"
 local damage=math.floor((heavy and 27 or(key=="K"and 17 or 11))*style.Damage*(1+(R.Level(d)-1)*.035)*(now<s.Awake and 1.2 or 1)*(finisher and 1.4 or 1))
 event:FireAllClients("Attack",{UserId=p.UserId,Heavy=heavy,Kick=key=="K",Combo=s.Combo,Cooldown=cooldown})
 event:FireClient(p,"Combo",{Text=launch and"PK • LAUNCHER"or(finisher and(s.History.." • FINISHER")or s.History),Style=style.Name})
 if finisher then s.History=""end
 task.delay(heavy and .3 or .12,function()
  if not p.Parent or A.Fighters[p]or hum(p)~=h or h.Health<=0 or os.clock()<s.Stun then return end
  local rr=root(p);if not rr then return end
  local enc=R.Encounters[p:GetAttribute("VisitFloor")or 1]
  if enc and enc.Players[p]then for _,e in enc.Enemies do if not e.Dead then
   local v=e.Root.Position-rr.Position;local flat=Vector3.new(v.X,0,v.Z)
   if flat.Magnitude<style.Range+(e.Boss and 3 or 0)and math.abs(v.Y)<12 and(flat.Magnitude<.1 or rr.CFrame.LookVector:Dot(flat.Unit)>.1)then hurt(p,enc,e,damage,launch or finisher)end
  end end end
  if A.Wilds then A.Wilds.Hit(p,damage,style.Range,.1,launch or finisher,false)end
  for _,bag in A.Tower.GetBags(p)do local v=bag.Position-rr.Position
   if v.Magnitude<9 and rr.CFrame.LookVector:Dot(v.Unit)>.1 then
    A.Tower.RecordTraining(p);p:SetAttribute("PracticeHits",(p:GetAttribute("PracticeHits")or 0)+1)
    event:FireClient(p,"Practice",{Heavy=heavy,Count=p:GetAttribute("PracticeHits"),Target=bag});break
   end
  end
 end)
end
local function skill(p,slot)
 local d=data(p);local r=root(p);local h=hum(p);local s=state(p);local now=os.clock()
 if not(d and r and h and h.Health>0)or(slot~=1 and slot~=2)or now>=s.Awake or now<s.Skills[slot]or now<s.Stun or s.Energy<25 then return end
 s.Skills[slot]=now+(slot==1 and 5 or 9);s.Energy-=25;s.Block=false
 local relic=D.Relics[d.Relic];local enc=R.Encounters[p:GetAttribute("VisitFloor")or 1]
 local pos=r.Position;local dir=r.CFrame.LookVector
 if A.Fighters[p]then
  if A.RelicSkill then A.RelicSkill(p,slot)end
 else
  if d.Relic=="Tide"and slot==2 then
   if enc and enc.Players[p]then for _,who in participants(enc)do local hr=root(who);local hh=hum(who)
    if (hr.Position-pos).Magnitude<24 then local heal=math.min(30,hh.MaxHealth-hh.Health);hh.Health+=heal;enc.Players[p].Support+=heal end
   end end
   h.Health=math.min(h.MaxHealth,h.Health+20)
  elseif enc and enc.Players[p]then
   for _,e in enc.Enemies do if not e.Dead then local v=e.Root.Position-pos;local flat=Vector3.new(v.X,0,v.Z);local dot=flat.Magnitude<.1 and 1 or dir:Dot(flat.Unit)
    local hit=slot==2 and flat.Magnitude<20 or(slot==1 and flat.Magnitude<37 and dot>.72)
    if hit and math.abs(v.Y)<15 then hurt(p,enc,e,math.floor((slot==2 and 48 or 38)*(1+(R.Level(d)-1)*.035)),d.Relic=="Storm")end
   end end
  end
 end
 if not A.Fighters[p]and A.Wilds and not(d.Relic=="Tide"and slot==2)then A.Wilds.Hit(p,math.floor((slot==2 and 48 or 38)*(1+(R.Level(d)-1)*.035)),slot==2 and 20 or 37,.72,d.Relic=="Storm",slot==2)end
 event:FireAllClients("RelicFX",{UserId=p.UserId,Position=pos,Direction=dir,Color=relic.Color,Slot=slot,Name=relic.Skills[slot]})
 event:FireClient(p,"SkillCooldown",{Slot=slot,Seconds=slot==1 and 5 or 9})
end
function R.HandleAction(p,action,value)
 local d=data(p);if not d then return false end
 local f=A.Fighters[p];local s=state(p);local now=os.clock()
 if action=="RPGSync"then R.Sync(p);return true end
 if action=="EquipStyle"or action=="EquipRelic"then
  if f or p:GetAttribute("RPGRaid")or type(value)~="string"then return true end
  local spec=action=="EquipStyle"and D.Styles[value]or D.Relics[value]
  if not spec or spec.Floor>d.BestFloor then tell(p,"Clear more floor guardians to unlock that equipment.");return true end
  if action=="EquipStyle"then d.Style=value else d.Relic=value;s.Awake=0 end;R.Sync(p);tell(p,spec.Name.." equipped.");return true
 elseif action=="Boss"then R.Challenge(p,value);return true
 elseif action=="LeaveRaid"then R.Leave(p);A.Tower.Return(p);return true
 elseif action=="Awaken"then
  if now<s.Awake or s.Charge<50 or not hum(p)or hum(p).Health<=0 or(f and f.Match.Phase~="Fight")then return true end
  s.Charge-=50;s.Awake=now+15;R.Sync(p);tell(p,"RELIC AWAKENED • Z / X skills available for 15 seconds.");return true
 elseif action=="Skill1"or action=="Skill2"then skill(p,action=="Skill1"and 1 or 2);return true
 end
 if f then return false end
 if action=="Punch"or action=="Kick"or action=="Heavy"then attack(p,action=="Punch"and"P"or(action=="Kick"and"K"or"H"));return true
 elseif action=="Block"and type(value)=="boolean"then s.Block=value and now>=s.Stun and now>=s.Next and s.Energy>0 or false;p:SetAttribute("Blocking",s.Block);return true
 elseif action=="Dash"then
  if typeof(value)~="Vector3"or value.X~=value.X or value.Z~=value.Z or math.abs(value.X)>1.01 or math.abs(value.Z)>1.01 or now<s.Dash or now<s.Stun or s.Energy<22 then return true end
  local r=root(p);local h=hum(p);if not(r and h and h.Health>0)then return true end
  local dir=Vector3.new(value.X,0,value.Z);dir=dir.Magnitude>.1 and dir.Unit or-r.CFrame.LookVector
  s.Dash=now+1.4;s.Inv=now+.28;s.Block=false;s.Energy-=22
  local att=Instance.new("Attachment",r);local v=Instance.new("LinearVelocity");v.Attachment0=att;v.MaxForce=100000;v.VectorVelocity=dir*60;v.Parent=r;Debris:AddItem(v,.16);Debris:AddItem(att,.18)
  event:FireAllClients("Dodge",{UserId=p.UserId,Cooldown=1.4});return true
 elseif action=="Queue"and p:GetAttribute("RPGRaid")then tell(p,"Leave the guardian challenge before joining PvP.");return true end
 return false
end
function R.Reset(p)R.Leave(p);R.States[p]=nil end
function R.RecordPvEHit(p)
 local s=state(p);s.Charge=math.min(100,s.Charge+6);s.CombatUntil=os.clock()+6
end
function R.ApplyPvEDamage(p,amount,source)
 local h=hum(p);local r=root(p);local s=state(p);local now=os.clock()
 if not(h and r and h.Health>0)or A.Fighters[p]or p:GetAttribute("RPGRaid")or now<s.Inv then return false end
 local delta=source-r.Position;local flat=Vector3.new(delta.X,0,delta.Z)
 if math.abs(delta.Y)>8 then return false end
 local block=s.Block and(flat.Magnitude<.1 or r.CFrame.LookVector:Dot(flat.Unit)>.1)
 if block then amount=math.ceil(amount*.3);s.Energy=math.max(0,s.Energy-20)
  if s.Energy==0 then s.Block=false;s.Stun=now+.7 end
 else s.Stun=now+.18 end
 if A.World then A.World.Dismount(p)end
 s.CombatUntil=now+6;h:TakeDamage(amount)
 event:FireAllClients("Impact",{UserId=p.UserId,Damage=amount,Blocked=block,GuardBreak=block and not s.Block});return true
end
function R.RecordPvPHit(p)local s=state(p);s.Charge=math.min(100,s.Charge+10)end
function R.Start(arena,remote,pushStats,notice)
 A=arena;event=remote;stats=pushStats;tell=notice
 world=workspace.SkySprout:FindFirstChild("Adventure")or Instance.new("Folder");world.Name="Adventure";world.Parent=workspace.SkySprout
 for _,floor in A.Tower.Floors do for _,pr in floor:GetDescendants()do
  if pr:IsA("ProximityPrompt")and pr:GetAttribute("RPGAction")=="Boss"then pr.Triggered:Connect(function(p)R.Challenge(p,pr:GetAttribute("Floor"),pr)end)end
 end end
 Players.PlayerRemoving:Connect(function(p)R.Leave(p);R.States[p]=nil end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;local step=math.min(elapsed,.3);elapsed=0;local now=os.clock()
  for _,p in Players:GetPlayers()do if data(p)then
   local s=state(p);s.Energy=math.clamp(s.Energy+(s.Block and-5 or 12)*step,0,100);if s.Energy==0 then s.Block=false end
   local h=hum(p);if h and not A.Fighters[p]then
    h.WalkSpeed=now<s.Stun and 0 or(s.Block and 8 or(A.World and A.World.Speed(p)or C.WalkSpeed));p:SetAttribute("Blocking",s.Block)
    if not p:GetAttribute("RPGRaid")and now>(s.CombatUntil or 0)then h.Health=math.min(h.MaxHealth,h.Health+2*step)end
   end
   R.Sync(p)
  end end
  for _,enc in pairs(R.Encounters)do if not enc.Done then
   local ps=participants(enc)
   for p in pairs(enc.Players)do if not table.find(ps,p)then enc.Players[p]=nil;if p.Parent then p:SetAttribute("RPGRaid",false);event:FireClient(p,"BossState",{Active=false})end end end
   if #ps==0 then
    enc.EmptySince=enc.EmptySince or now
    if now-enc.EmptySince>4 then enc.Done=true;enc.Model:Destroy();R.Encounters[enc.Floor]=nil end
   else
    enc.EmptySince=nil
    local living=0
    for _,e in enc.Enemies do if not e.Dead then
     living+=1;e.Text.Text=e.Model.Name.."\n"..math.ceil(e.HP).." / "..math.ceil(e.MaxHP)
     local target=ps[1];local best=math.huge
     for _,p in ps do local dist=(root(p).Position-e.Root.Position).Magnitude;if dist<best then best=dist;target=p end end
     local rr=root(target);local delta=Vector3.new(rr.Position.X-e.Root.Position.X,0,rr.Position.Z-e.Root.Position.Z)
     if now>e.Stun and now>e.Next-.65 then
      local pos=e.Root.Position
      if delta.Magnitude>(e.Boss and 10 or 5)then pos+=delta.Unit*math.min(delta.Magnitude,(e.Boss and 5 or 8)*step)end
      e.Model:PivotTo(CFrame.lookAt(pos,Vector3.new(rr.Position.X,pos.Y,rr.Position.Z)))
     end
     if e.Boss and e.HP<e.MaxHP*.5 and e.Phase==1 then
      e.Phase=2;e.Model:SetAttribute("Phase",2);for _,p in ps do tell(p,"PHASE TWO • A new attack enters the pattern. Watch the numbered warnings!")end
      for i=1,2 do enemy(enc,enc.Center+Vector3.new(i==1 and-17 or 17,0,-12),false,i+3)end
     end
     if now>e.Next and now>e.Stun then e.Next=now+(e.Boss and(e.Phase==2 and 2 or 3)or 2.5);R.Pattern(enc,e,target)end
    end end
    if living==0 and not enc.Boss then enc.Wave="Guardian";enc.Boss=enemy(enc,enc.Center+Vector3.new(0,0,-4),true,enc.Floor)end
    for _,p in ps do event:FireClient(p,"BossState",{Active=true,Name=enc.Boss and enc.Boss.Model.Name or"Guardian disciples",HP=enc.Boss and enc.Boss.HP or 0,MaxHP=enc.Boss and enc.Boss.MaxHP or 0,Phase=enc.Boss and enc.Boss.Phase or 0,Wave=enc.Wave,Party=#ps})end
   end
  end end
 end)
end
return R
