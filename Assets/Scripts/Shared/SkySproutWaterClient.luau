local W={Config=require(game.ReplicatedStorage.SkySproutWaterConfig),Zone=nil,Fish={},VisibleFish=0}
local P=game.Players.LocalPlayer
function W.Contains(position,floor)
 local c=W.Config;if floor~=c.Floor or typeof(position)~="Vector3"then return false end
 local v=position-c.Center;local h=c.Size/2
 return math.abs(v.X)<=h.X and math.abs(v.Y)<=h.Y and math.abs(v.Z)<=h.Z
end
function W.Start()
 if W.Started then return end;W.Started=true
 local world=workspace:WaitForChild("SkySprout");local models={};local originals={}
 local function add(v)
  if v:IsA("Model")and v:GetAttribute("ScenicFish")and not models[v]then
   local center=v:GetAttribute("Center");if typeof(center)~="Vector3"then return end
   models[v]={Center=center,Radius=v:GetAttribute("Radius")or 12,Phase=v:GetAttribute("Phase")or 0}
   W.Fish[v]=true
  elseif v:IsA("BasePart")and v.Parent and v.Parent:GetAttribute("ScenicFish")and originals[v]==nil then originals[v]=v.Transparency end
 end
 world.DescendantAdded:Connect(add)
 world.DescendantRemoving:Connect(function(v)if originals[v]~=nil then v.Transparency=originals[v];originals[v]=nil end;models[v]=nil;W.Fish[v]=nil end)
 task.spawn(function()for i,v in world:GetDescendants()do add(v);if i%1000==0 then task.wait()end end;W.Ready=true end)
 local time=0;local elapsed=0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  time+=dt;elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
  local f=P:GetAttribute("VisitFloor")or 1;local valid=f==W.Config.Floor and f<=(P:GetAttribute("UnlockedFloor")or 1)and not P:GetAttribute("RPGRaid")and not P:GetAttribute("TowerTraveling")and P:GetAttribute("ArenaMode")~="Match"and P:GetAttribute("ArenaMode")~="Loading"
  local zone=valid and root and W.Contains(root.Position,f)and W.Config or nil
  if W.Zone~=zone then W.Zone=zone;P:SetAttribute("ScenicRegion",zone and zone.Name or nil)end
  local show=valid and root and(root.Position-W.Config.Center).Magnitude<280 and not P:GetAttribute("LowEffects")
  local visible=0
  for model,v in models do
   if not model.Parent then models[model]=nil;W.Fish[model]=nil
   elseif show and model.PrimaryPart then
    local a=time*.32+v.Phase;local at=v.Center+Vector3.new(math.cos(a)*v.Radius,math.sin(a*.7)*1.5,math.sin(a)*v.Radius*.65)
    local tangent=Vector3.new(-math.sin(a),0,math.cos(a)*.65)
    model:PivotTo(CFrame.lookAt(at,at+tangent));visible+=1
   end
  end
  for v,original in originals do if v.Parent then local value=show and original or 1;if v.Transparency~=value then v.Transparency=value end end end
  W.VisibleFish=visible
 end)
end
return W
