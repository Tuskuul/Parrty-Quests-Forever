unpack=unpack or table.unpack
local locked=false
GetTime=function() return 100 end
InCombatLockdown=function() return locked end
local function frame(shown)
 local f={shown=shown~=false,attrs={},refs={},scripts={},wrapped={}}
 function f:IsShown() return self.shown end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false end
 function f:SetAttribute(k,v) self.attrs[k]=v end
 function f:GetAttribute(k) return self.attrs[k] end
 function f:SetFrameRef(k,v) self.refs[k]=v end
 function f:GetFrameRef(k) return self.refs[k] end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:RegisterEvent() end
 function f:CallMethod(k,...) return self[k](self,...) end
 return f
end
CreateFrame=function() return frame() end
local function snippet(body,self,newstate,control)
 return assert(load('return function(self,newstate,control) '..body..' end'))()(self,newstate,control)
end
RegisterStateDriver=function(f,state,value)
 assert(not locked and state=='combat' and value=='[combat] 1; 0')
 f:SetAttribute('state-combat',0)
 snippet(f:GetAttribute('_onstate-combat'),f,0)
end
SecureHandlerWrapScript=function(f,event,c,body) assert(not locked);f.wrapped[event]={controller=c,body=body} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local module=frame(true);module.hasContents=true
local native=frame(true);native.modules={module};native.closed=false
native.Header={MinimizeButton=frame(),SetCollapsed=function(self,v) self.closed=v end}
native.IsCollapsed=function(self) return self.closed end
native.SetCollapsed=function(self,v) assert(not locked,'native full collapse attempted in combat');self.closed=v end
ObjectiveTrackerFrame=native
A.db={displayMode='blizzard',trackerHidden=false,trackerCollapsed=false}
A.sidebar=frame(true);A.sidebar.trackerBackground=frame(true);A.window=frame(false)
A.partyTrackerButton=frame()
function A:RefreshCombatTrackerPane()
 if self:SyncCombatAutoHide() then return end
 self.sidebar:Show();self.sidebar.trackerBackground:Show()
end
function A:ShouldShowPartyView() return true end
A:SyncCombatAutoHide()
local c=A.integration.combatController
assert(c and module.wrapped.OnShow and A.partyTrackerButton.wrapped.OnClick,'secure setup incomplete')
local function state(v)
 c:SetAttribute('state-combat',v);snippet(c:GetAttribute('_onstate-combat'),c,v)
end
local function click(f)
 local w=f.wrapped.OnClick;return snippet(w.body,f,nil,w.controller)
end
locked=true;state(1);A:SyncCombatAutoHide()
assert(native.shown and not module.shown and native.Header.closed,'whole native tracker failed to collapse to header')
assert(not A.sidebar.shown and not A.sidebar.trackerBackground.shown)
assert(not native.closed and not A.db.trackerHidden,'visual collapse altered native/saved state')
assert(click(A.partyTrackerButton)==false,'collapsed Party Quests click was not handled')
assert(not module.shown and not A.sidebar.shown and A.integration.expandAfterCombat,'combat click must queue expansion without reopening frames')
assert(click(native.Header.MinimizeButton)==false and not module.shown,'main expansion did not remain safely queued')
-- A native redraw trying to show its module must respect the secure collapsed state.
module.shown=true
snippet(module.wrapped.OnShow.body,module,nil,c)
assert(not module.shown,'native redraw resurrected combat-collapsed module')
locked=false;state(0);A:SyncCombatAutoHide()
assert(native.shown and module.shown and not native.Header.closed and A.integration.restoreNativeLayout)
A.db.trackerHidden=true;native.closed=true
A:ApplyPendingTrackerRestore()
assert(not A.integration.expandAfterCombat and not native.closed and not A.db.trackerHidden,'queued post-combat docked expansion failed')
-- Outside combat the party launcher must expand an actually collapsed native view.
native.closed=true;A.db.trackerHidden=true
function A:SetViewShown(v) self.db.trackerHidden=not v end
local ticks=0;function A:TrackerIntegrationTick() ticks=ticks+1 end
A:TogglePartyTracker()
assert(not native.closed and not A.db.trackerHidden and ticks==1,'out-of-combat party launcher did not expand whole tracker')
-- Preserve a preexisting native collapse after the automatic visual cycle.
native.closed=true;module.shown=false;A:SyncCombatAutoHide()
locked=true;state(1);locked=false;state(0);A:SyncCombatAutoHide()
assert(native.closed and not module.shown,'automatic cycle expanded a previously collapsed native view')
A.db.combatAutoHide=false;A:SyncCombatAutoHide();locked=true;state(1)
assert(not c:GetAttribute('combat-collapsed'),'explicit option off was ignored')
print('PASS: secure whole-tracker combat collapse, Party Quests/main expansion, native redraw suppression, out-of-combat expansion and saved state/opt-out')
