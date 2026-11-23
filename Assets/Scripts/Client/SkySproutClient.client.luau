local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local C=require(RS.SkySproutConfig)
local p=Players.LocalPlayer
local event=RS:WaitForChild("ArenaEvent")
local gui=p:WaitForChild("PlayerGui"):WaitForChild("SkySproutHUD")
require(RS.SkySproutCombatFX).Start(event)
local match;local blocking=false;local noticeToken=0;local queueSince=0
local attackUntil=0;local dodgeUntil=0;local uiTime=0;local resultToken=0
local normalColors={Punch=Color3.fromRGB(240,70,80),Heavy=Color3.fromRGB(255,140,40),Block=Color3.fromRGB(50,150,255),Dash=Color3.fromRGB(150,90,255)}
local PARTY=C.PartyMode==true
local function send(a,v)if not PARTY and(a=="Punch"or a=="Heavy")then require(RS.SkySproutTargeting).Assist()end;event:FireServer(a,v)end
-- Notices queue up (#125): several can arrive at once (a round's end can bring a crown, a challenge and a gift), so
-- each stays at least NOTICE_MIN seconds while others wait, the last one stays NOTICE_HOLD, and a flood keeps only the
-- newest NOTICE_MAX.
local NOTICE_MIN,NOTICE_HOLD,NOTICE_MAX=1.8,4,5
local noticeQueue={};local noticeBusy=false
local function notice(t)
 table.insert(noticeQueue,t)
 while #noticeQueue>NOTICE_MAX do table.remove(noticeQueue,1)end
 if noticeBusy then return end
 noticeBusy=true
 task.spawn(function()
  while #noticeQueue>0 do
   noticeToken+=1;gui.Notice.Text=table.remove(noticeQueue,1)
   local shown=os.clock()
   while os.clock()-shown<NOTICE_HOLD and not(#noticeQueue>0 and os.clock()-shown>=NOTICE_MIN)do task.wait(0.1)end
  end
  gui.Notice.Text="";noticeBusy=false
 end)
end
local function dash()
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 send("Dash",h and h.MoveDirection or Vector3.zero)
end
local function block(on)blocking=on;send("Block",on)end
gui.Actions.Punch.Activated:Connect(function()send("Punch")end)
gui.Actions.Heavy.Activated:Connect(function()send("Heavy")end)
gui.Actions.Dash.Activated:Connect(dash)
gui.Actions.Block.Activated:Connect(function()block(not blocking)end)
gui.Lobby.Queue.Activated:Connect(function()send("Queue")end)
gui.Lobby.Styles.Activated:Connect(function()
 if PARTY then gui.Shop.Visible=not gui.Shop.Visible;return end
 gui.Shop.Visible=false;local panel=gui:FindFirstChild("Loadout");if panel then panel.Visible=not panel.Visible end end)
gui.Shop.Close.Activated:Connect(function()gui.Shop.Visible=false end)
local MPS=game:GetService("MarketplaceService")
local styleList=Instance.new("ScrollingFrame");styleList.Name="StyleList";styleList.BackgroundTransparency=1;styleList.BorderSizePixel=0
styleList.Position=UDim2.fromOffset(16,52);styleList.Size=UDim2.new(1,-32,1,-112);styleList.CanvasSize=UDim2.new();styleList.AutomaticCanvasSize=Enum.AutomaticSize.Y
styleList.ScrollBarThickness=4;styleList.ScrollingDirection=Enum.ScrollingDirection.Y;styleList.Parent=gui.Shop
local listLayout=Instance.new("UIListLayout");listLayout.Padding=UDim.new(0,8);listLayout.SortOrder=Enum.SortOrder.LayoutOrder;listLayout.Parent=styleList
local template=gui.Shop.Lilac
local function shopButton(name,order)
 local b=gui.Shop:FindFirstChild(name)or template:Clone();b.Name=name;b.Position=UDim2.new();b.Size=UDim2.new(1,-8,0,44);b.LayoutOrder=order;b.Parent=styleList;return b
end
for i,s in ipairs(C.Skins)do if not s.Premium then
 local id=s.Id;shopButton(id,i).Activated:Connect(function()send("Skin",id)end)
end end
local packs={{Key="Coins500",Coins=500},{Key="Coins2000",Coins=2000},{Key="Coins6000",Coins=6000}}
for i,pack in ipairs(packs)do
 local id=C.ProductIds and C.ProductIds[pack.Key]or 0
 if id>0 then
  local b=shopButton(pack.Key,200+i);b.Text="💰 +"..pack.Coins.." coins";b.BackgroundColor3=Color3.fromRGB(230,165,20)
  b.Activated:Connect(function()MPS:PromptProductPurchase(p,id)end)
  task.spawn(function()local ok,info=pcall(function()return MPS:GetProductInfo(id,Enum.InfoType.Product)end)
   if ok and type(info)=="table"and info.PriceInRobux then b.Text="💰 +"..pack.Coins.." coins • R$ "..info.PriceInRobux end end)
 end
end
local anyPaid=C.PassId>0 or(C.DoubleLavaPassId or 0)>0;for _,id in pairs(C.ProductIds or{})do if id>0 then anyPaid=true end end
gui.Shop.Footer.Text=anyPaid and"All styles have the same combat stats. Robux items are optional:\nevery style except Aurora can be earned in Lava Rush, quests and duels."or"All styles have the same combat stats.\nEarn coins in Lava Rush, quests and duels."
local auroraButton;local auroraPrice=""
local function auroraUI()
 if not auroraButton then return end
 local equipped=p:GetAttribute("GloveStyle")=="Aurora";local owns=p:GetAttribute("AuroraPass")==true
 auroraButton.Text="✨ Aurora Gloves • "..(equipped and"EQUIPPED"or(owns and"EQUIP"or("glowing cosmetic"..auroraPrice)))
 auroraButton.BackgroundColor3=equipped and Color3.fromRGB(67,128,230)or Color3.fromRGB(47,50,59)
end
if C.PassId>0 then
 auroraButton=shopButton("AuroraPass",100)
 auroraButton.Activated:Connect(function()
  if p:GetAttribute("AuroraPass")==true then send("Skin","Aurora")else MPS:PromptGamePassPurchase(p,C.PassId)end
 end)
 task.spawn(function()
  local ok,info=pcall(function()return MPS:GetProductInfo(C.PassId,Enum.InfoType.GamePass)end)
  if ok and type(info)=="table"and info.PriceInRobux then auroraPrice=" • R$ "..info.PriceInRobux end;auroraUI()
 end)
 p:GetAttributeChangedSignal("AuroraPass"):Connect(auroraUI);p:GetAttributeChangedSignal("GloveStyle"):Connect(auroraUI)
 auroraUI()
end
if (C.DoubleLavaPassId or 0)>0 then
 local b=shopButton("DoubleLavaPass",101);local price=""
 local function ui()b.Text="🔥 2x Lava Coins • "..(p:GetAttribute("DoubleLavaPass")and"OWNED"or("double every Lava Rush payout"..price))end
 b.Activated:Connect(function()if not p:GetAttribute("DoubleLavaPass")then MPS:PromptGamePassPurchase(p,C.DoubleLavaPassId)end end)
 task.spawn(function()local ok,info=pcall(function()return MPS:GetProductInfo(C.DoubleLavaPassId,Enum.InfoType.GamePass)end)
  if ok and type(info)=="table"and info.PriceInRobux then price=" • R$ "..info.PriceInRobux end;ui()end)
 p:GetAttributeChangedSignal("DoubleLavaPass"):Connect(ui);ui()
end
local function bind(name,action,...)
 CAS:BindAction(name,function(_,state)
  if UIS:GetFocusedTextBox()or(gui:GetAttribute("ModalOpen")and not(action=="Block"and(state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel)))then return Enum.ContextActionResult.Pass end
  if action=="Block"then if state==Enum.UserInputState.Begin then block(true)elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then block(false)end
  elseif state==Enum.UserInputState.Begin then if action=="Dash"then dash()else send(action)end end
  return Enum.ContextActionResult.Sink
 end,false,...)
end
bind("ArenaPunch","Punch",Enum.KeyCode.ButtonR2)
bind("ArenaHeavy","Heavy",Enum.KeyCode.R,Enum.KeyCode.ButtonY)
bind("ArenaBlock","Block",Enum.KeyCode.F,Enum.KeyCode.ButtonL2)
bind("ArenaDodge","Dash",Enum.KeyCode.Q,Enum.KeyCode.ButtonB)
UIS.InputBegan:Connect(function(input,processed)
 if not processed and not UIS:GetFocusedTextBox()and not gui:GetAttribute("ModalOpen") and input.UserInputType==Enum.UserInputType.MouseButton1 then send("Punch")end
end)
UIS.WindowFocusReleased:Connect(function()block(false)end)
local function lobbyUI()
 local mode=p:GetAttribute("ArenaMode")
 local fighting=mode=="Match"
 gui.Duel.Visible=fighting
 if not fighting then match=nil end
 gui.Lobby.Queue.Text=mode=="Queue"and"✖️  Cancel duel"or"⚔️  Find duel"
 if mode=="Queue"then queueSince=os.clock()end
 gui.Lobby.Status.Text=mode=="Loading"and"Loading your profile…"or"Defeat the guardian to unlock the next floor."
 if fighting then gui.Shop.Visible=false end
end
local function progress()
 local points=p:GetAttribute("Points")or 0;local floor=p:GetAttribute("Floor")or 1
 local unlocked=p:GetAttribute("UnlockedFloor")or floor
 local xp=p:GetAttribute("XP")or 0;local lv=p:GetAttribute("RPGLevel")or 1
 gui.Top.Progress.Text=PARTY and("👑 "..(p:GetAttribute("Crowns")or 0).." crowns  •  climb to the top!")or("Level "..lv.."  •  Floor "..(p:GetAttribute("VisitFloor")or 1).." / "..unlocked)
 gui.Top.ProgressTrack.Visible=not PARTY
 local low=80*(lv-1)^2;local high=80*lv^2
 gui.Top.ProgressTrack.Fill.Size=UDim2.fromScale(math.clamp((xp-low)/(high-low),0,1),1)
 for _,s in ipairs(C.Skins)do
  local button=not s.Premium and gui.Shop:FindFirstChild(s.Id,true)
  if button then
   local equipped=p:GetAttribute("GloveStyle")==s.Id
   local owned=p:GetAttribute("Owns"..s.Id)==true
   button.Text=(equipped and"✅ "or"")..s.Name.." • "..(equipped and"EQUIPPED"or(owned and"EQUIP"or"💰 "..s.Cost))
   button.BackgroundColor3=s.Color:Lerp(Color3.new(),(equipped or owned)and 0.05 or 0.3)
   button.TextStrokeColor3=Color3.fromRGB(16,12,40);button.TextStrokeTransparency=0.15
  end
 end
end
p:GetAttributeChangedSignal("ArenaMode"):Connect(lobbyUI)
for _,a in ipairs({"XP","RPGLevel","Points","Floor","UnlockedFloor","VisitFloor","Coins","GloveStyle","Crowns"})do p:GetAttributeChangedSignal(a):Connect(progress)end
for _,s in ipairs(C.Skins)do p:GetAttributeChangedSignal("Owns"..s.Id):Connect(progress)end
p:GetAttributeChangedSignal("Blocking"):Connect(function()blocking=p:GetAttribute("Blocking")==true end)
event.OnClientEvent:Connect(function(kind,v)
 if kind=="Notice"then notice(v)
 elseif kind=="Match"then
  match=v
  local clock=v.Phase=="Countdown"and("READY "..v.Remaining)or(v.Phase=="Fight"and(v.Remaining.."s")or string.upper(v.Phase))
  gui.Duel.Round.Text="FLOOR "..v.Floor.." • ROUND "..v.Round.." • "..clock
  gui.Duel.Versus.Text=v.Names[1].."  "..v.Scores[1].." : "..v.Scores[2].."  "..v.Names[2]..(v.ToWin==2 and" • First to 2"or"")
 elseif kind=="Attack"then if v.UserId==p.UserId then attackUntil=os.clock()+(v.Cooldown or .4)end
 elseif kind=="Practice"then notice((v.Heavy and"HEAVY • Guard breaker"or"PUNCH • Keep your range").." • "..v.Count.." practice hits")
 elseif kind=="Dodge"then if v.UserId==p.UserId then dodgeUntil=os.clock()+(v.Cooldown or 1.4)end
 elseif kind=="Result"then
  resultToken+=1;local token=resultToken
  local function delta(n)return(n>=0 and"+"or"")..n end
  gui.Result.Visible=true;gui.Result.Outcome.Text=v.Outcome
  gui.Result.Outcome.TextColor3=v.Outcome=="VICTORY"and Color3.fromRGB(88,198,118) or(v.Outcome=="DEFEAT"and Color3.fromRGB(255,151,145)or Color3.fromRGB(240,241,244))
  gui.Result.Reason.Text=v.Reason;gui.Result.Rewards.Text=delta(v.RankDelta).." rank • "..delta(v.CoinDelta).." coins"
  gui.Directory.Visible=false;gui.QuestPanel.Visible=false
  gui.Result.Floor.Text="PVP RANK "..v.Floor.." • Guardians unlock tower floors"
  gui.Result.Floor.TextColor3=v.Promoted and Color3.fromRGB(247,209,117) or Color3.fromRGB(226,237,243)
  task.delay(4.2,function()if resultToken==token then gui.Result.Visible=false end end)
 end
end)
local function responsive()
 for name,label in {Punch=PARTY and"Shove"or"Attack",Heavy="Heavy",Block="Guard",Dash="Dodge"}do gui.Actions[name].Text=label;gui.Actions[name].TextColor3=Color3.fromRGB(240,241,244);if PARTY and name~="Punch"then gui.Actions[name].Visible=false end end
end
local function reset()
 block(false);attackUntil=0;dodgeUntil=0
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid");if h then h.AutoRotate=true;h:SetStateEnabled(Enum.HumanoidStateType.Jumping,p:GetAttribute("ArenaMode")~="Match")end
 local touch=p.PlayerGui:FindFirstChild("TouchGui");local jump=touch and touch:FindFirstChild("JumpButton",true);if jump then jump.Visible=p:GetAttribute("ArenaMode")~="Match"end
end
p.CharacterAdded:Connect(function()task.delay(.4,reset)end)
local hudElapsed=0
Run.RenderStepped:Connect(function(dt)
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid");local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 local fighting=p:GetAttribute("ArenaMode")=="Match"
 hudElapsed+=dt
 local tickHUD=hudElapsed>=.1;if tickHUD then hudElapsed=0 end
 local stamina=p:GetAttribute("Stamina")or 100
 if fighting then
  local other=Players:GetPlayerByUserId(p:GetAttribute("OpponentId")or 0);local o=other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
  if h and r and o then h.AutoRotate=false;local target=Vector3.new(o.Position.X,r.Position.Y,o.Position.Z);if(target-r.Position).Magnitude>.1 then r.CFrame=CFrame.lookAt(r.Position,target)end end
  if tickHUD then
  local hp=p:GetAttribute("HP")or 100;local enemy=other and(other:GetAttribute("HP")or 100)or 100
  gui.Duel.Health.Text="YOU "..hp.." HP     RIVAL "..enemy.." HP"
  gui.Duel.OwnHealth.Fill.Size=UDim2.fromScale(hp/100,1);gui.Duel.EnemyHealth.Fill.Size=UDim2.fromScale(enemy/100,1)
  gui.Duel.Track.Fill.Size=UDim2.fromScale(stamina/100,1)
  gui.Duel.Stamina.Text=p:GetAttribute("Blocking")and"BLOCKING • STAMINA DRAINS"or(p:GetAttribute("Stunned")and"STUNNED"or"STAMINA")
 end
 elseif h then h.AutoRotate=not p:GetAttribute("PVETargetLocked")end
 if not tickHUD then return end
 local now=os.clock();local ready=not p:GetAttribute("Stunned")and(not fighting or(match and match.Phase=="Fight"))
 if not fighting then stamina=p:GetAttribute("RPGStamina")or 100 end
 local available={Punch=ready and now>=attackUntil and stamina>=C.Punch.Cost,Heavy=ready and now>=attackUntil and stamina>=C.Heavy.Cost,Block=ready and stamina>0,Dash=ready and now>=dodgeUntil and stamina>=C.Dash.Cost}
 for name,base in pairs(normalColors)do gui.Actions[name].BackgroundColor3=(name=="Block"and blocking)and Color3.fromRGB(67,128,230)or(available[name]and base or base:Lerp(Color3.fromRGB(30,44,59),.65))end
 
 uiTime+=dt
 if uiTime>.5 then uiTime=0
  if p:GetAttribute("ArenaMode")=="Queue"then local waiting=math.floor(now-queueSince)
   gui.Lobby.Status.Text=#Players:GetPlayers()<2 and("Waiting for another player • "..waiting.."s")or("Finding a nearby floor • "..waiting.."s")
  end
 end
end)
lobbyUI();progress();responsive();reset();task.delay(2,reset);send("Sync")
if PARTY then
 notice("🔥 Climb the lava tower • Attack = shove • 🧤 Gloves in the menu")
 require(RS.SkySproutWaterClient).Start()
 require(RS.SkySproutPerception).Start()
 require(RS.SkySproutRendering).Start()
 require(RS.SkySproutHUD).Start(event,gui)
else
require(RS.SkySproutTowerClient).Start(event,gui)
notice("V: summon your mount • M: map • Clear guardians to climb.")

require(RS.SkySproutRPGClient).Start(event,gui)

require(RS.SkySproutTargeting).Start(gui)

require(RS.SkySproutWorldClient).Start(event,gui)

require(RS.SkySproutRendering).Start()
require(RS.SkySproutMountClient).Start()
require(RS.SkySproutNavigation).Start(gui)
require(RS.SkySproutContractsClient).Start(event,gui)
require(RS.SkySproutHUD).Start(event,gui)

require(RS.SkySproutPortalClient).Start()
end

require(RS.SkySproutTravelClient).Start(event,gui)
require(RS.SkySproutAdminClient).Start(gui)
