-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
local function widget()
 return setmetatable({shown=true},{__index=function(_,k)
  if k=='IsShown' then return function(self) return self.shown end end
  if k=='SetShown' then return function(self,v) self.shown=v end end
  if k=='SetPoint' then return function(self,...) self.point={...} end end
  if k=='GetWidth' then return function() return 420 end end
  if k=='GetHeight' then return function() return 540 end end
  if k=='GetFrameLevel' then return function() return 1 end end
  if k:match('^[A-Z]') then return function() end end
 end})
end
CreateFrame=widget;GetTime=function() return 100 end
UIParent=widget()
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('Definitions.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
A.db={combineShared=false,groupByZone=false,questExpanded={},displayMode='blizzard',trackerSide='left'}
local m={guid='offline',name='Triscin Booplesnoot',connected=false,quests={}}
local view={own={},members={m},sections={[m.guid]={count=0,shared={},other={}}},combined={}}
function A:BuildPartyViewData() return view end
local entries=A:BuildTrackerEntries()
assert(#entries==2 and entries[1].kind=='member' and entries[2].title=='No cached quests.')
for _,e in ipairs(entries) do assert(e.kind~='group','empty section header was rendered') end
A.db.combineShared=true
entries=A:BuildTrackerEntries();assert(#entries==2,'empty combined section was rendered')
m.connected=true;m.syncedAt=100
entries=A:BuildTrackerEntries();assert(entries[2].title=='No active quests.')
m.syncedAt=nil
entries=A:BuildTrackerEntries();assert(entries[2].title=='No quests discovered yet.')
A.db.trackerMembersClosed={[m.guid]=true}
entries=A:BuildTrackerEntries();assert(#entries==1,'collapsed empty member rendered extra rows')
A.db.trackerMembersClosed={}
local f=widget();f.title=widget();f.headerArt=widget();f.collapse=widget();f.scroll=widget()
f.collapse.normal=widget();f.collapse.pushed=widget();f.heightLimit=420
A.sidebar=f;A.window=widget()
function A:InitTrackerSidebar() end
function A:SyncTrackerSidebarOpacity() end
function A:SyncTrackerSidebarAppearance() end
function A:EnsurePartyTrackerButton() end
function A:ShouldShowPartyView() return true end
function A:SizeTrackerSidebar() end
local joined
function A:JoinTrackerHeader(_,enabled) joined=enabled end
function A:RenderTrackerSidebar() end
ObjectiveTrackerFrame=widget();ObjectiveTrackerFrame.Header=widget()
ObjectiveTrackerFrame.shown=false
A:TrackerIntegrationTick()
assert(f.headerOffset==0 and f.title.point[5]==-6 and f.scroll.point[5]==-36,'party-only header was not compact')
assert(f.point[1]=='TOPLEFT' and f.point[2]==ObjectiveTrackerFrame and f.point[3]=='TOPLEFT','party-only pane anchored beside hidden tracker')
assert(not joined and f.partyOnlyHeader==nil,'synthetic All Objectives header remained')
ObjectiveTrackerFrame.shown=true
A:TrackerIntegrationTick()
assert(f.headerOffset==38 and f.title.point[5]==-44,'normal sidebar spacing was not restored')
assert(f.point[1]=='TOPRIGHT' and f.point[2]==ObjectiveTrackerFrame.Header and f.point[3]=='TOPLEFT','normal left attachment was not restored')
assert(joined)
A.db.trackerCollapsed=true
ObjectiveTrackerFrame.IsCollapsed=function() return false end
A:TrackerIntegrationTick()
assert(f.scroll.shown and not f.collapse.shown and not f.viewCollapsed,'legacy party collapse overrode the main tracker')
ObjectiveTrackerFrame.IsCollapsed=function() return true end
A:TrackerIntegrationTick()
assert(not f.shown and not f.collapse.shown,'main collapse left party content or a duplicate button')
ObjectiveTrackerFrame.IsCollapsed=function() return false end
A:TrackerIntegrationTick();assert(f.shown and f.scroll.shown,'main expand did not restore party')
ObjectiveTrackerFrame.Header.shown=false
A:TrackerIntegrationTick()
assert(f.headerOffset==0 and not joined,'hidden native header did not return to compact mode')
assert(f.collapse.shown and not f.scroll.shown and f.viewCollapsed,'party-only collapse fallback did not retain a single control')
assert(A.db.displayMode=='blizzard' and A.db.trackerSide=='left','empty state changed saved preferences')
print('PASS: empty/offline/synced states, no empty sections or fake heading, compact standalone anchoring and restored native sidebar')

