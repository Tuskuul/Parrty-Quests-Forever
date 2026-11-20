unpack=unpack or table.unpack
local widgets={}
local function widget(parent)
 local f={scripts={},shown=true,width=460,height=540,points={},text='',scroll=0,parent=parent}
 widgets[#widgets+1]=f
 local methods={
 SetScript=function(self,k,v) self.scripts[k]=v end,
 CreateFontString=function(self) return widget(self) end,
 CreateTexture=function(self) return widget(self) end,
 SetSize=function(self,w,h) self.width=w;self.height=h end,
 SetWidth=function(self,w) self.width=w end,SetHeight=function(self,h) self.height=h end,
 GetWidth=function(self) return self.width end,GetHeight=function(self) return self.height end,
 SetText=function(self,t) self.text=t end,GetText=function(self) return self.text end,
 GetStringHeight=function(self) return math.max(14,math.ceil(#self.text/45)*14) end,
 SetTextColor=function(self,...) self.color={...} end,
 SetPoint=function(self,...) self.points[#self.points+1]={...} end,
 ClearAllPoints=function(self) self.points={} end,
 GetFrameLevel=function() return 1 end,
 SetChecked=function(self,v) self.checked=v end,GetChecked=function(self) return self.checked end,
 SetShown=function(self,v) self.shown=v end,IsShown=function(self) return self.shown end,
 Hide=function(self) self.shown=false end,Show=function(self) self.shown=true end,
 GetVerticalScroll=function(self) return self.scroll end,
 SetVerticalScroll=function(self,n) self.scroll=n end,
 SetBackdropColor=function(self,...) self.background={...} end,
 SetAtlas=function(self,v) self.atlas=v end,SetTexture=function(self,v) self.texture=v end,
 SetFontObject=function(self,v) self.font=v end,
 GetLeft=function() return 10 end,GetTop=function() return 500 end,
 }
 return setmetatable(f,{__index=function(_,k)
  if methods[k] then return methods[k] end
  if k:match('^[A-Z]') then return function() end end
 end})
end
CreateFrame=function(_,name,parent,template)
 local f=widget(parent);f.template=template
 if template=='BasicFrameTemplateWithInset' then f.TitleText=widget(f);f.CloseButton=widget(f);f.Inset=widget(f) end
 return f
end
UIParent=widget();SlashCmdList={};GetTime=function() return 100 end
IsInRaid=function() return false end
InCombatLockdown=function() return false end
QuestFont='quest-heading';QuestFontNormalSmall='quest-body';GameFontNormal='gold-title'
C_Texture={GetAtlasInfo=function() return {} end}
local A={}
for _,file in ipairs({'Core.lua','QuestieCompatibility.lua','Definitions.lua','ShareRequests.lua','TrackerIntegration.lua','QuestDialogStyle.lua','UI.lua','Settings.lua'}) do
 assert(loadfile(file))('SimplyPartyQuests',A)
end
A.db={displayMode='window',size={width=380,height=400},expanded={},questExpanded={},sectionCollapsed={},zoneCollapsed={},combineShared=true}
function A:OpenQuestLogShare() self.shareOpened=true end
A:InitUI()
assert(A.window.template=='BasicFrameTemplateWithInset' and A.window.questPaper.atlas=='QuestBG-Parchment')
assert(not A.window.Inset.shown and not A.window.TitleText.shown)
assert(A.windowShareButton and A.windowShareButton.scripts.OnClick)
A.windowShareButton.scripts.OnClick();assert(A.shareOpened)
local refreshed=0;function A:RefreshParty() refreshed=refreshed+1 end
A.windowRefreshButton.scripts.OnClick();assert(refreshed==1)
for _,w in ipairs(widgets) do assert(w.text~='Party Quests - Alpha','stale alpha title survived cleanup') end
assert(not A.combineButton and not A.zoneButton and not A.trackerButton)
assert(A.scroll.points[1][3]==-36,'obsolete toolbar space was not reclaimed')
-- Docked/hidden updates defer popout rendering until it is actually opened.
local build=A.BuildPartyViewData;local builds=0
function A:BuildPartyViewData() builds=builds+1;return build(self) end
A.db.displayMode='blizzard';A:Render();assert(builds==0 and A.standaloneDirty)
A.db.displayMode='window';A:ShowStandaloneWindow(true);assert(builds==1 and not A.standaloneDirty)
A:SetViewShown(false);A:Render();assert(builds==1 and A.standaloneDirty)
A:SetViewShown(true);assert(builds==2 and not A.standaloneDirty and A.window.shown)
A.BuildPartyViewData=build
A:InitSettings();A.settingsPanel:Show();A.settingsAdvancedOpen=true;A.db.nativeTrackerRepair=true;A.db.displayMode='blizzard'
local writes=true
function A:NativeTrackerWritesAllowed() return writes end
A:SyncSettings();assert(A.settingsControls.repair.shown)
writes=false;A:SyncSettings();assert(not A.settingsControls.repair.shown and A.db.nativeTrackerRepair)
writes=true;A:SyncSettings();assert(A.settingsControls.repair.shown and A.db.nativeTrackerRepair)
local before=A.db.combineShared
A.settingsControls.combine.checked=not before;A.settingsControls.combine.scripts.OnClick();assert(A.db.combineShared==not before)
A.settingsControls.combine.checked=before;A.settingsControls.combine.scripts.OnClick();assert(A.db.combineShared==before)
A.db.displayMode='window'

A:Demo()
assert(A.child.height>1 and A.body.shown and A.resizeGrip.shown)
local hasDarkObjective,hasHeading=false,false
for _,w in ipairs(widgets) do
 if type(w.text)=='string' and w.text:find('Boar tusks',1,true) then
  assert(w.text:find(A:QuestDialogColorCode('body'),1,true),'objective ink is not parchment-safe')
  hasDarkObjective=true
 end
 if type(w.text)=='string' and w.text:find('Shared quests',1,true) then
  assert(w.color and w.color[1]>0.5 and w.color[2]>0.5,'heading color illegible on parchment')
  hasHeading=true
 end
end
assert(hasHeading)
-- Expand sample shared quest and validate its dark inline ink.
A.demoQuestExpanded['all:101']=true;A:Render()
for _,w in ipairs(widgets) do if type(w.text)=='string' and w.text:find('Boar tusks',1,true) then
 assert(w.text:find(A:QuestDialogColorCode('body'),1,true));hasDarkObjective=true
end end
assert(hasDarkObjective)
A.scroll.scroll=99999;A:Render();assert(A.scroll.scroll<99999,'shrunk list retained an unreachable scroll offset')
A.collapse.scripts.OnClick();assert(not A.body.shown and not A.resizeGrip.shown)
A.collapse.scripts.OnClick();assert(A.body.shown and A.resizeGrip.shown)
A.window.CloseButton.scripts.OnClick();assert(A.db.hidden and not A.window.shown)
-- Same shared style degrades to the classic parchment texture without atlases.
C_Texture=nil
local fallback=widget();A:StyleQuestDialog(fallback)
assert(fallback.questPaper.texture=='Interface\\QuestFrame\\UI-QuestGreeting-TopLeft')
print('PASS: parchment popout/frame and classic fallback, readable text, shared style, share action, minimum-width rendering, scroll clamp, persistent close and collapse/resize controls')
