local M={}
function M.Start()
 local p=game.Players.LocalPlayer;local world=workspace:WaitForChild("SkySprout");local Themes=require(game.ReplicatedStorage.SkySproutWorldThemes);local nodes={}
 local halos=Instance.new("Folder");halos.Name="MyPortalRunes";halos.Parent=workspace
 local glyphs={};for i=1,16 do
  local v=Instance.new("Part");v.Name="PortalRune";v.Size=Vector3.new(1.4,.16,.12);v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false;v.Material=Enum.Material.Neon;v.Transparency=1;v.Parent=halos;glyphs[i]=v
 end
 local function update(v)
  if not v.Parent then nodes[v]=nil;return end
  local d=v:GetAttribute("DestinationFloor");local best=p:GetAttribute("UnlockedFloor")or 1;local from=v:GetAttribute("SourceFloor")
  local locked=type(d)=="number"and d>best;local travelling=p:GetAttribute("TowerTraveling");local combat=p:GetAttribute("InCombat")or p:GetAttribute("RPGRaid")or p:GetAttribute("ArenaMode")=="Match"
  local pr=v:FindFirstChildOfClass("ProximityPrompt");local label=v:FindFirstChild("PortalLabel");local t=label and label:FindFirstChild("Title")
  local status=locked and"Defeat this floor's guardian"or(travelling and"Preparing a path…"or(combat and"Available after combat"or(v:GetAttribute("Directory")and"Choose any earned world"or(d and d>from and"ASCEND"or"RETURN"))))
  if t then t.Text=(locked and"LOCKED • "or"")..v:GetAttribute("PortalTitle").."\n"..status end
  if pr then pr.ActionText=locked and"Guardian victory required"or(travelling and"Preparing path"or(combat and"After combat"or(v:GetAttribute("Directory")and"Choose earned floor"or"Travel")));pr.Enabled=from==(p:GetAttribute("VisitFloor")or 1)and p:GetAttribute("ArenaMode")~="Match"end
  local veil=v.Parent:FindFirstChild("PortalVeil");if veil then veil.Color=locked and Color3.fromRGB(120,102,135)or Themes[d or from].Accent;veil.Transparency=locked and .85 or .68 end
 end
 local function add(v)
  if v:IsA("BasePart")and v:GetAttribute("FloorPortal")then nodes[v]=true;update(v)
  elseif v.Parent and v.Parent:IsA("BasePart")and v.Parent:GetAttribute("FloorPortal")then update(v.Parent)
  elseif v.Name=="Title"and v.Parent and v.Parent.Name=="PortalLabel"and v.Parent.Parent then update(v.Parent.Parent)
  elseif v.Name=="PortalVeil"and v.Parent then local focus=v.Parent:FindFirstChild("PortalFocus");if focus then update(focus)end end
 end
 for _,v in world:GetDescendants()do add(v)end
 world.DescendantAdded:Connect(add);world.DescendantRemoving:Connect(function(v)nodes[v]=nil end)
 for _,attr in {"UnlockedFloor","VisitFloor","InCombat","TowerTraveling","ArenaMode","RPGRaid"}do p:GetAttributeChangedSignal(attr):Connect(function()for v in nodes do update(v)end end)end
 M.Refresh=function()for v in nodes do update(v)end end
 local elapsed,angle=0,0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;angle+=elapsed*.35;elapsed=0
  local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local nearby={}
  if r and not p:GetAttribute("LowEffects")and p:GetAttribute("ArenaMode")~="Match"and not p:GetAttribute("RPGRaid")then
   for v in nodes do if v.Parent and v:GetAttribute("SourceFloor")==(p:GetAttribute("VisitFloor")or 1)then local dist=(r.Position-v.Position).Magnitude;if dist<140 then table.insert(nearby,{v,dist})end end end
  end
  table.sort(nearby,function(a,b)return a[2]<b[2]end)
  for i,glyph in glyphs do
   local slot=math.ceil(i/8);local entry=nearby[slot]
   if entry then
    local node=entry[1];local dest=node:GetAttribute("DestinationFloor")or node:GetAttribute("SourceFloor");local locked=dest>(p:GetAttribute("UnlockedFloor")or 1)
    local a=(i-1)%8*math.pi/4+angle*(slot==1 and 1 or -1)
    glyph.CFrame=CFrame.new(node.Position+Vector3.new(0,4.1,0))*CFrame.Angles(0,0,a)*CFrame.new(0,4.8,0)
    glyph.Color=locked and Color3.fromRGB(120,102,135)or Themes[dest].Accent;glyph.Transparency=locked and .72 or(.35+entry[2]/140*.35)
   elseif glyph.Transparency~=1 then glyph.Transparency=1 end
  end
 end)
 M.Halos=halos
end
return M
