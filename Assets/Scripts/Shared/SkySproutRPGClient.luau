local M={}
function M.Start(event,gui)
 local Players=game:GetService("Players");local Run=game:GetService("RunService");local CAS=game:GetService("ContextActionService");local UIS=game:GetService("UserInputService")
 local Tween=game:GetService("TweenService");local Debris=game:GetService("Debris");local p=Players.LocalPlayer
 local D=require(game.ReplicatedStorage.SkySproutRPGConfig)
 local ink=Color3.fromRGB(27,29,35);local light=Color3.fromRGB(240,241,244);local mint=Color3.fromRGB(47,50,59);local gold=Color3.fromRGB(67,128,230)
 local function frame(name,parent,size,pos)
  local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=ink;f.BackgroundTransparency=.08;f.BorderSizePixel=0;f.Parent=parent
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,10);c.Parent=f;return f
 end
 local function text(parent,txt,size,pos,height)
  local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.new(1,-16,0,height or 24);t.Position=pos or UDim2.fromOffset(8,0);t.TextColor3=light;t.Font=Enum.Font.GothamMedium;t.TextSize=size or 14;t.Text=txt;t.TextWrapped=true;t.Parent=parent;return t
 end
 local function button(parent,name,txt,size,pos,fn)
  local b=Instance.new("TextButton");b.Name=name;b.Size=size;b.Position=pos;b.Text=txt;b.TextSize=13;b.Font=Enum.Font.GothamBold;b.TextColor3=light;b.BackgroundColor3=mint;b.BorderSizePixel=0;b.Parent=parent
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=b;b.Activated:Connect(fn);return b
 end
 local function send(a,v)if a=="Kick"or a=="Punch"or a=="Heavy"or a=="Skill1"or a=="Skill2"then require(game.ReplicatedStorage.SkySproutTargeting).Assist()end;event:FireServer(a,v)end
 local vital=frame("RPGVitals",gui,UDim2.fromOffset(232,85),UDim2.new(0,12,1,-185))
 local title=text(vital,"Vanguard • Ember",13,UDim2.fromOffset(8,4),22)
 local hp=text(vital,"100 / 100 HP",15,UDim2.fromOffset(8,27),22)
 local energy=text(vital,"Energy 100 • Relic 0 / 50",12,UDim2.fromOffset(8,53),20)
 local hot=frame("RPGHotbar",gui,UDim2.fromOffset(392,70),UDim2.new(.5,-196,1,-82))
 local keys={{"Kick","KICK\nC"},{"Awaken","AWAKEN\nT"},{"Skill1","SKILL 1\nZ"},{"Skill2","SKILL 2\nX"}}
 local hotButtons={};local cooldowns={0,0}
 for i,v in keys do hotButtons[v[1]]=button(hot,v[1],v[2],UDim2.new(.25,-6,1,-12),UDim2.new((i-1)*.25,4,0,6),function()send(v[1])end)end
 local combo=text(gui,"",17,UDim2.new(.5,-170,1,-121),30);combo.Size=UDim2.fromOffset(340,30);local comboUntil=0
 local panel=frame("Loadout",gui,UDim2.new(.94,0,.86,0),UDim2.fromScale(.5,.5));panel.AnchorPoint=Vector2.new(.5,.5);panel.Visible=false
 local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(510,570);constraint.Parent=panel
 text(panel,"COMBAT ARTS & RELICS",21,UDim2.fromOffset(10,14),28)
 text(panel,"Clear guardians to earn new equipment. Mix one fighting style with one relic.",13,UDim2.fromOffset(10,47),40)
 button(panel,"Close","×",UDim2.fromOffset(34,32),UDim2.new(1,-44,0,12),function()panel.Visible=false end).BackgroundColor3=gold
 local scroll=Instance.new("ScrollingFrame");scroll.Name="Choices";scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.Size=UDim2.new(1,-20,1,-103);scroll.Position=UDim2.fromOffset(10,91);scroll.ScrollBarThickness=5;scroll.CanvasSize=UDim2.fromOffset(0,800);scroll.Parent=panel
 local choices={}
 for groupIndex,group in {{"Vanguard","Gale","Bastion"},{"Ember","Tide","Storm"}}do
  for i,id in group do local isStyle=groupIndex==1;local spec=(isStyle and D.Styles or D.Relics)[id];local y=(groupIndex-1)*315+(i-1)*103
   local b=button(scroll,id,spec.Name,UDim2.new(1,-10,0,94),UDim2.fromOffset(2,y),function()send(isStyle and"EquipStyle"or"EquipRelic",id)end)
   b.Text="";local label=text(b,spec.Name,16,UDim2.fromOffset(10,4),24);label.TextColor3=light
   local description=text(b,isStyle and spec.Description or("Awaken, then use "..spec.Skills[1].." and "..spec.Skills[2].."."),12,UDim2.fromOffset(10,29),37);description.TextColor3=light
   local status=text(b,"",12,UDim2.fromOffset(10,68),22);status.TextColor3=light;choices[id]={Button=b,Status=status,Spec=spec,Attribute=isStyle and"CombatStyle"or"Relic"}
  end
 end
 button(scroll,"Cosmetics","GLOVE COSMETICS",UDim2.new(1,-10,0,42),UDim2.fromOffset(2,638),function()panel.Visible=false;gui.Shop.Visible=true end).BackgroundColor3=gold
 local boss=frame("GuardianStatus",gui,UDim2.new(.9,0,0,96),UDim2.new(.5,0,0,206));boss.AnchorPoint=Vector2.new(.5,0);boss.Visible=false
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(550,96);limit.Parent=boss
 local bossName=text(boss,"GUARDIAN",16,UDim2.fromOffset(8,3),24)
 local bossHP=text(boss,"",13,UDim2.fromOffset(8,27),22)
 local cue=text(boss,"Move out of red warnings. Stand in mint safe zones.",13,UDim2.fromOffset(8,54),32);cue.TextColor3=gold
 local cueUntil=0
 button(boss,"Leave","LEAVE",UDim2.fromOffset(58,24),UDim2.new(1,-66,0,2),function()send("LeaveRaid")end).BackgroundColor3=gold
 local victory=frame("GuardianVictory",gui,UDim2.new(.85,0,0,150),UDim2.fromScale(.5,.5));victory.AnchorPoint=Vector2.new(.5,.5);victory.Visible=false
 local vc=Instance.new("UISizeConstraint");vc.MaxSize=Vector2.new(480,150);vc.Parent=victory
 local vt=text(victory,"GUARDIAN CLEARED",22,UDim2.fromOffset(8,12),35)
 local vr=text(victory,"",14,UDim2.fromOffset(8,53),32);local nextFloor=1
 button(victory,"Continue","CONTINUE EXPLORING",UDim2.new(.53,-14,0,42),UDim2.new(0,10,1,-52),function()victory.Visible=false end).BackgroundColor3=gold
 button(victory,"Climb","NEXT FLOOR",UDim2.new(.47,-10,0,42),UDim2.new(.53,0,1,-52),function()victory.Visible=false;send("Travel",nextFloor)end)
 text(scroll,"World assets: anomon, Remadex Development, Rubzlc,\nFedoraTheNoob, SlimevdGamer3dScythe, Zenrt0827,\nLoucDu44, StealthCoder, wensda6, Exp_p\nAmbience: ProSoundEffects",10,UDim2.fromOffset(4,686),90)

 local story
 local storyBox=frame("ExpeditionCard",gui.QuestPanel,UDim2.new(1,-24,0,124),UDim2.fromOffset(12,78))
 local storyTitle=text(storyBox,"MIRA'S EXPEDITION",15,UDim2.fromOffset(8,4),24)
 local storyText=text(storyBox,"Speak to Wayfinder Mira beside the quest board.",12,UDim2.fromOffset(8,30),43)
 local storyProgress=text(storyBox,"Complete the route, then defeat the guardian.",11,UDim2.fromOffset(8,74),20)
 local tracker=frame("StoryTracker",gui,UDim2.fromOffset(232,88),UDim2.new(0,12,1,-283))
 local trackerText=text(tracker,"Speak to Mira to begin your expedition.",12,UDim2.fromOffset(8,4),75)
 local Nav=require(game.ReplicatedStorage.SkySproutNavigation)
 local function markStory()if story then Nav.SetStory(story)end end
 local navigate=button(storyBox,"Navigate","TRACK OBJECTIVE",UDim2.new(.54,-12,0,26),UDim2.new(0,8,1,-32),function()
  if not story then return end
  Nav.SelectStory()
  if story.TargetFloor~=(p:GetAttribute("VisitFloor")or 1)then send("Travel",story.TargetFloor)else gui.QuestPanel.Visible=false;markStory()end
 end)
 button(storyBox,"Speak","SPEAK / REPORT",UDim2.new(.46,-12,0,26),UDim2.new(.54,0,1,-32),function()send("StartStory")end).BackgroundColor3=gold
 gui.QuestPanel.List.Position=UDim2.fromOffset(12,212);gui.QuestPanel.List.Size=UDim2.new(1,-24,1,-226)
 p:GetAttributeChangedSignal("VisitFloor"):Connect(markStory)

 local function update()
  local style=D.Styles[p:GetAttribute("CombatStyle")or"Vanguard"];local relic=D.Relics[p:GetAttribute("Relic")or"Ember"]
  title.Text=style.Name.." • "..relic.Name
  local health=p:GetAttribute("RPGHP")or 100;local max=p:GetAttribute("RPGMaxHP")or 100
  hp.Text=health.." / "..max.." HP"
  energy.Text="Energy "..(p:GetAttribute("RPGStamina")or 100).." • Relic "..(p:GetAttribute("RelicCharge")or 0).." / 50"
  for id,v in choices do local owned=(p:GetAttribute("UnlockedFloor")or 1)>=v.Spec.Floor;local equipped=p:GetAttribute(v.Attribute)==id
   v.Status.Text=equipped and"EQUIPPED"or(owned and"EQUIP"or("UNLOCK AT FLOOR "..v.Spec.Floor));v.Button.BackgroundColor3=equipped and gold or(owned and mint or Color3.fromRGB(47,50,59))
  end
  gui.Lobby.Styles.Text="🧤  Loadout"
  local touch=game:GetService("UserInputService").TouchEnabled
  hotButtons.Kick.Text=touch and"KICK"or"KICK\nC"
  local awake=p:GetAttribute("RelicAwake");hotButtons.Awaken.Text=awake and"AWAKENED"or(touch and"AWAKEN"or"AWAKEN\nT")
  hotButtons.Awaken.BackgroundColor3=awake and gold or((p:GetAttribute("RelicCharge")or 0)>=50 and mint or Color3.fromRGB(47,50,59))
  for slot=1,2 do local seconds=math.max(0,math.ceil(cooldowns[slot]-os.clock()));local b=hotButtons["Skill"..slot]
   b.Text=(touch and""or(slot==1 and"Z • "or"X • "))..relic.Skills[slot]..(seconds>0 and("\n"..seconds.."s")or"");b.TextWrapped=true;b.TextSize=11;b.BackgroundColor3=awake and seconds==0 and relic.Color or Color3.fromRGB(47,50,59)
  end
 end
 local function bind(name,key,...)
  CAS:BindAction("TowerRPG"..name,function(_,input)
   if UIS:GetFocusedTextBox()or gui:GetAttribute("ModalOpen") then return Enum.ContextActionResult.Pass end
   if input==Enum.UserInputState.Begin then send(name)end;return Enum.ContextActionResult.Sink
  end,false,key,...)
 end
 bind("Kick",Enum.KeyCode.C,Enum.KeyCode.ButtonR1);bind("Awaken",Enum.KeyCode.T,Enum.KeyCode.ButtonL1);bind("Skill1",Enum.KeyCode.Z,Enum.KeyCode.DPadLeft);bind("Skill2",Enum.KeyCode.X,Enum.KeyCode.DPadRight)
 event.OnClientEvent:Connect(function(kind,v)
  if kind=="Story"then
   story=v;storyTitle.Text="EXPEDITION • "..v.Title;storyText.Text=v.Text
   storyProgress.Text=v.Complete and"READY FOR THE GUARDIAN"or("Step "..v.Step.." / "..v.Total.." • "..v.XP.." XP • "..v.Coins.." coins")
   navigate.Text=v.TargetFloor~=(p:GetAttribute("VisitFloor")or 1)and("TRAVEL TO FLOOR "..v.TargetFloor)or"TRACK OBJECTIVE"
   trackerText.Text="EXPEDITION • FLOOR "..v.Home.."\n"..v.Text
   gui.QuestPanel.District.Text="District errands and multi-floor expeditions";markStory()
  elseif kind=="BossState"then
   boss.Visible=v.Active
   if v.Active then
    bossName.Text=v.Name;bossHP.Text=v.Phase==0 and("DEFEAT THE DISCIPLES • Party "..v.Party.." / 4")or("PHASE "..v.Phase.." • "..math.ceil(v.HP).." / "..math.ceil(v.MaxHP).." HP • Party "..v.Party.." / 4")
    if os.clock()>cueUntil then cue.Text="Move out of red warnings. Stand in mint safe zones."end
   end
  elseif kind=="BossCue"then cueUntil=os.clock()+v.Duration+.5;cue.Text=v.Text
  elseif kind=="WildReward"then combo.Text="RUIN WATCHER • +"..v.XP.." XP • +"..v.Coins.." coins";comboUntil=os.clock()+2
  elseif kind=="Combo"then combo.Text=v.Style.." • "..v.Text;comboUntil=os.clock()+1
  elseif kind=="SkillCooldown"then cooldowns[v.Slot]=os.clock()+v.Seconds
  elseif kind=="BossVictory"then
   boss.Visible=false;victory.Visible=true;nextFloor=v.Next
   vt.Text=v.Floor==20 and"TOWER CONQUERED"or"GUARDIAN CLEARED"
   vr.Text=v.First and("Floor "..v.Next.." unlocked • XP and coins earned")or"Guardian defeated • +35 XP • +20 coins"
  elseif kind=="NPCImpact"and v.Target and v.Target.Parent then
   local rr=p.Character and p.Character:FindFirstChild("HumanoidRootPart");if not rr or(v.Target.Position-rr.Position).Magnitude>140 then return end
   local b=Instance.new("BillboardGui");b.Size=UDim2.fromOffset(160,45);b.StudsOffset=Vector3.new(0,6,0);b.AlwaysOnTop=true;b.MaxDistance=100;b.Parent=v.Target
   local t=text(b,"-"..v.Damage..(v.Launch and" STAGGER"or""),21,nil,45);t.TextColor3=gold;Debris:AddItem(b,.7)
   if not p:GetAttribute("LowEffects")then local hi=Instance.new("Highlight");hi.Adornee=v.Target.Parent;hi.FillColor=mint;hi.FillTransparency=.35;hi.Parent=v.Target.Parent;Debris:AddItem(hi,.13)end
  elseif kind=="RelicFX"then
   local rr=p.Character and p.Character:FindFirstChild("HumanoidRootPart");if p:GetAttribute("LowEffects")or not rr or(v.Position-rr.Position).Magnitude>180 then return end
   local sphere=Instance.new("Part");sphere.Shape=Enum.PartType.Ball;sphere.Anchored=true;sphere.CanCollide=false;sphere.CanTouch=false;sphere.CanQuery=false;sphere.Material=Enum.Material.Neon;sphere.Color=v.Color;sphere.Transparency=.45
   sphere.Size=Vector3.one*2;sphere.Position=v.Position+(v.Slot==1 and v.Direction*10 or Vector3.zero);sphere.Parent=workspace
   Tween:Create(sphere,TweenInfo.new(.45),{Size=Vector3.one*(v.Slot==1 and 10 or 32),Transparency=1}):Play();Debris:AddItem(sphere,.5)
  end
 end)
 local function aura(who)
  local ch=who.Character;if not ch then return end;local old=ch:FindFirstChild("RelicAura")
  if who:GetAttribute("RelicAwake")and not p:GetAttribute("LowEffects")then
   if not old then old=Instance.new("Highlight");old.Name="RelicAura";old.FillTransparency=.85;old.OutlineTransparency=.35;old.DepthMode=Enum.HighlightDepthMode.Occluded;old.Parent=ch end
   old.FillColor=D.Relics[who:GetAttribute("Relic")or"Ember"].Color;old.OutlineColor=old.FillColor
  elseif old then old:Destroy()end
 end
 local function track(who)
  who:GetAttributeChangedSignal("RelicAwake"):Connect(function()aura(who)end);who:GetAttributeChangedSignal("Relic"):Connect(function()aura(who)end)
  who.CharacterAdded:Connect(function()task.defer(aura,who)end);aura(who)
 end
 Players.PlayerAdded:Connect(track);for _,who in Players:GetPlayers()do track(who)end
 p:GetAttributeChangedSignal("LowEffects"):Connect(function()for _,who in Players:GetPlayers()do aura(who)end end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.2 then return end;elapsed=0;update();combo.Visible=os.clock()<comboUntil and not gui:GetAttribute("ModalOpen")
  if p:GetAttribute("ArenaMode")=="Match"then panel.Visible=false;boss.Visible=false;victory.Visible=false end
 end)
 send("RPGSync");send("StorySync");update()
end
return M
