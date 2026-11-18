local M={}
function M.Start(event,gui)
 local p=game.Players.LocalPlayer;local CAS=game:GetService("ContextActionService");local UIS=game:GetService("UserInputService")
 require(game.ReplicatedStorage.SkySproutHUD).Prepare(gui)
 local paper=Color3.fromRGB(240,241,244);local mint=Color3.fromRGB(67,128,230)
 require(game.ReplicatedStorage.SkySproutAtlas).Start(event,gui)
 local sprintHeld=false;local sprintLatched=false
 local function sprintAllowed()
  return not UIS:GetFocusedTextBox()and not gui:GetAttribute("ModalOpen")and p:GetAttribute("ArenaMode")~="Match"and p:GetAttribute("ArenaMode")~="Loading"and not p:GetAttribute("RPGRaid")
 end
 local function sprintSend()
  if not sprintAllowed()then sprintHeld=false;sprintLatched=false end
  event:FireServer("Sprint",sprintHeld or sprintLatched)
  local b=gui:FindFirstChild("RunToggle");if b then b.Text=sprintLatched and"Walk"or"Run";b.BackgroundColor3=sprintLatched and mint or Color3.fromRGB(47,50,59)end
 end
 local function clearSprint()sprintHeld=false;sprintLatched=false;sprintSend()end
 function M.SprintInput(_,state,input)
  local toggle=input and(input.KeyCode==Enum.KeyCode.ButtonL3 or input.UserInputType==Enum.UserInputType.Touch)
  if state==Enum.UserInputState.Cancel then clearSprint();return Enum.ContextActionResult.Sink end
  if state==Enum.UserInputState.Begin then
   if not sprintAllowed()then return Enum.ContextActionResult.Pass end
   if toggle then sprintLatched=not sprintLatched else sprintHeld=true end;sprintSend()
  elseif state==Enum.UserInputState.End and not toggle then sprintHeld=false;sprintSend()end
  return Enum.ContextActionResult.Sink
 end
 CAS:BindAction("TowerSprint",M.SprintInput,false,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
 UIS.WindowFocusReleased:Connect(clearSprint)
 UIS.TextBoxFocused:Connect(clearSprint)
 p.CharacterAdded:Connect(clearSprint)
 gui:GetAttributeChangedSignal("ModalOpen"):Connect(function()if gui:GetAttribute("ModalOpen")then clearSprint()end end)
 p:GetAttributeChangedSignal("VisitFloor"):Connect(clearSprint)
 p:GetAttributeChangedSignal("TowerTraveling"):Connect(function()if p:GetAttribute("TowerTraveling")then clearSprint()end end)
 p:GetAttributeChangedSignal("ArenaMode"):Connect(function()if p:GetAttribute("ArenaMode")=="Match"then clearSprint()end end)
 p:GetAttributeChangedSignal("RPGRaid"):Connect(function()if p:GetAttribute("RPGRaid")then clearSprint()end end)
 CAS:BindAction("SkyboundMount",function(_,state)if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox()and not gui:GetAttribute("ModalOpen")then event:FireServer("Mount")end;return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.V,Enum.KeyCode.DPadUp)
 M.RunInput=function()return M.SprintInput("TowerSprint",Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.Unknown,UserInputType=Enum.UserInputType.Touch})end
 gui.RunToggle.Activated:Connect(M.RunInput);M.RunConnected=true
 require(game.ReplicatedStorage.SkySproutWaterClient).Start()
 require(game.ReplicatedStorage.SkySproutPerception).Start()
 local region=Instance.new("TextLabel");region.Name="CurrentRegion";region.BackgroundTransparency=1;region.Size=UDim2.fromOffset(260,25);region.Position=UDim2.new(.5,-130,0,181);region.Font=Enum.Font.GothamBold;region.TextSize=13;region.TextColor3=paper;region.Parent=gui
 local function update()region.Text=(p:GetAttribute("ScenicRegion")or p:GetAttribute("RegionName")or"Gateward Town")end
 p:GetAttributeChangedSignal("RegionName"):Connect(update);p:GetAttributeChangedSignal("ScenicRegion"):Connect(update);update()
end
return M
