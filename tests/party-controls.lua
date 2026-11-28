unpack=unpack or table.unpack
GetTime=function() return 100 end
local locked=false
InCombatLockdown=function() return locked end
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
SlashCmdList={}
local A={}
for _,name in ipairs({'Core.lua','Definitions.lua','UI.lua','QuestZones.lua','TrackerIntegration.lua','PartyControls.lua'}) do assert(loadfile(name))('SimplyPartyQuests',A) end
A.db={combineShared=true,groupByZone=true,questExpanded={},trackerGroupsClosed={},trackerMembersClosed={}}
A.own={[914]={id=914,title='Leaders of the Fang',readyKnown=true,ready=true}}
A.members={}
for i=1,4 do local guid='member'..i;A.members[guid]={guid=guid,name='Member '..i,quests={
 [914]={id=914,title='Leaders of the Fang',readyKnown=true,ready=true},
 [91316]={id=91316,title='Making Repairs',objectives={}}}} end
function A:Render() end
local function entries() return A:BuildTrackerEntries() end
local rows=entries();local shared,header=0,0
for _,e in ipairs(rows) do if e.kind=='quest' and e.key=='all:914' then shared=shared+1;assert(e.title:find('[Ready]',1,true)) end;if e.kind=='partyHeader' then header=header+1 end end
assert(shared==1 and header==1,'shared quest/header missing')
assert(select(2,A:QuestZone(91316))=='Paladin quests' and select(2,A:QuestZone(91858))=='Paladin quests')
function A:QuestieField() return 0 end
assert(select(2,A:QuestZone(91316))=='Paladin quests','zero live metadata defeated bundled fallback')
A.db.questExpanded['all:914']=true;A.db.trackerGroupsClosed['all:header:Wailing Caverns']=true
A:SetPartyExpansion('collapse');assert(not A.db.trackerPartyCollapsed)
for guid in pairs(A.members) do assert(A.db.trackerMembersClosed[guid]) end
A:SetPartyExpansion('collapse');assert(A.db.trackerPartyCollapsed)
for _,e in ipairs(entries()) do assert(e.kind~='member','hidden member row leaked') end
A:SetPartyExpansion('members');assert(not A.db.trackerPartyCollapsed)
for guid in pairs(A.members) do assert(A.db.trackerMembersClosed[guid]) end
A:SetPartyExpansion('collapse');assert(not A.db.trackerPartyCollapsed,'first press after Expand hid names')
A:SetPartyExpansion('collapse');assert(A.db.trackerPartyCollapsed)
A:SetPartyExpansion('all');assert(not A.db.trackerPartyCollapsed)
for guid in pairs(A.members) do assert(not A.db.trackerMembersClosed[guid] and A.db.questExpanded[guid..':91316'] and A.db.trackerOwnProgressExpanded[guid..':91316']) end
assert(A.db.questExpanded['all:914'] and A.db.trackerGroupsClosed['all:header:Wailing Caverns'],'party controls changed Shared state')
local f=widget();A.sidebar=f;f.rows={};f.child=widget();f.scroll=widget();f.hint=widget();f.trackerBackground=widget()
function A:SizeTrackerSidebar() end
function A:UpdateTrackerQuestFocus() end
A:RenderTrackerSidebar(entries(),4)
local heading
for _,r in ipairs(f.rows) do if r.label and r.label.text=='Party members' then heading=r end end
assert(heading and heading.partyActions.shown and #heading.partyActions.buttons==3)
A:SetPartyExpansion('collapse');A:SetPartyExpansion('collapse');A:RenderTrackerSidebar(entries(),4)
assert(heading.partyBar.shown and heading.partyBar.label.text=='4 party members collapsed')
local combatRenders=0
function A:RenderCombatTrackerSidebar() combatRenders=combatRenders+1 end
locked=true;A:SetPartyExpansion('members');assert(combatRenders==1 and not A.db.trackerPartyCollapsed)
print('PASS: class category fallback, complete shared Fang quest, two-stage party collapse, members/all expansion, own-progress expansion, shared isolation, real header rendering and combat routing')
