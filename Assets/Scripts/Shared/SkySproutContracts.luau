local D={}
local themes={
 [1]={Title="Gateward Trail",Item="survey flags",Verb="restore",Patrol="Old Road Patrol"},
 [2]={Title="Harvest Lantern Walk",Item="harvest lanterns",Verb="light",Patrol="Hollow Watch"},
 [3]={Title="Relay Reconnection",Item="signal relays",Verb="reboot",Patrol="Circuit Patrol"},
 [4]={Title="Corsair Supply Route",Item="cargo seals",Verb="recover",Patrol="Coastwatch Bounty"},
 [5]={Title="Neighborhood Restoration",Item="service stations",Verb="repair",Patrol="Neighborhood Watch"},
 [6]={Title="Frostbound Rescue Trail",Item="rescue braziers",Verb="light",Patrol="Snowpass Patrol"},
 [7]={Title="Oasis Water Route",Item="water caches",Verb="secure",Patrol="Caravan Guard"},
 [8]={Title="Sporelight Field Study",Item="glowspore samples",Verb="collect",Patrol="Grovekeeper Patrol"},
 [9]={Title="Jade Pilgrimage",Item="shrine bells",Verb="ring",Patrol="Shrine Wardens"},
 [10]={Title="Forge Cooling Circuit",Item="coolant valves",Verb="open",Patrol="Forge Patrol"},
 [11]={Title="Sanctum Tide Survey",Item="tide gauges",Verb="calibrate",Patrol="Tidewatch Patrol"},
 [12]={Title="Carnival Preparations",Item="festival stations",Verb="prepare",Patrol="Carnival Watch"},
 [13]={Title="Foundry Restart",Item="clockwork regulators",Verb="reset",Patrol="Foundry Patrol"},
 [14]={Title="The Hollowmoon Lights",Item="ward lanterns",Verb="light",Patrol="Manor Watch"},
 [15]={Title="Prism Network Repair",Item="prism terminals",Verb="reconnect",Patrol="Skyline Patrol"},
 [16]={Title="Harbor Storm Readiness",Item="harbor beacons",Verb="secure",Patrol="Stormwatch Patrol"},
 [17]={Title="Silverpine Rescue Route",Item="mountain signals",Verb="raise",Patrol="Alpine Rangers"},
 [18]={Title="Roseglass Restoration",Item="garden fountains",Verb="restore",Patrol="Garden Wardens"},
 [19]={Title="Starfall Calibration",Item="star lenses",Verb="align",Patrol="Observatory Watch"},
 [20]={Title="The Crown Pilgrimage",Item="crown sigils",Verb="attune",Patrol="Crown Sentinels"},
}
D.IDs={"Survey","Patrol"}
D.RegionOrder={"Forest","Highlands","Lake"}
function D.Get(f,id)
 local t=themes[f];if not t then return end
 if id=="Survey"then
  return {Id=id,Title=t.Title,Description="Follow the woodland, highland and lakeside route to "..t.Verb.." three "..t.Item..". Return to the town contract board.",Stops={"Forest","Highlands","Lake"},Item=t.Item,Verb=t.Verb,Coins=50+f*6,XP=100+f*14}
 elseif id=="Patrol"then
  return {Id=id,Title=t.Patrol,Description="Defeat three ruin watchers on this floor, then report to the town contract board.",Stops={"Hunt"},Coins=60+f*8,XP=120+f*16}
 end
end
return D
