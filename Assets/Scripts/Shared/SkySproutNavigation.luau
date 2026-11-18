local N={Story=nil,Contract=nil,Location=nil,Kind="Story"}
local gui,label,marker,anchor,markerText
local P=game.Players.LocalPlayer
local Trails=require(game.ReplicatedStorage.SkySproutTrails)
local function selected()if N.Kind=="Explore"then return N.Location end;return N.Kind=="Contract"and N.Contract or N.Story end
local function clearMarker()if anchor then anchor:Destroy();anchor=nil;marker=nil;markerText=nil end end
local function rebuild()
 clearMarker();if P:GetAttribute("ArenaMode")=="Match"or P:GetAttribute("RPGRaid")then return end;local v=selected();if not v or v.TargetFloor~=(P:GetAttribute("VisitFloor")or 1)or typeof(v.TargetPosition)~="Vector3"then return end
 anchor=Instance.new("Part");anchor.Name="MyObjectiveAnchor";anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Transparency=1;anchor.Size=Vector3.one;anchor.Position=v.TargetPosition;anchor:SetAttribute("TargetKind",N.Kind);anchor:SetAttribute("TargetFloor",v.TargetFloor);anchor.Parent=workspace
 marker=Instance.new("BillboardGui");marker.Name="MyStoryWaypoint";marker.Size=UDim2.fromOffset(200,48);marker.StudsOffset=Vector3.new(0,8,0);marker.AlwaysOnTop=true;marker.MaxDistance=4500;marker.Parent=anchor
 markerText=Instance.new("TextLabel");markerText.Size=UDim2.fromScale(1,1);markerText.BackgroundColor3=Color3.fromRGB(27,29,35);markerText.BackgroundTransparency=.2;markerText.TextColor3=N.Kind=="Contract"and Color3.fromRGB(255,213,128)or Color3.fromRGB(151,197,255);markerText.Font=Enum.Font.GothamBold;markerText.TextSize=12;markerText.TextWrapped=true;markerText.Parent=marker
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=markerText
end
function N.SetStory(v)N.Story=v;if N.Kind=="Story"then rebuild()end end
function N.SelectStory()N.Kind="Story";N.PreviousKind=nil;N.Location=nil;rebuild()end
function N.TrackContract(v)N.Contract=v;N.Kind="Contract";N.PreviousKind=nil;N.Location=nil;rebuild()end
function N.UpdateContracts(snapshot)
 if not N.Contract or snapshot.Floor~=N.Contract.Floor then return end
 for _,v in snapshot.Entries do if v.Id==N.Contract.Id then
  N.Contract=v
  if v.Complete then
   if N.Kind=="Contract"then N.Kind="Story"elseif N.Kind=="Explore"and N.PreviousKind=="Contract"then N.PreviousKind="Story"end
  end
  rebuild();return
 end end
end
function N.Current()return selected()end
function N.TrackRegion(v)
 if N.Kind~="Explore"then N.PreviousKind=N.Kind end;N.Location=v;N.Kind="Explore";rebuild()
end
function N.ResumeQuest()
 N.Kind=N.PreviousKind=="Contract"and N.Contract and"Contract"or"Story";N.Location=nil;N.PreviousKind=nil;rebuild()
end
function N.Discoveries(v)
 if N.Kind~="Explore"or not N.Location or N.Location.TargetFloor~=v.Floor then return end
 local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
 for _,node in v.Nodes do if node.Id==N.Location.Id and node.Known then
  N.Location.Known=true
  if root and(root.Position-N.Location.TargetPosition).Magnitude<35 then N.ResumeQuest()end
  return
 end end
end
function N.Start(screen)
 if N.Started then return end;N.Started=true;gui=screen
 Trails.Start(selected,gui)
 label=gui.StoryTracker:FindFirstChildWhichIsA("TextLabel")
 for _,attr in {"VisitFloor","ArenaMode","RPGRaid"}do P:GetAttributeChangedSignal(attr):Connect(rebuild)end
 local elapsed=0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;elapsed=0
  local v=selected();if not v then return end
  local r=P.Character and P.Character:FindFirstChild("HumanoidRootPart");local at=P:GetAttribute("VisitFloor")or 1;local distance
  local hint="Floor "..v.TargetFloor.." • use Floors to travel"
  if at==v.TargetFloor and r and typeof(v.TargetPosition)=="Vector3"then
   local delta=v.TargetPosition-r.Position;distance=math.floor(delta.Magnitude+.5)
   local camera=workspace.CurrentCamera;local facing=(camera and camera.ViewportSize.X>1 and camera.CFrame or r.CFrame):VectorToObjectSpace(delta)
   local direction=math.abs(facing.X)>math.abs(facing.Z)and(facing.X>0 and"right"or"left")or(facing.Z>0 and"behind"or"ahead")
   local route=Trails.Current;local along=route and route.Floor==at and route.TargetPosition and(route.TargetPosition-v.TargetPosition).Magnitude<2 and route.Length
   local trailHint=along and(route.Climb and along<60 and"Crest Trail • follow the ramps on foot"or("Trail "..math.floor(along+.5).." studs • "..(P:GetAttribute("LowEffects")and"follow the roads"or"follow the arrows")))
   hint=distance<=17 and"Nearby • interact with E / the prompt"or(trailHint or(distance.." studs • "..direction))
  end
  if N.Kind=="Explore"and v.Known and distance and distance<=17 then N.ResumeQuest();return end
  local title=N.Kind=="Explore"and("EXPLORE • "..v.Title)or(N.Kind=="Contract"and("REGIONAL • "..v.Title)or("STORY • FLOOR "..v.Home))
  local value=title.."\n"..v.Text.."\n"..hint
  if label and label.Text~=value then label.Text=value end
  if markerText then local text=(N.Kind=="Explore"and(v.MarkerLabel or"WAYSTONE")or(N.Kind=="Contract"and"REGIONAL OBJECTIVE"or"STORY OBJECTIVE")).."\n"..(distance and(distance.." studs")or"");if markerText.Text~=text then markerText.Text=text end end
  if gui:GetAttribute("TrackingKind")~=N.Kind then gui:SetAttribute("TrackingKind",N.Kind)end
 end)
 rebuild()
end
return N
