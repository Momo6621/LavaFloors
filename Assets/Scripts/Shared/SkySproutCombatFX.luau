local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local FX={}
function FX.Start(event)
 local localPlayer=Players.LocalPlayer
 local moves={};local applied={};local rigs=setmetatable({},{__mode="k"})
 local function rig(ch)
  local cached=rigs[ch];if cached then return cached end
  local joints={}
  for _,d in ipairs(ch:GetDescendants())do
   if d:IsA("Motor6D")or d:IsA("AnimationConstraint")then
    local name=d.Name:gsub(" ","")
    if name=="RightShoulder"then joints.Right=d
    elseif name=="LeftShoulder"then joints.Left=d
    elseif name=="RightElbow"then joints.RightElbow=d
    elseif name=="LeftElbow"then joints.LeftElbow=d
    elseif name=="RightHip"then joints.RightHip=d
    elseif name=="RightKnee"then joints.RightKnee=d
    elseif name=="LeftHip"then joints.LeftHip=d
    elseif name=="LeftKnee"then joints.LeftKnee=d
    elseif name=="Waist"then joints.Waist=d end
   end
  end
  rigs[ch]=joints;return joints
 end
 local function near(ch)
  local r=ch and ch:FindFirstChild("HumanoidRootPart");local own=localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
  return r and own and(r.Position-own.Position).Magnitude<160
 end
 local function offset(joint,degrees)
  if not joint then return CFrame.identity end
  local basis=joint.C0.Rotation
  return basis:Inverse()*CFrame.Angles(math.rad(degrees.X),math.rad(degrees.Y),math.rad(degrees.Z))*basis
 end
 local function apply(joint,degrees)
  if not joint or not joint.Parent then return end
  local pose=offset(joint,degrees);joint.Transform=joint.Transform*pose;applied[joint]=pose
 end
 Run.PreAnimation:Connect(function()
  for joint,pose in pairs(applied)do if joint.Parent then joint.Transform=joint.Transform*pose:Inverse()end end
  table.clear(applied)
 end)
 Run.PreSimulation:Connect(function()
  local now=os.clock()
  for _,player in ipairs(Players:GetPlayers())do
   local ch=player.Character;local move=moves[player.UserId]
   local active=player:GetAttribute("ArenaMode")=="Match"
   if move and now-move.Time>(move.Heavy and .9 or .38)then moves[player.UserId]=nil;move=nil end
   if ch and(active or move or player:GetAttribute("Mounted"))and near(ch)then
    local j=rig(ch)
    local block=player:GetAttribute("Blocking")==true
    local stunned=player:GetAttribute("Stunned")==true
    local right=Vector3.new(block and 85 or 55,-12,-15);local left=Vector3.new(block and 85 or 55,12,15)
    local elbow=block and 100 or 78
    local re,le=elbow,elbow
    local twist=0
    if stunned then right=Vector3.new(20,-12,-20);left=Vector3.new(20,12,20);re=30;le=30
    elseif move then
     local age=now-move.Time
     if move.Heavy then
      if age<.45 then
       local a=math.clamp(age/.18,0,1);right=right:Lerp(Vector3.new(35,-50,-38),a);re=110;twist=-16*a
      else
       local a=math.sin(math.clamp((age-.45)/.38,0,1)*math.pi)
       right=right:Lerp(Vector3.new(100,25,-4),a);re=elbow*(1-a);twist=22*a
      end
     else
      local a=math.sin(math.clamp(age/.32,0,1)*math.pi)
      if move.Combo%2==1 and move.Combo~=3 then left=left:Lerp(Vector3.new(92,-5,3),a);le=elbow*(1-a);twist=-8*a
      else right=right:Lerp(Vector3.new(92,5,-3),a);re=elbow*(1-a);twist=move.Combo==3 and 16*a or 8*a end
     end
    end
    if move and move.Kick then local a=math.sin(math.clamp((now-move.Time)/.42,0,1)*math.pi);apply(j.RightHip,Vector3.new(95*a,0,-10*a));apply(j.RightKnee,Vector3.new(-25*a,0,0))end
    if player:GetAttribute("Mounted")then
     apply(j.RightHip,Vector3.new(75,0,-18));apply(j.LeftHip,Vector3.new(75,0,18));apply(j.RightKnee,Vector3.new(-70,0,0));apply(j.LeftKnee,Vector3.new(-70,0,0));right=Vector3.new(28,0,-10);left=Vector3.new(28,0,10);re=70;le=70
    end
    apply(j.Right,right);apply(j.Left,left);apply(j.RightElbow,Vector3.new(re,0,0));apply(j.LeftElbow,Vector3.new(le,0,0));apply(j.Waist,Vector3.new(stunned and -8 or 0,twist,0))
   end
  end
 end)
 local function sound(parent,heavy,block)
  if game.Players.LocalPlayer:GetAttribute("SoundMuted")then return end
  if not parent then return end
  local s=Instance.new("Sound");s.Name="ArenaHit";s.SoundId="rbxasset://sounds/action_jump_land.mp3";s.Volume=block and .2 or .32;s.PlaybackSpeed=block and 1.8 or(heavy and .85 or 1.25);s.RollOffMaxDistance=70;s.Parent=parent;s:Play();Debris:AddItem(s,2)
 end
 local function flash(ch,color,duration)
  if not ch or not near(ch)or localPlayer:GetAttribute("LowEffects")then return end
  local h=Instance.new("Highlight");h.Adornee=ch;h.FillColor=color;h.OutlineColor=color;h.FillTransparency=.6;h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=ch;Debris:AddItem(h,duration)
 end
 local function number(target,label,color)
  local root=target:IsA("BasePart")and target or target:FindFirstChild("HumanoidRootPart")
  if not root then return end
  local b=Instance.new("BillboardGui");b.Name="ArenaDamage";b.Adornee=root;b.Size=UDim2.fromOffset(190,50);b.StudsOffsetWorldSpace=Vector3.new(0,3,0);b.AlwaysOnTop=true;b.MaxDistance=90;b.Parent=root
  local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextSize=22;t.TextColor3=color;t.TextStrokeTransparency=.5;t.Text=label;t.Parent=b
  Tween:Create(b,TweenInfo.new(.65,Enum.EasingStyle.Quad),{StudsOffsetWorldSpace=Vector3.new(0,5,0)}):Play()
  Tween:Create(t,TweenInfo.new(.65),{TextTransparency=1,TextStrokeTransparency=1}):Play();Debris:AddItem(b,.7)
 end
 local function spark(root,color)
  if not root or localPlayer:GetAttribute("LowEffects")then return end
  local ball=Instance.new("Part");ball.Name="ArenaHitSpark";ball.Shape=Enum.PartType.Ball;ball.Anchored=true;ball.CanCollide=false;ball.CanTouch=false;ball.CanQuery=false;ball.Material=Enum.Material.Neon;ball.Color=color;ball.Transparency=.25;ball.Size=Vector3.one*.45;ball.Position=root.Position;ball.Parent=workspace
  Tween:Create(ball,TweenInfo.new(.16),{Size=Vector3.one*2.5,Transparency=1}):Play();Debris:AddItem(ball,.18)
 end
 event.OnClientEvent:Connect(function(kind,v)
  if kind=="Attack"then
   moves[v.UserId]={Time=os.clock(),Heavy=v.Heavy,Kick=v.Kick,Combo=v.Combo or 1}
   local who=Players:GetPlayerByUserId(v.UserId)
   if v.Heavy and who and who.Character then flash(who.Character,Color3.fromRGB(255,202,109),.5);number(who.Character,"HEAVY",Color3.fromRGB(255,207,112))end
  elseif kind=="Impact"then
   local who=Players:GetPlayerByUserId(v.UserId);local ch=who and who.Character
   if ch and near(ch)then
    local color=v.GuardBreak and Color3.fromRGB(255,197,103)or(v.Blocked and Color3.fromRGB(151,202,255)or Color3.fromRGB(255,131,128))
    flash(ch,color,.18);spark(ch:FindFirstChild("HumanoidRootPart"),color);sound(ch:FindFirstChild("HumanoidRootPart"),v.Damage>=14,v.Blocked)
    number(ch,(v.GuardBreak and"GUARD BREAK "or(v.Blocked and"BLOCK "or"")).."-"..v.Damage,color)
   end
  elseif kind=="Practice"and v.Target then
   sound(v.Target,v.Heavy,false);number(v.Target,v.Heavy and"HEAVY"or"HIT "..v.Count,Color3.fromRGB(255,222,142));spark(v.Target,Color3.fromRGB(128,244,207))
  elseif kind=="Dodge"then
   local who=Players:GetPlayerByUserId(v.UserId);if who and who.Character then flash(who.Character,Color3.fromRGB(194,164,255),.26)end
  end
 end)
 Players.PlayerRemoving:Connect(function(player)moves[player.UserId]=nil end)
end
return FX
