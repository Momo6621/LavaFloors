local M={}
function M.Start()
 local Collection=game:GetService("CollectionService");local P=game.Players.LocalPlayer
 local lights={}
 local function add(v)if v:IsA("Light")then lights[v]=true;v.Enabled=false end end
 for _,v in Collection:GetTagged("SkyboundManagedLight")do add(v)end
 Collection:GetInstanceAddedSignal("SkyboundManagedLight"):Connect(add)
 Collection:GetInstanceRemovedSignal("SkyboundManagedLight"):Connect(function(v)lights[v]=nil end)
 local elapsed=0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.5 then return end;elapsed=0
  local r=P.Character and P.Character:FindFirstChild("HumanoidRootPart");local nearby={}
  for v in lights do
   if not v.Parent then lights[v]=nil
   elseif r and not P:GetAttribute("LowEffects")then
    local part=v:FindFirstAncestorWhichIsA("BasePart")
    if part and part.LocalTransparencyModifier<.9 then local delta=part.Position-r.Position;local d=delta:Dot(delta);if d<10000 then table.insert(nearby,{v,d})end end
   end
  end
  table.sort(nearby,function(a,b)return a[2]<b[2]end)
  local enabled={};for i=1,math.min(18,#nearby)do enabled[nearby[i][1]]=true end
  for v in lights do local on=enabled[v]==true;if v.Enabled~=on then v.Enabled=on end end
 end)
end
return M
