local P={Nodes={},Times={}}
local A,event,tell
local Profiles=require(script.Parent.SkySproutProfiles)
function P.Use(p,prompt)
 local node=P.Nodes[prompt];local session=Profiles.Sessions[p]
 local ch=p.Character;local r=ch and ch:FindFirstChild("HumanoidRootPart");local h=ch and ch:FindFirstChildOfClass("Humanoid")
 if not(node and session and r and h and h.Health>0 and prompt.Parent and prompt:IsDescendantOf(workspace.SkySprout))then return false,"Invalid portal"end
 local from=node:GetAttribute("SourceFloor");local destination=node:GetAttribute("DestinationFloor")
 if p:GetAttribute("VisitFloor")~=from or from>session.Data.BestFloor or(r.Position-prompt.Parent.Position).Magnitude>16 then return false,"Out of reach"end
 if p:GetAttribute("TowerTraveling")or p:GetAttribute("RPGRaid")or A.Fighters[p]then return false,"In encounter"end
 local st=A.RPG.States[p];local now=os.clock()
 if st and(now<(st.CombatUntil or 0)or now<st.Stun or now<st.Next)then tell(p,"Portals become available after combat.");return false,"In combat"end
 if now<(P.Times[p]or 0)then return false,"Portal cooling down"end
 P.Times[p]=now+.8
 if node:GetAttribute("Directory")then event:FireClient(p,"OpenFloors");return true end
 if type(destination)~="number"or destination>session.Data.BestFloor then tell(p,"LOCKED • Defeat this floor's guardian to reach the next world.");return false,"Locked"end
 return A.Tower.Travel(p,destination,false,node:GetAttribute("Arrival"))
end
function P.Start(arena,remote,notice)
 A=arena;event=remote;tell=notice
 for _,v in workspace.SkySprout:GetDescendants()do
  if v:IsA("ProximityPrompt")and v.Parent and v.Parent:GetAttribute("FloorPortal")then
   P.Nodes[v]=v.Parent;v.Triggered:Connect(function(p)P.Use(p,v)end)
  end
 end
 game.Players.PlayerRemoving:Connect(function(p)P.Times[p]=nil end)
end
return P
