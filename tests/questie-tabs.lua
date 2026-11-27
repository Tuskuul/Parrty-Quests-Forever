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
for _,name in ipairs({'Core.lua','QuestieCompatibility.lua','TrackerIntegration.lua','Settings.lua','TrackerTabs.lua','QuestieDock.lua','QuestieTabs.lua'}) do
 assert(loadfile(name))('SimplyPartyQuests',A)
end
local profile={trackerEnabled=true,trackerBackdropEnabled=true,trackerBorderEnabled=true,
 trackerBackdropColor={r=0.1,g=0.2,b=0.3,a=0.7}}
Questie={db={profile=setmetatable({},{__index=profile,__newindex=function() error('Questie settings mutated') end})}}
Questie_BaseFrame=widget();local root=Questie_BaseFrame
root.parent=UIParent;root.left=1200;root.top=850;root.width=340;root.height=600
root:SetBackdrop({bgFile='fill',edgeFile='border',edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
root:SetBackdropColor(0.1,0.2,0.3,0.7);root:SetBackdropBorderColor(1,1,1,0.7)
local originalClick=function() end;root:SetScript('OnMouseDown',originalClick)
A.db={displayMode='blizzard',defaultTrackerLayout='sidebar',trackerTab='objectives',combatAutoHide=true}
A:NormalizeSavedSettings();assert(A.db.questieTrackerLayout=='tabs')
A.members={};A.window=widget()
local fullIntegrationTick=A.TrackerIntegrationTick
function A:TrackerIntegrationTick() return self:TrackerTabsTick() end
function A:SyncSettings() end
function A:ReleaseNativeCombatControl() end
function A:BuildTrackerEntries() return {},0 end
local renders=0
function A:RenderTrackerSidebar() renders=renders+1;self.sidebar.contentHeight=500 end
A:TrackerIntegrationTick()
local t,f=A.trackerTabs,A.sidebar
assert(t.active and t.provider=='questie' and t.bar.shown and root:IsVisible())
assert(not t.control.registered and wraps==0,'Questie root made secure or scripts wrapped')
assert(root:GetParent()==t.control and native:GetParent()==UIParent,'wrong tracker reparented')
assert(A:EffectiveDisplayMode()=='blizzard' and A:TrackerLayoutSetting()=='questieTrackerLayout')
A:SelectTrackerTab('party')
assert(f.shown and not root:IsVisible() and root:IsShown() and renders==1)
assert(f.width==340 and f.heightLimit==600 and not f.questiePlain,'party pane did not share tracker viewport')
assert(f.trackerBackground.questieTabsArt.backdropColor[4]==0.7)
for i=1,20 do root:Hide();root:Show();assert(not root:IsVisible(),'Questie update flashed hidden tab') end
assert(root.scripts.OnMouseDown==originalClick,'Questie drag script replaced')
-- Scaling/moving an inactive Questie root still positions the shared viewport.
root.scale=0.8;root.left=1000;root.width=360;A:TrackerIntegrationTick()
assert(f.scale==0.8 and f.width==360 and f.point[4]==1000)
root.height=25;A:TrackerIntegrationTick();assert(f.heightLimit==600,'minimized tracker crushed party rows')
locked=true;A:SelectTrackerTab('objectives');assert(t.pending=='objectives' and not root:IsVisible())
A:TrackerIntegrationTick();assert(f.viewCollapsed and not f.scroll.shown)
A:SetViewCollapsed(false);assert(f.scroll.shown,'combat party reopening failed')
A:SetDefaultTrackerLayout('sidebar');assert(A.db.questieTrackerLayout=='tabs')
locked=false;A:TrackerIntegrationTick()
assert(A.db.questieTrackerLayout=='sidebar' and A.db.defaultTrackerLayout=='sidebar')
assert(not t.active and not t.bar.shown and root:GetParent()==UIParent and root:IsVisible())
assert(not f.trackerBackground.questieTabsArt.shown,'plugin art leaked into dock')
A:SetDefaultTrackerLayout('tabs');assert(A.trackerTabs==t and t.active,'provider host not reused')
A:SetViewShown(true);assert(A.db.trackerTab=='party' and not root:IsVisible())
A:SetViewShown(false);assert(A.db.trackerTab=='objectives' and root:IsVisible() and t.bar.shown)
-- Questie's own Hide intent remains in force; our tabs remain reachable solo.
root:Hide();A:TrackerIntegrationTick();assert(not root:IsVisible() and t.bar.shown)
A:SelectTrackerTab('party');assert(f.shown and t.bar.shown)
root:Show();profile.trackerEnabled=false
A:TrackerIntegrationTick();assert(not t.active and root:GetParent()==UIParent and root:IsShown())
-- Provider transitions restore the outgoing root before acquiring the next.
A.db.defaultTrackerLayout='tabs';A:TrackerIntegrationTick()
assert(A.trackerTabs.provider=='blizzard' and native:GetParent()==A.trackerTabs.control)
profile.trackerEnabled=true;A:TrackerIntegrationTick()
assert(A.trackerTabs==t and t.active and native:GetParent()==UIParent and root:GetParent()==t.control)
A.db.displayMode='window';A:TrackerIntegrationTick()
assert(root:GetParent()==UIParent and A:EffectiveDisplayMode()=='window')
A.db.displayMode='blizzard';A:TrackerIntegrationTick();assert(t.active)
Questie_BaseFrame=nil;A:TrackerIntegrationTick();assert(not t.active and root:GetParent()==UIParent)
Questie_BaseFrame=root;A:TrackerIntegrationTick();assert(t.active)
-- Invalid/missing profile means read-only fallback, never ownership by guess.
Questie.db.profile={};A:TrackerIntegrationTick();assert(not t.active and root:GetParent()==UIParent)
assert(profile.trackerEnabled and profile.trackerBackdropColor.a==0.7)
Questie.db.profile=setmetatable({},{__index=profile,__newindex=function() error('Questie settings mutated') end})
A.db.trackerTab='party';fullIntegrationTick(A)
assert(A.trackerTabs.active and f.shown and not root:IsVisible(),'compatibility cleanup hid the active tab')
local beforeRenders=renders;A.integration.dirty=true;fullIntegrationTick(A)
assert(f.shown and renders==beforeRenders+1,'full integration path failed to refresh Party rows')
-- Questie's ordinary parent leaves its own UI writable during combat.
locked=true;root:SetSize(350,550);root:Hide();root:Show();fullIntegrationTick(A)
assert(not root:IsVisible() and f.shown,'combat root refresh escaped tab host')
A:SetDefaultTrackerLayout('sidebar');profile.trackerEnabled=false;locked=false
fullIntegrationTick(A)
assert(A.db.questieTrackerLayout=='sidebar' and A.db.defaultTrackerLayout=='tabs','queued layout changed the wrong provider preference')
print('PASS: Questie tabs share one viewport, preserve update/drag/profile ownership, restore dock/parents, retain solo tabs, queue combat switches, follow scale/movement, preserve hidden intent, and switch providers without native writes')
