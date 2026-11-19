unpack=unpack or table.unpack
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={readable=function(v) return type(v)=='table' end,public=function(v,k) return type(v)==k end,db={}}
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local function region()
 local r={points={{'LEFT','original','LEFT',7,0}},width=300}
 function r:GetWidth() return self.width end
 function r:SetWidth(v) self.width=v end
 function r:GetNumPoints() return #self.points end
 function r:GetPoint(i) return unpack(self.points[i]) end
 function r:ClearAllPoints() self.points={} end
 function r:SetPoint(...) self.points[#self.points+1]={...} end
 return r
end
local background,title=region(),region()
local header={Background=background,Text=title}
local tracker={Header=header,IsCollapsed=function() return false end}
ObjectiveTrackerFrame=tracker
A.sidebar={SetShown=function() end}
GetTime=function() return 100 end
InCombatLockdown=function() return true end
A.db.displayMode='blizzard'
function A:ShouldShowPartyView() return true end
function A:ResizeCombatTrackerBackground() end
function A:RenderCombatTrackerSidebar() end
A.integration.nativeVisible=true
for _,side in ipairs({'left','right'}) do
 A.db.trackerSide=side
 A:JoinTrackerHeader(tracker,true)
 assert(title.points[1][1]=='CENTER' and title.points[1][2]==background,'expanded title must center on joined artwork')
 A:PositionJoinedTrackerTitle(true)
 assert(title.points[1][1]=='CENTER' and title.points[1][2]==background,'collapsed title is not centered on the visible bar')
 A:PositionJoinedTrackerTitle(false)
 assert(title.points[1][1]=='CENTER','re-expanding did not restore centered title')
 A.integration.nativeCollapsed=true
 A:RefreshCombatTrackerPane()
 assert(not A.integration.joinedHeader and background.points[1][2]=='original','combat collapse did not restore compact header')
 A.db.trackerHidden=true;A:RefreshCombatTrackerPane()
 assert(not A.integration.joinedHeader,'hidden party pane kept its joined header')
 A.db.trackerHidden=false;A:RefreshCombatTrackerPane()
 assert(not A.integration.joinedHeader and title.points[1][2]=='original','party toggle widened a collapsed header')
 A.integration.nativeCollapsed=false
 A:RefreshCombatTrackerPane()
 assert(A.integration.joinedHeader and title.points[1][1]=='CENTER','main expand did not restore centered full-width header')
 A:SyncCombatTrackerHeader(false)
 assert(title.points[1][2]=='original' and background.points[1][2]=='original','combat hide left the header stretched')
 A:SyncCombatTrackerHeader(true)
 assert(title.points[1][1]=='CENTER' and #background.points==2,'combat reopen did not restore joined header')
 A:SyncCombatTrackerHeader(false)
 A:SyncCombatTrackerHeader(true)
 assert(title.points[1][2]==background,'repeated combat toggle lost centered title')
 tracker.IsCollapsed=function() return true end
 A:JoinTrackerHeader(tracker,true)
 assert(not A.integration.joinedHeader and background.points[1][2]=='original','out-of-combat layout kept wide collapsed header')
 tracker.IsCollapsed=function() return false end
 A:JoinTrackerHeader(tracker,true)
 assert(title.points[1][1]=='CENTER','expanded layout failed to restore joined header')
 A:JoinTrackerHeader(tracker,false)
 assert(title.points[1][2]=='original' and title.points[1][4]==7,'native title anchors not restored')
 assert(background.points[1][4]==-17 and background.width==324,'native-only artwork did not fill left inset')
 A:JoinTrackerHeader(tracker,false)
 assert(background.points[1][4]==-17 and background.width==324,'native-only extension accumulated')
 A:FitNativeTrackerHeader(nil,false)
 assert(background.points[1][4]==7 and background.width==300,'native artwork not exactly restored on detach')
end
-- Two-edge native textures keep the right edge, width constraints and height.
background.points={{'TOPLEFT',header,'TOPLEFT',0,0},{'BOTTOMRIGHT',header,'BOTTOMRIGHT',8,-32}}
A:FitNativeTrackerHeader(tracker,true)
assert(background.points[1][4]==-24 and background.points[2][4]==8 and background.points[2][5]==-32,'two-edge fit moved the right/bottom art')
A:FitNativeTrackerHeader(nil,false)
assert(background.points[1][4]==0 and background.points[2][4]==8,'two-edge art did not restore')
print('PASS: expanded title center, compact collapsed header, combat collapse and party toggles, both sidebar sides and native anchor restoration')

