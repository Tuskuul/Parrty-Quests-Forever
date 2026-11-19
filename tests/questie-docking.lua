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
 function w:SetAlpha(v) write(self);self.alpha=v end
 function w:GetAlpha() return self.alpha or 1 end
 function w:GetEffectiveAlpha() return self.alpha or 1 end
 function w:SetBackdropColor(...) write(self);self.backdropColor={...} end
 function w:GetBackdropColor() if self.backdropColor then return table.unpack(self.backdropColor) end end
 function w:SetBackdropBorderColor(...) write(self);self.borderColor={...} end
 function w:GetBackdropBorderColor() if self.borderColor then return table.unpack(self.borderColor) end end
 function w:GetScript(k) return self.scripts[k] end
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
 function w:GetFont() return table.unpack(self.font or {'NativeFont',13,''}) end
 function w:SetFont(...) write(self);self.font={...} end
 function w:SetText(t) write(self);self.text=t end
 function w:GetFrameLevel() return 1 end
 return setmetatable(w,{__index=function(_,name)
  if not name:match('^[A-Z]') then return nil end
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
Questie_HeaderFrame.trackedQuests={label=widget('FontString',true)}
Questie_HeaderFrame.trackedQuests.label.font={'QuestieFont',14,'OUTLINE'}
A:TrackerIntegrationTick()
local f=A.sidebar
assert(A:QuestieDockActive() and A:EffectiveDisplayMode()=='blizzard' and f:IsShown() and not A.window:IsShown(),tostring(A.integration.lastError))
assert(f.point[2]==UIParent and f.point[3]=='BOTTOMLEFT' and f.point[4]==428 and f.point[5]==896,'dock did not use independent numeric geometry')
assert(f.heightLimit==496 and f.height<=496 and f.maxScroll>0 and renders==1)
assert(not A:NativeTrackerWritesAllowed() and not A:NativeCombatControlsAllowed())
assert(f.title.font[1]=='QuestieFont' and f.title.font[2]==14,'header font did not follow Questie')
assert(not f.headerArt:IsShown() and not f.share:IsShown() and not f.refresh:IsShown() and f.settings.caption.text=='...','Questie dock retained the heavy toolbar')
local p=Questie.db.profile
p.trackerBackdropEnabled=false;p.trackerBorderEnabled=false
A:TrackerIntegrationTick()
assert(f.trackerBackground.questieArt.backdropColor[4]==0 and f.trackerBackground.questieArt.borderColor[4]==0,'disabled Questie background left an opaque party box')
p.trackerBackdropEnabled=true;p.trackerBorderEnabled=true;p.trackerBackdropColor={r=0.2,g=0.3,b=0.4,a=0.6}
A:TrackerIntegrationTick()
assert(f.trackerBackground.questieArt.backdropColor[4]==0.6,'profile fallback opacity ignored')
-- The rendered backdrop wins over the static profile, including hover fades.
Questie_BaseFrame.backdropColor={0.1,0.2,0.3,0.12};Questie_BaseFrame.borderColor={1,1,1,0.07}
Questie_BaseFrame.alpha=0.5
A:TrackerIntegrationTick()
local art=f.trackerBackground.questieArt
assert(art.backdropColor[1]==0.1 and art.backdropColor[4]==0.12 and art.borderColor[4]==0.07)
assert(f.alpha==0.5 and f.trackerBackground.alpha==0.5,'overall Questie transparency not mirrored')
Questie_BaseFrame.backdropColor[4]=0;Questie_BaseFrame.borderColor[4]=0
A:TrackerIntegrationTick();assert(art.backdropColor[4]==0 and art.borderColor[4]==0,'fade to zero was lost')
Questie_BaseFrame.alpha=1
local shared,refreshed,settings=0,0,0
local currentDraft,lastShared='draft'
function A:CaptureQuestLogChatDraft() return currentDraft end
function A:OpenQuestLogShare(draft) lastShared=draft;shared=shared+1 end
function A:RefreshParty() refreshed=refreshed+1 end
function A:OpenSettings() settings=settings+1 end
f.settings.scripts.OnMouseDown();currentDraft='newer draft'
f.settings.scripts.OnClick();assert(A.questieDockMenu:IsShown())
A.questieDockMenu.buttons[1].scripts.OnClick();assert(shared==1 and not A.questieDockMenu:IsShown() and lastShared=='draft' and currentDraft=='newer draft')
f.settings.scripts.OnClick();A.questieDockMenu.buttons[2].scripts.OnClick();assert(refreshed==1)
f.questieHeaderClick.scripts.OnClick(nil,'RightButton');A.questieDockMenu.buttons[3].scripts.OnClick();assert(settings==1)

A.db.trackerSide='right';Questie_BaseFrame.left=800;Questie_HeaderFrame.left=800
A:TrackerIntegrationTick();assert(f.point[4]==1102,'right-side follow failed')
Questie_BaseFrame.scale=0.8;Questie_HeaderFrame.scale=0.8
A:TrackerIntegrationTick();assert(f.point[4]==882 and f.heightLimit==398,'mixed UI scales were ignored')
assert(math.abs(f.title.font[2]-11.2)<0.01,'Questie header font scale was ignored')
-- At the right screen edge, prefer the side with room without changing settings.
Questie_BaseFrame.scale=1;Questie_HeaderFrame.scale=1;Questie_BaseFrame.left=1450;Questie_HeaderFrame.left=1450
A:TrackerIntegrationTick();assert(A.questieCompatibility.dockRect.side=='left' and A.db.trackerSide=='right')
locked=true;A:TrackerIntegrationTick()
assert(f.viewCollapsed and f:IsShown() and not f.scroll:IsShown(),'combat did not collapse only our dock')
A:SetViewCollapsed(false);A:TrackerIntegrationTick()
assert(not f.viewCollapsed and f.scroll:IsShown() and not A.db.trackerCollapsed,'manual combat reopen changed outside-combat preference')
Questie_BaseFrame.left=1400;Questie_HeaderFrame.left=1400
A:TrackerIntegrationTick();assert(f.point[4]==978,'already-independent dock stopped following during combat')
A:TogglePartyTracker();assert(not f:IsShown() and A.db.trackerHidden)
A:TogglePartyTracker();assert(f:IsShown() and not A.db.trackerHidden)
locked=false;A:TrackerIntegrationTick();assert(not f.viewCollapsed)
-- Minimizing Questie keeps our pane independently usable at the header.
Questie_BaseFrame.height=30
A:TrackerIntegrationTick();assert(f.heightLimit>=128 and not f.viewCollapsed)
-- Explicit separate-window mode remains available and clears old dock art.
A.db.displayMode='window';A:TrackerIntegrationTick()
assert(A:EffectiveDisplayMode()=='window' and A.window:IsShown() and not f:IsShown() and not f.trackerBackground:IsShown())
assert(f.title.font[1]=='NativeFont','native title font was not restored')
assert(f.headerArt:IsShown() and f.share:IsShown() and f.refresh:IsShown() and f.alpha==1 and f.settings.caption.text=='Settings','Blizzard styling was not restored after undocking')
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
A.members={};A:TrackerIntegrationTick()
assert(A.questieCompatibility.dockRect.width==180 and f.viewCollapsed and not f.scroll:IsShown(),'solo dock left an oversized empty panel')
A.members={member={}};A.db.trackerCollapsed=false;A:TrackerIntegrationTick()
assert(f:GetWidth()==420 and not f.viewCollapsed,'joining a party retained the compact solo layout')
assert(nativeAccess==0 and foreignWrites==0,'docking wrote to Questie or accessed Blizzard frames')
assert(Questie.db.profile.trackerEnabled and Questie.db.char.isTrackerExpanded)
print('PASS: Questie independent docking, left/right/edge/scale/resize geometry, scroll cap, combat follow/collapse/reopen, hide/show, minimized/missing/hidden targets and standalone fallback without native/Questie writes; rendered/fallback/zero/faded backdrop opacity, overall alpha, compact menu and solo header')
