unpack=unpack or table.unpack
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={readable=function(v) return type(v)=='table' end,db={}}
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local function region()
 local r={points={{'LEFT','original','LEFT',7,0}}}
 function r:GetNumPoints() return #self.points end
 function r:GetPoint(i) return unpack(self.points[i]) end
 function r:ClearAllPoints() self.points={} end
 function r:SetPoint(...) self.points[#self.points+1]={...} end
 return r
end
local background,title=region(),region()
local header={Background=background,Text=title}
local tracker={Header=header,IsCollapsed=function() return false end}
A.sidebar={}
for _,side in ipairs({'left','right'}) do
 A.db.trackerSide=side
 A:JoinTrackerHeader(tracker,true)
 assert(title.points[1][1]=='CENTER' and title.points[1][2]==background,'expanded title must center on joined artwork')
 A:PositionJoinedTrackerTitle(true)
 assert(title.points[1][1]=='LEFT' and title.points[1][4]==32,'collapsed title lost its inset')
 A:PositionJoinedTrackerTitle(false)
 assert(title.points[1][1]=='CENTER','re-expanding did not restore centered title')
 A:JoinTrackerHeader(tracker,false)
 assert(title.points[1][2]=='original' and title.points[1][4]==7,'native title anchors not restored')
end
print('PASS: expanded title center, collapsed inset, both sidebar sides and native anchor restoration')
