-- Run from the addon directory with Lua 5.1+; no WoW client required.
CreateFrame=function() return setmetatable({},{__index=function() return function() end end}) end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
Enum={EditModeObjectiveTrackerSetting={Height=1}}
local configured=800
local tracker={editModeHeight=700,GetHeight=function() return 250 end,
 GetSettingValue=function(_,setting) assert(setting==1);return configured end}
A.db={sidebarHeight=240}
assert(A:TrackerSidebarHeightLimit(tracker)==800,'configured height was capped by old sidebar/native content height')
configured=600;assert(A:TrackerSidebarHeightLimit(tracker)==600,'Edit Mode height change ignored')
configured=nil;assert(A:TrackerSidebarHeightLimit(tracker)==700,'cached Edit Mode fallback failed')
tracker.editModeHeight=nil;assert(A:TrackerSidebarHeightLimit(tracker)==250,'native height fallback failed')
assert(A:TrackerSidebarHeightLimit({})==420,'unavailable tracker fallback failed')
configured=800
local f={headerOffset=32,contentHeight=100,heightLimit=A:TrackerSidebarHeightLimit(tracker),
 GetWidth=function() return 420 end,
 SetHeight=function(self,h) self.width=w;self.height=h end,
 scroll={position=0,SetSize=function(self,w,h) self.width=w;self.height=h end,
  GetVerticalScroll=function(self) return self.position end,
  SetVerticalScroll=function(self,n) self.position=n end},
 hint={SetShown=function(self,shown) self.shown=shown end}}
A.sidebar=f;A:SizeTrackerSidebar()
assert(7+f.scroll.width<420,'scroll viewport spills into the adjacent native pane')
assert(f.height==176 and f.maxScroll==0 and not f.hint.shown,'small list did not shrink')
f.contentHeight=1500;A:SizeTrackerSidebar()
assert(f.height==800 and f.scroll.height==710 and f.maxScroll==790 and f.hint.shown,'long list did not use shared cap and scroll')
configured=500;f.heightLimit=A:TrackerSidebarHeightLimit(tracker);A:SizeTrackerSidebar()
assert(f.height==500 and f.maxScroll>0,'new Edit Mode cap was not applied')
f.scroll.position=900;f.contentHeight=1;f.headerOffset=0;A:SizeTrackerSidebar()
assert(f.height==45 and f.maxScroll==0 and f.scroll.position==0,'empty view did not shrink/reset scrolling')
f.viewCollapsed=true;A:SizeTrackerSidebar()
assert(f.height==30 and not f.hint.shown,'collapsed header did not stay compact')
print('PASS: shared Edit Mode height cap, live changes, small/empty contraction, overflow scrolling, legacy setting ignored and fallbacks')

