-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
CreateFrame=function() return setmetatable({},{__index=function() return function() end end}) end
GetTime=function() return 100 end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('Definitions.lua'))('SimplyPartyQuests',A)
assert(loadfile('TrackerIntegration.lua'))('SimplyPartyQuests',A)
local function quest(id,title,item,done,total)
 return {id=id,title=title,lastNativeSource='native',
  objectives=done and {{text=done..'/'..total..' '..item,done=done,total=total}} or {},
  requirements={{text=total..' required '..item}}}
end
local foul=quest(501,'Foul Magics','Bloodstone Amulet',10,10)
local spirits=quest(502,'Raising Spirits','Highland Raptor Eye',10,10)
local sigil=quest(503,'Sigil of Strom','Sigil of Strom',nil,1)
local silky=quest(504,'Silky Sutures','Surgical Spider Silk',12,12)
assert(A:IsQuestReady(foul) and A:IsQuestReady(spirits) and A:IsQuestReady(silky))
foul.requirements[1].text='20 required Bloodstone Amulet'
assert(not A:IsQuestReady(foul),'mismatched required count tagged Ready')
foul.requirements[1].text='10 required Bloodstone Amulet'
assert(not A:IsQuestReady(sigil),'unknown progress tagged Ready')
local partial=quest(505,'Multi-step','First item',2,2)
partial.requirements[2]={text='3 required Second item'}
assert(not A:IsQuestReady(partial),'missing requirement tagged Ready')
partial.objectives[2]={text='2/3 Second item',done=2,total=3}
assert(not A:IsQuestReady(partial),'incomplete requirement tagged Ready')
partial.objectives[2]={text='3/3 Second item',done=3,total=3}
assert(A:IsQuestReady(partial),'all steps complete but no Ready')
partial.objectives[2]={text='Second item'}
assert(not A:IsQuestReady(partial),'unknown step tagged Ready')
partial.objectives[2]={text='Second item',finished=true}
assert(A:IsQuestReady(partial),'completed non-count step ignored')
foul.ready=false
assert(A:IsQuestReady(foul),'old native incomplete flag hid later complete counts')
foul.lastNativeSource=nil
assert(not A:IsQuestReady(foul),'explicit full-log incomplete flag was overridden')
foul.ready=true;foul.objectives={}
assert(A:IsQuestReady(foul),'explicit turn-in flag ignored')
foul=quest(501,'Foul Magics','Bloodstone Amulet',10,10)
local noDefinition=quest(506,'Unknown full objective list','Item',1,1)
noDefinition.requirements={}
assert(not A:IsQuestReady(noDefinition),'unknown requirement coverage tagged Ready')

-- The screenshot contains another player's quests; the local log is empty.
A.own={};A.db={combineShared=false,groupByZone=false,questExpanded={}}
local member={guid='party-member',name='Dahlina Shadowfoot',quests={[501]=foul,[502]=spirits,[503]=sigil,[504]=silky}}
function A:BuildPartyViewData()
 return {members={member},own=self.own,sections={[member.guid]={count=4,shared={},other={foul,spirits,sigil,silky}}}}
end
-- A readiness display must never query this player's progress for somebody else.
C_QuestLog={GetQuestObjectives=function() error('local progress queried for a party quest') end}
local entries=A:BuildTrackerEntries();local found={}
for _,e in ipairs(entries) do if e.kind=='quest' then found[e.id]=e end end
for _,id in ipairs({501,502,504}) do
 assert(found[id].title:find('[Ready]',1,true),'party quest title missing Ready')
 assert(found[id].lines[1]:find('Dahlina Shadowfoot:',1,true))
 assert(found[id].lines[1]:find('Ready for turn-in',1,true),'party member line missing Ready')
end
assert(not found[503].title:find('[Ready]',1,true))
assert(found[503].lines[1]:find('progress unknown',1,true))
assert(next(A.own)==nil and foul.ready==nil,'readiness display modified quest state')
print('PASS: other-player-only Ready tags, complete counts, all-step coverage, unknown/incomplete rejection, authoritative flags and no local progress access')
