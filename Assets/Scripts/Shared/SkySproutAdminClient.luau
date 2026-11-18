local M={}
local P=game.Players.LocalPlayer
local H=require(game.ReplicatedStorage.SkySproutHUD)
local UIS=game:GetService("UserInputService")
local function rounded(v)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=v end
local function label(parent,name,value)
 local t=Instance.new("TextLabel");t.Name=name;t.Text=value;t.BackgroundTransparency=1;t.Font=Enum.Font.GothamMedium;t.TextSize=12;t.TextColor3=Color3.fromRGB(240,241,244);t.TextWrapped=true;t.Parent=parent;return t
end
local function button(parent,name,value)
 local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.BackgroundColor3=Color3.fromRGB(47,50,59);b.TextColor3=Color3.fromRGB(240,241,244);b.Font=Enum.Font.GothamMedium;b.TextSize=12;b.BorderSizePixel=0;b.Selectable=true;rounded(b);b.Parent=parent;return b
end
local function input(parent,name,value,placeholder)
 local b=Instance.new("TextBox");b.Name=name;b.Text=value;b.PlaceholderText=placeholder;b.ClearTextOnFocus=false;b.BackgroundColor3=Color3.fromRGB(36,39,48);b.TextColor3=Color3.fromRGB(240,241,244);b.PlaceholderColor3=Color3.fromRGB(160,169,185);b.Font=Enum.Font.GothamMedium;b.TextSize=13;b.BorderSizePixel=0;rounded(b);b.Parent=parent;return b
end
function M.Layout(panel,size)
 panel.Title.Position=UDim2.fromOffset(12,8);panel.Title.Size=UDim2.new(1,-70,0,24)
 panel.Close.Position=UDim2.new(1,-56,0,8);panel.Close.Size=UDim2.fromOffset(44,44)
 panel.Identity.Position=UDim2.fromOffset(12,35);panel.Identity.Size=UDim2.new(1,-78,0,28)
 local body=panel.Body;body.Position=UDim2.fromOffset(12,70);body.Size=UDim2.fromOffset(size.X-24,math.max(70,size.Y-126))
 local width=size.X-30
 for i,row in panel.Body:GetChildren()do if row:IsA("Frame")then
  row.Position=UDim2.fromOffset(0,row:GetAttribute("Row")*52);row.Size=UDim2.fromOffset(width,46)
  local children={};for _,v in row:GetChildren()do if v:IsA("GuiObject")then table.insert(children,v)end end;table.sort(children,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
  local n=#children;local w=(width-(n-1)*6)/n
  for j,v in children do v.Position=UDim2.fromOffset((j-1)*(w+6),1);v.Size=UDim2.fromOffset(w,44)end
 end end
 body.CanvasSize=UDim2.fromOffset(0,12*52)
 panel.Status.Position=UDim2.new(0,12,1,-48);panel.Status.Size=UDim2.new(1,-24,0,40)
end
function M.Start(gui)
 if M.Started then return end;M.Started=true
 local remote=game.ReplicatedStorage:WaitForChild("SkyboundOwnerAdmin");local motion=game.ReplicatedStorage:WaitForChild("SkyboundOwnerMotion")
 local busy=false;local panel;local controls={};local up=false;local down=false
 function M.Request(command,value)
  if busy then return nil end;busy=true
  local ok,r=pcall(function()return remote:InvokeServer(command,value)end);busy=false
  if not ok then r={Ok=false,Message="Owner tools could not reach the server."}end
  if panel then panel.Status.Text=r.Message or"";panel.Status.TextColor3=r.Ok and Color3.fromRGB(137,224,185)or Color3.fromRGB(255,166,157)end
  if r.State then M.State=r.State end
  return r
 end
 local function make()
  if panel then return end
  panel=Instance.new("Frame");panel.Name="OwnerPanel";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(520,500);panel.BackgroundColor3=Color3.fromRGB(27,29,35);panel.BorderSizePixel=0;panel.Visible=false;rounded(panel);panel.Parent=gui;M.Panel=panel
  label(panel,"Title","Owner controls").TextSize=18;label(panel,"Identity",P.Name.." • "..P.UserId.." • sole owner")
  local close=button(panel,"Close","X");close.Activated:Connect(function()H.Close()end)
  local body=Instance.new("ScrollingFrame");body.Name="Body";body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.ScrollingDirection=Enum.ScrollingDirection.Y;body.Parent=panel
  label(panel,"Status","Flight: movement + Space/Ctrl. Powers reset on travel, respawn and encounters.")
  local function row(index,name)local f=Instance.new("Frame");f.Name=name;f:SetAttribute("Row",index);f.BackgroundTransparency=1;f.Parent=body;return f end
  local function command(parent,name,text,action,value)local b=button(parent,name,text);b.LayoutOrder=#parent:GetChildren();b.Activated:Connect(function()local payload=value;if type(value)=="function"then payload=value()end;M.Request(action,payload)end);controls[name]=b;return b end
  local f=row(0,"Travel");local floor=input(f,"Floor","1","Floor 1–20");floor.LayoutOrder=0;command(f,"GoFloor","Go to floor","Floor",function()return tonumber(floor.Text)end)
  f=row(1,"Region");local region=input(f,"Region","Town","Region ID");region.LayoutOrder=0;command(f,"GoRegion","Go to region","Region",function()return region.Text end)
  f=row(2,"Survival");command(f,"Heal","Heal + recharge","Heal");command(f,"God","God mode","God",function()return not P:GetAttribute("OwnerGod")end)
  f=row(3,"Motion");command(f,"Fly","Flight","Fly",function()return not P:GetAttribute("OwnerFlying")end);command(f,"Noclip","Noclip + flight","Noclip",function()return not P:GetAttribute("OwnerNoclip")end)
  f=row(4,"Speed");local speed=input(f,"Speed","78","Speed 1–150");speed.LayoutOrder=0;command(f,"ApplySpeed","Set speed","Speed",function()return tonumber(speed.Text)end)
  f=row(5,"Jump");local jump=input(f,"Jump","80","Jump 1–150");jump.LayoutOrder=0;command(f,"ApplyJump","Set jump","Jump",function()return tonumber(jump.Text)end)
  f=row(6,"Coins");local coins=input(f,"Amount","1000","Coin amount");coins.LayoutOrder=0;command(f,"GiveCoins","Add coins","Coins",function()return tonumber(coins.Text)end)
  f=row(7,"XP");local xp=input(f,"Amount","1000","XP amount");xp.LayoutOrder=0;command(f,"GiveXP","Add XP","XP",function()return tonumber(xp.Text)end)
  f=row(8,"Progress");command(f,"UnlockRoutes","Unlock waystones","UnlockRoutes");command(f,"MaxProgress","Max progression","MaxProgress")
  f=row(9,"Reset");command(f,"ClearPowers","Reset powers","ClearPowers");command(f,"Respawn","Respawn","Respawn")
  f=row(10,"PlayerId");local target=input(f,"Target","","Other player's numeric user ID");target.LayoutOrder=0;command(f,"Roster","Show player IDs","State").Activated:Connect(function()if M.State then local names={};for _,p in M.State.Players do table.insert(names,p.Name..": "..p.Id)end;panel.Status.Text=table.concat(names," • ")end end)
  f=row(11,"Moderation");command(f,"KickPlayer","Kick","Kick",function()return tonumber(target.Text)end);command(f,"BanPlayer","Ban this server","BanServer",function()return tonumber(target.Text)end);command(f,"UnbanPlayer","Unban server","UnbanServer",function()return tonumber(target.Text)end)
  local toggle=button(gui,"OwnerToggle","Admin [F2]");toggle.Size=UDim2.fromOffset(108,44);toggle.Position=UDim2.new(1,-120,0,82);toggle.Text=UIS.TouchEnabled and"Admin"or"Admin [F2]";M.Toggle=toggle
  toggle.Activated:Connect(function()M.Open()end)
  function M.Open()H.Toggle("OwnerPanel");if panel.Visible then M.Request("State")end end
  game:GetService("ContextActionService"):BindAction("OpenOwnerTools",function(_,state)if state==Enum.UserInputState.Begin and not UIS:GetFocusedTextBox()then M.Open()end;return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.F2)
  local flyUp=button(gui,"OwnerFlyUp","Fly up");flyUp.Size=UDim2.fromOffset(70,44);flyUp.Position=UDim2.new(1,-150,0,136)
  local flyDown=button(gui,"OwnerFlyDown","Fly down");flyDown.Size=UDim2.fromOffset(70,44);flyDown.Position=UDim2.new(1,-150,0,186)
  for _,v in {{flyUp,function(on)up=on end},{flyDown,function(on)down=on end}}do
   v[1].InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then v[2](true)end end)
   v[1].InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then v[2](false)end end)
  end
  local function refresh()
   controls.God.Text=P:GetAttribute("OwnerGod")and"God mode: ON"or"God mode: OFF"
   controls.Fly.Text=P:GetAttribute("OwnerFlying")and"Flight: ON"or"Flight: OFF"
   controls.Noclip.Text=P:GetAttribute("OwnerNoclip")and"Noclip: ON"or"Noclip: OFF"
   flyUp.Visible=UIS.TouchEnabled and P:GetAttribute("OwnerFlying")==true and not gui:GetAttribute("ModalOpen");flyDown.Visible=flyUp.Visible
  end
  for _,key in {"OwnerGod","OwnerFlying","OwnerNoclip"}do P:GetAttributeChangedSignal(key):Connect(refresh)end;gui:GetAttributeChangedSignal("ModalOpen"):Connect(refresh)
  UIS.WindowFocusReleased:Connect(function()up=false;down=false;motion:FireServer(Vector3.zero)end)
  local elapsed=0
  game:GetService("RunService").Heartbeat:Connect(function(dt)
   elapsed+=dt;if elapsed<.08 then return end;elapsed=0
   if P:GetAttribute("OwnerFlying")then
    local h=P.Character and P.Character:FindFirstChildOfClass("Humanoid");local direction=Vector3.zero
    if h and not UIS:GetFocusedTextBox()and not gui:GetAttribute("ModalOpen")then
     local vertical=((up or UIS:IsKeyDown(Enum.KeyCode.Space))and 1 or 0)-((down or UIS:IsKeyDown(Enum.KeyCode.LeftControl))and 1 or 0)
     direction=h.MoveDirection+Vector3.new(0,vertical,0);if direction.Magnitude>1 then direction=direction.Unit end
    end
    motion:FireServer(direction)
   end
  end)
  refresh();H.Refresh();M.Ready=true
 end
 local checking=false
 local function check()
  if M.Ready or checking or not P:GetAttribute("SkyboundOwner")then return end;checking=true
  task.spawn(function()local r=M.Request("State");if r and r.Ok and r.State and r.State.Role=="Owner"then make()end;checking=false end)
 end
 P:GetAttributeChangedSignal("SkyboundOwner"):Connect(check);P:GetAttributeChangedSignal("UnlockedFloor"):Connect(check);check()
end
return M
