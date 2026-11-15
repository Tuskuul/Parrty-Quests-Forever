unpack=unpack or table.unpack
local scripts={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,name,fn) scripts[name]=fn end} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local id,questMode=101,true
C_SuperTrack={GetSuperTrackedQuestID=function() return id end,IsSuperTrackingQuest=function() return questMode end}
InCombatLockdown=function() return true end
ObjectiveTrackerFrame=setmetatable({},{__index=function() error('native tracker write/access during focus update') end})
local writes=0
local function row(kind,questID)
 local function art() return {SetShown=function(self,v) self.shown=v;writes=writes+1 end} end
 return {entry={kind=kind,id=questID},focusFill=art(),focusAccent=art(),
  label={SetText=function() error('focus changed quest text') end}}
end
local a,b,duplicate,group=row('quest',101),row('quest',102),row('quest',101),row('group',101)
A.sidebar={rows={a,b,duplicate,group}}
A:UpdateTrackerQuestFocus()
assert(a.focusShown and duplicate.focusShown and not b.focusShown and not group.focusShown,'wrong quest highlighted')
local before=writes;A:UpdateTrackerQuestFocus();assert(writes==before,'unchanged focus rewrote art')
id=102;A.integration.dirty=false;scripts.OnEvent(nil,'SUPER_TRACKING_CHANGED')
assert(b.focusShown and not a.focusShown and not duplicate.focusShown,'focus event left old highlights')
assert(not A.integration.dirty,'focus event requested full layout')
b.entry={kind='member',id=102};A:UpdateTrackerQuestFocus();assert(not b.focusShown,'pooled non-quest row retained highlight')
b.entry={kind='quest',id=102};A:UpdateTrackerQuestFocus();assert(b.focusShown)
questMode=false;A:UpdateTrackerQuestFocus();assert(not b.focusShown,'waypoint selection retained quest highlight')
questMode=true;id=0;A:UpdateTrackerQuestFocus();assert(A.integration.focusedQuestID==nil)
id=101;A:UpdateTrackerQuestFocus();assert(a.focusShown)
C_SuperTrack=nil;A:UpdateTrackerQuestFocus();assert(not a.focusShown,'missing API retained stale highlight')
C_SuperTrack={GetSuperTrackedQuestID=function() error('restricted') end}
A:UpdateTrackerQuestFocus();assert(A.integration.focusedQuestID==nil)
print('PASS: focused quest matching, duplicate views, live combat event updates, clearing, row reuse, missing APIs and no native/text changes')
