-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
local now=100
local locked=true
local created=0
GetTime=function() return now end
InCombatLockdown=function() return locked end
CreateFrame=function()
 created=created+1
 return setmetatable({},{__index=function() return function() end end})
end
local A={}
for _,file in ipairs({'Core.lua','Polling.lua','LiveProgress.lua','EventTriggers.lua','NativeTracker.lua','TrackerIntegration.lua'}) do
 assert(loadfile(file))('SimplyPartyQuests',A)
end
A.db={displayMode='blizzard'}
A.members={party={guid='party',unit='party1',quests={[101]={id=101,objectives={{done=1,total=3}}}}}}
UnitExists=function() return false end
UnitGUID=function() return nil end
function A:QueueMembershipValidation() error('membership queued during combat') end
A:BuildLiveTasks()
assert(#A.liveTasks==1 and A.liveTasks[1].kind=='party','known quest not queued during combat')
local queries=0
function A:QueryPartyProgress(id)
 assert(locked and id==101)
 queries=queries+1
 self.members.party.quests[id].objectives[1].done=2
 self.liveDirty=true
end
function A:Changed() self:InvalidateTrackerIntegration() end
function A:ValidationStep() error('membership checked during combat') end
A:QueueTriggeredRefresh('PARTY_KILL')
now=101;A:TriggerTick()
assert(A.triggerTasks and A.triggerActive,'combat trigger did not start')
A:LiveTick()
assert(queries>0 and A.members.party.quests[101].objectives[1].done==2,'progress did not update during combat')
-- A membership task queued before combat must also be skipped.
A.triggerTasks=nil;A.liveTasks={{kind='membership',value=101}};A.liveIndex=1
A:LiveTick()

local protectedTouches=0
ObjectiveTrackerFrame=setmetatable({},{__index=function()
 protectedTouches=protectedTouches+1;error('Blizzard tracker touched during combat')
end})
local function row(key,index)
 return setmetatable({liveQuestKey=key,liveLine=index,IsShown=function() return true end,
  label={SetText=function(self,value) self.text=value end}},
  {__index=function(_,name) error('combat layout operation: '..name) end})
end
local header,progress=row('party:101',0),row('party:101',1)
A.sidebar=setmetatable({rows={header,progress},IsShown=function() return true end},
 {__index=function(_,name) error('combat sidebar geometry/visibility operation: '..name) end})
function A:BuildTrackerEntries()
 local done=self.members.party.quests[101].objectives[1].done
 return {{kind='quest',key='party:101',open=true,title='Quest',lines={'Party member: '..done..'/3'}}},1
end
function A:RenderTrackerSidebar() error('full sidebar layout ran during combat') end
local framesBefore=created
now=102;A:TrackerIntegrationTick()
assert(header.label.text=='- Quest' and progress.label.text=='Party member: 2/3','visible text stayed stale in combat')
assert(protectedTouches==0 and created==framesBefore and not A.integration.lastError,'combat update touched frame layout')
assert(not A.integration.dirty)
-- Combat exit must schedule the full layout that was deferred.
locked=false;A.integrationEvents=nil;A:InvalidateTrackerIntegration()
assert(A.integration.dirty,'post-combat layout did not remain schedulable')
locked=true;C_QuestLog={IsUnitOnQuest=function() error('catalog sweep queried during combat') end}
A.sweep={};A:PollTick()
assert(A.sweepStatus=='Quest sweep paused (combat)')
A.nativeTracker.due=0;A:NativeTrackerTick()
assert(A.nativeTracker.due==0,'native repair was consumed during combat')
print('PASS: combat queries/triggers, existing-row text updates, no native frame access or layout, membership/discovery/repair deferral')
