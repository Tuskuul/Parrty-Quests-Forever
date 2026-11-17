CreateFrame=function() return {SetScript=function() end,RegisterEvent=function() end} end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
local difficulty=1
C_PlayerInfo={GetContentDifficultyQuestForPlayer=function(id) assert(id==701);return difficulty end}
local colors={{r=1,g=0.1,b=0.1},{r=1,g=0.5,b=0.25},{r=1,g=1,b=0},{r=0.25,g=0.75,b=0.25},{r=0.5,g=0.5,b=0.5}}
local hex={'ff1a1a','ff8040','ffff00','40bf40','808080'}
GetDifficultyColor=function(value) return colors[value] end
for i=1,5 do
 difficulty=i
 assert(A:QuestTitleText(701,'Title')=='|cff'..hex[i]..'Title|r','native palette was changed')
end
assert(A:QuestTitleText(701,'|cffff0000Title|r |Hfoo|h')=='|cff808080Title ||Hfoo||h|r','untrusted title markup survived')
assert(A:QuestTitleText(nil,'Unknown')=='Unknown','invalid identity reached the native API')
colors[5]={r=0/0,g=1,b=1}
assert(A:QuestTitleText(701,'Unknown')=='Unknown','invalid native color was formatted')
C_PlayerInfo.GetContentDifficultyQuestForPlayer=function() error('restricted') end
assert(A:QuestTitleText(701,'Unknown')=='Unknown','failed native query broke rendering')
C_QuestLog={GetQuestDifficultyLevel=function(id) assert(id==701);return 33 end}
GetQuestDifficultyColor=function(level) assert(level==33);return {r=0,g=1,b=0} end
assert(A:QuestTitleText(701,'Fallback')=='|cff00ff00Fallback|r','legacy native fallback failed')
issecretvalue=function(value) return value==33 end
assert(A:QuestTitleText(701,'Unknown')=='Unknown','secret level was used')
issecretvalue=nil
C_QuestLog.GetQuestDifficultyLevel=function() return -1 end
assert(A:QuestTitleText(701,'Unknown')=='Unknown','missing level was guessed')
print('PASS: native viewer-relative difficulty palette, legacy fallback, unavailable/restricted data and title markup')
