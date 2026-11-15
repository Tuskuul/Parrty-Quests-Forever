unpack=unpack or table.unpack
local locked=false
GetTime=function() return 100 end
InCombatLockdown=function() return locked end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local function frame(shown)
 return {shown=shown,IsShown=function(self) return self.shown end,
  Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
  SetAttribute=function(self,key,value) self[key]=value end}
end
local native=frame(true);local registrations,removals=0,0
RegisterStateDriver=function(f,state,value)
 assert(not locked and f==native and state=='visibility' and value=='[combat] hide; nil')
 registrations=registrations+1
end
UnregisterStateDriver=function(f,state) assert(not locked and f==native);removals=removals+1 end
ObjectiveTrackerFrame=native
A.db={displayMode='blizzard',trackerHidden=false,trackerCollapsed=true}
A.sidebar=frame(true);A.sidebar.trackerBackground=frame(true);A.window=frame(false)
A:SyncCombatAutoHide();assert(registrations==1 and A.integration.autoHideNativeShown)
locked=true
-- Emulate the secure driver; ordinary addon code must never hide native in combat.
native.shown=false
native.Hide=function() error('insecure native Hide in combat') end
assert(A:SyncCombatAutoHide())
assert(not A.sidebar.shown and not A.sidebar.trackerBackground.shown and not A.window.shown)
assert(not A.db.trackerHidden and A.db.trackerCollapsed,'auto-hide rewrote user preferences')
A:SetJoinedCollapseVisual(false)
assert(not A.sidebar.shown and not A.sidebar.trackerBackground.shown,'main toggle resurrected auto-hidden view')
A.db.combatAutoHide=false
assert(A:SyncCombatAutoHide(),'setting changed native driver inside combat')
locked=false;A:SyncCombatAutoHide()
assert(native.shown and removals==1 and A.integration.restoreNativeLayout,'native view not restored')
assert(not A:SyncCombatAutoHide() and not A.integration.autoHideArmed)
-- A native tracker already hidden before combat must stay hidden afterward.
A.db.combatAutoHide=true;native.shown=false;A:SyncCombatAutoHide()
locked=true;A:SyncCombatAutoHide();locked=false;A:SyncCombatAutoHide()
assert(not native.shown,'auto-hide forced an originally hidden tracker open')
native.Update=function() error('recovery opened a previously hidden native tracker') end
native.IsCollapsed=function() return false end
A:RestoreNativeExpandedLayout(native)
-- Expanded layout repair runs once, out of combat, and preserves main collapse.
local contents=frame(false);local updates=0
local module={ContentsFrame=contents,IsCollapsed=function(self) return self.closed end,
 SetCollapsed=function(self,v) self.closed=v end,closed=true}
native.shown=true
native.modules={module};native.IsCollapsed=function(self) return self.closed end
native.Update=function() assert(not locked);updates=updates+1 end
A.integration.restoreNativeLayout=true;native.closed=true;A:RestoreNativeExpandedLayout(native)
assert(updates==0 and not contents.shown,'restoration expanded a user-collapsed tracker')
A.integration.restoreNativeLayout=true;native.closed=false
locked=true;A:RestoreNativeExpandedLayout(native);assert(updates==0 and A.integration.restoreNativeLayout)
locked=false;A:RestoreNativeExpandedLayout(native)
assert(updates==1 and contents.shown and not module.closed,'blank module contents were not restored')
A:RestoreNativeExpandedLayout(native);assert(updates==1,'normal update repeated every tick')
print('PASS: secure combat hide, setting opt-out/deferred changes, saved choices, hidden-native preservation and one-shot expanded-content restore')
