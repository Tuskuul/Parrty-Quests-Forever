unpack=table.unpack
local now,locked=100,false
GetTime=function() return now end
InCombatLockdown=function() return locked end
CreateFrame=function() return {SetScript=function() end,RegisterEvent=function() end} end
local notices={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) notices[#notices+1]=text end}
local roster={'sync','native'}
IsInRaid=function() return false end
GetNumSubgroupMembers=function() return #roster end
UnitGUID=function(unit) return roster[tonumber(unit:match('%d+'))] end
UnitClass=function() return 'Druid','DRUID' end
UnitIsConnected=function() return true end
local requests=0
C_ChatInfo={SendAddonMessage=function() requests=requests+1 end}
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('Polling.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
function A:UpdateMemberName(m) m.name=m.guid end
function A:Changed() end
local reads,scans,known=0,{},0
function A:ReadOwn() reads=reads+1 end
function A:ScanUnit(unit) scans[unit]=true end
function A:RefreshKnown() known=known+1;self.liveDue=GetTime() end
function A:PopulateRequirements() end
function A:QueryPartyProgress() end
function A:QuestTitle(id) return 'Quest '..id end
local nativeCalls=0
C_QuestLog={IsUnitOnQuest=function(unit,id)
 assert(not locked,'discovery called during combat');nativeCalls=nativeCalls+1
 return unit=='party2' and id==42
end}
A.db={};A.comms=true;A.questCatalog={42,43};A.own={}
local old={id=7,title='Known',objectives={}}
A.members={sync={guid='sync',unit='party1',syncedAt=90,quests={[7]=old}}}
A.sweep={old=true};A.partyQueryCache={stale=true};A.questQueryState={stale=true}
local function button() return {SetText=function(self,text) self.text=text end} end
A.sidebar={refresh=button()};A.windowRefreshButton=button()
A.settingsControls={refresh=button()};A.questieDockMenu={buttons={button(),button()}}
A:RefreshParty()
local job=A.manualRefresh
assert(A.members.native and A.members.sync.quests[7]==old,'roster was not rebuilt or known data was erased')
assert(A.sweep and not A.sweep.old and not next(A.partyQueryCache) and not next(A.questQueryState),'stale discovery/cache reused')
assert(reads==1 and known==1 and scans.target and scans.mouseover and A.sendPending,'refresh sources omitted')
assert(A.sidebar.refresh.text=='Working' and A.settingsControls.refresh.text=='Working party quests')
A:RefreshParty();assert(A.manualRefresh==job and reads==1,'repeated clicks restarted work')
A:PartyRefreshTick();assert(requests==1,'fresh full logs were not requested')
local sweep=A.sweep
locked=true;now=102;A:PollTick();A:PartyRefreshTick()
assert(nativeCalls==0 and A.sweep==sweep,'combat discarded discovery work')
locked=false;A:PollTick()
assert(A.members.native.quests[42] and not A.sweep,'new non-addon member was not rediscovered')
now=106;A:PartyRefreshTick()
assert(A.manualRefresh,'an old synced log counted as a fresh full response')
A.members.sync.quests[9]={id=9};A.members.sync.progressAt=106
A:PartyRefreshTick();assert(A.manualRefresh,'a delta counted as a full log')
A.members.sync.quests={[8]={id=8}};A.members.sync.syncedAt=107
now=107;A:PartyRefreshTick()
assert(not A.manualRefresh and A.sidebar.refresh.text=='Refresh')
assert(A.partyRefreshStatus:find('1 full addon log') and A.partyRefreshStatus:find('1 game%-data quest match'),'results were not reported')

-- A combat click queues the entire rebuild, including the roster/log read.
locked=true;A:RefreshParty();assert(A.manualRefresh.queued and reads==1 and A.sidebar.refresh.text=='Queued')
A:RefreshParty();A:PartyRefreshTick();assert(reads==1)
locked=false;now=110;A:PartyRefreshTick();assert(reads==2 and not A.manualRefresh.queued)
-- Empty API replies and absent sync replies retain existing data and are visible.
C_QuestLog.IsUnitOnQuest=function() return false end
A:PollTick();now=131;A:PartyRefreshTick()
assert(not A.manualRefresh and A.members.native.quests[42],'empty responses erased observed data')
assert(A.partyRefreshStatus:find('did not return a fresh full log') and A.partyRefreshStatus:find('does not confirm an empty log'))

-- No discovery API is a reported limitation, not a successful empty rebuild.
C_QuestLog=nil;roster={'native'};now=140;A:RefreshParty();now=161;A:PartyRefreshTick()
assert(not A.manualRefresh and A.partyRefreshStatus:find('Quest discovery API unavailable'))
-- Solo manual visibility must survive roster reconciliation.
roster={};A.soloOverride=true;now=170;A:RefreshParty();now=176;A:PartyRefreshTick()
assert(A.soloOverride and not A.manualRefresh)
print('PASS: full manual refresh roster/cache rebuild, synced requests and new non-addon discovery, visible feedback, click coalescing, combat queue/resume, unreadable/empty preservation and solo intent')
