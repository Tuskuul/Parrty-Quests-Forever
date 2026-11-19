securecallfunction=function(fn,...) return fn(...) end
unpack=unpack or table.unpack
GetTime=function() return 100 end
local locked=false
InCombatLockdown=function() return locked end
local function widget(fields)
 local w=fields or {};w.hooks={};w.shown=true
 function w:IsShown() return self.shown end
 function w:Show() local was=self.shown;self.shown=true;if not was and self.hooks.OnShow then self.hooks.OnShow(self) end end
 function w:Hide() self.shown=false end
 function w:SetShown(v) if v then self:Show() else self:Hide() end end
 function w:HookScript(name,fn) self.hooks[name]=fn end
 function w:GetEffectiveScale() return self.scale or 0.8 end
 function w:GetFrameLevel() return 5 end
 function w:GetFrameStrata() return self.strata or "LOW" end
 function w:SetFrameStrata(v) self.strata=v end
 function w:GetLeft() return self.left end
 function w:GetRight() return self.right end
 function w:GetTop() return self.top end
 function w:GetBottom() return self.bottom end
 function w:GetWidth() return self.width end
 function w:GetHeight() return self.height end
 function w:ClearAllPoints() self.anchors=(self.anchors or 0)+1 end
 function w:SetPoint(...) self.point={...} end
 function w:SetWidth(v) self.width=v end
 function w:SetHeight(v) self.height=v end
 function w:SetScale(v) self.scale=v end
 function w:SetFrameLevel(v) self.level=v end
 function w:RegisterEvent() end
 function w:SetScript() end
 return w
end
CreateFrame=function() return widget() end;UIParent=widget()
hooksecurefunc=function(frame,name,fn)
 local original=frame[name];frame[name]=function(self,...) original(self,...);fn(self,...) end
end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
A.db={displayMode='blizzard',combatAutoHide=false};function A:ShouldShowPartyView() return true end
local background=widget();local native=widget({left=980,right=1600,top=2000,bottom=500,scale=0.4})
local button=widget();local module={Header={MinimizeButton=button},collapsed=true}
function module:IsCollapsed() return self.collapsed end
function module:SetCollapsed(v) self.collapsed=v end
local tracker=widget({NineSlice=native,modules={module}})
function tracker:IsCollapsed() return self.collapsed end
function tracker:SetCollapsed(v) self.collapsed=v end
local f=widget({width=420,height=850,left=100,top=1000,trackerBackground=background})
A.sidebar=f
A:SyncTrackerBackgroundJoin(tracker,true)
assert(not native:IsShown() and not button:IsShown() and not module.collapsed,'native visuals or stale module collapse were retained')
assert(background:IsShown() and background.width==700 and background.height==850,'combined scaled bounds must include both columns')
assert(background.point[4]==0 and background.point[5]==0,'combined anchor is wrong')
local anchors=background.anchors;A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.anchors==anchors,'unchanged geometry was reanchored')
native:Show();button:Show()
assert(not native:IsShown() and not button:IsShown(),'native redraw resurrected duplicate art/buttons')
tracker:SetCollapsed(true)
assert(not f:IsShown() and background.height==26 and not background:IsShown(),'main collapse left party contents or a tall background')
tracker:SetCollapsed(false)
assert(f:IsShown() and background:IsShown() and background.height==850,'main expand failed to restore party contents')
locked=true;local before=background.anchors;A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.anchors==before,'combat touched geometry')
tracker:SetCollapsed(true);assert(not f:IsShown() and background.height==26 and not background:IsShown(),'combat main collapse did not hide party immediately')
tracker:SetCollapsed(false);locked=false
A.db.trackerHidden=true;f:Hide();A:SyncTrackerBackgroundJoin(tracker,true)
assert(not native:IsShown() and not button:IsShown(),'party toggle brought back the redundant Quests collapse button')
assert(background:IsShown() and background.width==310 and background.height==750,'native-only background retained the hidden party column')
assert(background.strata=='LOW','shared backdrop must stay behind LOW-strata Blizzard text')
tracker:SetCollapsed(true)
assert(background.height==26 and not background:IsShown() and not f:IsShown(),'native-only main collapse left a tall empty background')
A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.height==26 and not background:IsShown() and background.width==310,'native-only collapsed tick restored a tall backdrop')
tracker:SetCollapsed(false)
assert(background:IsShown() and background.height==750 and not f:IsShown(),'native-only expand changed party visibility')
button:Show();assert(not button:IsShown(),'native-only redraw resurrected the secondary collapse button')
A.db.trackerHidden=false;A:SyncTrackerBackgroundJoin(tracker,true)
tracker:SetCollapsed(true)
A.db.trackerHidden=true;A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.width==310 and background.height==26 and not background:IsShown(),'hiding party while collapsed changed main collapse')
A.db.trackerHidden=false;A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.width==700 and background.height==26 and not background:IsShown() and not f:IsShown(),'opening party while collapsed expanded its content')
tracker:SetCollapsed(false);assert(f:IsShown(),'main expand after toggles failed to restore party')
-- Enumerators can supply modules before they appear in the container array.
local lateButton=widget();local lateModule={Header={MinimizeButton=lateButton}}
function tracker:ForEachModule(callback) callback(module);callback(lateModule) end
A:SyncTrackerBackgroundJoin(tracker,true);assert(not lateButton:IsShown(),'late module retained a second collapse button')
A:SyncTrackerBackgroundJoin(tracker,false)
assert(native:IsShown() and button:IsShown() and lateButton:IsShown() and background.width==420 and background.height==850,'party-only fallback failed')
-- Right-side party pane and a taller native pane share one rectangle too.
native.left=-500;native.right=220;native.top=2000;native.bottom=0
A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.width==770 and background.height==1000 and background.point[4]==-350,'right-side union is wrong')
local validLeft=native.left;native.left=nil
A:SyncTrackerBackgroundJoin(tracker,true)
assert(native:IsShown() and button:IsShown() and not background:IsShown(),'invalid geometry suppressed native art')
native.left=validLeft;A:SyncTrackerBackgroundJoin(tracker,true)
A.db.displayMode='window';A:SyncTrackerBackgroundJoin(tracker,true)
assert(native:IsShown() and button:IsShown() and not background:IsShown(),'detaching left native art suppressed')
-- Panel visibility must come from its preference, even while collapsed.
A.db.displayMode='blizzard';A.db.trackerHidden=false;f:Hide()
function A:SetViewShown(shown) self.db.trackerHidden=not shown end
function A:TrackerIntegrationTick() end
A:TogglePartyTracker();assert(A.db.trackerHidden,'collapsed panel toggle reopened an already-enabled panel')
A:TogglePartyTracker();assert(not A.db.trackerHidden,'second toggle failed to enable panel')
-- Quest Timers has its own backdrop above All Objectives. The shared canvas
-- must not stretch upward across that reserved area, at either pane visibility.
A.db.displayMode='blizzard';A.db.trackerHidden=false;A.db.trackerSide='left'
f.left=100;f.top=1000;f.width=420;f.height=850
native.left=980;native.right=1600;native.top=2200;native.bottom=500;native.scale=0.4
tracker.Header=widget({top=2000,scale=0.4});tracker.collapsed=false
QuestTimerFrame={IsVisible=function() return true end}
A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.point[5]==0 and background.height==850,'timer padding stretched joined background upward')
A.db.trackerHidden=true;A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.point[5]==0,'native-only background still covered timer area')
A.db.trackerHidden=false
locked=true;A:ResizeCombatTrackerBackground()
assert(background.point[5]==0,'combat measurement restored timer overlap')
locked=false;QuestTimerFrame.IsVisible=function() return false end
A:SyncTrackerBackgroundJoin(tracker,true)
assert(background.point[5]==100 and background.height==950,'normal native bounds not restored when timer disappeared')
QuestTimerFrame=nil
print('PASS: header-only collapsed art, native-only and joined collapse, no duplicate module button, background behind native text, one union backdrop, alpha-safe suppression, redraw hooks, one main collapse including combat, visibility toggles, scale/both sides, standalone and native restoration')


assert(loadfile('QuestieCompatibility.lua'))('SimplyPartyQuests',A)
Questie={db={profile={trackerEnabled=false}}}
ObjectiveTrackerFrame=tracker
locked=false
tracker:SetCollapsed(true)
A:SyncTrackerBackgroundJoin(tracker,true)
for i=1,3 do A:ReleaseNativeCombatControl() end
assert(A.integration.nativeCollapsed==true and not A.questieCompatibility.cleanupError)
locked=true
A:ResizeCombatTrackerBackground()
assert(tracker:IsCollapsed() and not background:IsShown(),'maps-only combat refresh resurrected collapsed backdrop')
-- Missing/stale cached state cannot resurrect a natively collapsed tracker.
A.integration.nativeCollapsed=nil
A:ResizeCombatTrackerBackground()
assert(not background:IsShown())
locked=false;tracker:SetCollapsed(false)
A:SyncTrackerBackgroundJoin(tracker,true);A:ReleaseNativeCombatControl()
locked=true;A:ResizeCombatTrackerBackground()
assert(background:IsShown(),'maps-only expanded tracker lost its backdrop')
print('PASS: Questie maps-only repeated cleanup preserves collapse and combat background follows live native collapse')
