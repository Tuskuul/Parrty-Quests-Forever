-- Run from the test addon directory with Lua 5.1+.
CreateFrame=function() return setmetatable({},{__index=function() return function() end end}) end
GetTime=function() return 100 end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('Definitions.lua'))('SimplyPartyQuests',A)
function A:Changed() end
local complete=true
local info={questID=4641,title='Sting of the Scorpid',isHeader=false}
C_QuestLog={GetNumQuestLogEntries=function() return 1 end,GetInfo=function() return info end,
 GetQuestObjectives=function() return {{text='10/10 Scorpid Worker Tail',numFulfilled=10,numRequired=10,finished=true}} end,
 IsComplete=function(id) assert(id==4641);return complete end}
A:ReadOwn()
assert(A.own[4641].ready and A.own[4641].readyKnown,'dedicated API completion was ignored when GetInfo flag was absent')
local packet=A:Serialize()
local received=A:Deserialize(packet)
assert(received[4641].ready and A:IsQuestReady(received[4641]),'completion was lost in full-log sync')
complete=false;A:ReadOwn()
assert(A.own[4641].ready==false and A.own[4641].readyKnown)
received=A:Deserialize(A:Serialize())
received[4641].requirements={{text='10 required Scorpid Worker Tail'}}
assert(received[4641].ready==false and received[4641].readyKnown and not A:IsQuestReady(received[4641]),'confirmed incomplete status was overridden')
-- Old versions sent 0 for both missing and false readiness; use complete
-- per-player objectives with full requirement coverage for those legacy logs.
local legacy=A:Deserialize('Q\t4641\tSting of the Scorpid\t0\nO\t4641\t10/10 Scorpid Worker Tail\t10\t10')
legacy[4641].requirements={{text='10 required Scorpid Worker Tail'}}
assert(A:IsQuestReady(legacy[4641]),'legacy full-log 10/10 entry still lacked Ready')
legacy[4641].requirements[2]={text='1 required Hidden step'}
assert(not A:IsQuestReady(legacy[4641]),'partial coverage was incorrectly marked Ready')
-- API failure/absent info completion must remain unknown, not definite false.
C_QuestLog.IsComplete=function() error('unavailable') end
A:ReadOwn()
assert(A.own[4641].ready==nil and not A.own[4641].readyKnown)
info.isComplete=1;A:ReadOwn();assert(A.own[4641].ready,'GetInfo fallback failed')
info.isComplete=nil;C_QuestLog.IsComplete=function() return 1 end
A:ReadOwn();assert(A.own[4641].ready,'numeric completion result failed')
assert(not A:Deserialize('Q\t4641\tInvalid\tgarbage'),'invalid readiness marker was accepted')
print('PASS: completion API, missing flags, full-log sync, legacy 10/10 inference, authoritative incomplete state and complete requirement coverage')
