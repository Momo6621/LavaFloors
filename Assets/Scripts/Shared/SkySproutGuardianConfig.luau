local G={}
G.Floors={
 [1]={Name="Gateward Colossus",Deck={"Line","Circle","Ring"},Second="Cross"},
 [2]={Name="Harvest Hollow Reaper",Deck={"Circle","Ring","Barrage"},Second="Sweep"},
 [3]={Name="Circuit Sentinel",Deck={"Line","Cross","Sweep"},Second="Barrage"},
 [4]={Name="Corsair Admiral",Deck={"Line","Ring","Sweep"},Second="Cross"},
 [5]={Name="Maple Watch Captain",Deck={"Circle","Cross","Line"},Second="Barrage"},
 [6]={Name="Frostbound Titan",Deck={"Ring","Barrage","Line"},Second="Sweep"},
 [7]={Name="Dune Caravan Warden",Deck={"Line","Cross","Circle"},Second="Ring"},
 [8]={Name="Sporeheart Keeper",Deck={"Barrage","Circle","Ring"},Second="Cross"},
 [9]={Name="Jade Bell Ronin",Deck={"Sweep","Line","Ring"},Second="Barrage"},
 [10]={Name="Emberforge Golem",Deck={"Cross","Sweep","Ring"},Second="Circle"},
 [11]={Name="Tideglass Leviathan",Deck={"Ring","Barrage","Sweep"},Second="Line"},
 [12]={Name="Carnival Ringmaster",Deck={"Circle","Barrage","Cross"},Second="Sweep"},
 [13]={Name="Brasswork Colossus",Deck={"Cross","Line","Sweep"},Second="Ring"},
 [14]={Name="Hollowmoon Specter",Deck={"Barrage","Ring","Circle"},Second="Sweep"},
 [15]={Name="Prism Overseer",Deck={"Sweep","Cross","Barrage"},Second="Ring"},
 [16]={Name="Stormbreak Admiral",Deck={"Sweep","Line","Ring"},Second="Cross"},
 [17]={Name="Silverpine Guardian",Deck={"Ring","Cross","Line"},Second="Barrage"},
 [18]={Name="Roseglass Knight",Deck={"Circle","Barrage","Sweep"},Second="Cross"},
 [19]={Name="Starfall Oracle",Deck={"Barrage","Cross","Ring"},Second="Sweep"},
 [20]={Name="The Crown Warden",Deck={"Cross","Sweep","Barrage"},Second="Ring"},
}
G.Cues={
 Line="SIDESTEP • Leave the long red lane.",
 Circle="MOVE OUT • Leave the red circle.",
 Ring="MOVE CLOSE • The mint center is safe.",
 Cross="MOVE DIAGONALLY • Leave both crossing lanes.",
 Sweep="KEEP MOVING • Three lanes strike in sequence.",
 Barrage="KEEP MOVING • Three marks strike in sequence.",
}
function G.Select(f,index,phase)
 local spec=G.Floors[f];local length=#spec.Deck+(phase==2 and 1 or 0)
 local at=index%length+1;return spec.Deck[at]or spec.Second
end
return G
