local T={Active={},Sequence={}}
local event
function T.Current(p,ticket)return T.Active[p]==ticket and p.Parent~=nil and p.Character==ticket.Character end
function T.Begin(p,details)
 local old=T.Active[p];if old then T.Finish(p,old,false,"Travel replaced.")end
 local id=(T.Sequence[p]or 0)+1;T.Sequence[p]=id
 local ticket={Id=id,Character=p.Character,Floor=details.Floor,Name=details.Name,Kind=details.Kind,Started=os.clock()}
 T.Active[p]=ticket;p:SetAttribute("TravelId",id);p:SetAttribute("TravelName",details.Name);p:SetAttribute("TowerTraveling",true)
 event:FireClient(p,"TravelBegin",{Id=id,Floor=ticket.Floor,Name=ticket.Name,Kind=ticket.Kind})
 return ticket
end
function T.Finish(p,ticket,success,reason)
 if T.Active[p]~=ticket then return false end
 T.Active[p]=nil
 if p.Parent then
  p:SetAttribute("TowerTraveling",false)
  event:FireClient(p,"TravelFinished",{Id=ticket.Id,Floor=ticket.Floor,Name=ticket.Name,Success=success==true,Reason=reason})
 end
 return true
end
function T.Cancel(p,id)
 local ticket=T.Active[p]
 if not ticket or type(id)~="number"or id~=ticket.Id then return false end
 return T.Finish(p,ticket,false,"Travel cancelled.")
end
function T.Start(remote)
 event=remote
 local function added(p)p.CharacterAdded:Connect(function(ch)local ticket=T.Active[p];if ticket and ticket.Character~=ch then T.Finish(p,ticket,false,"Respawned.")end end)end
 game.Players.PlayerAdded:Connect(added);for _,p in game.Players:GetPlayers()do added(p)end
 game.Players.PlayerRemoving:Connect(function(p)T.Active[p]=nil;T.Sequence[p]=nil end)
 local elapsed=0;game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.5 then return end;elapsed=0
  for p,ticket in T.Active do
   local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
   if not T.Current(p,ticket)or not h or h.Health<=0 then T.Finish(p,ticket,false,"Travel interrupted.")
   elseif os.clock()-ticket.Started>8 then T.Finish(p,ticket,false,"Destination took too long. Try again.")end
  end
 end)
end
return T
