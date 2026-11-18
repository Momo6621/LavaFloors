local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local Collection=game:GetService("CollectionService")
local T={Target=nil}
local p=Players.LocalPlayer
local highlight,button,gui
local function root()return p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function valid(model,range)
 local r=root()
 return model and model.Parent and model:IsA("Model")and model.PrimaryPart and model:GetAttribute("CombatNPC")==true
  and(model:GetAttribute("HP")or 0)>0 and model:GetAttribute("NPCFloor")==(p:GetAttribute("VisitFloor")or 1)
  and r and(model.PrimaryPart.Position-r.Position).Magnitude<range
end
local function clear()
 T.Target=nil;p:SetAttribute("PVETargetLocked",false)
 if highlight then highlight:Destroy();highlight=nil end
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid");if h and p:GetAttribute("ArenaMode")~="Match"then h.AutoRotate=true end
end
function T.Toggle()
 if p:GetAttribute("ArenaMode")=="Match"or p:GetAttribute("Mounted")then clear();return nil end
 if T.Target then clear();return nil end
 local r=root();if not r then return nil end
 local nearest=45;local selected
 for _,m in Collection:GetTagged("SkyboundCombatNPC")do if valid(m,nearest)then
  local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={p.Character,m};params.RespectCanCollide=true
  local delta=m.PrimaryPart.Position-r.Position;local hit=workspace:Raycast(r.Position,delta,params)
  if not hit then selected=m;nearest=delta.Magnitude end
 end end
 T.Target=selected
 if selected then
  p:SetAttribute("PVETargetLocked",true);highlight=Instance.new("Highlight");highlight.Name="MyCombatTarget";highlight.Adornee=selected;highlight.FillTransparency=1;highlight.OutlineColor=Color3.fromRGB(255,210,132);highlight.OutlineTransparency=0;highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=selected
 end
 return selected
end
function T.Assist()
 if not valid(T.Target,65)or p:GetAttribute("ArenaMode")=="Match"then return end
 local r=root();local pos=T.Target.PrimaryPart.Position;local look=Vector3.new(pos.X,r.Position.Y,pos.Z)
 if(look-r.Position).Magnitude>.2 then r.CFrame=CFrame.lookAt(r.Position,look)end
end
function T.Start(screen)
 if T.Started then return end;T.Started=true;gui=screen
 button=Instance.new("TextButton");button.Name="TargetLock";button.Size=UDim2.fromOffset(158,54);button.AnchorPoint=Vector2.new(1,1);button.Position=UDim2.new(1,-12,1,-226)
 button.BackgroundColor3=Color3.fromRGB(255,211,137);button.TextColor3=Color3.fromRGB(29,44,61);button.Font=Enum.Font.GothamBold;button.TextSize=12;button.TextWrapped=true;button.BorderSizePixel=0;button.Parent=gui
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=button
 button.Activated:Connect(T.Toggle)
 CAS:BindAction("SkyboundTargetLock",function(_,state)
  if UIS:GetFocusedTextBox()or not button.Visible then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then T.Toggle()end
  return Enum.ContextActionResult.Sink
 end,false,Enum.KeyCode.G,Enum.KeyCode.ButtonR3)
 p:GetAttributeChangedSignal("VisitFloor"):Connect(clear)
 p:GetAttributeChangedSignal("ArenaMode"):Connect(function()if p:GetAttribute("ArenaMode")=="Match"then clear()end end)
 p.CharacterAdded:Connect(clear)
 p:GetAttributeChangedSignal("Mounted"):Connect(function()if p:GetAttribute("Mounted")then clear()end end)
 local elapsed=0
 Run.RenderStepped:Connect(function(dt)
  if T.Target and not valid(T.Target,65)then clear()end
  if T.Target then
   local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid");if h then h.AutoRotate=false end
   T.Assist()
  end
  elapsed+=dt;if elapsed<.2 then return end;elapsed=0
  button.Visible=not gui:GetAttribute("ModalOpen")and p:GetAttribute("ArenaMode")~="Match"and not p:GetAttribute("Mounted")
  if T.Target then button.Text=T.Target.Name.."\n"..math.ceil(T.Target:GetAttribute("HP"))..(UIS.TouchEnabled and" HP • Tap to unlock"or" HP • G / R3 unlock")
  else button.Text=UIS.TouchEnabled and"LOCK TARGET"or"LOCK TARGET\nG / R3"end
 end)
end
return T
