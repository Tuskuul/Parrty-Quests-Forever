unpack=unpack or table.unpack
local locked=false
local restricted=false
GetTime=function() return 100 end
InCombatLockdown=function() return locked end
local function frame(shown)
 local f={shown=shown~=false,attrs={},refs={},scripts={},wrapped={}}
 function f:IsShown() return self.shown end
 function f:Show() assert(not locked or not self.protected or restricted,'protected frame shown from addon Lua');self.shown=true end
 function f:Hide() assert(not locked or not self.protected or restricted,'protected frame hidden from addon Lua');self.shown=false end
 function f:SetAttribute(k,v) self.attrs[k]=v end
 function f:GetAttribute(k) return self.attrs[k] end
 function f:SetFrameRef(k,v) self.refs[k]=v end
 function f:GetFrameRef(k) return self.refs[k] end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:RegisterEvent() end
 function f:RegisterForClicks() end
 function f:SetParent(v) self.parent=v end
 function f:ClearAllPoints() end
 function f:SetAllPoints(v) self.anchor=v end
 function f:GetFrameLevel() return 1 end
 function f:SetFrameLevel(v) self.level=v end
 function f:CallMethod(k,...)
  local before=restricted;restricted=false
  local result=self[k](self,...);restricted=before;return result
 end
 return f
end
CreateFrame=function(_,_,parent,template)
 local f=frame();f.parent=parent
 f.protected=template and template:find('SecureHandler',1,true)~=nil
 return f
end
local function snippet(body,self,newstate,control)
 local before=restricted;restricted=true
 local result=assert(load('return function(self,newstate,control) '..body..' end'))()(self,newstate,control)
 restricted=before;return result
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
local module=frame(true);module.hasContents=true;module.protected=true
local empty=frame(false);empty.hasContents=false;empty.protected=true
local native=frame(true);native.modules={module,empty};native.closed=false
native.Header={MinimizeButton=frame(),SetCollapsed=function(self,v) self.closed=v end}
native.IsCollapsed=function(self) return self.closed end
native.SetCollapsed=function(self,v) assert(not locked,'native full collapse attempted in combat');self.closed=v end
native.Update=function() assert(not locked,'native layout update attempted in combat') end
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
local main=A.integration.combatMainButton
assert(main and main.wrapped.OnClick and main.anchor==native.Header.MinimizeButton,'native +/- has no dedicated secure click surface')
assert(not main.shown and not native.Header.MinimizeButton.wrapped.OnClick,'outside-combat native button should remain untouched')
local function state(v)
 c:SetAttribute('state-combat',v);snippet(c:GetAttribute('_onstate-combat'),c,v)
end
local function click(f)
 if f==native.Header.MinimizeButton then f=main end
 local w=f.wrapped.OnClick;return snippet(w.body,f,nil,w.controller)
end
locked=true;state(1);A:SyncCombatAutoHide()
assert(main.shown,'combat main control was not activated')
-- Native handler replacement must not remove the independent combat control.
native.Header.MinimizeButton:SetScript('OnClick',function() error('native handler ran in combat') end)
assert(native.shown and not module.shown and native.Header.closed,'whole native tracker failed to collapse to header')
assert(not A.sidebar.shown and not A.sidebar.trackerBackground.shown)
assert(not native.closed and not A.db.trackerHidden,'visual collapse altered native/saved state')
assert(click(A.partyTrackerButton)==false,'collapsed Party Quests click was not handled')
assert(module.shown and A.sidebar.shown and not native.Header.closed,'secure combat reopening failed')
assert(not empty.shown and not A.integration.expandAfterCombat,'combat reopening showed empty module or queued instead')
assert(not A:SyncCombatAutoHide() and A.sidebar.shown,'combat polling re-collapsed manually opened tracker')
assert(click(A.partyTrackerButton)==nil,'expanded party button should retain normal pane toggle')
assert(click(native.Header.MinimizeButton)==false and not module.shown,'main combat collapse failed')
-- A native redraw trying to show its module must respect the secure collapsed state.
module.shown=true
snippet(module.wrapped.OnShow.body,module,nil,c)
assert(not module.shown,'native redraw resurrected combat-collapsed module')
assert(click(native.Header.MinimizeButton)==false and module.shown and not native.Header.closed,'main secure combat expansion failed')
-- A native hide while manually open uses the restricted restoration path.
module.shown=false;snippet(module.wrapped.OnHide.body,module,nil,c)
assert(module.shown,'secure manual-open state did not survive native hide')
-- Only the Party Quests launcher changes the saved party-pane visibility.
assert(click(native.Header.MinimizeButton)==false and not module.shown)
A.db.trackerHidden=true
assert(click(native.Header.MinimizeButton)==false and module.shown and A.db.trackerHidden,'main button changed saved party visibility')
click(native.Header.MinimizeButton)
assert(click(A.partyTrackerButton)==false and not A.db.trackerHidden and module.shown,'party launcher did not enable hidden party pane')
-- Ordinary calls without the secure click remain queued as a fallback.
click(native.Header.MinimizeButton)
A:TogglePartyTracker()
assert(A.integration.expandAfterCombat and not module.shown,'unsecured expansion did not use fallback queue')
locked=false;state(0);A:SyncCombatAutoHide()
assert(not main.shown,'combat overlay obscures native button outside combat')
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
assert(not main.shown,'option off still intercepts native button clicks')
print('PASS: restricted combat reopen/collapse, no protected addon-Lua writes or native rebuild, no empty modules, redraw/manual-open persistence, queued fallback and saved state/opt-out')

