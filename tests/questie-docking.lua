unpack=unpack or table.unpack
local locked,now=false,100
GetTime=function() return now end
InCombatLockdown=function() return locked end
local nativeAccess,foreignWrites=0,0
local function widget(kind,foreign)
 local w={shown=true,width=420,height=500,scale=1,scroll=0,scripts={},kind=kind or 'Frame',foreign=not not foreign}
 local function write(self) if self.foreign then foreignWrites=foreignWrites+1;error('Questie frame mutated') end end
 function w:SetScript(k,v) write(self);self.scripts[k]=v end
 function w:HookScript(k,v) write(self);self.scripts[k]=v end
 function w:RegisterEvent() write(self) end
 function w:IsShown() return self.shown end
 function w:Show() write(self);self.shown=true end
 function w:Hide() write(self);self.shown=false end
 function w:SetShown(v) if v then self:Show() else self:Hide() end end
 function w:SetSize(x,y) write(self);self.width=x;self.height=y end
 function w:SetWidth(x) write(self);self.width=x end
 function w:SetHeight(x) write(self);self.height=x end
 function w:GetWidth() return self.width end
 function w:GetHeight() return self.height end
 function w:SetScale(x) write(self);self.scale=x end
 function w:GetEffectiveScale() return self.scale end
 function w:GetLeft() return self.left end
 function w:GetRight() return self.left and self.left+self.width end
 function w:GetTop() return self.top end
 function w:GetBottom() return self.top and self.top-self.height end
 function w:ClearAllPoints() write(self);self.point=nil end
 function w:SetPoint(...) write(self);self.point={...} end
 function w:SetVerticalScroll(x) write(self);self.scroll=x end
 function w:GetVerticalScroll() return self.scroll or 0 end
 function w:CreateTexture() write(self);return widget('Texture') end
 function w:CreateFontString() write(self);return widget('FontString') end
 function w:GetFrameLevel() return 1 end
 return setmetatable(w,{__index=function(_,name)
  if name:match('^Set') or name:match('^Enable') then return function(self) write(self) end end
  return function() end
 end})
end
CreateFrame=function(kind) return widget(kind) end
UIParent=widget();UIParent.width=1800;UIParent.height=1000
ObjectiveTrackerFrame=setmetatable({},{__index=function() nativeAccess=nativeAccess+1;error('native tracker accessed in Questie dock path') end})
local A={}
for _,name in ipairs({'Core.lua','QuestieCompatibility.lua','TrackerIntegration.lua','QuestieDock.lua','Settings.lua'}) do
 assert(loadfile(name))('SimplyPartyQuests',A)
end
A.db={displayMode='blizzard',sidebarWidth=420,trackerSide='left',combatAutoHide=true,trackerCollapsed=false}
A.window=widget();A.members={member={}}
function A:ShouldShowPartyView() return true end
function A:SyncSettings() end
function A:UpdateMinimapButton() end
function A:RestoreJoinedTrackerHeader() assert(not locked) end
function A:RestoreTrackerJoinVisuals() assert(not locked) end
function A:BuildTrackerEntries() return {{kind='member',title='Party'}},1 end
local renders=0
function A:RenderTrackerSidebar() renders=renders+1;self.sidebar.contentHeight=800;self:SizeTrackerSidebar() end
Questie={db={profile={trackerEnabled=true},char={isTrackerExpanded=true}}}
Questie_BaseFrame=widget('Frame',true);Questie_BaseFrame.left=850;Questie_BaseFrame.top=900;Questie_BaseFrame.width=300;Questie_BaseFrame.height=500
Questie_HeaderFrame=widget('Button',true);Questie_HeaderFrame.left=850;Questie_HeaderFrame.top=890;Questie_HeaderFrame.width=200;Questie_HeaderFrame.height=20
A:TrackerIntegrationTick()
local f=A.sidebar
assert(A:QuestieDockActive() and A:EffectiveDisplayMode()=='blizzard' and f:IsShown() and not A.window:IsShown(),tostring(A.integration.lastError))
assert(f.point[2]==UIParent and f.point[3]=='BOTTOMLEFT' and f.point[4]==422 and f.point[5]==896,'dock did not use independent numeric geometry')
assert(f.heightLimit==500 and f.height<=500 and f.maxScroll>0 and renders==1)
assert(not A:NativeTrackerWritesAllowed() and not A:NativeCombatControlsAllowed())
A.db.trackerSide='right';Questie_BaseFrame.left=800;Questie_HeaderFrame.left=800
A:TrackerIntegrationTick();assert(f.point[4]==1108,'right-side follow failed')
Questie_BaseFrame.scale=0.8;Questie_HeaderFrame.scale=0.8
A:TrackerIntegrationTick();assert(f.point[4]==888 and f.heightLimit==400,'mixed UI scales were ignored')
-- At the right screen edge, prefer the side with room without changing settings.
Questie_BaseFrame.scale=1;Questie_HeaderFrame.scale=1;Questie_BaseFrame.left=1450;Questie_HeaderFrame.left=1450
A:TrackerIntegrationTick();assert(A.questieCompatibility.dockRect.side=='left' and A.db.trackerSide=='right')
locked=true;A:TrackerIntegrationTick()
assert(f.viewCollapsed and f:IsShown() and not f.scroll:IsShown(),'combat did not collapse only our dock')
A:SetViewCollapsed(false);A:TrackerIntegrationTick()
assert(not f.viewCollapsed and f.scroll:IsShown() and not A.db.trackerCollapsed,'manual combat reopen changed outside-combat preference')
Questie_BaseFrame.left=1400;Questie_HeaderFrame.left=1400
A:TrackerIntegrationTick();assert(f.point[4]==972,'already-independent dock stopped following during combat')
A:TogglePartyTracker();assert(not f:IsShown() and A.db.trackerHidden)
A:TogglePartyTracker();assert(f:IsShown() and not A.db.trackerHidden)
locked=false;A:TrackerIntegrationTick();assert(not f.viewCollapsed)
-- Minimizing Questie keeps our pane independently usable at the header.
Questie_BaseFrame.height=30
A:TrackerIntegrationTick();assert(f.heightLimit>=128 and not f.viewCollapsed)
-- Explicit separate-window mode remains available and clears old dock art.
A.db.displayMode='window';A:TrackerIntegrationTick()
assert(A:EffectiveDisplayMode()=='window' and A.window:IsShown() and not f:IsShown() and not f.trackerBackground:IsShown())
-- Hidden/missing/oversized trackers fall back without touching either tracker.
A.db.displayMode='blizzard';Questie_BaseFrame.shown=false;A:TrackerIntegrationTick()
assert(A:EffectiveDisplayMode()=='window' and A.window:IsShown())
Questie_BaseFrame.shown=true;Questie_BaseFrame.left=100;Questie_BaseFrame.width=1600
A:TrackerIntegrationTick();assert(not A:QuestieDockActive() and A.window:IsShown())
Questie_BaseFrame=nil;A:TrackerIntegrationTick();assert(A.window:IsShown())
-- Opting out of automatic collapse must preserve a manually closed pane.
Questie_BaseFrame=widget('Frame',true);Questie_BaseFrame.left=850;Questie_BaseFrame.top=900;Questie_BaseFrame.width=300
A.db.combatAutoHide=false;A.db.trackerCollapsed=true
A:TrackerIntegrationTick();assert(f.viewCollapsed)
locked=true;A:TrackerIntegrationTick();assert(f.viewCollapsed,'combat reopened a manually closed pane with auto-collapse disabled')
A:SetViewCollapsed(false);assert(not f.viewCollapsed and A.db.trackerCollapsed)
locked=false;A:TrackerIntegrationTick();assert(f.viewCollapsed,'combat exit lost the saved collapsed preference')
assert(nativeAccess==0 and foreignWrites==0,'docking wrote to Questie or accessed Blizzard frames')
assert(Questie.db.profile.trackerEnabled and Questie.db.char.isTrackerExpanded)
print('PASS: Questie independent docking, left/right/edge/scale/resize geometry, scroll cap, combat follow/collapse/reopen, hide/show, minimized/missing/hidden targets and standalone fallback without native/Questie writes')
