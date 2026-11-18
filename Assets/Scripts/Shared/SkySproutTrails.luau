local T={Data=require(game.ReplicatedStorage.SkySproutTrailData),Current=nil,Visible=0}
local P=game.Players.LocalPlayer
local function flat(v,y)return Vector3.new(v.X,y,v.Z)end
local function project(p,a,b)
 local d=b-a;local length=d:Dot(d);if length<.001 then return a end
 return a+d*math.clamp((p-a):Dot(d)/length,0,1)
end
function T.Plan(floor,start,goal)
 local map=T.Data[floor];if not map or typeof(start)~="Vector3"or typeof(goal)~="Vector3"then return nil end
 start=flat(start,map.Y);goal=flat(goal,map.Y)
 local nodes=table.clone(map.Nodes);local edges=table.clone(map.Edges)
 local function snap(pos)
  local chosen,point,best
  for _,e in map.Edges do if e[1]~=e[2]then local at=project(pos,nodes[e[1]],nodes[e[2]]);local d=(pos-at).Magnitude;if not best or d<best then chosen=e;point=at;best=d end end end
  if not chosen then return nil end
  table.insert(nodes,point);local id=#nodes;table.insert(edges,{id,chosen[1]});table.insert(edges,{id,chosen[2]});return id,best,chosen
 end
 local a,offA,edgeA=snap(start);local b,offB,edgeB=snap(goal);if not a or not b then return nil end
 if edgeA==edgeB then table.insert(edges,{a,b})end
 local dist={[a]=0};local previous={};local used={}
 for _=1,#nodes do
  local u,lowest=nil,math.huge;for i,cost in dist do if not used[i]and cost<lowest then u=i;lowest=cost end end
  if not u then return nil end;if u==b then break end;used[u]=true
  for _,e in edges do local v=e[1]==u and e[2]or e[2]==u and e[1];if v then local nextCost=lowest+(nodes[u]-nodes[v]).Magnitude;if nextCost<(dist[v]or math.huge)then dist[v]=nextCost;previous[v]=u end end end
 end
 if not dist[b]then return nil end
 local reversed={};local id=b
 repeat table.insert(reversed,nodes[id]);if id==a then break end;id=previous[id]until not id
 local points={start};local function add(v)if(points[#points]-v).Magnitude>.75 then table.insert(points,v)end end
 for i=#reversed,1,-1 do add(reversed[i])end;add(goal)
 if(start-goal).Magnitude<90 then points={start,goal}end
 local length=0;for i=2,#points do length+=(points[i]-points[i-1]).Magnitude end
 return {Floor=floor,Points=points,Length=length,Goal=goal,OffTrail=offA,EndOffset=offB}
end
function T.AtDistance(plan,distance)
 for i=2,#plan.Points do local a,b=plan.Points[i-1],plan.Points[i];local d=(b-a).Magnitude
  if d>.001 then if distance<=d then return a:Lerp(b,distance/d),(b-a).Unit end;distance-=d end
 end;return nil
end
function T.Allowed(player,target)
 return target and target.TargetFloor==(player:GetAttribute("VisitFloor")or 1)and target.TargetFloor<=(player:GetAttribute("UnlockedFloor")or 1)
  and not player:GetAttribute("TowerTraveling")and not player:GetAttribute("RPGRaid")and not player:GetAttribute("InCombat")and player:GetAttribute("ArenaMode")~="Match"and player:GetAttribute("ArenaMode")~="Loading"
end
function T.Start(current,gui)
 if T.Started then return end;T.Started=true
 local folder=Instance.new("Folder");folder.Name="MyTrailGuidance";folder.Parent=workspace;T.Folder=folder
 local pool={}
 for i=1,24 do local p=Instance.new("Part");p.Name="TrailGlyph";p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Size=Vector3.new(.55,.09,3.4);p.Transparency=1;p.Parent=folder;pool[i]=p end
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include;ray.RespectCanCollide=true
 local elapsed=0
 local function hide()for _,p in pool do p.Transparency=1 end;T.Visible=0 end
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.25 then return end;elapsed=0
  local target=current();local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
  local floor=P:GetAttribute("VisitFloor")or 1;local map=T.Data[floor]
  if not(root and map and T.Allowed(P,target)and typeof(target.TargetPosition)=="Vector3")or math.abs(root.Position.Y-map.Y)>14 then T.Current=nil;hide();return end
  local elevated=target.TargetPosition.Y-map.Y>24
  local goal=elevated and map.Nodes[map.Waystones.Highlands]or target.TargetPosition
  local plan=T.Plan(floor,root.Position,goal);if plan then plan.TargetPosition=target.TargetPosition;plan.Climb=elevated end;T.Current=plan
  if not plan or plan.Length<17 or P:GetAttribute("LowEffects")or gui:GetAttribute("ModalOpen")then hide();return end
  local world=workspace:FindFirstChild("SkySprout");local floors=world and world:FindFirstChild("Floors");local active=floors and floors:FindFirstChild("Floor_"..floor)
  if not active then hide();return end
  local included={active};local ward=floor==1 and world:FindFirstChild("BedrockWard");if ward then table.insert(included,ward)end;ray.FilterDescendantsInstances=included
  local accent=require(game.ReplicatedStorage.SkySproutWorldThemes)[floor].Accent:Lerp(Color3.new(1,1,1),.25)
  hide()
  for i=1,12 do
   local at,dir=T.AtDistance(plan,10+i*13)
   if at then
    local hit=workspace:Raycast(at+Vector3.new(0,6,0),Vector3.new(0,-12,0),ray)
    if hit and hit.Normal.Y>.7 and hit.Position.Y<map.Y+4 then
     local tip=Vector3.new(at.X,hit.Position.Y+.16,at.Z)+dir*1.4;local side=dir:Cross(Vector3.yAxis)
     for j,s in {-1,1}do local back=tip-dir*2.7+side*s*1.65;local p=pool[(i-1)*2+j];p.Size=Vector3.new(.55,.09,(tip-back).Magnitude);p.CFrame=CFrame.lookAt((tip+back)/2,tip);p.Color=accent;p.Transparency=.2+i*.025;T.Visible+=1 end
    end
   end
  end
 end)
end
return T
