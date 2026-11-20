securecallfunction=function(fn,...) return fn(...) end
unpack=unpack or table.unpack
local locked=false
local restricted=false
local snippet
GetTime=function() return 100 end
InCombatLockdown=function() return locked end
local function frame(shown)
 local f={shown=shown~=false,attrs={},refs={},scripts={},wrapped={}}
 function f:IsProtected() return not not self.protected,not not self.explicit end
 function f:HookScript(k,fn)
  local old=self.scripts[k]
  self.scripts[k]=old and function(...) old(...);fn(...) end or fn
 end
 local function event(name)
  local w=f.wrapped[name]
  if w then snippet(w.body,f,nil,w.controller) end
  if f.scripts[name] then
   local before=restricted;restricted=false;f.scripts[name](f);restricted=before
  end
 end
 function f:IsShown() return self.shown end
 function f:SetShown(v) if v then self:Show() else self:Hide() end end
 function f:Show() assert(not restricted or self.protected,'invalid unprotected frame handle');assert(not locked or not self.protected or restricted,debug.traceback('protected frame shown from addon Lua'));local changed=not self.shown;self.shown=true;if changed then event('OnShow') end end
 function f:Hide() assert(not restricted or self.protected,'invalid unprotected frame handle');assert(not locked or not self.protected or restricted,'protected frame hidden from addon Lua');local changed=self.shown;self.shown=false;if changed then event('OnHide') end end
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
 f.protected=template and template:find('SecureHandler',1,true)~=nil;f.explicit=f.protected
 return f
end
snippet=function(body,self,newstate,control)
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
local module=frame(true);module.hasContents=true;module.protected=true;module.explicit=true
local empty=frame(false);empty.hasContents=false;empty.protected=true
local ordinary=frame(true);ordinary.hasContents=true
local native=frame(true);native.modules={module,empty,ordinary};native.closed=false
native.Header={MinimizeButton=frame(),SetCollapsed=function(self,v) self.closed=v end}
native.IsCollapsed=function(self) return self.closed end
native.SetCollapsed=function(self,v)
 assert(not locked,'native full collapse attempted in combat');self.closed=v
 self:Update()
end
native.Update=function()
 assert(not locked,'native layout update attempted in combat')
 for _,m in ipairs(native.modules) do m:SetShown(not native.closed and m.hasContents) end
end
ObjectiveTrackerFrame=native
A.db={displayMode='blizzard',trackerHidden=false,trackerCollapsed=false}
A.sidebar=frame(true);A.sidebar.trackerBackground=frame(true);A.window=frame(false)
A.partyTrackerButton=frame();A.partyTrackerButton.protected=true;A.partyTrackerButton.explicit=true
function A:RefreshCombatTrackerPane()
 if self:SyncCombatAutoHide() then return end
 self.sidebar:Show();self.sidebar.trackerBackground:Show()
end
function A:ShouldShowPartyView() return true end
A:SyncCombatAutoHide()
assert(next(A.integration.combatGuards)==nil,'native module was protected by an addon-owned secure child')
local c=A.integration.combatController
assert(c and module.wrapped.OnShow and A.partyTrackerButton.wrapped.OnClick,'secure setup incomplete')
local main=A.integration.combatMainButton
assert(main and main.wrapped.OnClick and main.anchor==native.Header.MinimizeButton,'native +/- has no dedicated secure click surface')
assert(main.shown and not native.Header.MinimizeButton.wrapped.OnClick,'prepared collapse control must cover the native button while enabled')
local function state(v)
 c:SetAttribute('state-combat',v);snippet(c:GetAttribute('_onstate-combat'),c,v)
end
local function click(f)
 if f==native.Header.MinimizeButton then f=main end
 local w=f.wrapped.OnClick;local result=snippet(w.body,f,nil,w.controller)
 if result~=false and f.scripts.OnClick then f.scripts.OnClick(f) end
 return result
end

local function enter() locked=true;state(1);A:SyncCombatAutoHide() end
local function leave(eventFirst)
 locked=false
 if eventFirst then A.integrationEvents.scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED') end
 state(0);A:SyncCombatAutoHide()
end
-- The exit event must never recapture the hidden state ahead of the driver.
for i=1,50 do
 enter();assert(not module.shown and not ordinary.shown)
 leave(i%2==0)
 assert(module.shown and ordinary.shown,'exit ordering lost visible contents')
 assert(A.integration.dirty and A.integration.due<=GetTime(),'post-combat sidebar redraw still debounced')
 assert(not A.integration.combatRestorePending and not A.integration.combatCycleActive,'exit state remained pending')
end
-- The driver can fire before lockdown clears: defer protected ordinary writes.
enter();state(0)
assert(A.integration.combatRestorePending,'early secure exit was not deferred')
locked=false;A:SyncCombatAutoHide()
assert(module.shown and ordinary.shown and not A.integration.combatRestorePending,'deferred exit did not restore')
-- A new combat can start before a deferred exit finishes.
enter();state(0);assert(A.integration.combatRestorePending)
state(1);A:SyncCombatAutoHide();leave(true)
assert(module.shown and ordinary.shown and not A.integration.combatRestorePending,'rapid re-entry lost pending restore')
-- New contents must not inherit the old empty-module visibility snapshot.
enter();empty.hasContents=true;leave(true)
assert(empty.shown,'newly populated module stayed hidden')
-- Current empty modules must stay hidden, including protected modules.
enter();module.hasContents=false;ordinary.hasContents=false;leave(false)
assert(not module.shown and not ordinary.shown,'empty module was resurrected')
module.hasContents=true;ordinary.hasContents=true;native:Update();A:SyncCombatAutoHide()
-- Preserve a native hide during the cycle; our own hide must not count as one.
enter();click(main);assert(module.shown and ordinary.shown)
snippet('self:Hide()',module);ordinary:Hide()
leave(true)
assert(not module.shown and not ordinary.shown,'native hide during combat was undone')
-- A later native show supersedes its earlier hide.
native:Update();A:SyncCombatAutoHide();enter();click(main)
snippet('self:Hide(); self:Show()',module);ordinary:Hide();ordinary:Show()
leave(false)
assert(module.shown and ordinary.shown,'later native visibility was discarded')
-- Preserve the saved collapse through either exit ordering.
A:SetPreparedTrackerCollapsed(true);A:SyncCombatAutoHide()
for i=1,20 do enter();leave(i%2==0);assert(not module.shown and not ordinary.shown and A:IsNativeTrackerCollapsed(native)) end
print('PASS: 50 alternating exit orders, early secure exit, new/empty contents, native hide/show intent and 20 preclosed cycles')
