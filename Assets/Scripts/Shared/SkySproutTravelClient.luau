local M={Phase="Idle"}
function M.Start(event,gui)
 local P=game.Players.LocalPlayer;local H=require(game.ReplicatedStorage.SkySproutHUD)
 local veil=Instance.new("Frame");veil.Name="TravelVeil";veil.Size=UDim2.fromScale(1,1);veil.BackgroundColor3=Color3.fromRGB(12,17,26);veil.BackgroundTransparency=.28;veil.BorderSizePixel=0;veil.Visible=false;veil.Active=true;veil.ZIndex=30;veil.Parent=gui
 local card=Instance.new("Frame");card.Name="Card";card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.45);card.Size=UDim2.new(.88,0,0,132);card.BackgroundColor3=Color3.fromRGB(27,29,35);card.BorderSizePixel=0;card.ZIndex=31;card.Parent=veil
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(440,132);limit.Parent=card
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=card
 local function text(name,value,y,h,size)
  local v=Instance.new("TextLabel");v.Name=name;v.Text=value;v.Position=UDim2.fromOffset(16,y);v.Size=UDim2.new(1,-32,0,h);v.BackgroundTransparency=1;v.Font=Enum.Font.GothamMedium;v.TextSize=size;v.TextColor3=Color3.fromRGB(240,241,244);v.TextWrapped=true;v.ZIndex=32;v.Parent=card;return v
 end
 local title=text("Title","Opening a path",12,22,18);local detail=text("Detail","Preparing your destination",40,32,13)
 local cancel=Instance.new("TextButton");cancel.Name="Cancel";cancel.Size=UDim2.fromOffset(160,44);cancel.AnchorPoint=Vector2.new(.5,0);cancel.Position=UDim2.new(.5,0,0,80);cancel.Text="Cancel travel";cancel.TextColor3=Color3.fromRGB(240,241,244);cancel.Font=Enum.Font.GothamMedium;cancel.TextSize=13;cancel.BackgroundColor3=Color3.fromRGB(47,50,59);cancel.BorderSizePixel=0;cancel.ZIndex=32;cancel.Parent=card
 local cc=Instance.new("UICorner");cc.CornerRadius=UDim.new(0,8);cc.Parent=cancel
 local whoosh=Instance.new("Sound");whoosh.Name="SkyboundTravelWhoosh";whoosh.SoundId="rbxassetid://9125648149";whoosh.Volume=.07;whoosh.Parent=game:GetService("SoundService")
 local function soundState()whoosh.Volume=P:GetAttribute("SoundMuted")and 0 or .07;if P:GetAttribute("SoundMuted")then whoosh:Stop()end end
 P:GetAttributeChangedSignal("SoundMuted"):Connect(soundState);soundState()
 task.spawn(function()pcall(function()game:GetService("ContentProvider"):PreloadAsync({whoosh})end);M.AudioLoaded=whoosh.IsLoaded end)
 function M.Cancel()
  if M.Phase~="Loading"or not M.Id then return false end
  cancel.Text="Cancelling…";cancel.Active=false;event:FireServer("CancelTravel",M.Id);return true
 end
 cancel.Activated:Connect(M.Cancel)
 function M.Begin(v)
  if type(v)~="table"or type(v.Id)~="number"or(M.Id and v.Id<M.Id)then return end
  M.Id=v.Id;M.Name=v.Name;M.Phase="Loading";H.Close();title.Text=v.Kind=="Waystone"and"Waystone travel"or"Opening a tower path"
  detail.Text=v.Name or"Preparing your destination";cancel.Text="Cancel travel";cancel.Active=true;cancel.Visible=true;veil.Visible=true
  if whoosh.IsLoaded and not P:GetAttribute("SoundMuted")then whoosh.TimePosition=0;whoosh:Play()end
  H.Refresh()
 end
 function M.Finish(v)
  if type(v)~="table"or v.Id~=M.Id then return end
  local id=M.Id;M.Phase="Ending";cancel.Visible=false;title.Text=v.Success and"Path opened"or"Travel stopped";detail.Text=v.Success and(v.Name or"Arrived")or(v.Reason or"Travel interrupted.")
  task.delay(v.Success and .18 or .55,function()if M.Id==id and M.Phase=="Ending"then M.Phase="Idle";veil.Visible=false;H.Refresh()end end)
 end
 event.OnClientEvent:Connect(function(kind,v)if kind=="TravelBegin"then M.Begin(v)elseif kind=="TravelFinished"then M.Finish(v)end end)
 P.CharacterAdded:Connect(function()M.Phase="Idle";veil.Visible=false;H.Refresh()end)
 if P:GetAttribute("TowerTraveling")then M.Begin({Id=P:GetAttribute("TravelId")or 0,Name=P:GetAttribute("TravelName")})end
 veil:GetPropertyChangedSignal("Visible"):Connect(function()if H.Refresh then H.Refresh()end end)
 M.Ready=true;M.Gui=veil;M.Sound=whoosh
end
return M
