-- Run from the addon directory with Lua 5.1+; no WoW client required.
CreateFrame=function() return setmetatable({},{__index=function() return function() end end}) end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local calls=0
local background={SetAlpha=function(self,value) calls=calls+1;self.alpha=value end}
A.sidebar={trackerBackground=background,SetAlpha=function() error('quest text was faded') end}
local tracker={NineSlice={GetAlpha=function() return 0.6 end}}
ObjectiveTrackerManager={backgroundAlpha=0.25}
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==0.25,'Edit Mode opacity was not applied')
A:SyncTrackerSidebarOpacity(tracker)
assert(calls==1,'unchanged opacity was unnecessarily reapplied')
ObjectiveTrackerManager.backgroundAlpha=0
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==0,'zero opacity was ignored')
ObjectiveTrackerManager.backgroundAlpha=1
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==1)
ObjectiveTrackerManager=nil
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==0.6,'native background fallback failed')
A:SyncTrackerSidebarOpacity({})
assert(background.alpha==0.6,'unavailable setting replaced last known opacity')
ObjectiveTrackerManager={backgroundAlpha=0/0}
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==0.6,'invalid setting changed opacity')
ObjectiveTrackerManager.backgroundAlpha=2
A:SyncTrackerSidebarOpacity(tracker)
assert(background.alpha==1,'opacity was not clamped')
print('PASS: Edit Mode background opacity, slider changes, zero/full alpha, fallback, invalid values and no quest-text fading')
