local M={Snapshots={}}
local RS=game:GetService("ReplicatedStorage")
local P=game.Players.LocalPlayer
local Nav=require(RS.SkySproutNavigation)
local Trails=require(RS.SkySproutTrails)
local Water=require(RS.SkySproutWaterConfig)
local ink=Color3.fromRGB(27,29,35);local white=Color3.fromRGB(240,241,244);local muted=Color3.fromRGB(165,174,190)
local blue=Color3.fromRGB(67,128,230);local gold=Color3.fromRGB(255,213,128);local mint=Color3.fromRGB(121,211,176)
local titles={Town="Town",Meadow="Lowlands",Forest="Woodland",Lake="Lake Village",Highlands="Crest Highlands",Ruins="Guardian Citadel"}
local order={"Town","Meadow","Forest","Lake","Highlands","Ruins"}
local function rounded(v,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 8);c.Parent=v end
local function text(parent,name,value,size,pos)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=value;t.Size=size;t.Position=pos;t.BackgroundTransparency=1;t.TextColor3=white;t.Font=Enum.Font.GothamMedium;t.TextSize=12;t.TextWrapped=true;t.Parent=parent;return t
end
local function button(parent,name,value)
 local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.TextColor3=white;b.Font=Enum.Font.GothamMedium;b.TextSize=12;b.BackgroundColor3=Color3.fromRGB(47,50,59);b.BorderSizePixel=0;b.Selectable=true;rounded(b,7);b.Parent=parent;return b
end
function M.Project(position,radius)
 if typeof(position)~="Vector3"or type(radius)~="number"or radius<=0 then return Vector2.new(.5,.5),true end
 local v=Vector2.new(position.X,position.Z)/radius
 local outside=v.Magnitude>1;if outside then v=v.Unit end
 return Vector2.new(.5+v.X*.44,.5+v.Y*.44),outside
end
function M.Layout(panel,size)
 local body=panel:FindFirstChild("AtlasBody");if not body then return end
 local w,h=size.X,size.Y;local bw,bh=w-24,math.max(80,h-140)
 body.Position=UDim2.fromOffset(12,78);body.Size=UDim2.fromOffset(bw,bh)
 local side=w>=440 or h<400
 local mapSize=side and math.min(260,math.floor(bw*.47),bh)or math.min(194,math.floor(bh*.5),bw)
 local plot=body.Plot;local list=body.Waystones
 local lx,ly,lw,lh,cols
 if side then
  plot.Position=UDim2.fromOffset(0,(bh-mapSize)/2);lx=mapSize+12;ly=0;lw=bw-lx;lh=bh;cols=1
 else
  plot.Position=UDim2.fromOffset((bw-mapSize)/2,0);lx=0;ly=mapSize+12;lw=bw;lh=bh-ly;cols=bw>=310 and 2 or 1
 end
 plot.Size=UDim2.fromOffset(mapSize,mapSize)
 list.Position=UDim2.fromOffset(lx,ly);list.Size=UDim2.fromOffset(lw,lh)
 local layoutOrder=table.clone(order);if panel:GetAttribute("ScenicFloor")then table.insert(layoutOrder,"Scenic")end
 local rows=math.ceil(#layoutOrder/cols);local gap=6;local cw=(lw-6-gap*(cols-1))/cols
 for i,id in layoutOrder do local row=list:FindFirstChild(id)
  if row then
   row.Position=UDim2.fromOffset(((i-1)%cols)*(cw+gap),math.floor((i-1)/cols)*54);row.Size=UDim2.fromOffset(cw,48)
   row.Track.Position=UDim2.fromOffset(4,2);row.Track.Size=UDim2.new(1,-68,1,-4)
   row.Go.Position=UDim2.new(1,-62,0,2);row.Go.Size=UDim2.fromOffset(56,44)
   row.Track.NextSelectionRight=row.Go;row.Go.NextSelectionLeft=row.Track
   local up=list:FindFirstChild(layoutOrder[i-cols]or"");local down=list:FindFirstChild(layoutOrder[i+cols]or"")
   row.Track.NextSelectionUp=up and up.Track or nil;row.Go.NextSelectionUp=up and up.Go or nil
   row.Track.NextSelectionDown=down and down.Track or panel.Floors;row.Go.NextSelectionDown=down and down.Go or panel.Close
  end
 end
 list.CanvasSize=UDim2.fromOffset(0,rows*54-6)
 panel.Floors.Position=UDim2.new(0,12,1,-52);panel.Floors.Size=UDim2.new(.5,-18,0,44)
 panel.Close.Position=UDim2.new(.5,6,1,-52);panel.Close.Size=UDim2.new(.5,-18,0,44)
 panel.Floors.NextSelectionRight=panel.Close;panel.Close.NextSelectionLeft=panel.Floors
 local last=panel:GetAttribute("ScenicFloor")and list.Scenic or list.Ruins;panel.Floors.NextSelectionUp=last.Track;panel.Close.NextSelectionUp=last.Go
 plot.FloorOutline.ZIndex=11;plot.InnerWall.ZIndex=12;plot.Tower.ZIndex=12;plot.North.ZIndex=14
 for _,v in plot.RegionLinks:GetChildren()do v.ZIndex=13 end
 for _,v in plot.Pins:GetChildren()do v.ZIndex=14 end
 plot.PlayerPin.ZIndex=16;plot.ObjectivePin.ZIndex=15
end
function M.Start(event,gui)
 local map=Instance.new("Frame");map.Name="RegionMap";map.AnchorPoint=Vector2.new(.5,.5);map.Position=UDim2.fromScale(.5,.5);map.Size=UDim2.fromOffset(520,500);map.BackgroundColor3=ink;map.BorderSizePixel=0;map.Visible=false;rounded(map,12);map.Parent=gui
 M.Panel=map
 local title=text(map,"Title","FLOOR ATLAS",UDim2.new(1,-24,0,26),UDim2.fromOffset(12,8));title.TextSize=18
 local hint=text(map,"Hint","Explore waystones to discover fast travel.",UDim2.new(1,-24,0,34),UDim2.fromOffset(12,38));hint.TextColor3=muted;hint.TextSize=11
 local body=Instance.new("Frame");body.Name="AtlasBody";body.BackgroundTransparency=1;body.Parent=map
 local plot=Instance.new("Frame");plot.Name="Plot";plot.BackgroundTransparency=1;plot.ClipsDescendants=false;plot.Parent=body
 local disc=Instance.new("Frame");disc.Name="FloorOutline";disc.AnchorPoint=Vector2.new(.5,.5);disc.Position=UDim2.fromScale(.5,.5);disc.Size=UDim2.fromScale(.91,.91);disc.BackgroundColor3=Color3.fromRGB(36,43,57);disc.BorderSizePixel=0;rounded(disc,1000);disc.Parent=plot
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(83,103,124);stroke.Thickness=1.5;stroke.Parent=disc
 for _,sample in {{.675,"InnerWall"},{.4,"Tower"}}do
  local ring=disc:Clone();ring.Name=sample[2];ring.Size=UDim2.fromScale(sample[1],sample[1]);ring.BackgroundTransparency=1;ring.Visible=false;ring.Parent=plot
 end
 text(plot,"North","N",UDim2.fromOffset(18,14),UDim2.new(.5,-9,0,0)).TextColor3=muted
 local wardLabel=text(plot,"WardTower","Tower",UDim2.fromOffset(74,18),UDim2.new(.5,-37,.4,-9));wardLabel.Visible=false;wardLabel.ZIndex=15
 local links=Instance.new("Folder");links.Name="RegionLinks";links.Parent=plot
 local pins=Instance.new("Folder");pins.Name="Pins";pins.Parent=plot
 local scenic=button(pins,"Conservatory","A");scenic.AnchorPoint=Vector2.new(.5,.5);scenic.Size=UDim2.fromOffset(26,26);scenic.BackgroundColor3=Color3.fromRGB(38,88,104);scenic.TextColor3=mint;scenic.SelectionOrder=37;scenic.Visible=false
 scenic.Activated:Connect(function()if M.TrackScenic then M.TrackScenic()end end)
 local player=text(plot,"PlayerPin","▲",UDim2.fromOffset(20,20),UDim2.fromScale(.5,.5));player.AnchorPoint=Vector2.new(.5,.5);player.TextSize=20;player.TextColor3=Color3.fromRGB(131,185,255);player.ZIndex=14
 local objective=text(plot,"ObjectivePin","◆",UDim2.fromOffset(20,20),UDim2.fromScale(.5,.5));objective.AnchorPoint=Vector2.new(.5,.5);objective.TextSize=20;objective.TextColor3=gold;objective.ZIndex=13;objective.Visible=false
 local list=Instance.new("ScrollingFrame");list.Name="Waystones";list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.Parent=body
 local floors=button(map,"Floors","Tower floors");local close=button(map,"Close","Close")
 close.Activated:Connect(function()map.Visible=false end)
 floors.Activated:Connect(function()local H=require(RS.SkySproutHUD);H.Toggle("Directory")end)
 local current;local byId={};local markers={};local linkParts={};local routeParts={};local targetRadius;local currentWard
 local scenicRow=Instance.new("Frame");scenicRow.Name="Scenic";scenicRow.BackgroundColor3=Color3.fromRGB(36,39,48);scenicRow.BorderSizePixel=0;rounded(scenicRow,8);scenicRow.Visible=false;scenicRow.Parent=list
 local scenicTrack=button(scenicRow,"Track","Coral sea walk\nOptional scenic trail");scenicTrack.BackgroundTransparency=1;scenicTrack.TextXAlignment=Enum.TextXAlignment.Left;scenicTrack.TextSize=11;scenicTrack.TextWrapped=true;scenicTrack.SelectionOrder=38
 local scenicGo=button(scenicRow,"Go","TRACK");scenicGo.BackgroundColor3=blue;scenicGo.SelectionOrder=39
 for _,b in {scenicTrack,scenicGo}do b.Activated:Connect(function()if M.TrackScenic then M.TrackScenic()end end)end
 for i=1,48 do
  for _,pool in {linkParts,routeParts}do local link=Instance.new("Frame");link.Name=(pool==linkParts and"Road_"or"Route_")..i;link.AnchorPoint=Vector2.new(.5,.5);link.BorderSizePixel=0;link.BackgroundColor3=pool==linkParts and Color3.fromRGB(67,78,94)or gold;link.ZIndex=13;link.Visible=false;link.Parent=links;pool[i]=link end
 end
 local function floorId()return P:GetAttribute("VisitFloor")or 1 end
 local function busy()return P:GetAttribute("InCombat")or P:GetAttribute("TowerTraveling")or P:GetAttribute("RPGRaid")or P:GetAttribute("ArenaMode")=="Match"end
 local function rowState()
  if not current then return end
  local n=0
  for id,node in byId do
   if node.Known then n+=1 end
   local row=list:FindFirstChild(id)
   if row then
    row.Track.Text=string.format("%02d",table.find(order,id)).." "..titles[id].."\n"..(node.Known and"Track on foot"or"Find waystone")
    row.Go.Text=not node.Known and"FIND"or(busy()and"WAIT"or"GO")
    row.Go.Active=not node.Known or not busy();row.Go.AutoButtonColor=row.Go.Active;row.Go.BackgroundColor3=node.Known and not busy()and blue or Color3.fromRGB(47,50,59)
   end
   local pin=markers[id];if pin then pin.TextColor3=node.Known and mint or muted end
  end
  hint.Text=busy()and(n.."/6 waystones • Travel available after combat. Tracking still works.")or(n.."/6 waystones • Blue: you • Gold: objective • Track to explore, GO to travel.")
  if current.Floor==Water.Floor then hint.Text..=" A: coral sea walk."end
 end
 function M.Select(id,travel)
  local node=byId[id];if not(current and node and current.Floor==floorId())then return false end
  if travel and node.Known then
   if busy()then return false end
   event:FireServer("RegionTravel",id);map.Visible=false;return true
  end
  Nav.TrackRegion({Id=id,Title=titles[id],Text="Reach the "..titles[id].." waystone.",TargetFloor=current.Floor,TargetPosition=node.Position,Known=node.Known})
  map.Visible=false;return true
 end
 function M.TrackScenic()
  if not current or current.Floor~=Water.Floor or current.Floor~=floorId()or current.Floor>(P:GetAttribute("UnlockedFloor")or 1)then return false end
  Nav.TrackRegion({Id=Water.Id,Title=Water.Name,Text="Follow the lake trail through the glass gallery to the observation room.",TargetFloor=Water.Floor,TargetPosition=Water.Target,Known=true,MarkerLabel="OBSERVATION ROOM"})
  map.Visible=false;return true
 end
 for i,id in order do
  local row=Instance.new("Frame");row.Name=id;row.BackgroundColor3=Color3.fromRGB(36,39,48);row.BorderSizePixel=0;rounded(row,8);row.Parent=list
  local track=button(row,"Track","");track.BackgroundTransparency=1;track.TextXAlignment=Enum.TextXAlignment.Left;track.TextSize=11;track.TextWrapped=true;track.SelectionOrder=i*2;track.Activated:Connect(function()M.Select(id,false)end)
  local go=button(row,"Go","FIND");go.SelectionOrder=i*2+1;go.Activated:Connect(function()M.Select(id,true)end)
  local pin=button(pins,id,tostring(i));pin.AnchorPoint=Vector2.new(.5,.5);pin.Size=UDim2.fromOffset(26,26);pin.BackgroundColor3=Color3.fromRGB(31,35,45);pin.TextColor3=muted;pin.TextSize=12;pin.ZIndex=12;pin.SelectionOrder=30+i
  pin.Activated:Connect(function()M.Select(id,false)end);markers[id]=pin
 end
 local function render()
  if not current then return end
  local r=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
  local ward=current.Floor==1 and r and Vector2.new(r.Position.X,r.Position.Z).Magnitude>current.Radius+30
  targetRadius=ward and(current.EntryRadius or 3600)or current.Radius
  currentWard=ward==true;map:SetAttribute("WardView",currentWard);map:SetAttribute("MapRadius",targetRadius);map:SetAttribute("SnapshotFloor",current.Floor)
  plot.InnerWall.Visible=currentWard;plot.Tower.Visible=currentWard;wardLabel.Visible=currentWard
  title.Text=(currentWard and"BEDROCK WARD"or("FLOOR "..current.Floor.." • "..require(RS.SkySproutWorldThemes)[current.Floor].Name))
  scenic.Visible=current.Floor==Water.Floor and not currentWard
  scenicRow.Visible=current.Floor==Water.Floor
  if scenic.Visible then local point=M.Project(Water.Target,targetRadius);scenic.Position=UDim2.fromScale(point.X,point.Y)end
  local size=plot.Size.X.Offset
  for _,pool in {linkParts,routeParts}do for _,line in pool do line.Visible=false end end
  local function mapLine(line,a,b,thickness)
   local start=M.Project(a,targetRadius);local finish=M.Project(b,targetRadius);local delta=finish-start;local mid=(start+finish)/2
   line.Visible=true;line.Position=UDim2.fromScale(mid.X,mid.Y);line.Size=UDim2.fromOffset(delta.Magnitude*size,thickness);line.Rotation=math.deg(math.atan2(delta.Y,delta.X))
  end
  local trails=Trails.Data[current.Floor]
  if trails then for i,edge in trails.Edges do if linkParts[i]then local a,b=trails.Nodes[edge[1]],trails.Nodes[edge[2]];local exterior=math.max(Vector2.new(a.X,a.Z).Magnitude,Vector2.new(b.X,b.Z).Magnitude)>current.Radius+30;if currentWard or not exterior then mapLine(linkParts[i],a,b,1)end end end end
  local route=Trails.Current
  if route and route.Floor==current.Floor then for i=2,#route.Points do if routeParts[i-1]then mapLine(routeParts[i-1],route.Points[i-1],route.Points[i],2)end end end
  for id,node in byId do
   markers[id].Visible=not currentWard
   local point=M.Project(node.Position,targetRadius);markers[id].Position=UDim2.fromScale(point.X,point.Y)
  end
  if r then local at,outside=M.Project(r.Position,targetRadius);player.Position=UDim2.fromScale(at.X,at.Y);player.Rotation=math.deg(math.atan2(r.CFrame.LookVector.X,-r.CFrame.LookVector.Z));player.Visible=true;player:SetAttribute("Outside",outside)else player.Visible=false end
  local objectiveInfo=Nav.Current();local show=objectiveInfo and objectiveInfo.TargetFloor==current.Floor and typeof(objectiveInfo.TargetPosition)=="Vector3"
  objective.Visible=show==true
  if show then local point=M.Project(objectiveInfo.TargetPosition,targetRadius);objective.Position=UDim2.fromScale(point.X,point.Y)end
 end
 function M.Receive(v)
  if type(v)~="table"or type(v.Floor)~="number"or v.Floor%1~=0 or v.Floor<1 or v.Floor>20 or type(v.Radius)~="number"or v.Radius<=0 or type(v.Nodes)~="table"then return end
  M.Snapshots[v.Floor]=v
  if v.Floor~=floorId()then return end
  current=v;M.Current=v;byId={}
  map:SetAttribute("ScenicFloor",v.Floor==Water.Floor);M.Layout(map,Vector2.new(map.Size.X.Offset,map.Size.Y.Offset))
  for _,node in v.Nodes do if titles[node.Id]and typeof(node.Position)=="Vector3"then byId[node.Id]=node end end
  for id,pin in markers do pin.Visible=byId[id]~=nil end
  Nav.Discoveries(v);rowState();render()
 end
 function M.Refresh()rowState();render()end
 local CAS=game:GetService("ContextActionService");local UIS=game:GetService("UserInputService")
 local function toggle()
  if P:GetAttribute("ArenaMode")=="Match"or P:GetAttribute("RPGRaid")or P:GetAttribute("TowerTraveling")then return end
  require(RS.SkySproutHUD).Toggle("RegionMap")
 end
 CAS:BindAction("TowerRegionMap",function(_,state)if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox()then toggle()end;return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.M,Enum.KeyCode.ButtonSelect)
 event.OnClientEvent:Connect(function(kind,v)if kind=="Regions"then M.Receive(v)elseif kind=="OpenRegions"then if not P:GetAttribute("RPGRaid")and P:GetAttribute("ArenaMode")~="Match"then require(RS.SkySproutHUD).Toggle("RegionMap")end end end)
 map:GetPropertyChangedSignal("Visible"):Connect(function()if map.Visible then event:FireServer("RegionSync");M.Refresh()end end)
 P:GetAttributeChangedSignal("VisitFloor"):Connect(function()map.Visible=false;current=nil;M.Current=nil;local saved=M.Snapshots[floorId()];if saved then M.Receive(saved)end end)
 for _,attr in {"InCombat","TowerTraveling","ArenaMode","RPGRaid"}do P:GetAttributeChangedSignal(attr):Connect(function()rowState();if P:GetAttribute("ArenaMode")=="Match"or P:GetAttribute("RPGRaid")or P:GetAttribute("TowerTraveling")then map.Visible=false end end)end
 local elapsed=0;game:GetService("RunService").Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed<.25 then return end;elapsed=0;if map.Visible then render()end end)
 M.Layout(map,Vector2.new(520,500));event:FireServer("RegionSync");return map
end
return M
