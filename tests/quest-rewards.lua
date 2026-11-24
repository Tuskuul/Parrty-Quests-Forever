local now,reads=0,0
GetTime=function() return now end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestRewards.lua'))('SimplyPartyQuests',A)
local value=2350
GetQuestLogRewardXP=function(id) reads=reads+1;assert(id==42);return value end
C_QuestLog={SetSelectedQuest=function() error('reward query changed selected quest') end}
assert(A:QuestRewardXPText(42,false)==nil and reads==0)
assert(A:QuestRewardXPText(42,true)=='2,350 XP' and reads==1)
A:QuestRewardXPText(42,true);assert(reads==1)
now=31;value=0;assert(A:QuestRewardXPText(42,true)==nil)
now=62;value=-1;assert(A:QuestRewardXPText(42,true)==nil)
now=93;value=0/0;assert(A:QuestRewardXPText(42,true)==nil)
local secret={};issecretvalue=function(v) return v==secret end
now=124;value=secret;assert(A:QuestRewardXPText(42,true)==nil)
now=155;GetQuestLogRewardXP=function() error('unavailable') end
assert(A:QuestRewardXPText(42,true)==nil)
assert(A:QuestRewardXPText(-1,true)==nil)
-- Real row reuse reserves width, then clears XP on a non-ready/non-quest row.
local function label()
 return {SetFont=function() end,GetFont=function() return 'Font',12,'' end,
 SetTextColor=function() end,SetJustifyH=function() end,SetWordWrap=function() end,
 ClearAllPoints=function() end,SetPoint=function() end,
 SetText=function(self,v) self.text=v end,GetStringWidth=function() return 65 end,
 SetWidth=function(self,v) self.width=v end,Show=function(self) self.shown=true end,
 Hide=function(self) self.shown=false end}
end
local row={CreateFontString=label};local text=label()
A:LayoutQuestRewardXP(row,text,'2,350 XP',300)
assert(text.width==223 and row.rewardXP.text=='2,350 XP' and row.rewardXP.shown)
A:LayoutQuestRewardXP(row,text,nil,300)
assert(text.width==300 and not row.rewardXP.shown,'pooled row retained XP or narrow title')
print('PASS: ready-only viewer XP, no selection changes, bounded refresh, unavailable/zero/restricted values and collision-free pooled row layout')
