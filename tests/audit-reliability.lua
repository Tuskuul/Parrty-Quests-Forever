unpack=unpack or table.unpack
Enum={TooltipDataLineType={QuestTitle=17,QuestPlayer=9,QuestObjective=8},TooltipDataType={QuestPartyProgress=24,Item=1}}
local now=100
GetTime=function() return now end
InCombatLockdown=function() return true end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
UnitName=function() return 'Me' end
local A={}
for _,f in ipairs({'Core.lua','Definitions.lua','LiveProgress.lua','QuestDialogStyle.lua','QuestLogLinks.lua','BattleNetQuestLinks.lua'}) do assert(loadfile(f))('SimplyPartyQuests',A) end
local changed=0;A.Changed=function() changed=changed+1 end
A.db={};A.members={}
local info={questID=101,title='Quest',isHeader=false}
local rows={{text='2/5 Item',numFulfilled=2,numRequired=5,finished=false}}
C_QuestLog={GetNumQuestLogEntries=function() return 1 end,GetInfo=function() return info end,
 GetQuestObjectives=function() return rows end,IsComplete=function() return false end}
A:ReadOwn();local good=A.own
A.progressPending=nil;A.sendPending=nil;local renders=changed
A:ReadOwn();assert(changed==renders and not A.progressPending,'unchanged reads trigger redraws or progress messages')
good=A.own
C_QuestLog.GetQuestObjectives=function() error('temporary API refusal') end
A:ReadOwn();assert(A.own==good and A.ownReadError and A.ownDue,'temporary API failure discarded good progress')
C_QuestLog.GetQuestObjectives=function() return nil end
A:ReadOwn();assert(A.own[101].objectives[1].done==2,'uncached objectives erased known counts')
C_QuestLog.GetInfo=function() return nil end;good=A.own
A:ReadOwn();assert(A.own==good,'partial log enumeration removed quests')
issecretvalue=function() error('predicate refused') end
assert(not A.public(1,'number') and not A.readable({}),'secret predicate refusal became readable')
A:ReadOwn();assert(A.own==good,'refused secrecy check discarded log')
issecretvalue=nil
C_QuestLog.GetInfo=function() return info end
C_QuestLog.GetQuestObjectives=function() return rows end
A:ReadOwn();assert(not A.ownReadError,'recovered API left permanent error')
C_QuestLog.GetNumQuestLogEntries=function() return 0 end
A:ReadOwn();assert(next(A.own)==nil and A.progressPending,'genuine empty log did not remove quests')
-- Bounds apply to both party progress and shared snapshots.
for _,payload in ipairs({'Q\t1\tX\t1\nO\t1\tItem\t-1\t5','Q\t1\tX\t1\nO\t1\tItem\t1e999\t5',
 'Q\t10000001\tX\t1','Q\t1\t'..string.rep('x',241)..'\t1'}) do
 assert(not A:Deserialize(payload),'invalid payload accepted')
end
assert(A:Deserialize('Q\t1\tX\t1\nO\t1\tItem\t6\t5'),'over-complete public counts were rejected')
-- Retry throttled sends without discarding a packet; bounded failure queues recovery.
A.members.friend={guid='friend',name='Friend',unit='party1',quests={}}
A.comms=true;A.queue={'packet1','packet2'}
local calls=0
C_ChatInfo={SendAddonMessage=function() calls=calls+1;return calls==1 and 2 or 0 end}
A:SendPartyPacket();assert(#A.queue==2,'throttled packet was discarded')
now=100.2;A:SendPartyPacket();assert(calls==1,'send retry ignored backoff')
now=100.6;A:SendPartyPacket();assert(#A.queue==1 and A.queue[1]=='packet2','retry sent or removed wrong packet')
C_ChatInfo.SendAddonMessage=function() error('transport down') end
for i=1,6 do now=now+0.6;A:SendPartyPacket() end
assert(#A.queue==0 and A.sendPending and not A.publishedQuests,'transport failure did not request full recovery')
-- Older full snapshots cannot roll newer deltas back; missing deltas request recovery.
local member=A.members.friend
A.MemberFromSender=function() return member end
C_ChatInfo.SendAddonMessage=function() return 0 end
A:Receive('17:1:1:Q\t101\tCurrent\t1','Friend')
A:Receive('16:1:1:Q\t101\tStale\t0','Friend')
assert(member.quests[101].title=='Current','older full packet rolled state back')
A:Receive('D19:1:1:R\t101','Friend')
assert(member.quests[101],'delta with a missing predecessor was applied')
member.progressSequence=nil
A:Receive('20:1:2:Q\t101\tPartial\t1','Friend')
A:Receive('1:1:1:Q\t101\tReloaded\t1','Friend')
assert(member.quests[101].title=='Reloaded','sender reload was blocked by an old incomplete packet')
-- Fresh per-quest addon progress remains authoritative even without a fresh full log.
member.syncedAt=nil;member.quests[101].syncedAt=now;member.quests[101].objectives={{text='4/5 Item',done=4,total=5}}
A:Consume({lines={{type=17,id=101,leftText='Current'},{type=9,guid='friend'},{type=8,leftText='1/5 Item',numFulfilled=1,numRequired=5}}},101)
assert(member.quests[101].objectives[1].done==4,'native tooltip overwrote fresh addon delta')
-- Corrupt optional preferences recover without resetting valid explicit opt-outs.
A.db={displayMode='broken',trackerSide='bad',sidebarWidth=0/0,minimapAngle=math.huge,size='bad',position={x=math.huge,y=0},
 expanded=7,questExpanded={kept=true},combatAutoHide=false,nativeTrackerRepair=false,diagLines={'old private capture'}}
A:NormalizeSavedSettings()
assert(A.db.displayMode=='blizzard' and A.db.sidebarWidth==420 and A.db.minimapAngle==140 and A.db.size.width==460 and not A.db.position)
assert(A.db.questExpanded.kept and A.db.combatAutoHide==false and A.db.nativeTrackerRepair==false and not A.db.diagLines)
A.db.diag=true;A:Diag('session capture');assert(A.diagLines[1] and not A.db.diagLines,'capture persisted in saved variables')
-- A changed chat draft is never overwritten when Share is submitted or cancelled.
local box={GetText=function() return 'New draft' end}
box.Insert=function() error('new draft overwritten') end
local ok=A:InsertQuestLogChatLink('marker',{box=box,text='Original draft'})
assert(ok==false,'newer chat draft was overwritten')
-- Snapshot response packets survive a temporary failure and clear stale transport errors.
A.questLinks={published={token={localTime=now}},outgoing={{token='token',target='Friend',message='S|packet'}},pending={}}
A.questLinkFrame={SetScript=function() end};A.QuestLinkTrace=function() end
local attempts=0
A.SendQuestLogPacket=function() attempts=attempts+1;return attempts>1 end
A:QuestLinkTransferTick();assert(#A.questLinks.outgoing==1,'snapshot packet dropped on failure')
now=now+0.6;A:QuestLinkTransferTick();assert(#A.questLinks.outgoing==0,'snapshot retry failed to drain')
print('PASS: transient/restricted log preservation, no unchanged redraws, bounded payloads, retry/recovery, ordered sync, delta ownership, saved-state repair, session-only captures, draft preservation and snapshot retries')
