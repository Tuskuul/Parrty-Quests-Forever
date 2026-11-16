-- Run from the addon directory with Lua 5.1+; no WoW client required.
unpack=unpack or table.unpack
local function widget()
 local o={scripts={},shown=true,enabled=true}
 return setmetatable(o,{__index=function(_,k)
  if k=='CreateFontString' or k=='CreateTexture' then return function() return widget() end end
  if k=='SetScript' then return function(self,n,fn) self.scripts[n]=fn end end
  if k=='SetText' then return function(self,s)
   self.text=s;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
  end end
  if k=='IsShown' then return function(self) return self.shown end end
  if k=='GetText' then return function(self) return self.text or '' end end
  if k=='HighlightText' then return function(self) self.highlighted=true end end
  if k=='SetShown' then return function(self,v) self.shown=v end end
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
for _,file in ipairs({'Core.lua','ShareRequests.lua','QuestEligibility.lua','QuestLogLinks.lua','QuestOffers.lua'}) do assert(loadfile(file))('SimplyPartyQuests',A) end
local level,race,class,used=28,2,1,0
local unavailable=false
local completed={}
local repeatable={}
UnitLevel=function() return level end
UnitRace=function() return 'Orc','Orc',race end
UnitClass=function() return 'Warrior','WARRIOR',class end
UnitGUID=function(unit) return unit=='party1' and 'peer-guid' or 'self-guid' end
GetUnitName=function(unit) return unit=='party1' and 'Owner-Realm' or 'Tester-Realm' end
InCombatLockdown=function() return false end
C_QuestLog={
 GetMaxNumQuestsCanAccept=function() return 25 end,
 GetNumQuestLogEntries=function() return 100,used end,
 IsQuestFlaggedCompleted=function(id) if unavailable then return nil end;return completed[id] or false end,
 IsRepeatableQuest=function(id) return repeatable[id] or false end,
}
A.own={};A.members={['peer-guid']={guid='peer-guid',unit='party1',name='Owner-Realm',connected=true}}
A.db={}
function A:ReadOwn() end
local sent=0
function A:SendQuestLogPacket() sent=sent+1;return true end
function A:QuestLinkTrace(stage) self.lastStage=stage end
local function check(id,expected,fragment)
 local value,reason=A:CheckQuestOfferEligibility(id)
 assert(value==expected and (not fragment or reason:find(fragment,1,true)),tostring(id)..': '..tostring(value)..' '..tostring(reason))
end
-- These are the actual reverse-share quests in the two live reports.
assert(A.questEligibility[701].level==29 and A.questEligibility[1361].level==30)
check(701,false,'Requires level 29')
check(1361,false,'Requires level 30')
unavailable=true;check(701,false,'Requires level 29')
unavailable=false;level=29;check(701,false,'prerequisite')
completed[675]=true;check(701,true)
completed[701]=true;check(701,false,'Already completed')
repeatable[701]=true;check(701,nil,'Repeatable')
repeatable[701]=nil;completed[701]=nil
race=3;check(701,false,'Race restriction');race=2
A.questEligibility[123]={level=1,races=0,classes=1,flags=0}
class=2;check(123,false,'Class restriction');class=1
check(123,true) -- A published offer has native shareability; static flags cannot override it.
assert(A:CheckShareEligibility(123)==false,'ordinary legacy requests lost their shareability check')
used=25;check(123,false,'quest log is full');used=24;check(123,true)
unavailable=true;check(701,nil,'Completion history');unavailable=false
check(999999,nil,'verification')
A.questEligibility[124]={level=1,races=0,flags=8,exclusive={500}}
completed[500]=true;check(124,false,'alternative quest');completed[500]=nil
A.questEligibility[125]={level=1,races=0,flags=8,skill=164}
check(125,nil,'Profession')
-- The recipient sees a reason, and a blocked click never sends an addon request.
level=28;used=0
local token='aa-bb-1'
local snapshot={owner='Owner-Realm',offer=true,created=10000,localTime=100,quests={[701]={id=701,title='Guile of the Raptor',objectives={}}}}
A:QuestLinkState().received[token]=snapshot
A:ShowSharedQuestLog(token,snapshot)
local row=A.sharedQuestLogWindow.rows[1]
assert(row.label.text:find('Not eligible',1,true),'known failure was not marked in the recipient list')
row.scripts.OnClick()
assert(sent==0 and A:QuestOfferStatus(token):find('Not eligible: Requires level 29',1,true),'ineligible request was sent or lacked a clear reason')
assert(A.lastStage=='offer-ineligible','eligibility denial was not diagnosable')
-- Recheck when clicked: a cached grey row must not block a newly eligible character.
level=29;row.scripts.OnClick()
assert(sent==1 and row.label.text:find('Request share',1,true),'level-up was not rechecked before requesting')
print('PASS: recipient-only eligibility and reasons, actual level-29/30 cases, missing prerequisites, completion/repeatables, race/class, log capacity, unknown-rule warnings, legacy shareability, no blocked sends and live click recheck')
