unpack=unpack or table.unpack
local now=100
GetTime=function() return now end
InCombatLockdown=function() return true end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local function addon()
 local a={};assert(loadfile('Core.lua'))('SimplyPartyQuests',a)
 a.comms=true;a.db={};a.Changed=function() end
 return a
end
local sender,receiver=addon(),addon()
local member={guid='friend',quests={}}
receiver.members.friend=member
receiver.MemberFromSender=function() return member end
sender.members.friend={quests={}}
local function q(id,done) return {id=id,title='Quest '..id,ready=false,readyKnown=true,objectives={{text=done..'/5 Items',done=done,total=5}}} end
sender.own={[101]=q(101,1),[102]=q(102,2)}
local function deliver()
 local messages=sender.queue;sender.queue={}
 for _,msg in ipairs(messages) do assert(#msg<=255);receiver:Receive(msg,'friend') end
 return messages
end
sender:SendSnapshot();deliver()
assert(member.quests[101].objectives[1].done==1 and member.quests[102])
now=100.4;sender.own[101]=q(101,3);sender:SendProgressDelta()
assert(#sender.queue>0 and sender.queue[1]:sub(1,1)=='D','sub-second change waited for full-log cooldown')
local messages=deliver()
assert(member.quests[101].objectives[1].done==3 and member.quests[102],'delta replaced unrelated quests')
assert(member.syncedAt==100,'partial update renewed full-log freshness')
now=100.8;sender.own[101]=q(101,4);sender:SendProgressDelta();deliver()
for _,msg in ipairs(messages) do receiver:Receive(msg,'friend') end
assert(member.quests[101].objectives[1].done==4,'stale delta rolled progress back')
now=101.2;sender.own[102]=nil;sender:SendProgressDelta();deliver()
assert(not member.quests[102] and member.removedQuests[102],'removed quest survived delta')
now=101.6;sender:SendProgressDelta();assert(#sender.queue==0,'unchanged data sent a delta')
-- Legacy clients can reload with a reset packet serial; full snapshots remain compatible.
receiver:Receive('1:1:1:Q\t103\tLegacy\t1','friend')
assert(member.quests[103] and not member.quests[101],'legacy full snapshot no longer replaces whole log')
assert(not receiver:Deserialize('R\t103'),'deletion accepted in full snapshot')
assert(not receiver:Deserialize('R\t103\nQ\t103\tConflict\t1',true),'conflicting delta accepted')
-- Multipart updates are atomic and do not interrupt an in-flight full snapshot.
now=106;sender.own={[101]=q(101,1)};sender.own[101].title=string.rep('Long quest ',18)
sender:SendSnapshot();assert(#sender.queue>1)
local before=#sender.queue;sender:SendProgressDelta();assert(#sender.queue==before)
receiver:Receive(sender.queue[1],'friend');assert(member.quests[103],'incomplete packet applied')
deliver();assert(member.quests[101].title==sender.own[101].title)
-- Party events bypass empty-result backoff; ordinary queries retain bounded pacing.
Enum={TooltipDataLineType={QuestTitle=17,QuestPlayer=9,QuestObjective=8},TooltipDataType={QuestPartyProgress=24,Item=1}}
local A=addon();assert(loadfile('LiveProgress.lua'))('SimplyPartyQuests',A)
A.members.friend={guid='friend',unit='party1',quests={[101]={id=101,objectives={}}}}
A.partyQueryCache[101]={at=now,empty=3};A.own={}
local queries=0
C_TooltipInfo={GetQuestPartyProgress=function() queries=queries+1;return {dataInstanceID=9,lines={}} end}
now=now+1;A:QueryPartyProgress(101);assert(queries==0)
A.liveTriggerContext='UNIT_QUEST_LOG_CHANGED';A:QueryPartyProgress(101);assert(queries==1,'fresh signal obeyed empty backoff')
A.liveTriggerContext=nil
A:TooltipDataUpdated(8);A:TooltipRetryTick();assert(queries==1,'unrelated tooltip retried query')
A:TooltipDataUpdated(9);A:TooltipRetryTick();assert(queries==2,'cache notification did not retry query')
A:TooltipRetryTick();assert(queries==2,'cache notification retried continuously')
for i=1,80 do A:LiveQuery('item',function() return {dataInstanceID=i,lines={}} end,nil,i) end
local count=0;for _ in pairs(A.tooltipQueries) do count=count+1 end
assert(count<=64,'tooltip query cache grew unbounded')
now=now+31;A:TooltipRetryTick();assert(next(A.tooltipQueries)==nil,'old tooltip queries retained')
-- Native per-objective completion flags survive normalization without invented counts.
assert(loadfile('Definitions.lua'))('SimplyPartyQuests',A)
A.members.friend.name='Friend';A.members.friend.fullName='Friend';A.members.friend.firstName='Friend'
A.MemberFromName=function(_,name) if name=='Friend' then return A.members.friend,true end end
local native={lines={{type=9,leftText='Friend'},{type=8,leftText='Free the prisoner',completed=true}}}
A:RecordLiveData('party-progress',native,101)
assert(A.members.friend.quests[101].objectives[1].finished==true,'native completion flag lost')
A.members.friend.quests[101].requirements={{text='Free the prisoner'}}
assert(A:IsQuestReady(A.members.friend.quests[101]),'all-step native completion not recognized')
native.lines[2].completed=false
A:RecordLiveData('party-progress',native,101)
assert(A.members.friend.quests[101].objectives[1].finished==false and not A:IsQuestReady(A.members.friend.quests[101]),'native incomplete flag ignored')
print('PASS: fast atomic quest deltas, removal, stale-delta rejection, legacy full sync, unchanged suppression, multipart pacing, urgent native polling and bounded cache-resolution retries')
