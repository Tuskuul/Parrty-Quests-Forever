local locked=false
InCombatLockdown=function() return locked end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
assert(loadfile('Settings.lua'))('SimplyPartyQuests',A)
A.db={displayMode='blizzard'}
function A:InvalidateTrackerIntegration() end
local inside,calls,dirty=false,0,0
local target={closed=false,Header={IsShown=function() return true end},IsShown=function() return true end}
function target:IsCollapsed() return self.closed end
function target:SetCollapsed(value)
 assert(inside,'native collapse ran directly from addon execution')
 self.closed=value;calls=calls+1
end
function target:MarkDirty() assert(inside);dirty=dirty+1 end
securecallfunction=function(fn,...)
 inside=true
 local ok,err=pcall(fn,...)
 inside=false
 if not ok then error(err) end
end
local trusted=true
issecurevariable=function(object,name) assert(object==target);return trusted end
ObjectiveTrackerFrame=target
A:SetViewCollapsed(true);assert(target.closed and calls==1)
A:SetViewCollapsed(false);assert(not target.closed and calls==2)
assert(A:CallNativeTrackerMethod(target,'MarkDirty') and dirty==1)
trusted=false
local ok,err=A:CallNativeTrackerMethod(target,'SetCollapsed',true)
assert(not ok and err:find('tainted',1,true) and calls==2)
trusted=true;locked=true
assert(not A:CallNativeTrackerMethod(target,'SetCollapsed',true) and calls==2)
locked=false
local barrier=securecallfunction;securecallfunction=nil
assert(not A:CallNativeTrackerMethod(target,'SetCollapsed',true) and calls==2,'missing barrier used a direct fallback')
securecallfunction=barrier
function target:Update() error('full native layout rebuilt during sidebar reconciliation') end
local module={IsCollapsed=function() return true end,
 SetCollapsed=function() error('module collapse rewritten during reconciliation') end,
 ContentsFrame={Show=function() error('native contents forced visible') end}}
target.modules={module}
A.integration.blockedRestore=true
A:ApplyPendingTrackerRestore()
assert(not A.integration.blockedRestore and calls==2)
print('PASS: native execution boundary, replaced-method/combat/missing-API rejection, and no full native/module rebuild during reconciliation (mocked; live taint validation required)')
