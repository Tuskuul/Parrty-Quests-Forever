unpack=unpack or table.unpack
local locked,now=false,100
GetTime=function() return now end
InCombatLockdown=function() return locked end
local nativeAccess,foreignWrites=0,0
local secure=false
local runSnippet
local function widget(kind,foreign)
 local w={shown=true,width=420,height=500,scale=1,scroll=0,scripts={},kind=kind or 'Frame',foreign=not not foreign}
 local function write(self) assert(not (locked and self.native and not secure),'addon changed native visibility during combat');if self.foreign then foreignWrites=foreignWrites+1;error('Questie frame mutated') end end
 function w:SetScript(k,v) write(self);self.scripts[k]=v end
 function w:HookScript(k,v) write(self);self.scripts[k]=v end
 function w:RegisterEvent() write(self) end
 function w:IsShown() return self.shown end
 function w:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
 function w:GetParent() return self.parent end
 function w:SetParent(parent)
  write(self);local visible=self:IsVisible();self.parent=parent
  if not visible and self:IsVisible() then
   local wrap=self.wrapShow;local allow,message
   if wrap then allow,message=runSnippet(wrap.body,wrap.control,self) end
   if allow~=false and self.scripts.OnShow then self.scripts.OnShow(self) end
   if wrap and wrap.postBody and message~=nil then runSnippet(wrap.postBody,wrap.control,self) end
  end
 end
 function w:SetAllPoints(target) write(self);self.allPoints=target end
 function w:SetNormalFontObject(font) self.normalFont=font end
 function w:GetFontString() return self.fontString end
 function w:Show()
  write(self);local changed=not self.shown;self.shown=true
  if changed then
   local wrap=self.wrapShow;local allow,message
   if wrap then allow,message=runSnippet(wrap.body,wrap.control,self) end
   if allow~=false and self.scripts.OnShow then self.scripts.OnShow(self) end
   if wrap and wrap.postBody and message~=nil then runSnippet(wrap.postBody,wrap.control,self) end
  end
 end
 function w:Hide() write(self);local changed=self.shown;self.shown=false;if changed and self.wrapHide then runSnippet(self.wrapHide.body,self.wrapHide.control,self) end end
 function w:SetShown(v) if v then self:Show() else self:Hide() end end
 function w:SetSize(x,y) write(self);self.width=x;self.height=y end
 function w:SetWidth(x) write(self);self.width=x end
 function w:SetHeight(x) write(self);self.height=x end
 function w:GetWidth() return self.width end
 function w:GetHeight() return self.height end
 function w:SetScale(x) write(self);self.scale=x end
 function w:GetEffectiveScale() return self.scale end
 function w:GetScale() return self.scale end
 function w:SetAttribute(k,v) assert(not locked or secure,'combat attribute write');self.attrs=self.attrs or {};self.attrs[k]=v end
 function w:GetAttribute(k) return self.attrs and self.attrs[k] end
 function w:SetFrameRef(k,v) self.refs=self.refs or {};self.refs[k]=v end
 function w:GetFrameRef(k) return self.refs and self.refs[k] end
 function w:SetAlpha(v) write(self);self.alpha=v end
 function w:GetAlpha() return self.alpha or 1 end
 function w:GetEffectiveAlpha() return self.alpha or 1 end
 function w:GetBackdrop() return self.backdrop end
 function w:SetBackdrop(v) write(self);self.backdrop=v;self.backdropWrites=(self.backdropWrites or 0)+1 end
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
 function w:SetPoint(...) write(self);self.point={...};self.anchorWrites=(self.anchorWrites or 0)+1 end
 function w:SetVerticalScroll(x) write(self);self.scroll=x end
 function w:GetVerticalScroll() return self.scroll or 0 end
 function w:CreateTexture() write(self);return widget('Texture') end
 function w:CreateFontString() write(self);return widget('FontString') end
 function w:GetFont() return table.unpack(self.font or {'NativeFont',13,''}) end
 function w:SetFont(...) write(self);self.font={...};self.fontWrites=(self.fontWrites or 0)+1 end
 function w:SetText(t) write(self);self.text=t end
 function w:GetFrameLevel() return 1 end
 return setmetatable(w,{__index=function(_,name)
  if not name:match('^[A-Z]') then return nil end
  if name:match('^Set') or name:match('^Enable') then return function(self) write(self) end end
  return function() end
 end})
end

runSnippet=function(body,control,frame,newstate)
 local previous=secure;secure=true
 local ok,a,b=pcall(assert(load(body,'restricted snippet','t',setmetatable({self=frame or control,control=control,newstate=newstate},{__index=_G}))))
 secure=previous;assert(ok,a);return a,b
end
CreateFrame=function(kind) return widget(kind) end
RegisterStateDriver=function(control) control.registered=true end
local wraps=0
SecureHandlerWrapScript=function(frame,script,control,body,postBody)
 wraps=wraps+1
 frame[script=='OnShow' and 'wrapShow' or 'wrapHide']={control=control,body=body,postBody=postBody}
end
securecallfunction=function(fn,...) return fn(...) end
local messages={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,v) messages[#messages+1]=v end}
UIParent=widget();UIParent.width=1800;UIParent.height=1000
ObjectiveTrackerFrame=widget();local native=ObjectiveTrackerFrame
native.parent=UIParent;native.native=true;native.left=1200;native.top=850;native.width=300
native.Header=widget();native.Header.MinimizeButton=widget()
local A={}
for _,name in ipairs({'Core.lua','QuestieCompatibility.lua','TrackerIntegration.lua','Settings.lua','TrackerTabs.lua'}) do
 assert(loadfile(name))('SimplyPartyQuests',A)
end
A.db={displayMode='blizzard',defaultTrackerLayout='tabs',trackerTab='objectives',combatAutoHide=true}
A.members={member={}};A.window=widget()
local fallback=0
function A:TrackerIntegrationTick() if not self:TrackerTabsTick() then fallback=fallback+1 end end
function A:SyncSettings() end
function A:ReleaseNativeCombatControl() end
function A:BuildTrackerEntries() return {},1 end
local renders=0
function A:RenderTrackerSidebar() renders=renders+1;self.sidebar.contentHeight=500 end
A:TrackerIntegrationTick()
local t,f=A.trackerTabs,A.sidebar
assert(t.active and t.bar.shown and not f.shown and native:IsVisible(),'initial Objectives view hides native tracker')
assert(f.point[2]==UIParent and t.bar.point[2]==UIParent,'native anchor protection leaked into owned frames')
assert(f.width==300 and wraps==1 and not A:NativeCombatControlsAllowed())
A:SelectTrackerTab('party')
assert(f.shown and not native:IsVisible() and renders==1 and t.buttons[2].selected.shown,table.concat({tostring(f.shown),tostring(native:IsVisible()),renders,tostring(t.buttons[2].selected.shown),tostring(A.integration.due)},','))
native.scale=0.8;native.width=350;native.left=1100
A:TrackerIntegrationTick()
assert(f.width==350 and f.scale==0.8 and f.point[4]==1100 and t.bar.scale==0.8 and renders==2,'Edit Mode scale/width changes did not reflow')
native.scale=1;native.width=300;native.left=1200;A:TrackerIntegrationTick()
local priorRenders=renders
-- Native Show/SetShown calls cannot reveal a hidden ancestor, even if no
-- periodic tracker tick occurs between repeated turn-in layouts.
native.scripts.OnShow=function(self) self.shown=true end
native:Show();assert(not native:IsVisible() and native.shown and native:GetParent()==t.control,'native turn-in redraw leaked through before next tick')
for i=1,20 do
 native:Show();assert(not native:IsVisible(),'repeated native redraw flashed')
 native:SetParent(UIParent);assert(not native:IsVisible() and native:GetParent()==t.control,'managed frame reparent escaped visibility host')
end
native.scripts.OnShow=nil
-- A quest update rerenders only our rows; no native Update/SetCollapsed exists.
A.integration.dirty=true;A:TrackerIntegrationTick();assert(renders==priorRenders+1)
locked=true
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,1)
t.control.attrs['state-combat']=1
A:TrackerIntegrationTick();assert(f.viewCollapsed and f.shown and not f.scroll.shown and not native:IsVisible())
secure=true;native:SetParent(UIParent);native:Show();secure=false
assert(not native:IsVisible() and native:GetParent()==t.control,'secure native reparent escaped hidden tab during combat')
A:SetViewCollapsed(false);assert(not f.viewCollapsed and f.scroll.shown,'party combat reopening failed')
A:SelectTrackerTab('objectives');assert(t.pending=='objectives' and A.db.trackerTab=='party' and not native:IsVisible())
local noticeCount=#messages;A:SelectTrackerTab('objectives');assert(#messages==noticeCount,'repeat tab click spammed notices')
A:SelectTrackerTab('party');assert(not t.pending,'active tab failed to cancel queued switch')
A:SelectTrackerTab('objectives')
locked=false;t.control.attrs['state-combat']=0
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,0)
A:TrackerIntegrationTick();assert(native:IsVisible() and not f.shown and A.db.trackerTab=='objectives' and not t.pending)
-- Auto-hide the native view securely; retain the tab bar throughout combat.
locked=true;t.control.attrs['state-combat']=1
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,1)
A:TrackerIntegrationTick();assert(not native:IsVisible() and t.bar.shown)
locked=false;t.control.attrs['state-combat']=0
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,0)
A:TrackerIntegrationTick();assert(native:IsVisible() and not f.shown)
A.db.combatAutoHide=false;A:TrackerIntegrationTick()
locked=true;t.control.attrs['state-combat']=1
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,1)
A:TrackerIntegrationTick();assert(native:IsVisible(),'auto-hide opt-out ignored')
-- Layout changes during combat are deferred and restore normal UI afterward.
A:SetDefaultTrackerLayout('sidebar');assert(t.active and A.integration.pendingTrackerLayout=='sidebar')
locked=false;t.control.attrs['state-combat']=0
runSnippet(t.control:GetAttribute('_onstate-combat'),t.control,nil,0)
A:TrackerIntegrationTick();assert(not t.active and not t.bar.shown and native:IsVisible() and fallback>0)
assert(f.settings.point[2]==f and f.refresh.point[2]==f.settings and f.share.point[2]==f.refresh,'toolbar anchors did not restore')
-- Re-enable without duplicate visibility-parent guards; saved tab preference survives changes.
A.db.trackerTab='party';A:SetDefaultTrackerLayout('tabs')
assert(t.active and f.shown and not native:IsVisible() and wraps==1)
-- Both tabs remain available after the last party member leaves.
A.members={};A:TrackerIntegrationTick();assert(t.active and t.bar.shown)
A:SelectTrackerTab('objectives');assert(native:IsVisible())
A:SelectTrackerTab('party');assert(f.shown and t.bar.shown)
A.soloOverride=true;A:TrackerIntegrationTick();assert(t.active,'manual solo opening was lost')
-- Questie's active tracker ignores the stored default-UI layout preference.
Questie={db={profile={trackerEnabled=true}}}
A:TrackerIntegrationTick();assert(not t.active and not A:TrackerTabsRequested())
Questie=nil;A.db.displayMode='window';A:TrackerIntegrationTick();assert(not t.active)
-- Missing secure APIs fall back without taking native ownership.
A.db.displayMode='blizzard';A.integration.tabsRetryAt=nil
RegisterStateDriver=nil
A:TrackerIntegrationTick();assert(not t.active and A.integration.lastError:find('setup unavailable'))
-- Missing/invalid preferences choose Tabbed; explicit layout choices survive.
A.db.defaultTrackerLayout='bad';A.db.trackerTab='bad';A:NormalizeSavedSettings()
assert(A.db.defaultTrackerLayout=='tabs' and A.db.trackerTab=='objectives')
A.db.defaultTrackerLayout=nil;A:NormalizeSavedSettings();assert(A.db.defaultTrackerLayout=='tabs')
for _,layout in ipairs({'sidebar','tabs'}) do
 A.db.defaultTrackerLayout=layout;A:NormalizeSavedSettings();assert(A.db.defaultTrackerLayout==layout,'explicit layout preference overwritten')
end
-- Native framed top tabs use Blizzard's template/state functions. Selecting an
-- active tab must remain possible to cancel a pending combat switch.
RegisterStateDriver=function() end
PanelTopTabButtonMixin={}
PanelTemplates_SelectTab=function(button) button.selected:Show();button.enabled=false end
PanelTemplates_DeselectTab=function(button) button.selected:Hide();button.enabled=true end
PanelTemplates_TabResize=function(button,_,width) button:SetWidth(width or 160) end
CreateFrame=function(kind,_,parent,template)
 local f=widget(kind)
 f.parent=parent
 if template=='PanelTopTabButtonTemplate' then
  f.MiddleActive=widget('Texture');f.template=template;f.fontString=widget('FontString')
  function f:Enable() self.enabled=true end
 end
 return f
end
local fontSize=16
ObjectiveTrackerHeaderFont={GetFont=function() return 'TrackerHeader',fontSize,'' end}
A.trackerTabs=nil;A.integration.tabsRetryAt=nil;A.db.defaultTrackerLayout='tabs'
A:TrackerIntegrationTick()
local nativeTabs=A.trackerTabs
assert(nativeTabs.buttons[1].nativeTab and nativeTabs.buttons[1].template=='PanelTopTabButtonTemplate')
assert(nativeTabs.buttons[1].selected.shown and nativeTabs.buttons[1].enabled,'selected native tab cannot cancel a pending switch')
A:SelectTrackerTab('party')
assert(nativeTabs.buttons[2].selected.shown and not nativeTabs.buttons[1].selected.shown)
assert(nativeTabs.buttons[2].normalFont==ObjectiveTrackerHeaderFont,'native tabs retained the small template font')
fontSize=20;A:UpdateTrackerTabsLabels();assert(nativeTabs.buttons[2].tabVisualKey:match(':20$'),'tab text did not follow live tracker text size')
assert(nativeTabs.buttons[2].fontString.height==26 and nativeTabs.buttons[2].height==32,'larger tab text retained the template 10px clipping height')
assert(native:GetParent()==nativeTabs.control and nativeTabs.control.allPoints==UIParent,'visibility host changed parent bounds')
-- Native layout can hide an empty tracker while inactive. Opening Objectives
-- must not force the empty tracker shown again.
native:Hide();A:SelectTrackerTab('objectives');assert(not native:IsVisible())
native:Show();assert(native:IsVisible())
A:SetDefaultTrackerLayout('sidebar');assert(native:GetParent()==UIParent,'native parent was not restored')
local manager=widget();manager.parent=UIParent;manager.scale=0.75
native:SetParent(manager);A:SetDefaultTrackerLayout('tabs')
local host=A.trackerTabs.control
assert(host:GetParent()==UIParent and host.ignoreInLayout and host.allPoints==manager and host.scale==0.75,'host entered the managed layout child list or lost parent scale')
A:SelectTrackerTab('party');native:SetParent(manager)
assert(not native:IsVisible() and native:GetParent()==host,'managed container reparent revealed native objectives')
A:SetDefaultTrackerLayout('sidebar');assert(native:GetParent()==manager,'custom native parent was not restored')
-- Tabs initialize while solo, even with the old sidebar Hide flag saved.
A.db.defaultTrackerLayout='tabs';A.db.trackerHidden=true;A.db.trackerTab='objectives';A.members={};A.soloOverride=nil
A.partyTrackerButton=widget()
A:EnsurePartyTrackerButton(native);assert(not A.partyTrackerButton.shown)
A:TrackerIntegrationTick()
assert(A.trackerTabs.active and A.trackerTabs.bar.shown and native:IsVisible(),'tab strip unavailable while solo/hidden')
A:TogglePartyTracker()
assert(A.db.trackerTab=='party' and f.shown,'manual tab switch required another click')
A:SetViewShown(false);A:TrackerIntegrationTick()
assert(A.trackerTabs.active and A.trackerTabs.bar.shown and A.db.trackerTab=='objectives' and not f.shown,'Hide removed the entire tab bar')
A:SetViewShown(true);assert(A.db.trackerTab=='party' and f.shown)
-- Both tabs remain reachable throughout combat; the page switch is deferred.
A:SelectTrackerTab('objectives');locked=true
local priorNotices=#messages
A:TogglePartyTracker();A:TogglePartyTracker()
assert(A.trackerTabs.active and A.trackerTabs.bar.shown and A.trackerTabs.pending=='party' and #messages==priorNotices+1)
locked=false;A:TrackerIntegrationTick();assert(A.db.trackerTab=='party' and f.shown)
-- First creation during combat still waits for safe setup, without recursive
-- initialization when the queued open is applied.
A:SetDefaultTrackerLayout('sidebar');A.db.defaultTrackerLayout='tabs';locked=true
A:TogglePartyTracker();assert(A.integration.tabsOpenPending and not A.trackerTabs.active)
locked=false;A:TrackerIntegrationTick()
assert(not A.integration.tabsOpenPending and A.trackerTabs.active and f.shown)
A:SetDefaultTrackerLayout('sidebar');A:EnsurePartyTrackerButton(native)
assert(A.partyTrackerButton.shown,'side-by-side launcher was not restored')
local file=assert(io.open('Settings.lua'));local settings=file:read('*a');file:close()
assert(settings:find('"layoutSidebar","Side by Side"',1,true) and settings:find('"layoutTabs","Tabbed"',1,true),'layout names did not match requested labels')
print('PASS: default tracker tab selection, same-space geometry, native visibility guards, combat queues/collapse/restore/opt-out, owned row updates, pending layout, toolbar restoration, persistent solo/group tab availability, solo override, Questie isolation, saved defaults and secure-API fallback')
