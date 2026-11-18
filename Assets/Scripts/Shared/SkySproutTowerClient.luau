local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local C=require(RS.SkySproutConfig)
local M={}
function M.Start(event,gui)
 local p=Players.LocalPlayer;local snapshot;local muted=false
 local sound=workspace.SkySprout:FindFirstChild("DistrictAmbience")
 local function send(a,v)event:FireServer(a,v)end
 local function close()gui.Directory.Visible=false;gui.QuestPanel.Visible=false end
 local function directory()
  local best=p:GetAttribute("UnlockedFloor")or 1;local here=p:GetAttribute("VisitFloor")or 1;local busy=p:GetAttribute("InCombat")==true or p:GetAttribute("TowerTraveling")==true
  gui.Directory.Access.Text=busy and"Travel is paused during combat."or(best>=C.MaxFloor and"All twenty floors earned • Revisit any unlocked world."or("Your access: floors 1–"..best.." • Defeat the guardian to reach "..(best+1)))
  for i=1,C.MaxFloor do local b=gui.Directory.List["Floor_"..i];local open=i<=best
   b.Active=open and not busy;b.AutoButtonColor=b.Active
   b.Text=string.format("%02d",i).." • "..C.FloorNames[i]..(i==here and" • HERE"or(open and" • OPEN"or" • LOCKED"))
   b.BackgroundColor3=i==here and Color3.fromRGB(67,128,230)or(open and Color3.fromRGB(47,50,59)or Color3.fromRGB(69,83,99));b.TextColor3=open and Color3.fromRGB(240,241,244)or Color3.fromRGB(195,202,213)
  end
 end
 local function mode()
  local fight=p:GetAttribute("ArenaMode")=="Match"
  if fight then close()end
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h then h:SetStateEnabled(Enum.HumanoidStateType.Jumping,not fight)end
  local touch=p.PlayerGui:FindFirstChild("TouchGui");local jump=touch and touch:FindFirstChild("JumpButton",true);if jump then jump.Visible=not fight end
 end
 gui.Lobby.Floors.Activated:Connect(function()gui.Shop.Visible=false;gui.QuestPanel.Visible=false;directory();gui.Directory.Visible=not gui.Directory.Visible end)
 gui.Lobby.Quests.Activated:Connect(function()gui.Shop.Visible=false;gui.Directory.Visible=false;gui.QuestPanel.Visible=not gui.QuestPanel.Visible;send("QuestSync")end)
 gui.Directory.Close.Activated:Connect(close);gui.QuestPanel.Close.Activated:Connect(close)
 for i=1,C.MaxFloor do gui.Directory.List["Floor_"..i].Activated:Connect(function()send("Travel",i)end)end
 for _,id in ipairs({"Explore","Courier","Training"})do gui.QuestPanel.List[id].Claim.Activated:Connect(function()send("ClaimQuest",id)end)end
 gui.Lobby.Styles.Activated:Connect(close)
 gui.Top.Sound.Activated:Connect(function()
  muted=not muted;p:SetAttribute("SoundMuted",muted);gui.Top.Sound.Text=muted and"OFF"or"SFX";if sound then sound.Volume=muted and 0 or .08 end
 end)
 if sound then task.spawn(function()
  pcall(function()game:GetService("ContentProvider"):PreloadAsync({sound})end)
  if sound.IsLoaded then sound:Play()end
 end)end
 event.OnClientEvent:Connect(function(kind,v)
  if kind=="OpenFloors"then close();gui.Shop.Visible=false;directory();gui.Directory.Visible=true
  elseif kind=="OpenQuests"then close();gui.Shop.Visible=false;gui.QuestPanel.Visible=true
  elseif kind=="Travelled"then
   close();directory()
   gui.Lobby.Status.Text="Floor "..v.Floor.." • "..v.Name
  elseif kind=="Quests"then
   snapshot=v;gui.QuestPanel.District.Text="Floor "..v.Floor.." • "..v.Name.." • Coins help with cosmetics"
   local claimable=0
   for _,q in ipairs(v.Entries)do
    local card=gui.QuestPanel.List[q.Id];card.Title.Text=q.Title.." • "..q.Reward.." coins";card.Description.Text=q.Description
    card.Progress.Text=q.Progress.." / "..q.Target
    card.Claim.Text=q.Claimed and"CLAIMED"or(q.Progress>=q.Target and"CLAIM"or"IN PROGRESS")
    card.Claim.BackgroundColor3=q.Claimed and Color3.fromRGB(90,127,119)or(q.Progress>=q.Target and Color3.fromRGB(47,50,59)or Color3.fromRGB(47,50,59))
    if not q.Claimed and q.Progress>=q.Target then claimable+=1 end
   end
   gui.Lobby.Quests.Text=claimable>0 and("QUESTS +"..claimable)or"QUESTS"
   local f=workspace.SkySprout.Floors:FindFirstChild("Floor_"..v.Floor)
   if f then for _,d in ipairs(f:GetDescendants())do if d:IsA("BasePart")and d:GetAttribute("Seal")then
    local collected=v.Seals[d:GetAttribute("Seal")]==true;d:SetAttribute("LocallyCollected",collected)
    local pr=d:FindFirstChildOfClass("ProximityPrompt");if pr then pr.Enabled=not collected end
   end end end
  elseif kind=="Result"then close()
  end
 end)
 p:GetAttributeChangedSignal("VisitFloor"):Connect(directory)
 p:GetAttributeChangedSignal("UnlockedFloor"):Connect(directory)
 p:GetAttributeChangedSignal("InCombat"):Connect(directory)
 p:GetAttributeChangedSignal("TowerTraveling"):Connect(directory)
 p:GetAttributeChangedSignal("ArenaMode"):Connect(mode)
 p.CharacterAdded:Connect(function()task.delay(.6,mode)end)
 directory();mode();send("QuestSync")
end
return M
