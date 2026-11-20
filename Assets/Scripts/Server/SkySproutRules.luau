local C=require(game.ReplicatedStorage.SkySproutConfig)
local R={}
function R.floor(points)return math.clamp(1+math.floor(points/C.PointsPerFloor),1,C.MaxFloor)end
function R.new()return {Version=8,Waystones={},Contracts={},XP=0,Style="Vanguard",Relic="Ember",BossClears={},Hunts={},Stories={},Coins=0,Points=0,BestFloor=1,Wins=0,Losses=0,Knockouts=0,Skin="Mint",Owned={Mint=true},FloorQuests={},Receipts={},LastDaily=0,DailyStreak=0,Crowns=0,Hat="",OwnedHats={},PassSeason=0,PassXP=0,PassFree={},PassPrem={},Tipped=0,WelcomeClaimed=false,Invited={},InviteDay=0,InviteToday=0,Daily={Day=0,P={},C={}},Redeemed={},TutorialDone=false}end
function R.clean(raw)
 local p=R.new();if type(raw)~="table"then return p end
 for _,k in ipairs({"Coins","Points","Wins","Losses","Knockouts","BestFloor","XP","Crowns"})do
  local v=raw[k];if type(v)=="number"and v==v and math.abs(v)<math.huge then p[k]=math.clamp(math.floor(v),0,100000000)end
 end
 p.Points=math.min(p.Points,(C.MaxFloor-1)*C.PointsPerFloor);p.BestFloor=math.clamp(p.BestFloor,1,C.MaxFloor)
 for _,s in ipairs(C.Skins)do if not s.Premium and type(raw.Owned)=="table"and raw.Owned[s.Id]==true then p.Owned[s.Id]=true end end
 if type(raw.Skin)=="string"and(p.Owned[raw.Skin]or raw.Skin=="Aurora")then p.Skin=raw.Skin end
 for _,h in ipairs(C.Hats)do if type(raw.OwnedHats)=="table"and raw.OwnedHats[h.Id]==true then p.OwnedHats[h.Id]=true end end
 if type(raw.Hat)=="string"and(p.OwnedHats[raw.Hat]or raw.Hat==(C.Vip and C.Vip.Hat))then p.Hat=raw.Hat end
 local season=C.LavaPass and C.LavaPass.Season or 0
 if raw.PassSeason==season then
  p.PassSeason=season
  if type(raw.PassXP)=="number"and raw.PassXP==raw.PassXP then p.PassXP=math.clamp(math.floor(raw.PassXP),0,1000000)end
  for _,track in ipairs({"PassFree","PassPrem"})do
   if type(raw[track])=="table"then for tier=1,#C.LavaPass.Tiers do if raw[track][tostring(tier)]==true then p[track][tostring(tier)]=true end end end
  end
 else
  p.PassSeason=season
 end
 if type(raw.Tipped)=="number"and raw.Tipped==raw.Tipped then p.Tipped=math.clamp(math.floor(raw.Tipped),0,100000000)end
 if type(raw.FloorQuests)=="table"then for f=1,C.MaxFloor do
  local q=raw.FloorQuests[tostring(f)]
  if type(q)=="table"then local n=tonumber(q.Training)or 0;if n~=n or math.abs(n)==math.huge then n=0 end
   local clean={Seals={},Claimed={},Parcel=q.Parcel==true,Delivered=q.Delivered==true,Training=math.clamp(math.floor(n),0,3)}
   for i=1,3 do clean.Seals[tostring(i)]=type(q.Seals)=="table"and q.Seals[tostring(i)]==true or false end
   for _,id in ipairs({"Explore","Courier","Training"})do clean.Claimed[id]=type(q.Claimed)=="table"and q.Claimed[id]==true or false end
   p.FloorQuests[tostring(f)]=clean
  end
 end end
 p.XP=math.min(200000,p.XP)
 if type(raw.LastDaily)=="number"and raw.LastDaily==raw.LastDaily then p.LastDaily=math.clamp(math.floor(raw.LastDaily),0,10000000)end
 if type(raw.DailyStreak)=="number"and raw.DailyStreak==raw.DailyStreak then p.DailyStreak=math.clamp(math.floor(raw.DailyStreak),0,7)end
 p.WelcomeClaimed=raw.WelcomeClaimed==true
 p.TutorialDone=raw.TutorialDone==true
 if type(raw.Redeemed)=="table"then local n=0;for k,v in pairs(raw.Redeemed)do if type(k)=="string"and #k<=24 and v==true and n<200 then p.Redeemed[k]=true;n+=1 end end end
 if type(raw.Daily)=="table"then
  local day=raw.Daily.Day;if type(day)=="number"and day==day then p.Daily.Day=math.clamp(math.floor(day),0,10000000)end
  local n=0
  if type(raw.Daily.P)=="table"then for k,v in pairs(raw.Daily.P)do if type(k)=="string"and #k<=24 and type(v)=="number"and v==v and n<20 then p.Daily.P[k]=math.clamp(math.floor(v),0,100000);n+=1 end end end
  if type(raw.Daily.C)=="table"then for k,v in pairs(raw.Daily.C)do if type(k)=="string"and #k<=24 and v==true then p.Daily.C[k]=true end end end
 end
 if type(raw.Invited)=="table"then for _,id in ipairs(raw.Invited)do if type(id)=="number"and id==id and math.abs(id)<1e15 and #p.Invited<200 then table.insert(p.Invited,math.floor(id))end end end
 if type(raw.InviteDay)=="number"and raw.InviteDay==raw.InviteDay then p.InviteDay=math.clamp(math.floor(raw.InviteDay),0,10000000)end
 if type(raw.InviteToday)=="number"and raw.InviteToday==raw.InviteToday then p.InviteToday=math.clamp(math.floor(raw.InviteToday),0,1000)end
 if type(raw.Receipts)=="table"then for _,id in ipairs(raw.Receipts)do if type(id)=="string"and #id<=64 and #p.Receipts<60 then table.insert(p.Receipts,id)end end end
 local rpg=require(game.ReplicatedStorage.SkySproutRPGConfig)
 if type(raw.Style)=="string"and rpg.Styles[raw.Style]and rpg.Styles[raw.Style].Floor<=p.BestFloor then p.Style=raw.Style end
 if type(raw.Relic)=="string"and rpg.Relics[raw.Relic]and rpg.Relics[raw.Relic].Floor<=p.BestFloor then p.Relic=raw.Relic end
 for f=1,C.MaxFloor do local k=tostring(f)
  p.BossClears[k]=type(raw.BossClears)=="table"and raw.BossClears[k]==true or false
  local n=type(raw.Hunts)=="table"and raw.Hunts[k]or 0
  if type(n)~="number"or n~=n or math.abs(n)==math.huge then n=0 end;p.Hunts[k]=math.clamp(math.floor(n),0,3)
 end
 if type(raw.ActiveStory)=="number"and raw.ActiveStory==raw.ActiveStory then p.ActiveStory=math.clamp(math.floor(raw.ActiveStory),1,p.BestFloor)end
 for f=1,C.MaxFloor do local k=tostring(f);local q=type(raw.Stories)=="table"and raw.Stories[k]
  if type(q)=="table"then
   local maxStep=f<3 and 5 or 6;local step=q.Step
   if type(step)=="number"and step==step and math.abs(step)<math.huge and(type(raw.Version)~="number"or raw.Version<7)then
    if f==1 and step>=2 or f==2 or f>=3 and step>=2 then step+=1 end
   end
   if type(step)~="number"or step~=step or math.abs(step)==math.huge then step=1 end
   step=math.clamp(math.floor(step),1,maxStep);local complete=q.Complete==true and step==maxStep
   if not complete then step=math.min(step,maxStep-1)end
   local hunt=q.HuntCount;if type(hunt)~="number"or hunt~=hunt or math.abs(hunt)==math.huge then hunt=0 end
   p.Stories[k]={Step=step,Complete=complete,Rewarded=complete and q.Rewarded==true,HuntCount=math.clamp(math.floor(hunt),0,3)}
  end
 end
 local function integer(v,low,high)
  if type(v)~="number"or v~=v or math.abs(v)==math.huge then return low end
  return math.clamp(math.floor(v),low,high)
 end
 for f=1,p.BestFloor do
  local key=tostring(f);local saved=type(raw.Waystones)=="table"and raw.Waystones[key]
  local nodes={Town=true}
  for _,id in {"Meadow","Forest","Lake","Highlands","Ruins"}do nodes[id]=type(saved)=="table"and saved[id]==true or false end
  p.Waystones[key]=nodes
  local contracts=type(raw.Contracts)=="table"and raw.Contracts[key]
  if type(contracts)=="table"then
   p.Contracts[key]={}
   for _,id in {"Survey","Patrol"}do local q=contracts[id]
    if type(q)=="table"then
     local maximum=id=="Survey"and 4 or 2;local step=integer(q.Step,1,maximum);local count=integer(q.Count,0,3)
     if id=="Patrol"and count<3 then step=1 end
     local complete=q.Complete==true and q.Rewarded==true and step==maximum
     p.Contracts[key][id]={Step=step,Count=count,Complete=complete,Rewarded=complete}
    end
   end
  end
 end
 return p
end
function R.result(p,won,engaged)
 if won then
  p.Wins+=1;p.Points=math.min((C.MaxFloor-1)*C.PointsPerFloor,p.Points+C.WinPoints)
  if engaged then p.Coins+=C.WinCoins end
 else
  p.Losses+=1;p.Points=math.max(0,p.Points-C.LossPoints)
  if engaged then p.Coins+=C.LossCoins end
 end

end
function R.skin(p,id,premium)
 for _,s in ipairs(C.Skins)do if s.Id==id then
  if s.Premium then if not premium then return false,"Aurora is an optional cosmetic."end
  elseif not p.Owned[id]then if p.Coins<s.Cost then return false,s.Cost.." coins needed."end;p.Coins-=s.Cost;p.Owned[id]=true end
  p.Skin=id;return true,s.Name.." equipped."
 end end
 return false,"Unknown style."
end
function R.hat(p,id,vip)
 for _,h in ipairs(C.Hats)do if h.Id==id then
  if p.Hat==id then p.Hat="";return true,h.Name.." taken off."end
  if h.VipOnly then if not vip then return false,"⭐ "..h.Name.." is a VIP perk."end
  elseif h.PassOnly and not p.OwnedHats[id]then return false,"🎟️ Unlock "..h.Name.." in the Lava Pass."
  elseif not p.OwnedHats[id]then if p.Coins<h.Cost then return false,h.Cost.." coins needed."end;p.Coins-=h.Cost;p.OwnedHats[id]=true end
  p.Hat=id;return true,h.Name.." on!"
 end end
 return false,"Unknown hat."
end
return R
