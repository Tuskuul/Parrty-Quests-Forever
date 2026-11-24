-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
local locked=false
local now=1
GetTime=function() return now end
InCombatLockdown=function() return locked end
CreateFrame=function() return setmetatable({},{__index=function() return function() end end}) end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local function font(size)
 return {size=size,shadow=0.4,
  GetFont=function(self) return 'NativeFont',self.size,'OUTLINE' end,
  GetShadowOffset=function() return 1,-1 end,
  GetShadowColor=function(self) return 0,0,0,self.shadow end,
  GetSpacing=function() return 2 end}
end
ObjectiveTrackerHeaderFont=font(16);ObjectiveTrackerLineFont=font(14)
OBJECTIVE_TRACKER_COLOR={Header={r=1,g=0.8,b=0},Normal={r=0.8,g=0.8,b=0.8},Complete={r=0.6,g=0.6,b=0.6}}
UIParent={GetEffectiveScale=function() return 0.8 end}
local tracker={GetEffectiveScale=function() return 1.2 end}
local function text()
 return {SetFontObject=function(self,value) self.font=value end,
  SetTextColor=function(self,...) self.color={...} end}
end
local scales=0
A.sidebar={title=text(),hint=text(),partyOnlyTitle=text(),share={caption=text()},
 SetScale=function(self,value) scales=scales+1;self.scale=value end}
A:SyncTrackerSidebarAppearance(tracker)
assert(math.abs(A.sidebar.scale-1.5)<0.00001,'tracker scale not normalized to UIParent')
assert(A.sidebar.title.font==ObjectiveTrackerHeaderFont and A.sidebar.share.caption.font==ObjectiveTrackerLineFont)
assert(A.sidebar.hint.color[1]==0.8 and A.integration.dirty and A.integration.due==nil)
A.integration.dirty=false;now=2;A:SyncTrackerSidebarAppearance(tracker)
assert(not A.integration.dirty and scales==1,'unchanged appearance caused a full rebuild')
ObjectiveTrackerLineFont.size=20;now=3;A:SyncTrackerSidebarAppearance(tracker)
assert(A.integration.dirty,'in-place text size change did not reflow rows')
A.integration.dirty=false;ObjectiveTrackerLineFont.shadow=1;now=4;A:SyncTrackerSidebarAppearance(tracker)
assert(A.integration.dirty,'contrast/shadow change was not detected')
A.integration.dirty=false;OBJECTIVE_TRACKER_COLOR.Normal={r=1,g=1,b=1};now=5
A:SyncTrackerSidebarAppearance(tracker)
assert(A.sidebar.hint.color[1]==1 and A.integration.dirty,'live text colors were ignored')
A.integration.dirty=false;locked=true;now=6
ObjectiveTrackerLineFont.size=12;A:SyncTrackerSidebarAppearance(tracker)
assert(not A.integration.dirty,'appearance was applied during combat')
locked=false;A:SyncTrackerSidebarAppearance(tracker)
assert(A.integration.dirty,'deferred appearance was not applied after combat')
print('PASS: tracker font size, outline/shadow contrast, live palette, scale, stable-state caching, layout reflow and combat deferral')

