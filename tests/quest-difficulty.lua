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

-- Saved brightness applies to existing textures and input text independently.
assert(loadfile('QuestDialogStyle.lua'))('SimplyPartyQuests',A)
A.db={}
assert(A:QuestPaperBrightness()==65)
local paper={SetVertexColor=function(self,...) self.tint={...} end}
A.questDialogFrames={[{questPaper=paper}]=true}
local function font() return {SetTextColor=function(self,...) self.color={...} end} end
local body,input=font(),font()
A:StyleQuestDialogText(body,'body');A:StyleQuestDialogText(input,'input')
assert(body.color[1]>0.9 and input.color[1]<0.3,'dark paper or light field contrast failed')
local refreshed=0
A.RefreshQuestDifficultyViews=function() refreshed=refreshed+1 end
A:SetQuestPaperBrightness(100)
assert(A.db.questPaperBrightness==100 and paper.tint[1]==1 and paper.tint[2]==1)
assert(body.color[1]<0.3 and input.color[1]<0.3,'light paper contrast did not update live')
A:SetQuestPaperBrightness(-20)
assert(A.db.questPaperBrightness==35 and body.color[1]>0.9)
A:SetQuestPaperBrightness(0/0)
assert(A.db.questPaperBrightness==35 and refreshed==2,'invalid setting was saved')
A.db.questPaperBrightness='bad'
assert(A:QuestPaperBrightness()==65,'invalid saved preference lost the default')
print('PASS: saved/default/clamped parchment brightness, live texture/text changes and independent Copy/Import ink')

local function luminance(c)
 local function linear(v) return v<=0.04045 and v/12.92 or ((v+0.055)/1.055)^2.4 end
 return linear(c[1])*0.2126+linear(c[2])*0.7152+linear(c[3])*0.0722
end
local function contrast(a,b)
 local x,y=luminance(a),luminance(b)
 return (math.max(x,y)+0.05)/(math.min(x,y)+0.05)
end
local native={{1,0.1,0.1},{1,0.5,0.25},{1,1,0},{0.25,0.75,0.25},{0.5,0.5,0.5}}
for _,setting in ipairs({65,100}) do
 A.db.questPaperBrightness=setting
 local background=setting==65 and {0.55,0.38,0.24} or {0.88,0.70,0.43}
 for _,c in ipairs(native) do
  local adjusted={A:QuestPaperDifficultyColor(c[1],c[2],c[3])}
  assert(contrast(adjusted,background)>=contrast(c,background),'difficulty contrast regressed')
 end
end
print('PASS: all five difficulty colors improve or retain contrast on representative dark/light parchment')
