local locked,now=false,100
InCombatLockdown=function() return locked end
GetTime=function() return now end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local function frame(kind,l,r,t,b,scale)
 local f={kind=kind,left=l,right=r,top=t,bottom=b,scale=scale or 1,shown=true,children={}}
 function f:GetEffectiveScale() return self.scale end
 function f:GetLeft() return self.left end
 function f:GetRight() return self.right end
 function f:GetTop() return self.top end
 function f:GetBottom() return self.bottom end
 function f:IsShown() return self.shown end
 function f:IsObjectType(k) return k==self.kind end
 function f:GetChildren() return table.unpack(self.children) end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 function f:ClearAllPoints() self.points=(self.points or 0)+1 end
 function f:SetPoint(...) assert(not locked);self.point={...} end
 return f
end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogLinks.lua'))('SimplyPartyQuests',A)
WorldMapFrame=frame('Frame',0,1300,800,0)
local border=frame('Frame',0,1300,800,0);WorldMapFrame.BorderFrame=border
local arrow=frame('Frame',1230,1250,795,773);border.MaximizeMinimizeFrame=arrow
local other=frame('Button',1090,1222,795,773)
WorldMapFrame.children={border};border.children={arrow,other}
local own=frame('Button',1093,1225,795,773);A.questLogShareButton=own;border.children[3]=own
A:PositionQuestLogShareButton()
assert(own.point[2]==arrow and own.point[4]==-146 and own.shown,'overlapping title control was not avoided')
local count=own.points;A:PositionQuestLogShareButton();assert(own.points==count,'unchanged placement reanchored every tick')
other.shown=false;A:PositionQuestLogShareButton();assert(own.point[4]==-5,'normal placement was not restored')
other.shown=true;other.scale=0.5;other.left=2180;other.right=2444;other.top=1590;other.bottom=1546
A:PositionQuestLogShareButton();assert(own.point[4]==-146,'scaled foreign control collision missed')
local second=frame('Button',940,1080,795,773);border.children[4]=second
A:PositionQuestLogShareButton();assert(own.point[4]==-296,'multiple controls still overlap')
locked=true;other.shown=false;local prior=own.points;A:UpdateQuestLogSharePlacement();assert(own.points==prior,'combat moved a map-parented button')
locked=false;WorldMapFrame.shown=false;A:UpdateQuestLogSharePlacement();assert(own.points==prior,'hidden map was scanned')
WorldMapFrame.shown=true;second.shown=false;A:UpdateQuestLogSharePlacement();assert(own.point[4]==-5)
print('PASS: map share title-bar collision avoidance, multiple/scaled controls, stable anchors, hidden-map/combat deferral and normal-slot restoration')
