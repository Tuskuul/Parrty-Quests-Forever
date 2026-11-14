-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
local function widget()
 local o={scripts={},shown=true,enabled=true}
 return setmetatable(o,{__index=function(_,k)
  if k=='CreateFontString' or k=='CreateTexture' then return function() return widget() end end
  if k=='SetScript' then return function(self,n,fn) self.scripts[n]=fn end end
  if k=='SetText' then return function(self,s) self.text=s end end
  if k=='GetStringHeight' then return function() return 14 end end
  if k=='SetChecked' then return function(self,v) self.checked=v end end
  if k=='GetChecked' then return function(self) return self.checked end end
  if k=='SetEnabled' then return function(self,v) self.enabled=v end end
  if k=='Show' then return function(self) self.shown=true end end
  if k=='Hide' then return function(self)
   local was=self.shown;self.shown=false
   if was and self.scripts.OnHide then self.scripts.OnHide(self) end
  end end
  if k:match('^[A-Z]') then return function() end end
  return nil
 end})
end
CreateFrame=function() return widget() end
UIParent=widget();UISpecialFrames={}
GetTime=function() return 100 end
GetServerTime=function() return 10000 end
GetUnitName=function() return 'Tester-Realm' end
local A={}
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogLinks.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogSharePicker.lua'))('SimplyPartyQuests',A)
A.own={
 [101]={id=101,title='Alpha',objectives={{text='Escort',done=0,total=0}}},
 [202]={id=202,title='Beta',ready=true,objectives={{text='Collect',done=2,total=2}}},
 [303]={id=303,title='Gamma',objectives={{text='Secret quest',done=1,total=3}}},
}
local own=A.own
function A:ReadOwn() end
function A:QuestLinkTrace() end
function A:InitQuestLogLinks() return true end
A.questLinkComms=true
C_QuestLog={GetQuestObjectives=function(id)
 return {{text=A.own[id].objectives[1].text,finished=id~=303}}
end}
local function size(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local token,full=A:CreateQuestLogSnapshot()
assert(token and size(A:ValidateQuestLinkPayload(full.payload))==3,'full log changed')
local _,subset=A:CreateQuestLogSnapshot({[101]=true,[202]=true})
local q=A:ValidateQuestLinkPayload(subset.payload)
assert(q and size(q)==2 and q[101] and q[202] and not q[303],'subset leaked a quest')
assert(q[101].objectives[1].finished and q[202].ready,'completion flags lost')
assert(not subset.payload:find('303',1,true) and not subset.payload:find('Secret quest',1,true),'unselected data leaked')
assert(A.own==own and A.own[303],'sharing mutated own quest log')
assert(not A:CreateQuestLogSnapshot({}),'empty selection became full log')
assert(not A:CreateQuestLogSnapshot({[999]=true}),'stale selection became full log')
local _,single=A:CreateQuestLogSnapshot({[202]=true})
assert(size(A:ValidateQuestLinkPayload(single.payload))==1)

local draft={text='Original draft',recipient='Original recipient'}
function A:CaptureQuestLogChatDraft() return draft end
local markers={}
function A:InsertQuestLogChatLink(marker,saved)
 assert(saved==draft,'popup lost chat draft or recipient')
 markers[#markers+1]=marker;return true
end
local function click(b) assert(b.enabled~=false,'disabled control clicked');b.scripts.OnClick(b) end
A:OpenQuestLogShare(draft)
local f=A.questSharePicker
assert(f.full.text=='Full log' and f.choose.text=='Select quests')
assert(not f.scroll.shown and #markers==0,'opening popup published a snapshot')
click(f.choose)
assert(#f.quests==3 and not f.submit.enabled,'selection should start empty')
f.rows[1]:SetChecked(true);click(f.rows[1])
f.rows[2]:SetChecked(true);click(f.rows[2])
assert(f.submit.enabled and f.status.text=='2 of 3 quests selected')
click(f.submit)
assert(not f.shown and #markers==1 and f.draft==nil)
local sharedToken=markers[1]:match('Log:([^%]]+)')
assert(sharedToken and size(A:ValidateQuestLinkPayload(A.questLinks.published[sharedToken].payload))==2)
A:OpenQuestLogShare(draft);click(f.full)
assert(#markers==2)
sharedToken=markers[2]:match('Log:([^%]]+)')
assert(size(A:ValidateQuestLinkPayload(A.questLinks.published[sharedToken].payload))==3)
local before=size(A.questLinks.published)
A:OpenQuestLogShare(draft);click(f.choose);click(f.cancel)
assert(markers[3]=='' and size(A.questLinks.published)==before,'cancel published a snapshot')
A:OpenQuestLogShare(draft);click(f.choose)
assert(not f.submit.enabled and not f.rows[1].checked,'old selection survived reopening')
A.own={};click(f.choose)
assert(#f.quests==0 and not f.submit.enabled and f.prompt.text=='Your quest log is empty.')
f:Hide()
print('PASS: full/single/multiple sharing, no unselected payload or flags, stale/empty rejection, unchanged own log, popup choices, draft preservation, cancellation and empty-log UI')
