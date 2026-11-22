local H={}
local dark=Color3.fromRGB(38,32,84);local buttonColor=Color3.fromRGB(58,52,112);local white=Color3.fromRGB(255,255,255)
local ink=Color3.fromRGB(16,12,40)
local blue=Color3.fromRGB(67,128,230);local muted=Color3.fromRGB(200,205,235)
local gold=Color3.fromRGB(255,200,45)
local BOLD=Font.fromEnum(Enum.Font.LuckiestGuy)
local MEDIUM=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Bold)
local NAV={Queue=Color3.fromRGB(240,70,80),Floors=Color3.fromRGB(150,90,255),Quests=Color3.fromRGB(50,150,255),Styles=Color3.fromRGB(255,140,40),Map=Color3.fromRGB(25,195,165),Settings=Color3.fromRGB(120,125,160),Mount=Color3.fromRGB(80,195,75)}
local function stroke(v,thickness,color)
 local s=v:FindFirstChild("ModernStroke")or Instance.new("UIStroke");s.Name="ModernStroke";s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 s.Color=color or ink;s.Transparency=0;s.Thickness=thickness or 3;s.Parent=v
end
local function pop(v,color,thickness)
 v.BackgroundColor3=color;v.BackgroundTransparency=0
 local g=v:FindFirstChild("PopGradient")or Instance.new("UIGradient");g.Name="PopGradient";g.Rotation=90
 g.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(205,205,205));g.Parent=v
 stroke(v,thickness or 3,color:Lerp(Color3.new(),.55))
end
local function modernFonts(root)
 for _,v in root:GetDescendants()do
  if v:IsA("TextLabel")or v:IsA("TextButton")or v:IsA("TextBox")then
   local f=v.Font;local strong=v:IsA("TextButton")or f==Enum.Font.GothamBold or f==Enum.Font.GothamBlack or f==Enum.Font.GothamSemibold or f==Enum.Font.SourceSansBold or f==Enum.Font.FredokaOne
   local want=strong and BOLD or MEDIUM
   if v.FontFace.Family~=want.Family or v.FontFace.Weight~=want.Weight then v.FontFace=want end
  end
 end
end
local panels={"Directory","QuestPanel","Loadout","Shop","RegionMap","SettingsPanel","Result","GuardianVictory","OwnerPanel"}
local function rounded(v,r)local c=v:FindFirstChildOfClass("UICorner")or Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 10);c.Parent=v end
local function frame(parent,name,size,pos)
 local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=dark;f.BackgroundTransparency=.08;f.BorderSizePixel=0;f.Parent=parent;rounded(f);return f
end
local function text(parent,name,value,size,pos)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=value;t.Size=size;t.Position=pos;t.BackgroundTransparency=1;t.Font=Enum.Font.GothamMedium;t.TextSize=13;t.TextColor3=white;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=parent;return t
end
local function button(parent,name,value,size,pos)
 local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Size=size;b.Position=pos;b.BackgroundColor3=buttonColor;b.TextColor3=white;b.Font=Enum.Font.GothamMedium;b.TextSize=14;b.BorderSizePixel=0;b.Parent=parent;rounded(b);return b
end
function H.Prepare(gui)
 if gui:FindFirstChild("NavToggle")then return end
 gui:SetAttribute("StandardHUD",true)
 for _,v in gui:GetDescendants()do
  if v:IsA("TextButton")then v.BackgroundColor3=buttonColor;v.TextColor3=white
  elseif v:IsA("TextLabel")then v.TextColor3=white
  elseif v:IsA("Frame")and v.Name~="Fill"then v.BackgroundColor3=dark end
 end
 button(gui.Lobby,"Mount","Mount [V]",UDim2.fromOffset(120,38),UDim2.fromOffset(6,268))
 button(gui,"RunToggle","Run",UDim2.fromOffset(52,38),UDim2.new())
 button(gui,"NavToggle","Menu",UDim2.fromOffset(108,34),UDim2.fromOffset(12,86))
 button(gui.Lobby,"Map","Map",UDim2.fromOffset(120,38),UDim2.fromOffset(6,180))
 button(gui.Lobby,"Settings","Settings",UDim2.fromOffset(120,38),UDim2.fromOffset(6,224))
 local cash=text(gui.Top,"Coins","Coins 0",UDim2.fromOffset(150,20),UDim2.fromOffset(10,33));cash.TextColor3=Color3.fromRGB(247,209,117)
 local vital=frame(gui,"StandardVitals",UDim2.fromOffset(228,66),UDim2.new(0,12,1,-78))
 text(vital,"HPText","Health 100 / 100",UDim2.new(1,-20,0,17),UDim2.fromOffset(10,6))
 local hp=frame(vital,"HealthTrack",UDim2.new(1,-20,0,8),UDim2.fromOffset(10,27));hp.BackgroundColor3=Color3.fromRGB(57,62,68)
 local fill=frame(hp,"Fill",UDim2.fromScale(1,1),UDim2.new());fill.BackgroundColor3=Color3.fromRGB(88,198,118);fill.BackgroundTransparency=0
 text(vital,"EnergyText","Energy 100",UDim2.new(1,-20,0,14),UDim2.fromOffset(10,40)).TextSize=11
 local energy=frame(vital,"EnergyTrack",UDim2.new(1,-20,0,4),UDim2.fromOffset(10,58));energy.BackgroundColor3=Color3.fromRGB(57,62,68)
 local ef=frame(energy,"Fill",UDim2.fromScale(1,1),UDim2.new());ef.BackgroundColor3=blue;ef.BackgroundTransparency=0
 local settings=frame(gui,"SettingsPanel",UDim2.fromOffset(380,248),UDim2.fromScale(.5,.5));settings.AnchorPoint=Vector2.new(.5,.5);settings.Visible=false
 text(settings,"Title","Settings",UDim2.new(1,-70,0,28),UDim2.fromOffset(16,12)).TextSize=20
 button(settings,"Close","X",UDim2.fromOffset(32,32),UDim2.new(1,-44,0,10))
 local desc=text(settings,"Description","Effects quality\nUse Roblox's menu for graphics, camera and volume settings.",UDim2.new(1,-32,0,58),UDim2.fromOffset(16,55));desc.TextWrapped=true
 button(settings,"Standard","Standard",UDim2.new(.5,-22,0,42),UDim2.fromOffset(16,126))
 button(settings,"Low","Low effects",UDim2.new(.5,-22,0,42),UDim2.new(.5,6,0,126))
 local note=text(settings,"Note","Low effects reduces local lights and cosmetic effects. Combat warnings remain visible.",UDim2.new(1,-32,0,50),UDim2.fromOffset(16,181));note.TextWrapped=true;note.TextSize=12;note.TextColor3=muted
 local backdrop=button(gui,"MenuBackdrop","",UDim2.fromScale(1,1),UDim2.new());backdrop.BackgroundColor3=Color3.new();backdrop.BackgroundTransparency=.45;backdrop.Visible=false;backdrop.ZIndex=8;backdrop.AutoButtonColor=false
 gui.Help.Text="Click: attack   R: heavy   F: guard   Q: dodge   Shift: run   V: mount";gui.Help.TextSize=11
end
local function rect(v,x,y,w,h,ax,ay)
 if not v then return end;v.AnchorPoint=Vector2.new(ax or 0,ay or 0);v.Position=UDim2.fromOffset(x,y);v.Size=UDim2.fromOffset(w,h)
end
function H.Layout(gui,size,touch,navOpen,mode)
 H.Prepare(gui)
 local w,h=size.X,size.Y;local compact=touch or w<760 or h<520;local portrait=compact and w<600;local touchPortrait=touch and portrait
 gui:SetAttribute("CompactHUD",compact)
 local statsWidth=portrait and math.min(222,w-146)or(compact and 222 or 248)
 rect(gui.Top,12,10,statsWidth,64);pop(gui.Top,gold,4);rounded(gui.Top,18)
 gui.Top.Title.Text=require(game.ReplicatedStorage.SkySproutConfig).GameTitle;gui.Top.Title.Visible=false
 rect(gui.Top.Coins,14,4,statsWidth-62,28);gui.Top.Coins.TextSize=26;gui.Top.Coins.TextColor3=white;gui.Top.Coins.TextStrokeColor3=Color3.fromRGB(120,70,0);gui.Top.Coins.TextStrokeTransparency=0;gui.Top.Coins.TextXAlignment=Enum.TextXAlignment.Left
 rect(gui.Top.Progress,14,33,statsWidth-28,16);gui.Top.Progress.TextSize=13;gui.Top.Progress.TextXAlignment=Enum.TextXAlignment.Left;gui.Top.Progress.TextColor3=Color3.fromRGB(95,55,0)
 rect(gui.Top.Sound,statsWidth-44,9,34,24);gui.Top.Sound.TextSize=11;gui.Top.Sound.BackgroundColor3=Color3.fromRGB(120,70,0);gui.Top.Sound.BackgroundTransparency=0;gui.Top.Sound.TextColor3=white;rounded(gui.Top.Sound,12)
 rect(gui.Top.ProgressTrack,14,53,statsWidth-28,6);rounded(gui.Top.ProgressTrack,3);gui.Top.ProgressTrack.BackgroundColor3=Color3.fromRGB(150,95,0);local pf=gui.Top.ProgressTrack:FindFirstChild("Fill");if pf then rounded(pf,3);pf.BackgroundColor3=white end
 rect(gui.NavToggle,12,portrait and 156 or 82,108,34);pop(gui.NavToggle,Color3.fromRGB(255,110,60));gui.NavToggle.TextSize=18;gui.NavToggle.TextStrokeTransparency=.3;gui.NavToggle.TextStrokeColor3=ink;rounded(gui.NavToggle,17)
 local navColumns=compact and(not portrait and h<330 and 3 or 2)or 1
 local navW=compact and(navColumns==3 and 330 or 222)or 132;local navH=compact and(navColumns==3 and 135 or 178)or 308
 rect(gui.Lobby,12,portrait and 198 or 124,navW,navH);gui.Lobby.BackgroundTransparency=1;do local s=gui.Lobby:FindFirstChild("ModernStroke");if s then s:Destroy()end end
 local limit=gui.Lobby:FindFirstChildOfClass("UISizeConstraint");if limit then limit.MinSize=Vector2.zero;limit.MaxSize=Vector2.new(10000,10000)end
 gui.Lobby.Status.Visible=false
 local party=require(game.ReplicatedStorage.SkySproutConfig).PartyMode==true
 local menu=party and{"Styles","Settings"}or{"Queue","Floors","Quests","Styles","Map","Settings","Mount"}
 if party then for _,n in {"Queue","Floors","Quests","Map","Mount"}do local b=gui.Lobby:FindFirstChild(n);if b then b.Visible=false end end end
 for i,name in menu do
  local b=gui.Lobby:FindFirstChild(name);local col=(i-1)%navColumns;local row=math.floor((i-1)/navColumns)
  rect(b,6+col*108,6+row*43,compact and 102 or 120,37)
  pop(b,NAV[name]or buttonColor);b.TextSize=compact and 15 or 17;b.TextColor3=white;b.TextStrokeTransparency=.35;b.TextStrokeColor3=ink;rounded(b,12)
  b.TextXAlignment=Enum.TextXAlignment.Left;local pad=b:FindFirstChild("ModernPad")or Instance.new("UIPadding");pad.Name="ModernPad";pad.PaddingLeft=UDim.new(0,12);pad.Parent=b
 end
 gui.Lobby.Floors.Text="🗼  Floors";gui.Lobby.Quests.Text="📜  Quests";gui.Lobby.Styles.Text=party and"🧤  Gloves"or"🧤  Loadout";gui.Lobby.Map.Text="🗺️  Map";gui.Lobby.Settings.Text="⚙️  Settings"
 if compact then
  if not portrait then rect(gui.StandardVitals,w/2,math.max(h-146,154),198,66,.5,0)else rect(gui.StandardVitals,12,mode and(mode.Fight and 132 or(mode.Raid and 114 or 82))or 82,math.min(228,w-162),66)end
 else rect(gui.StandardVitals,12,h-78,228,66)end
 do local v=gui.StandardVitals;pop(v,dark);rounded(v,16)
  v.HPText.TextSize=14;v.EnergyText.TextSize=13;v.EnergyText.TextColor3=Color3.fromRGB(150,200,255)
  v.HealthTrack.Fill.BackgroundColor3=Color3.fromRGB(90,230,100);v.EnergyTrack.Fill.BackgroundColor3=Color3.fromRGB(70,165,255)
  v.HealthTrack.BackgroundColor3=ink;v.EnergyTrack.BackgroundColor3=ink
  v.HealthTrack.Size=UDim2.new(1,-20,0,8);rounded(v.HealthTrack,4);rounded(v.HealthTrack.Fill,4)
  v.EnergyTrack.Size=UDim2.new(1,-20,0,5);rounded(v.EnergyTrack,3);rounded(v.EnergyTrack.Fill,3)
 end
 for _,name in {"Top","Duel","Actions"}do local limit=gui[name]:FindFirstChildOfClass("UISizeConstraint");if limit then limit.MinSize=Vector2.zero;limit.MaxSize=Vector2.new(10000,10000)end end
 local tracker=gui:FindFirstChild("StoryTracker")
 if tracker then
  rect(tracker,12,portrait and 198 or(compact and 124 or(navOpen and 442 or 124)),portrait and math.min(200,w-198)or(compact and 222 or 248),(compact and not portrait)and math.max(20,math.min(96,h-278))or 96)
  pop(tracker,dark);rounded(tracker,16)
  local accent=tracker:FindFirstChild("Accent")or Instance.new("Frame");accent.Name="Accent";accent.BorderSizePixel=0;accent.BackgroundColor3=gold
  accent.Position=UDim2.fromOffset(8,10);accent.Size=UDim2.new(0,3,1,-20);rounded(accent,2);accent.Parent=tracker
  for _,t in tracker:GetChildren()do if t:IsA("TextLabel")then t.TextSize=13;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Size=UDim2.new(1,-30,1,-12);t.Position=UDim2.fromOffset(20,6)end end
 end
 local hot=gui:FindFirstChild("RPGHotbar");local hotW=compact and math.min(300,w-24)or 320
 if hot then
  rect(hot,w/2,h-(touchPortrait and 180 or(touch and h<300 and 4 or 10)),hotW,54,.5,1);pop(hot,dark);rounded(hot,18)
  for _,b in hot:GetChildren()do if b:IsA("TextButton")then b.TextSize=11;rounded(b,10);stroke(b,2);b.TextStrokeColor3=ink;b.TextStrokeTransparency=.3 end end
  local kick=hot:FindFirstChild("Kick");if kick then kick.BackgroundColor3=Color3.fromRGB(240,70,80)end
 end
 if party then gui.Help.Text="Click: shove   Space: jump   🟢 pads bounce   🛡️ bubbles block shoves"end
 rect(gui.Help,w/2,h-70,math.max(0,math.min(450,w-260)),20,.5,1);gui.Help.TextColor3=white;gui.Help.TextTransparency=.15;gui.Help.TextStrokeTransparency=.55;gui.Help.TextSize=13
 rect(gui.Notice,w/2,portrait and 198 or(compact and 82 or 16),math.min(430,w-36),42,.5,0);gui.Notice.TextSize=19;gui.Notice.TextColor3=white;gui.Notice.TextStrokeColor3=ink;gui.Notice.TextStrokeTransparency=0
 local own=gui:FindFirstChild("RPGVitals");if own then own.Visible=false end
 local actionsBottom=h-(touchPortrait and 250 or(touch and 168 or 154))
 local actionsHeight=touch and not portrait and h<350 and 104 or 124
 rect(gui.Actions,w-18,actionsBottom,158,actionsHeight,1,1)
 local target=gui:FindFirstChild("TargetLock")
 if target then rect(target,w-18,touch and(actionsBottom-actionsHeight-8)or(h-82),touchPortrait and 132 or(touch and(mode and mode.Raid and 158 or 98)or 132),touch and 44 or 30,1,1);target.TextSize=12;pop(target,dark);target.TextColor3=white;rounded(target,15)end
 local sprint=gui:FindFirstChild("RunToggle")
 if sprint then
  if portrait then rect(sprint,w-18,gui.StandardVitals.Position.Y.Offset+8,62,44,1,0)
  else rect(sprint,w-18-106,actionsBottom-actionsHeight-8,52,44,1,1)end
 end
 if touch and not portrait and h<330 then
  if target then rect(target,w-184,110,108,44,1,0)end
  if sprint then rect(sprint,w-302,110,52,44,1,0)end
 end
 local region=gui:FindFirstChild("CurrentRegion");if region then
  if portrait then rect(region,w-12,8,math.max(100,w-statsWidth-36),64,1,0)
  else rect(region,w/2,compact and 8 or 64,compact and math.max(120,math.min(380,w-500))or math.min(420,w-32),compact and 48 or 26,.5,0)end
  region.TextSize=compact and 10 or 12;region.TextWrapped=true;region.TextColor3=white
 end
 local mapButton=gui:FindFirstChild("RegionMapButton");if mapButton then mapButton.Visible=false end
 rect(gui.Duel,w/2,10,(touch and not portrait)and math.min(460,w-380)or math.min(460,w-24),114,.5,0)
 rect(gui.Duel.Round,8,4,gui.Duel.Size.X.Offset-16,22);gui.Duel.Round.TextSize=14
 rect(gui.Duel.Versus,8,26,gui.Duel.Size.X.Offset-16,20);gui.Duel.Versus.TextSize=12
 rect(gui.Duel.Health,8,48,gui.Duel.Size.X.Offset-16,18);gui.Duel.Health.TextSize=12
 gui.Duel.OwnHealth.Position=UDim2.fromOffset(12,70);gui.Duel.EnemyHealth.Position=UDim2.new(.5,6,0,70);gui.Duel.Track.Position=UDim2.fromOffset(12,83);gui.Duel.Stamina.Position=UDim2.fromOffset(8,94)
 local desired={Directory=540,QuestPanel=580,Loadout=580,RegionMap=500,SettingsPanel=248,Shop=440,Result=226,GuardianVictory=150,OwnerPanel=500}
 for _,name in panels do local panel=gui:FindFirstChild(name)
  if panel then
   local pw=math.min(name=="SettingsPanel"and 380 or 520,w-24);local ph=math.min(desired[name],h-24)
   rect(panel,w/2,h/2,pw,ph,.5,.5);panel.BackgroundColor3=dark;panel.BackgroundTransparency=0;panel.ZIndex=10;stroke(panel,5)
   local constraint=panel:FindFirstChildOfClass("UISizeConstraint");if constraint then constraint.MinSize=Vector2.zero;constraint.MaxSize=Vector2.new(10000,10000)end
   for _,v in panel:GetDescendants()do if v:IsA("GuiObject")then v.ZIndex=11;if v:IsA("TextButton")and name~="RegionMap"then v.TextColor3=white end end end
   rounded(panel,16)
   for _,b in panel:GetDescendants()do if b:IsA("TextButton")and b.Name~="Close"and name~="RegionMap"then rounded(b,12);stroke(b,2)end end
   local close=panel:FindFirstChild("Close");if close and close:IsA("TextButton")then pop(close,Color3.fromRGB(240,70,80),2);rounded(close,10)end
   if name=="RegionMap"then require(game.ReplicatedStorage.SkySproutAtlas).Layout(panel,Vector2.new(pw,ph))end
   if name=="OwnerPanel"then require(game.ReplicatedStorage.SkySproutAdminClient).Layout(panel,Vector2.new(pw,ph))end
  end
 end
 local boss=gui:FindFirstChild("GuardianStatus");if boss then rect(boss,w/2,10,(touch and not portrait)and math.min(500,w-380)or math.min(500,w-24),96,.5,0)end
 for _,name in {"Duel","GuardianStatus","CurrentRegion","Actions"}do local v=gui:FindFirstChild(name);if v and v:IsA("GuiObject")then rounded(v,14);if v.BackgroundTransparency<1 then stroke(v)end end end
 for _,b in gui.Actions:GetChildren()do if b:IsA("TextButton")then rounded(b,14);stroke(b,3);b.TextSize=17;b.TextStrokeColor3=ink;b.TextStrokeTransparency=.2 end end
 local owner=gui:FindFirstChild("OwnerToggle");if owner then pop(owner,buttonColor);rounded(owner,17)end
 modernFonts(gui)
end
local TweenService=game:GetService("TweenService")
local clickSound
local function feedback(b)
 if not b:IsA("GuiButton")or b.Name=="MenuBackdrop"or b:GetAttribute("PopFeedback")then return end
 b:SetAttribute("PopFeedback",true)
 local scale=b:FindFirstChild("PopScale")or Instance.new("UIScale");scale.Name="PopScale";scale.Parent=b
 local function to(v,t)TweenService:Create(scale,TweenInfo.new(t or .14,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=v}):Play()end
 b.MouseEnter:Connect(function()to(1.06)end);b.MouseLeave:Connect(function()to(1)end)
 b.MouseButton1Down:Connect(function()to(.92,.06)end);b.MouseButton1Up:Connect(function()to(1.06)end)
 b.Activated:Connect(function()if clickSound then clickSound:Play()end end)
end
function H.Start(event,gui)
 local P=game.Players.LocalPlayer;local UIS=game:GetService("UserInputService");local CAS=game:GetService("ContextActionService")
 H.Prepare(gui);H.Gui=gui
 clickSound=Instance.new("Sound");clickSound.Name="UIClick";clickSound.SoundId="rbxasset://sounds/clickfast.wav";clickSound.Volume=.45;clickSound.Parent=gui
 for _,d in gui:GetDescendants()do feedback(d)end;gui.DescendantAdded:Connect(feedback)
 local navOpen=not UIS.TouchEnabled;local regionUntil=os.clock()+5;local applying=false
 local function modal()
  for _,name in panels do local f=gui:FindFirstChild(name);if f and f.Visible then return f end end
 end
 local function layout()
  local camera=workspace.CurrentCamera;if not camera then return end
  local available=gui.AbsoluteSize
  if available.X<1 or available.Y<1 then available=camera.ViewportSize end
  local fight=P:GetAttribute("ArenaMode")=="Match";local raid=P:GetAttribute("RPGRaid")==true
  H.Layout(gui,available,UIS.TouchEnabled,navOpen,{Fight=fight,Raid=raid})
  local open=modal();local veil=gui:FindFirstChild("TravelVeil");local travelling=veil and veil.Visible
  local blocked=open~=nil or travelling or(gui:GetAttribute("CompactHUD")and navOpen)
  gui:SetAttribute("ModalOpen",blocked)
  gui.MenuBackdrop.Visible=open~=nil
  gui.Top.Visible=not fight and not raid and not open;gui.NavToggle.Visible=not fight and not raid and not open
  local ownerButton=gui:FindFirstChild("OwnerToggle");if ownerButton then ownerButton.Visible=P:GetAttribute("SkyboundOwner")==true and not fight and not raid and not open and not travelling end
  gui.Lobby.Visible=navOpen and not fight and not raid and not open
  local party=require(game.ReplicatedStorage.SkySproutConfig).PartyMode==true
  gui.StandardVitals.Visible=not party and not open and not travelling
  gui.Actions.Visible=UIS.TouchEnabled and not blocked
  gui.RunToggle.Visible=not party and UIS.TouchEnabled and not blocked and not fight and not raid
  gui.Help.Visible=not UIS.TouchEnabled and not gui:GetAttribute("CompactHUD")and not open
  local hot=gui:FindFirstChild("RPGHotbar");if hot then hot.Visible=not blocked end
  local tracker=gui:FindFirstChild("StoryTracker");if tracker then tracker.Visible=not open and not travelling and not fight and not raid and gui.Notice.Text==""and not(gui:GetAttribute("CompactHUD")and(navOpen or available.Y<340))end
  local own=gui:FindFirstChild("RPGVitals");if own then own.Visible=false end
  local region=gui:FindFirstChild("CurrentRegion");if region then region.Visible=not open and not fight and not raid and os.clock()<regionUntil end
  gui.Notice.Visible=gui.Notice.Text~=""and not open and not raid and not fight and not(gui:GetAttribute("CompactHUD")and navOpen)
  local settings=gui.SettingsPanel
  settings.Low.BackgroundColor3=P:GetAttribute("LowEffects")and blue or buttonColor
  settings.Standard.BackgroundColor3=not P:GetAttribute("LowEffects")and blue or buttonColor
 end
 local function close()
  applying=true;for _,name in panels do local f=gui:FindFirstChild(name);if f then f.Visible=false end end;applying=false;layout()
 end
 function H.Toggle(name)
  local veil=gui:FindFirstChild("TravelVeil");if veil and veil.Visible then return end
  local f=gui:FindFirstChild(name);if not f then return end;local show=not f.Visible
  close();f.Visible=show;if show and name=="RegionMap"then event:FireServer("RegionSync")end;layout()
 end
 H.Close=close;H.Refresh=layout
 gui.NavToggle.Activated:Connect(function()navOpen=not navOpen;layout()end)
 gui.Lobby.Map.Activated:Connect(function()H.Toggle("RegionMap")end)
 gui.Lobby.Mount.Activated:Connect(function()close();navOpen=false;event:FireServer("Mount");layout()end)
 gui.Lobby.Settings.Activated:Connect(function()H.Toggle("SettingsPanel")end)
 gui.SettingsPanel.Close.Activated:Connect(close);gui.MenuBackdrop.Activated:Connect(close)
 gui.SettingsPanel.Low.Activated:Connect(function()P:SetAttribute("LowEffects",true);layout()end)
 gui.SettingsPanel.Standard.Activated:Connect(function()P:SetAttribute("LowEffects",false);layout()end)
 for _,name in panels do local f=gui:FindFirstChild(name);if f then
  f:GetPropertyChangedSignal("Visible"):Connect(function()
   if applying then return end
   if f.Visible then applying=true;for _,otherName in panels do local other=gui:FindFirstChild(otherName);if other and other~=f then other.Visible=false end end;applying=false end
   layout()
  end)
 end end
 local function vitals()
  local fight=P:GetAttribute("ArenaMode")=="Match"
  local hp=fight and(P:GetAttribute("HP")or 100)or(P:GetAttribute("RPGHP")or 100)
  local maximum=fight and 100 or(P:GetAttribute("RPGMaxHP")or 100)
  local energy=fight and(P:GetAttribute("Stamina")or 100)or(P:GetAttribute("RPGStamina")or 100)
  gui.StandardVitals.HPText.Text="❤️ "..hp.." / "..maximum;gui.StandardVitals.HealthTrack.Fill.Size=UDim2.fromScale(math.clamp(hp/maximum,0,1),1)
  gui.StandardVitals.EnergyText.Text="⚡ "..energy;gui.StandardVitals.EnergyTrack.Fill.Size=UDim2.fromScale(math.clamp(energy/100,0,1),1)
  gui.Top.Coins.Text="💰 "..(P:GetAttribute("Coins")or 0)
  gui.Lobby.Mount.Text="🐴  "..(P:GetAttribute("Mounted")and"Dismount"or"Mount")..(UIS.TouchEnabled and""or" [V]")
 end
 for _,attr in {"HP","Stamina","RPGHP","RPGMaxHP","RPGStamina","Coins","Mounted"}do P:GetAttributeChangedSignal(attr):Connect(vitals)end
 for _,attr in {"ArenaMode","RPGRaid","LowEffects"}do P:GetAttributeChangedSignal(attr):Connect(function()if P:GetAttribute("ArenaMode")=="Match"or P:GetAttribute("RPGRaid")then close()end;vitals();layout()end)end
 for _,attr in {"RegionName","ScenicRegion"}do P:GetAttributeChangedSignal(attr):Connect(function()regionUntil=os.clock()+5;layout();task.delay(5.1,layout)end)end
 gui.Notice:GetPropertyChangedSignal("Text"):Connect(layout)
 CAS:BindActionAtPriority("CloseTowerMenus",function(_,state)
  if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
  local veil=gui:FindFirstChild("TravelVeil");if veil and veil.Visible then require(game.ReplicatedStorage.SkySproutTravelClient).Cancel();return Enum.ContextActionResult.Sink end
  if modal()then close();return Enum.ContextActionResult.Sink end
  if gui:GetAttribute("CompactHUD")and navOpen then navOpen=false;layout();return Enum.ContextActionResult.Sink end
  return Enum.ContextActionResult.Pass
 end,false,Enum.ContextActionPriority.High.Value+1,Enum.KeyCode.Backspace,Enum.KeyCode.ButtonB)
 local function cameraChanged()
  local camera=workspace.CurrentCamera;if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)end;layout()
 end
 workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
 cameraChanged();vitals();layout();task.delay(5.1,layout)
end
return H
