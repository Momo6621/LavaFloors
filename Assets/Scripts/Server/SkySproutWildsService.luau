local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Tween=game:GetService("TweenService")
local Profiles=require(script.Parent.SkySproutProfiles)
local W={Camps={}}
local A,event,stats,world
local function data(p)local s=Profiles.Sessions[p];return s and s.Data end
local function root(p)return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function hum(p)return p.Character and p.Character:FindFirstChildOfClass("Humanoid")end
local function eligible(p,f)
 local d=data(p);local h=hum(p)
 return p.Parent and d and f<=d.BestFloor and(p:GetAttribute("VisitFloor")or 1)==f and h and h.Health>0 and root(p)and not A.Fighters[p]and not p:GetAttribute("RPGRaid")
end
local function part(parent,n,s,cf,c)
 local p=Instance.new("Part");p.Name=n;p.Size=s;p.CFrame=cf;p.Color=c;p.Material=Enum.Material.Slate;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.Parent=parent;return p
end
local function make(camp,index)
 local f=camp.Floor;local home=camp.Center+({Vector3.new(-11,0,-6),Vector3.new(11,0,-6),Vector3.new(0,0,12)})[index]
 local model=Instance.new("Model");local kind=({"Brawler","Charger","Wisp"})[(index+f-2)%3+1];model.Name="Ruin "..kind
 local color=Color3.fromHSV((f*.073+index*.05)%1,.33,.8)
 local body=part(model,"HumanoidRootPart",Vector3.new(3.5,3,3.5),CFrame.new(home+Vector3.new(0,3,0)),color);body.Shape=Enum.PartType.Ball;model.PrimaryPart=body
 for _,s in {-1,1}do
  part(model,"Ear",Vector3.new(.6,2,.7),body.CFrame*CFrame.new(s*1.2,1.7,0)*CFrame.Angles(0,0,-s*.25),Color3.fromRGB(226,217,180))
  local eye=part(model,"Eye",Vector3.new(.5,.5,.3),body.CFrame*CFrame.new(s*.7,.4,-1.65),Color3.fromRGB(255,226,141));eye.Material=Enum.Material.Neon
  for _,z in {-1,1}do part(model,"Leg",Vector3.new(.7,1.7,.7),body.CFrame*CFrame.new(s*1.2,-1.8,z),Color3.fromRGB(123,131,130))end
 end
 local core=part(model,"Crest",Vector3.new(.8,.8,.25),body.CFrame*CFrame.new(0,-.4,-1.7),Color3.fromRGB(124,239,224));core.Material=Enum.Material.Neon
 local hp=36+f*7
 model:SetAttribute("CombatNPC",true);model:SetAttribute("NPCFloor",f);model:SetAttribute("HP",hp);model:SetAttribute("MaxHP",hp);model:SetAttribute("WildEnemy",true)
 local bill=Instance.new("BillboardGui");bill.Size=UDim2.fromOffset(155,38);bill.StudsOffset=Vector3.new(0,3.7,0);bill.MaxDistance=75;bill.Parent=body
 local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.Text=model.Name.." • "..hp.." HP";text.BackgroundColor3=Color3.fromRGB(30,47,61);text.BackgroundTransparency=.2;text.TextColor3=Color3.fromRGB(239,229,195);text.Font=Enum.Font.GothamBold;text.TextSize=12;text.Parent=bill
 game:GetService("CollectionService"):AddTag(model,"SkyboundCombatNPC")
 model.Parent=camp.Model
 local e={Model=model,Root=body,HP=hp,MaxHP=hp,Home=home,Index=index,Kind=kind,Next=os.clock()+2+index*.4,Busy=0,Stun=0,Credit={},Dead=false,Text=text}
 camp.Enemies[index]=e;return e
end
local function lineOfSight(p,target)
 local r=root(p);if not r then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={p.Character,world,workspace.SkySprout:FindFirstChild("Adventure")};params.RespectCanCollide=true
 local hit=workspace:Raycast(r.Position,target-r.Position,params)
 return hit==nil or(hit.Position-target).Magnitude<1
end
local function kill(camp,e)
 if e.Dead then return end;e.Dead=true;e.Respawn=os.clock()+18;e.Model:Destroy()
 local now=os.clock()
 for p,credit in pairs(e.Credit)do
  if eligible(p,camp.Floor)and now-credit.Time<=15 and(root(p).Position-camp.Center).Magnitude<49 then
   local d=data(p);d.Coins+=4+camp.Floor;A.RPG.AwardXP(p,14+camp.Floor*2);stats(p)
   if A.Story then A.Story.RecordHunt(p,camp.Floor)end
   if A.Contracts then A.Contracts.RecordHunt(p,camp.Floor)end
   event:FireClient(p,"WildReward",{Coins=4+camp.Floor,XP=14+camp.Floor*2,Name=e.Kind})
  end
 end
end
function W.Hit(p,damage,range,dot,launch,radial)
 local f=p:GetAttribute("VisitFloor")or 1;local camp=W.Camps[f];local r=root(p)
 if not camp or not eligible(p,f)or(r.Position-camp.Center).Magnitude>49 then return 0 end
 local hits=0
 for _,e in camp.Enemies do if not e.Dead then
  local delta=e.Root.Position-r.Position;local flat=Vector3.new(delta.X,0,delta.Z)
  if flat.Magnitude<range and math.abs(delta.Y)<8 and(radial or flat.Magnitude<.1 or r.CFrame.LookVector:Dot(flat.Unit)>dot)and lineOfSight(p,e.Root.Position)then
   e.HP=math.max(0,e.HP-damage);e.Model:SetAttribute("HP",e.HP);e.Stun=os.clock()+(launch and .7 or .16)
   e.Credit[p]={Time=os.clock()};hits+=1;A.RPG.RecordPvEHit(p)
   event:FireAllClients("NPCImpact",{Target=e.Root,Damage=damage,Launch=launch})
   if e.HP<=0 then kill(camp,e)end
  end
 end end
 return hits
end
local function attack(camp,e,target)
 local now=os.clock();local r=root(target);if not r then return end
 local position=e.Root.Position;local delta=Vector3.new(r.Position.X-position.X,0,r.Position.Z-position.Z)
 local dir=delta.Magnitude>.1 and delta.Unit or Vector3.new(0,0,-1)
 local line=e.Kind~="Brawler";local length=e.Kind=="Charger"and 22 or 29;local duration=e.Kind=="Wisp"and 1.05 or .9
 e.Busy=now+duration+.2;e.Next=now+2.8+(e.Index*.12)
 local warn=part(camp.Model,"WildWarning",line and Vector3.new(5,.15,length)or Vector3.new(.15,14,14),CFrame.new(position.X,camp.Center.Y+.4,position.Z),Color3.fromRGB(255,137,103))
 warn.Material=Enum.Material.Neon;warn.Transparency=.55
 if line then warn.CFrame=CFrame.lookAt(warn.Position,warn.Position+dir)*CFrame.new(0,0,-length/2)
 else warn.Shape=Enum.PartType.Cylinder;warn.CFrame*=CFrame.Angles(0,0,math.pi/2)end
 warn:SetAttribute("Warning",true);Debris:AddItem(warn,duration+.25)
 task.delay(duration,function()
  if e.Dead or not warn.Parent or not camp.Model.Parent or os.clock()<e.Stun then return end
  warn.Transparency=.15;warn.Color=Color3.fromRGB(255,220,155)
  if e.Kind=="Wisp"then
   local bolt=part(camp.Model,"RuneBolt",Vector3.one*1.7,CFrame.new(position),Color3.fromRGB(154,229,249));bolt.Shape=Enum.PartType.Ball;bolt.Material=Enum.Material.Neon
   Tween:Create(bolt,TweenInfo.new(.2),{Position=position+dir*length,Transparency=1}):Play();Debris:AddItem(bolt,.25)
  elseif e.Kind=="Charger"then
   local destination=position+dir*12;local flat=Vector3.new(destination.X-camp.Center.X,0,destination.Z-camp.Center.Z)
   if flat.Magnitude<26 then e.Model:PivotTo(CFrame.lookAt(destination,destination+dir))end
  end
  for _,p in Players:GetPlayers()do if eligible(p,camp.Floor)and(root(p).Position-camp.Center).Magnitude<42 then
   local delta=root(p).Position-position;local hit
   if line then local localPos=warn.CFrame:PointToObjectSpace(root(p).Position);hit=math.abs(localPos.X)<3 and math.abs(localPos.Z)<length/2
   else hit=Vector3.new(delta.X,0,delta.Z).Magnitude<7 end
   if hit and math.abs(root(p).Position.Y-position.Y)<8 and lineOfSight(p,e.Root.Position)then A.RPG.ApplyPvEDamage(p,6+math.floor(camp.Floor*.45),position)end
  end end
 end)
end
function W.Start(arena,remote,pushStats)
 A=arena;event=remote;stats=pushStats
 world=workspace.SkySprout:FindFirstChild("WildEnemies")or Instance.new("Folder");world.Name="WildEnemies";world.Parent=workspace.SkySprout
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.15 then return end;local step=math.min(elapsed,.3);elapsed=0;local now=os.clock()
  for f,floor in pairs(A.Tower.Floors)do
   local center=floor:GetAttribute("WildsCenter");local near=false
   if center then for _,p in Players:GetPlayers()do if eligible(p,f)and(root(p).Position-center).Magnitude<155 then near=true;break end end end
   local camp=W.Camps[f]
   if near and not camp then
    local m=Instance.new("Folder");m.Name="Camp_"..f;m.Parent=world
    camp={Floor=f,Center=center,Model=m,Enemies={}};W.Camps[f]=camp;for i=1,3 do make(camp,i)end
   end
   if camp then
    if near then camp.Empty=nil else camp.Empty=camp.Empty or now end
    if camp.Empty and now-camp.Empty>20 then camp.Model:Destroy();W.Camps[f]=nil
    else
     for i,e in camp.Enemies do
      if e.Dead then if near and now>=e.Respawn then make(camp,i)end
      else
       e.Text.Text=e.Model.Name.." • "..math.ceil(e.HP).." HP"
       local target;local nearest=24
       for _,p in Players:GetPlayers()do if eligible(p,f)and(root(p).Position-center).Magnitude<39 then
        local distance=(root(p).Position-e.Root.Position).Magnitude
        if distance<nearest then nearest=distance;target=p end
       end end
       local position=e.Root.Position
       if target then
        e.Idle=nil;local r=root(target);local flat=Vector3.new(r.Position.X-position.X,0,r.Position.Z-position.Z)
        if now>=e.Stun and now>=e.Busy then
         local stop=e.Kind=="Wisp"and 15 or 5
         if flat.Magnitude>stop then
          local destination=position+flat.Unit*(e.Kind=="Charger"and 8 or 6)*step
          if Vector3.new(destination.X-center.X,0,destination.Z-center.Z).Magnitude<27 then position=destination end
         end
         if flat.Magnitude>.1 then e.Model:PivotTo(CFrame.lookAt(position,Vector3.new(r.Position.X,position.Y,r.Position.Z)))end
         if now>=e.Next and nearest<(e.Kind=="Brawler"and 9 or 27)then attack(camp,e,target)end
        end
       else
        e.Idle=e.Idle or now
        if now-e.Idle>5 then
         e.HP=e.MaxHP;e.Model:SetAttribute("HP",e.HP);e.Credit={}
         local home=e.Home+Vector3.new(0,3,0);local delta=home-position
         if delta.Magnitude>.3 then e.Model:PivotTo(CFrame.new(position+delta.Unit*math.min(delta.Magnitude,6*step)))end
        end
       end
      end
     end
    end
   end
  end
 end)
end
return W
