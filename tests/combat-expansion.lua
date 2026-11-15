unpack=unpack or table.unpack
GetTime=function() return 100 end
InCombatLockdown=function() return true end
IsShiftKeyDown=function() return false end
local created=0
local function widget()
 local w={shown=true,width=412,height=20,offset=0,scripts={}}
 function w:SetScript(k,v) self.scripts[k]=v end
 function w:IsShown() return self.shown end
 function w:Show() self.shown=true end
 function w:Hide() self.shown=false end
 function w:SetShown(v) self.shown=v end
 function w:GetWidth() return self.width end
 function w:GetHeight() return self.height end
 function w:SetWidth(v) self.width=v end
 function w:SetHeight(v) self.height=v end
 function w:SetSize(x,y) self.width=x;self.height=y end
 function w:GetVerticalScroll() return self.offset or 0 end
 function w:SetVerticalScroll(v) self.offset=v end
 function w:SetText(v) self.text=v end
 function w:GetStringHeight() return 16 end
 function w:CreateFontString() return widget() end
 function w:CreateTexture() return widget() end
 return setmetatable(w,{__index=function() return function() end end})
end
CreateFrame=function() created=created+1;return widget() end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
assert(loadfile('Settings.lua'))('SimplyPartyQuests',A)
A.db={trackerMembersClosed={},trackerGroupsClosed={},questExpanded={}}
A.own={};A.members={m={}}
A.db.displayMode="blizzard";A.db.combatAutoHide=false
function A:ShouldShowPartyView() return true end
A.integration.nativeBackdrop={};A.integration.nativeVisible=true
A.sidebar=widget()
local f=A.sidebar
f.rows={};f.child=widget();f.scroll=widget();f.hint=widget()
f.viewCollapsed=false;f.heightLimit=140;f.headerOffset=38;f.trackerBackground=widget()
f.combatBackgroundBounds={native={left=412,right=680,top=-5,bottom=120}}
ObjectiveTrackerFrame=setmetatable({},{__index=function() error('native tracker accessed in combat') end})
function A:Render() error('popout/full render accessed in combat') end
function A:RefreshParty() error('discovery started in combat') end
function A:BuildTrackerEntries()
 local entries={{kind='member',key='m',title='Member',closed=self.db.trackerMembersClosed.m}}
 if not self.db.trackerMembersClosed.m then
  entries[#entries+1]={kind='group',key='g',title='Zone',section='Other quests',count=1,closed=self.db.trackerGroupsClosed.g}
  if not self.db.trackerGroupsClosed.g then
   entries[#entries+1]={kind='quest',key='q',id=101,title='Quest',open=self.db.questExpanded.q,requirements={{text='Requirement'}},lines={'Progress 1/3'}}
  end
 end
 return entries,1
end
local q={kind='quest',key='q',id=101}
A:TrackerEntryClick(q,'LeftButton')
assert(A.db.questExpanded.q and f.contentHeight>100 and f.maxScroll>0)
assert(not A.integration.lastError and created>1,'first-open rows failed in combat: '..tostring(A.integration.lastError))
assert(f.trackerBackground.height==math.max(f.height,120)+5,'shared art failed to grow')
f.scroll.offset=999
A:TrackerEntryClick(q,'LeftButton')
assert(not A.db.questExpanded.q and f.scroll.offset<=f.maxScroll,'collapse left invalid scrolling')
for _,entry in ipairs({{kind='member',key='m'},{kind='group',key='g'}}) do
 A:TrackerEntryClick(entry,'LeftButton')
 assert((entry.kind=='member' and A.db.trackerMembersClosed.m) or A.db.trackerGroupsClosed.g)
 A:TrackerEntryClick(entry,'LeftButton')
end
assert(not A.integration.lastError and A.integration.dirty,'post-combat reconciliation lost')
-- Automatic combat refresh must reflow changed line counts without a user click.
A:TrackerEntryClick(q,'LeftButton')
local baseBuild=A.BuildTrackerEntries
function A:BuildTrackerEntries()
 local entries,count=baseBuild(self)
 for _,e in ipairs(entries) do if e.kind=='quest' then e.lines={'Updated 2/3','New objective 1/2'} end end
 return entries,count
end
A.integration.due=0;A:TrackerIntegrationTick()
local found=false
for _,row in ipairs(f.rows) do
 if row:IsShown() and row.label.text=='New objective 1/2' then found=true end
end
assert(found and not A.integration.dirty,'automatic combat refresh did not add changed objective rows')
A.BuildTrackerEntries=baseBuild
A:TrackerEntryClick(q,'LeftButton')
-- Native bounds must follow live shrinking/expansion without data invalidation.
local nativeBottom=80
local native={GetEffectiveScale=function() return 1 end,GetLeft=function() return 412 end,
 GetRight=function() return 680 end,GetTop=function() return 1000 end,
 GetBottom=function() return nativeBottom end}
A.integration.nativeBackdrop.frame=native
function f:GetEffectiveScale() return 1 end
function f:GetLeft() return 0 end
function f:GetTop() return 1000 end
A.integration.dirty=false
A:TrackerIntegrationTick()
assert(f.trackerBackground.height==920,'combat backdrop did not follow native expansion')
nativeBottom=900
A:TrackerIntegrationTick()
assert(f.trackerBackground.height==math.max(f.height,100),'combat backdrop retained stale native height')
A.integration.nativeBackdrop.frame=nil
f.combatBackgroundBounds={native={left=412,right=680,top=-5,bottom=120}}
-- The local progress subheading is independently toggleable during combat.
A:TrackerEntryClick({kind='ownProgress',key='q'},'LeftButton')
assert(A.db.trackerOwnProgressExpanded.q and not A.db.questExpanded.q,'own-progress click toggled the quest')
A:TrackerEntryClick({kind='ownProgress',key='q'},'LeftButton')
assert(not A.db.trackerOwnProgressExpanded.q,'own-progress section did not close')
-- The actual top button uses SetViewShown then the combat tick.
A:TogglePartyTracker()
assert(A.db.trackerHidden and not f:IsShown(),'party button did not hide immediately')
assert(f.trackerBackground.width==268,'hidden party pane left a party-width backdrop')
f.scroll:Hide();f.child:Hide();for _,row in ipairs(f.rows) do row:Hide() end
A:TogglePartyTracker()
assert(not A.db.trackerHidden and f:IsShown() and f.scroll:IsShown() and f.child:IsShown(),'party button did not restore viewport')
assert(f.rows[1]:IsShown() and f.rows[1].label.text:find('Member'),'reopened pane was blank')
assert(f.trackerBackground.width==680,'reopened shared backdrop stayed native-only')
-- Native main collapse hook must restore content while combat continues.
A:SetJoinedCollapseVisual(true)
assert(not f:IsShown() and not f.trackerBackground:IsShown())
f.scroll:Hide();f.child:Hide();for _,row in ipairs(f.rows) do row:Hide() end
A:SetJoinedCollapseVisual(false)
assert(f:IsShown() and f.scroll:IsShown() and f.rows[1]:IsShown(),'main reopen left blank content')
A:SetJoinedCollapseVisual(true)
A:TogglePartyTracker();A:TogglePartyTracker()
assert(not f:IsShown(),'party button expanded the native collapsed tracker')
A:SetJoinedCollapseVisual(false)
assert(f:IsShown() and f.rows[1]:IsShown())
IsShiftKeyDown=function() return true end
A:TrackerEntryClick(q,'LeftButton')
assert(not A.db.questExpanded.q,'shift-refresh unexpectedly toggled a quest')
IsShiftKeyDown=function() return false end
function A:RenderTrackerSidebar() error('simulated layout rejection') end
local message;print=function(v) message=v end
A:TrackerEntryClick(q,'LeftButton')
assert(A.integration.lastError:find('simulated layout rejection') and message and A.integration.dirty)
io.write('PASS: combat first-open layout, all section toggles, scrolling, cached backdrop resize, native isolation and error deferral\n')
