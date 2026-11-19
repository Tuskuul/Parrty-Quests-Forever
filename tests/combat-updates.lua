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

-- Repeated quest events preserve the earliest own-log read deadline.
A.ownDue=nil;A:ScheduleOwn();local deadline=A.ownDue
now=now+0.2;A:ScheduleOwn();assert(A.ownDue==deadline,'quest events postponed own-log reads')
A.ownDue=nil;A:CombatOwnTick();assert(A.ownDue,'combat heartbeat failed to schedule own-log read')
-- Combat exit must schedule the full layout that was deferred.
locked=false;A.integrationEvents=nil;A:InvalidateTrackerIntegration()
assert(A.integration.dirty,'post-combat layout did not remain schedulable')
locked=true;C_QuestLog={IsUnitOnQuest=function() error('catalog sweep queried during combat') end}
A.sweep={};A:PollTick()
assert(A.sweepStatus=='Quest sweep paused (combat)')
A.sweep=nil;A:StartSweep();assert(not A.sweep and A.sweepDue>now,'manual discovery built a catalog pass during combat')
print('PASS: combat queries/triggers, own-log read deadlines and heartbeat, membership/discovery deferral')

