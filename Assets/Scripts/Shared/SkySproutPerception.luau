local M={}
local Players=game:GetService("Players");local Run=game:GetService("RunService");local Lighting=game:GetService("Lighting")
local Themes=require(game.ReplicatedStorage.SkySproutWorldThemes)
local LavaThemes=require(game.ReplicatedStorage:WaitForChild("LavaThemes"))
local P=Players.LocalPlayer
local Water=require(game.ReplicatedStorage.SkySproutWaterClient)
local looks={
 [1]={"Highlands",14,2.4,Color3.fromRGB(177,216,234),Color3.fromRGB(94,133,141),"Sun"},
 [2]={"Highlands",21,1.5,Color3.fromRGB(103,86,133),Color3.fromRGB(65,47,84),"Moon"},
 [3]={"Skyline",19,1.7,Color3.fromRGB(65,113,147),Color3.fromRGB(31,61,92),"TwinMoons"},
 [4]={"Islands",14,2.5,Color3.fromRGB(146,213,233),Color3.fromRGB(92,151,158),"Sun"},
 [5]={"Skyline",15,2.2,Color3.fromRGB(184,215,228),Color3.fromRGB(125,152,156),"Sun"},
 [6]={"Highlands",12.5,2.4,Color3.fromRGB(204,225,238),Color3.fromRGB(164,190,210),"Sun"},
 [7]={"Dunes",16.5,2.2,Color3.fromRGB(239,198,151),Color3.fromRGB(186,132,88),"Sun"},
 [8]={"Spires",20,1.6,Color3.fromRGB(114,103,158),Color3.fromRGB(84,60,111),"TwinMoons"},
 [9]={"Highlands",15,2.2,Color3.fromRGB(176,212,208),Color3.fromRGB(98,139,136),"Sun"},
 [10]={"Spires",19,1.6,Color3.fromRGB(149,97,86),Color3.fromRGB(97,53,48),"EmberSun"},
 [11]={"Islands",13,2.3,Color3.fromRGB(151,220,224),Color3.fromRGB(68,143,158),"Sun"},
 [12]={"Spires",15,2.3,Color3.fromRGB(231,197,223),Color3.fromRGB(179,141,187),"Sun"},
 [13]={"Skyline",16,2.1,Color3.fromRGB(216,185,139),Color3.fromRGB(145,113,76),"Sun"},
 [14]={"Spires",22,1.45,Color3.fromRGB(104,137,151),Color3.fromRGB(60,83,100),"Moon"},
 [15]={"Skyline",20,1.7,Color3.fromRGB(132,94,161),Color3.fromRGB(58,50,102),"TwinMoons"},
 [16]={"Islands",17,1.9,Color3.fromRGB(132,164,185),Color3.fromRGB(78,111,130),"Moon"},
 [17]={"Highlands",13,2.5,Color3.fromRGB(213,230,234),Color3.fromRGB(168,190,194),"Sun"},
 [18]={"Highlands",15.5,2.2,Color3.fromRGB(231,206,219),Color3.fromRGB(160,160,174),"Sun"},
 [19]={"Spires",23,1.65,Color3.fromRGB(96,109,162),Color3.fromRGB(55,61,108),"RingedMoon"},
 [20]={"Spires",14,2.7,Color3.fromRGB(241,228,187),Color3.fromRGB(181,176,145),"Sun"},
}
M.Looks=looks
function M.Start()
 if M.Started then return end;M.Started=true
 local world=workspace:WaitForChild("SkySprout");local floors=world:WaitForChild("Floors")
 local entries={};local proxies={};local avatars={};local activeVisuals={};local repairIndex=1;local revision=0;local inside=false;local floorId=1;local y=0;local radius=1600;local scenicZone
 local background=Instance.new("Folder");background.Name="MyFloorHorizon";background.Parent=workspace
 for _,v in Lighting:GetChildren()do if v:IsA("Atmosphere")then v:Destroy()end end
 local air=Instance.new("Atmosphere");air.Name="MyFloorAtmosphere";air.Parent=Lighting
 local grade=Instance.new("ColorCorrectionEffect");grade.Name="FloorThemeGrade";grade.Contrast=.025;grade.Saturation=.035;grade.Parent=Lighting
 local sky=Lighting:FindFirstChildOfClass("Sky");if sky then sky.CelestialBodiesShown=false end
 local FACES={"Bk","Dn","Ft","Lf","Rt","Up"}
 local SKIES={
  Day={"rbxassetid://6295671271","rbxassetid://6295671382","rbxassetid://6295671136","rbxassetid://6295670996","rbxassetid://6295671509","rbxassetid://6295671667"},
  Dusk={"rbxassetid://5674406298","rbxassetid://5674405985","rbxassetid://5674406449","rbxassetid://5674406184","rbxassetid://5674406378","rbxassetid://5674406072"},
  Night={},
 }
 for i,k in FACES do SKIES.Night[i]=sky and sky["Skybox"..k]or"" end
 local currentSky
 local function setSky(name)if sky and currentSky~=name then currentSky=name;for i,k in FACES do sky["Skybox"..k]=SKIES[name][i]end end end
 task.spawn(function()local s=Instance.new("Sky");for i,k in FACES do s["Skybox"..k]=SKIES.Dusk[i]end;pcall(function()game:GetService("ContentProvider"):PreloadAsync({s})end);s:Destroy()end)
 local function classify(v)
  local a=v
  while a and a~=world do
   if a.Parent==floors then return "Floor",a:GetAttribute("Floor")or tonumber(a.Name:match("^Floor_(%d+)$"))end
   if a.Parent==world then
    if a.Name=="Matches"or a.Name=="Adventure"then
     local b=v;while b and b.Parent~=a do b=b.Parent end
     return "Floor",b and(b:GetAttribute("Floor")or tonumber(b.Name:match("Guardian_(%d+)")))or 0
    end
    return "Exterior",0
   end
   a=a.Parent
  end
 end
 local function hidden(e)
  if e.Kind=="Avatar"then local owner=e.Owner;return (owner:GetAttribute("ArenaMode")=="Match"and owner:GetAttribute("ArenaFloor")or owner:GetAttribute("VisitFloor")or 1)~=floorId end
  if e.Kind=="Floor"then return e.Floor~=floorId end
  return inside
 end
 local function apply(e)
  local v=e.Item;if not v.Parent then entries[v]=nil;proxies[v]=nil;avatars[v]=nil;return end
  local hide=hidden(e);e.LastHidden=hide
  if e.Part then
   if e.Proxy and not hide then
    local r=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
    local localPoint=r and e.CF:PointToObjectSpace(r.Position)or Vector3.zero;local half=e.Half
    local d=Vector3.new(math.max(0,math.abs(localPoint.X)-half.X),math.max(0,math.abs(localPoint.Y)-half.Y),math.max(0,math.abs(localPoint.Z)-half.Z)).Magnitude
    v.LocalTransparencyModifier=d<=700 and 1 or(d>=1000 and 0 or 1-(d-700)/300)
   else local value=hide and 1 or(v:GetAttribute("LocallyCollected")and .65 or e.Original);if v.LocalTransparencyModifier~=value then v.LocalTransparencyModifier=value end end
  elseif e.Gui then v.Enabled=not hide and e.Original
  elseif e.Visual then v.Enabled=not hide and e.Original end
 end
 local function add(v)
  if entries[v]then return end
  if not(v:IsA("BasePart")or v:IsA("BillboardGui")or v:IsA("SurfaceGui")or v:IsA("ParticleEmitter")or v:IsA("Beam")or v:IsA("Trail"))then return end
  local kind,f=classify(v);if not kind then return end
  local e={Item=v,Kind=kind,Floor=f}
  if v:IsA("BasePart")then
   e.Part=true;e.Original=0
   if v:IsDescendantOf(world:FindFirstChild("DistantArchitecture")or background)then e.Proxy=true;e.CF=v.CFrame;e.Half=v.Size/2;v.Transparency=0;proxies[v]=e end
  elseif v:IsA("BillboardGui")or v:IsA("SurfaceGui")then e.Gui=true;e.Original=v.Enabled else e.Visual=true;e.Original=v.Enabled end
  entries[v]=e;apply(e)
  if e.Kind=="Floor"and e.Floor==floorId then table.insert(activeVisuals,e)end
  if v:IsA("BasePart")and v:GetAttribute("Seal")then v:GetAttributeChangedSignal("LocallyCollected"):Connect(function()if entries[v]then apply(entries[v])end end)end
 end
 world.DescendantAdded:Connect(add)
 world.DescendantRemoving:Connect(function(v)
  local e=entries[v]
  if e then
   if e.Part then v.LocalTransparencyModifier=e.Original elseif e.Gui or e.Visual then v.Enabled=e.Original end
  end
  entries[v]=nil;proxies[v]=nil
 end)
 task.spawn(function()for i,v in world:GetDescendants()do add(v);if i%750==0 then task.wait()end end;M.Ready=true end)
 local function refresh()
  activeVisuals={};repairIndex=1;for _,e in entries do if e.Kind=="Floor"and e.Floor==floorId then table.insert(activeVisuals,e)end end
  revision+=1;local token=revision
  task.spawn(function()local n=0;for _,e in entries do if token~=revision then return end;if e.LastHidden~=hidden(e)then apply(e);n+=1;if n%1500==0 then task.wait()end end end end)
 end
 local function visual(name,size,cf,col,shape)
  local v=Instance.new(shape=="Wedge"and"WedgePart"or"Part");v.Name=name;v.Size=size;v.CFrame=cf;v.Color=col
  v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false;v.Material=Enum.Material.SmoothPlastic
  if shape=="Ball"then v.Shape=Enum.PartType.Ball end;v.Parent=background;return v
 end
 local function backdrop()
  background:ClearAllChildren()
  if not inside then return end
  local look=looks[floorId];local theme=Themes[floorId];local rng=Random.new(floorId*7841)
  for i=1,36 do
   local angle=i*math.pi*2/36;local distance=rng:NextNumber(4700,5600);local h=rng:NextNumber(520,1300)
   local at=Vector3.new(math.sin(angle)*distance,y+h/2-150,math.cos(angle)*distance)
   local col=look[5]:Lerp(look[4],rng:NextNumber(.1,.35))
   local style=look[1]
   if style=="Skyline"then
    local tower=visual("DistantDistrict",Vector3.new(rng:NextNumber(280,510),h,rng:NextNumber(280,510)),CFrame.new(at)*CFrame.Angles(0,angle,0),col)
    if floorId==3 or floorId==15 then
     local band=visual("SkylineBeacon",Vector3.new(tower.Size.X+2,9,tower.Size.Z+2),tower.CFrame*CFrame.new(0,h/2-45,0),theme.Accent);band.Material=Enum.Material.Neon
    end
   else
    local width=style=="Dunes"and 1300 or rng:NextNumber(700,1150)
    if style=="Islands"then h*=.55;at=Vector3.new(at.X,y+h/2-100,at.Z)end
    visual("Far"..style,Vector3.new(width,h,850),CFrame.new(at)*CFrame.Angles(0,angle,0),col,"Wedge")
    visual("Far"..style,Vector3.new(width*.8,h*.8,900),CFrame.new(at+Vector3.new(180,-h*.1,-60))*CFrame.Angles(0,angle+math.pi,0),col,"Wedge")
   end
  end
  local celestial=look[6];local sun=celestial=="Sun"or celestial=="EmberSun"
  local at=Vector3.new(-4500,y+3300,-5600)
  local orb=visual(sun and"ArtificialSun"or"ArtificialMoon",Vector3.new(660,660,660),CFrame.new(at),sun and(celestial=="EmberSun"and Color3.fromRGB(255,144,72)or Color3.fromRGB(255,237,182))or Color3.fromRGB(202,226,248),"Ball");orb.Material=Enum.Material.Neon
  if celestial=="TwinMoons"then
   visual("ArtificialSecondMoon",Vector3.new(330,330,330),CFrame.new(2200,y+2600,-6400),theme.Accent,"Ball").Material=Enum.Material.Neon
  elseif celestial=="RingedMoon"then
   for i=0,23 do local a=i*math.pi*2/24
    local pos=at+Vector3.new(math.cos(a)*540,math.sin(a)*150,math.sin(a)*410)
    local seg=visual("MoonRing",Vector3.new(150,24,42),CFrame.new(pos)*CFrame.Angles(0,-a,math.rad(12)),theme.Accent);seg.Material=Enum.Material.Neon
   end
  end
  if not P:GetAttribute("LowEffects")then
   for i=1,10 do local a=i*math.pi*2/10;local atCloud=Vector3.new(math.sin(a)*3800,y+rng:NextNumber(1050,1450),math.cos(a)*3800)
    local cloud=visual("FarCloud",Vector3.new(1050,140,450),CFrame.new(atCloud),look[4]:Lerp(Color3.new(1,1,1),.45),"Ball");cloud.Transparency=.18
   end
  end
 end
 local lightingTweens={}
 local function lighting()
  for _,tween in lightingTweens do tween:Cancel()end;lightingTweens={}
  local groups={{Lighting,{"ClockTime","Brightness","FogStart","FogEnd","FogColor","Ambient","OutdoorAmbient"}},{air,{"Density","Haze","Color","Decay"}},{grade,{"TintColor"}}}
  local previous={};for i,group in groups do previous[i]={};for _,key in group[2]do previous[i][key]=group[1][key]end end
  local look=inside and looks[floorId]or looks[1];local night=look[3]<1.9
  Lighting.ClockTime=look[2];Lighting.Brightness=look[3]
  Lighting.Ambient=night and Color3.fromRGB(107,111,136)or Color3.fromRGB(157,174,188)
  Lighting.OutdoorAmbient=night and Color3.fromRGB(115,126,148)or Color3.fromRGB(184,199,205)
  Lighting.FogStart=0;Lighting.FogEnd=16000;Lighting.FogColor=look[4];Lighting.ExposureCompensation=night and .12 or 0
  air.Density=inside and .22 or .26;air.Offset=.1;air.Color=look[4];air.Decay=look[5];air.Glare=0;air.Haze=inside and .7 or 1.1
  grade.TintColor=Color3.new(1,1,1):Lerp(inside and Themes[floorId].Accent or Color3.new(1,1,1),night and .055 or .025)
  if scenicZone then
   Lighting.Brightness=1.85;Lighting.FogStart=35;Lighting.FogEnd=1500;Lighting.FogColor=Color3.fromRGB(61,147,169)
   Lighting.Ambient=Color3.fromRGB(122,175,188);Lighting.OutdoorAmbient=Color3.fromRGB(135,190,199)
   air.Density=.36;air.Haze=1.6;air.Color=Color3.fromRGB(118,200,214);air.Decay=Color3.fromRGB(51,117,142)
   grade.TintColor=Color3.fromRGB(213,246,250)
  end
  local mood=M.Mood=="Lava"and floorId==1
  local lt=mood and LavaThemes.Get(workspace:GetAttribute("LavaTheme"))
  if lt then
   Lighting.ClockTime=lt.Clock;Lighting.Brightness=lt.Brightness;Lighting.ExposureCompensation=lt.Exposure
   Lighting.Ambient=lt.Ambient;Lighting.OutdoorAmbient=lt.Outdoor
   air.Color=lt.AirColor;air.Decay=lt.AirDecay;air.Density=lt.AirDensity;air.Haze=lt.Haze
   grade.TintColor=lt.Tint
  end
  grade.Saturation=lt and lt.Saturation or .035;grade.Contrast=lt and lt.Contrast or .025
  setSky(lt and lt.Sky or(night and"Night"or"Day"))
  if sky then sky.StarCount=lt and lt.Stars or(night and 1800 or 400);sky.CelestialBodiesShown=not inside and not(lt and lt.Moon)end
  for _,v in Lighting:GetChildren()do if v:IsA("BloomEffect")or v:IsA("SunRaysEffect")or v:IsA("DepthOfFieldEffect")then
   v.Enabled=not P:GetAttribute("LowEffects")and not v:IsA("DepthOfFieldEffect")and not(scenicZone and v:IsA("SunRaysEffect"))
   if v:IsA("BloomEffect")then v.Intensity=lt and lt.Bloom or .16;v.Size=18;v.Threshold=lt and lt.BloomThreshold or 2 end
  end end
  for i,group in groups do local target={};for _,key in group[2]do target[key]=group[1][key];group[1][key]=previous[i][key]end
   local tween=game:GetService("TweenService"):Create(group[1],TweenInfo.new(M.MoodChanged and 1.6 or .4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),target);table.insert(lightingTweens,tween);tween:Play()
  end
  M.MoodChanged=false
 end
 M.SetMood=function(name)if M.Mood~=name then M.Mood=name;M.MoodChanged=true;lighting()end end
 workspace:GetAttributeChangedSignal("LavaTheme"):Connect(function()if M.Mood=="Lava"then M.MoodChanged=true;lighting()end end)
 local function update()
  local f=math.clamp(P:GetAttribute("ArenaMode")=="Match"and P:GetAttribute("ArenaFloor")or P:GetAttribute("VisitFloor")or 1,1,20);local r=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
  local distance=r and Vector2.new(r.Position.X,r.Position.Z).Magnitude or math.huge
  local active=f>1 or(f==floorId and inside and distance<1580)or distance<1520
  local zone=inside and Water.Zone and Water.Zone.Floor==f and Water.Zone or nil
  if scenicZone~=zone then scenicZone=zone;M.ScenicZone=zone and zone.Id or nil;lighting()end
  if f~=floorId or active~=inside then
   floorId=f;inside=active;y=(f-1)*256;radius=1600-(f-1)*40;scenicZone=active and Water.Zone and Water.Zone.Floor==f and Water.Zone or nil;M.ScenicZone=scenicZone and scenicZone.Id or nil
   M.Floor=f;M.Inside=inside;P:SetAttribute("InteriorPerception",inside);lighting();backdrop();refresh()
  end
 end
 M.Refresh=update;M.IsHidden=function(v)local e=entries[v];return e and hidden(e)or false end
 for _,attr in {"VisitFloor","ArenaMode","ArenaFloor"}do P:GetAttributeChangedSignal(attr):Connect(update)end
 P:GetAttributeChangedSignal("LowEffects"):Connect(function()lighting();backdrop()end)
 local function otherPlayer(owner)
  if owner==P then return end
  local characters=setmetatable({},{__mode="k"})
  local function character(ch)
   if characters[ch]then return end;characters[ch]=true
   local function visual(v)
    if avatars[v]then return end
    if v:IsA("BasePart")then local e={Item=v,Part=true,Original=0,Kind="Avatar",Owner=owner};entries[v]=e;avatars[v]=e;apply(e)
    elseif v:IsA("BillboardGui")then local e={Item=v,Gui=true,Original=v.Enabled,Kind="Avatar",Owner=owner};entries[v]=e;avatars[v]=e;apply(e)end
   end
   ch.DescendantAdded:Connect(visual);ch.DescendantRemoving:Connect(function(v)entries[v]=nil;avatars[v]=nil end)
   for _,v in ch:GetDescendants()do visual(v)end
  end
  owner.CharacterAdded:Connect(character);if owner.Character then character(owner.Character)end
 end
 Players.PlayerAdded:Connect(otherPlayer);for _,owner in Players:GetPlayers()do otherPlayer(owner)end
 M.Floor=1;M.Inside=false;lighting();update()
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;elapsed=0;update()
  for _,e in proxies do apply(e)end
  for _,e in avatars do apply(e)end
  for _=1,math.min(1200,#activeVisuals)do
   if #activeVisuals==0 then break end
   if repairIndex>#activeVisuals then repairIndex=1 end
   local e=activeVisuals[repairIndex];local v=e.Item
   if entries[v]~=e or not v.Parent then activeVisuals[repairIndex]=activeVisuals[#activeVisuals];activeVisuals[#activeVisuals]=nil
   else
    if e.Part then
     local expected=v:GetAttribute("LocallyCollected")and .65 or 0
     if v.LocalTransparencyModifier~=expected then apply(e)end
    elseif e.Gui and v.Enabled~=e.Original then apply(e)end
    repairIndex+=1
   end
  end
 end)
end
return M
