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
  Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
end
local native=frame(true);native.closed=false
native.Hide=function() error('automatic collapse must not hide Blizzard header') end
native.IsCollapsed=function(self) return self.closed end
native.SetCollapsed=function(self,value) self.closed=value;A:SetJoinedCollapseVisual(value) end
ObjectiveTrackerFrame=native
A.db={displayMode='blizzard',trackerHidden=false,trackerCollapsed=false}
A.sidebar=frame(true);A.sidebar.trackerBackground=frame(true);A.window=frame(false)
A:SyncCombatAutoHide();locked=true
assert(A:SyncCombatAutoHide())
assert(native.shown and native.closed and not A.sidebar.shown and not A.sidebar.trackerBackground.shown,'combat must leave compact native header')
assert(not A.db.trackerHidden and not A.db.trackerCollapsed,'automatic collapse changed preferences')
locked=false;A:SyncCombatAutoHide()
assert(native.shown and not native.closed and A.integration.restoreNativeLayout,'previous expanded state not restored')
-- An already collapsed view must remain collapsed after combat.
native.closed=true;A:SyncCombatAutoHide();locked=true;A:SyncCombatAutoHide();locked=false;A:SyncCombatAutoHide()
assert(native.closed,'combat exit expanded a previously collapsed tracker')
-- Explicit setting off stays off; a change in combat applies after exit.
A.db.combatAutoHide=false;A:SyncCombatAutoHide();native.closed=false
locked=true;assert(not A:SyncCombatAutoHide() and not native.closed)
locked=false;A.db.combatAutoHide=true;A:SyncCombatAutoHide();locked=true;A:SyncCombatAutoHide()
A.db.combatAutoHide=false;assert(A:SyncCombatAutoHide() and native.closed)
locked=false;A:SyncCombatAutoHide();assert(not native.closed and not A.integration.autoHideArmed)
-- A previously hidden native frame is not forced open or collapsed.
A.db.combatAutoHide=true;native.shown=false;native.closed=false;A:SyncCombatAutoHide()
locked=true;A:SyncCombatAutoHide();locked=false;A:SyncCombatAutoHide()
assert(not native.shown and not native.closed)
-- Separate-window mode preserves its visible title and saved collapse choice.
A.db.displayMode='window';A.db.collapsed=false;A.window.shown=true
function A:SetCollapsed(v) self.windowCollapsed=v;self.db.collapsed=v end
locked=true;A:SyncCombatAutoHide()
assert(A.window.shown and A.windowCollapsed and not A.db.collapsed,'popout title disappeared or saved choice overwritten')
locked=false;A:SyncCombatAutoHide();assert(not A.windowCollapsed)
A.db.displayMode='blizzard'
-- Expanded native layout restoration is one-shot and out of combat only.
local contents=frame(false);local updates=0
local module={ContentsFrame=contents,IsCollapsed=function(self) return self.closed end,
 SetCollapsed=function(self,v) self.closed=v end,closed=true}
native.shown=true;native.modules={module};native.Update=function() assert(not locked);updates=updates+1 end
A.integration.restoreNativeLayout=true;native.closed=true;A:RestoreNativeExpandedLayout(native)
assert(updates==0 and not contents.shown)
A.integration.restoreNativeLayout=true;native.closed=false;locked=true;A:RestoreNativeExpandedLayout(native)
assert(updates==0 and A.integration.restoreNativeLayout)
locked=false;A:RestoreNativeExpandedLayout(native)
assert(updates==1 and contents.shown and not module.closed)
A:RestoreNativeExpandedLayout(native);assert(updates==1)
print('PASS: combat compact header, expanded/collapsed restoration, opt-out, deferred setting changes, hidden tracker, popout title and one-shot native restore')
