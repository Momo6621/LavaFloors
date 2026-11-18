local M={}
function M.Start(event,gui)
 local P=game.Players.LocalPlayer;local Nav=require(game.ReplicatedStorage.SkySproutNavigation)
 local list=gui.QuestPanel.List;local cards={};local current
 local dark=Color3.fromRGB(36,39,46);local white=Color3.fromRGB(240,241,244);local blue=Color3.fromRGB(67,128,230)
 for i,id in {"Explore","Courier","Training"}do list[id].LayoutOrder=i end
 local function rounded(v)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=v end
 local heading=Instance.new("TextLabel");heading.Name="ContractsHeading";heading.Text="REGIONAL CONTRACTS • Optional exploration and combat";heading.Font=Enum.Font.GothamBold;heading.TextSize=12;heading.TextColor3=white;heading.TextWrapped=true;heading.BackgroundTransparency=1;heading.Size=UDim2.new(1,-8,0,32);heading.LayoutOrder=4;heading.Parent=list
 local function label(parent,name,size,pos,txt)
  local t=Instance.new("TextLabel");t.Name=name;t.Size=size;t.Position=pos;t.Text=txt or"";t.BackgroundTransparency=1;t.TextColor3=white;t.Font=Enum.Font.GothamMedium;t.TextSize=12;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=parent;return t
 end
 local function button(parent,name,title,x)
  local b=Instance.new("TextButton");b.Name=name;b.Text=title;b.Size=UDim2.new(.5,-14,0,30);b.Position=UDim2.new(x,8,1,-38);b.TextColor3=white;b.BackgroundColor3=blue;b.Font=Enum.Font.GothamBold;b.TextSize=12;b.BorderSizePixel=0;b.Parent=parent;rounded(b);return b
 end
 for i,id in {"Survey","Patrol"}do
  local f=Instance.new("Frame");f.Name="Contract_"..id;f.LayoutOrder=4+i;f.Size=UDim2.new(1,-8,0,184);f.BackgroundColor3=dark;f.BorderSizePixel=0;f.Parent=list;rounded(f)
  local title=label(f,"Title",UDim2.new(1,-16,0,26),UDim2.fromOffset(8,5),"Regional contract");title.Font=Enum.Font.GothamBold;title.TextSize=14
  local desc=label(f,"Description",UDim2.new(1,-16,0,60),UDim2.fromOffset(8,34))
  local reward=label(f,"Reward",UDim2.new(1,-16,0,24),UDim2.fromOffset(8,96));reward.TextColor3=Color3.fromRGB(247,209,117)
  local progress=label(f,"Progress",UDim2.new(1,-16,0,20),UDim2.fromOffset(8,120))
  local accept=button(f,"Accept","Accept",0);local track=button(f,"Track","Track",.5)
  accept.Activated:Connect(function()
   local data=cards[id].Data;if not data or data.Complete then return end
   event:FireServer(data.Started and"ContractClaim"or"ContractAccept",id)
  end)
  track.Activated:Connect(function()
   local data=cards[id].Data;if data and data.Started and not data.Complete then Nav.TrackContract(data);require(game.ReplicatedStorage.SkySproutHUD).Close()end
  end)
  cards[id]={Frame=f,Title=title,Description=desc,Reward=reward,Progress=progress,Accept=accept,Track=track}
 end
 event.OnClientEvent:Connect(function(kind,v)
  if kind~="Contracts"then return end;current=v;Nav.UpdateContracts(v)
  for _,data in v.Entries do local c=cards[data.Id];if c then
   c.Data=data;c.Title.Text=data.Title;c.Description.Text=data.Text;c.Reward.Text="+"..data.Coins.." coins • +"..data.XP.." XP"
   c.Progress.Text=data.Complete and"Completed on this floor"or(data.Ready and"Ready to report in town"or(data.Started and("Step "..data.Step.." / "..data.Total)or"Available on this floor"))
   c.Accept.Text=data.Complete and"Complete"or(data.Started and(data.Ready and"Report in town"or"In progress")or"Accept")
   c.Accept.Active=not data.Complete and(not data.Started or data.Ready);c.Accept.AutoButtonColor=c.Accept.Active;c.Accept.BackgroundColor3=c.Accept.Active and blue or dark
   c.Track.Visible=data.Started and not data.Complete;c.Track.Text="Track route"
  end end
 end)
 local function sync()event:FireServer("ContractSync")end
 P:GetAttributeChangedSignal("VisitFloor"):Connect(sync);P:GetAttributeChangedSignal("ArenaMode"):Connect(function()if P:GetAttribute("ArenaMode")=="Lobby"then sync()end end)
 gui.QuestPanel:GetPropertyChangedSignal("Visible"):Connect(function()if gui.QuestPanel.Visible then sync()end end)
 sync()
end
return M
