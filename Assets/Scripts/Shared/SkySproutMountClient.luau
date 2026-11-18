local M={}
function M.Start()
 local Players=game:GetService("Players");local Run=game:GetService("RunService");local me=Players.LocalPlayer
 local template=game.ReplicatedStorage:WaitForChild("SkyboundHorse");local horses={}
 local function remove(p)local h=horses[p];if h then h.Model:Destroy();horses[p]=nil end end
 Players.PlayerRemoving:Connect(remove)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;local step=me:GetAttribute("LowEffects")and .066 or .033;if elapsed<step then return end;elapsed=0
  local own=me.Character and me.Character:FindFirstChild("HumanoidRootPart");if not own then return end
  for _,p in Players:GetPlayers()do
   local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local delta=r and(r.Position-own.Position)
   local visible=p:GetAttribute("Mounted")==true and r and delta:Dot(delta)<40000
   if visible then
    local h=horses[p]
    if not h then
     local model=template:Clone();model.Name="Skystrider_"..p.UserId;local pieces={}
     for _,v in model:GetChildren()do if v:IsA("BasePart")then table.insert(pieces,{Part=v,Local=v.CFrame,Hip=v:GetAttribute("LegHip"),Phase=v:GetAttribute("LegPhase")or 0})end end
     h={Model=model,Pieces=pieces};horses[p]=h;model.Parent=workspace
    end
    local speed=Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z).Magnitude
    local moving=speed>2;local phase=os.clock()*math.clamp(speed*.18,5,14)
    local bob=moving and math.sin(phase*2)*.07 or math.sin(os.clock()*2)*.025
    local basis=r.CFrame*CFrame.new(0,-3+bob,0)
    local firstPerson=p==me and workspace.CurrentCamera and(workspace.CurrentCamera.CFrame.Position-r.Position).Magnitude<1.5
    for _,v in h.Pieces do
     local cf=v.Local
     if v.Hip and moving then cf=CFrame.new(v.Hip)*CFrame.Angles(math.sin(phase+v.Phase)*.45,0,0)*CFrame.new(-v.Hip)*cf end
     v.Part.CFrame=basis*cf
     v.Part.LocalTransparencyModifier=firstPerson and 1 or 0
    end
   else remove(p)end
  end
 end)
end
return M
