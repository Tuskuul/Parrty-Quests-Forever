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
for _,file in ipairs({'Core.lua','QuestDialogStyle.lua','QuestLogLinks.lua','QuestLogCopy.lua','BattleNetQuestLinks.lua','QuestShareDestinations.lua','QuestLogSharePicker.lua'}) do
 assert(loadfile(file))('SimplyPartyQuests',A)
end
local character='Owner-Realm'
GetUnitName=function() return character end
UnitGUID=function() return 'self-guid' end
function A:ReadOwn() end
function A:InitQuestLogLinks() return true end
function A:QuestLinkTrace() end
A.questLinkComms=true
A.own={[101]={id=101,title='One',objectives={}},[202]={id=202,title='Two',objectives={}}}
local copied=assert(A:CreateCopiedQuestLogLink({[101]=true}))
local ref=assert(A:ParseCopiedQuestLogLink(copied))
local publisher=A:QuestLinkState();local payload=publisher.published[ref.token].payload
local sent={}
WOW_PROJECT_ID=1
C_BattleNet={
 GetAccountInfoByID=function(id)
  assert(id==42)
  return {gameAccountInfo={clientProgram='WoW',isOnline=true,gameAccountID=900,characterName='Owner',realmName='Realm',wowProjectID=1}}
 end,
 SendGameData=function(id,prefix,message) sent[#sent+1]={id=id,message=message};return 0 end,
}
character='Guest-Realm';A.questLinks=nil
local shown
function A:ShowSharedQuestLog(token,snapshot,message) self.sharedQuestLogToken=token;shown={token=token,snapshot=snapshot,message=message} end
local rendered=A:ObserveBattleNetQuestLogLink(copied,'CHAT_MSG_BN_WHISPER',42)
assert(rendered:find('|Haddon:SPQLOG:',1,true),'copied Battle.net marker was not clickable')
local observed=A:QuestLinkState().observed[ref.token]
assert(observed.owner=='BN:900' and observed.publisher=='Owner-Realm','copy did not preserve publisher plus Battle.net data route')
assert(A:ImportCopiedQuestLogLink(copied)==ref.token and A.questLinks.observed[ref.token].owner=='BN:900','Import replaced an observed Battle.net route with character whispers')
A:OpenQuestLogLink(ref.token)
assert(sent[1].id==900 and sent[1].message=='R|'..ref.token,'copied log requested the wrong transport')
A:ReceiveQuestLogLink('S|'..ref.token..'|10000|1|1|'..payload,'BN:900','WHISPER')
assert(shown.snapshot and shown.snapshot.quests[101] and not shown.snapshot.quests[202],'copied Battle.net log did not complete correctly')
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local forwarded='[Party Quests Log:aa-bb-3:'..hex('Other-Realm')..']'
assert(A:ObserveBattleNetQuestLogLink(forwarded,'CHAT_MSG_BN_WHISPER',42):find('|Haddon:SPQLOG:',1,true))
assert(A.questLinks.observed['aa-bb-3'].owner=='Other-Realm','forwarded copy was rebound to the forwarding friend')
local offerCopy='[Party Quests Offer:aa-bb-5:'..hex('Owner-Realm')..']'
assert(A:ObserveBattleNetQuestLogLink(offerCopy,'CHAT_MSG_BN_WHISPER',42):find('|Haddon:SPQLOG:',1,true))
assert(A.questLinks.observed['aa-bb-5'].offer and A.questLinks.observed['aa-bb-5'].owner=='Owner-Realm','Battle.net text changed an offer into an unrestricted log route')
local forged='[Party Quests Log:'..ref.token..':'..hex('Attacker-Realm')..']'
assert(A:ObserveBattleNetQuestLogLink(forged,'CHAT_MSG_BN_WHISPER',42)==forged and A.questLinks.observed[ref.token].owner=='BN:900','conflicting publisher replaced a known token')
assert(A:ObserveBattleNetQuestLogLink('[Party Quests Log:aa-bb-4]','CHAT_MSG_BN_WHISPER',42):find('|Haddon:SPQLOG:',1,true),'original non-copy Battle.net marker regressed')
A.questLinks=publisher;character='Owner-Realm'
assert(A:ObserveBattleNetQuestLogLink(copied,'CHAT_MSG_BN_WHISPER_INFORM',42):find('|Haddon:SPQLOG:',1,true),'own outgoing copy was not published/rendered')

-- Destination enumeration, membership changes and stable channel identity.
local grouped,guild=true,true
IsInGroup=function() return grouped end;IsInRaid=function() return false end;IsInGuild=function() return guild end
local channels={1,'General',false,4,'LookingForGroup',false,7,'Muted',true}
GetChannelList=function() return unpack(channels) end
local destinations=A:GetQuestShareDestinations()
assert(#destinations==8 and destinations[2].kind=='PARTY' and destinations[3].kind=='GUILD')
assert(destinations[6].id==1 and destinations[7].id==4 and not destinations[8].enabled,'joined channel triples or disabled channels misread')
local lfg=destinations[7];channels[5]='Replacement'
assert(not A:ValidateQuestShareDestination(lfg),'reused channel ID redirected a selected destination')
channels[5]='LookingForGroup'
guild=false;assert(not A:ValidateQuestShareDestination(destinations[3]));guild=true
grouped=false;assert(not A:ValidateQuestShareDestination(destinations[2]));grouped=true

-- Public drafting must never send, replace an existing draft, or expose WIM text.
SendChatMessage=function() error('destination picker must not send automatically') end
local public=widget();public.attrs={chatType='BN_WHISPER',tellTarget=42};public.text=''
function public:SetAttribute(k,v) self.attrs[k]=v end
function public:SetCursorPosition(v) self.cursor=v end
function public:UpdateHeader() self.updated=true end
ChatEdit_ChooseBoxForSend=function() return public end
ChatEdit_ActivateChat=function(box) assert(box==public);box:Show() end
local private=widget();private.text='Private draft'
function private:SetCursorPosition(v) self.cursor=v end
function private:Insert(text) self.text=self.text..text end
local draft={box=private,text='Private draft',cursor=13,attributes={},kind='WIM'}
assert(A:InsertQuestLogChatLink('LINK',draft,destinations[4]))
assert(public.text=='LINK' and public.attrs.chatType=='SAY' and public.attrs.tellTarget==nil and private.text=='Private draft','public selection leaked or altered private draft')
public.text='Unsent text'
local ok,reason=A:InsertQuestLogChatLink('LINK',draft,lfg)
assert(not ok and reason:find('draft',1,true) and public.text=='Unsent text','occupied public editor was overwritten')
local countBefore=0;for _ in pairs(A.questLinks.published) do countBefore=countBefore+1 end
assert(not A:DraftQuestLogLink(draft,{[101]=true},false,lfg),'draft preflight should refuse before publishing')
local countAfter=0;for _ in pairs(A.questLinks.published) do countAfter=countAfter+1 end
assert(countBefore==countAfter,'failed public draft evicted/published a snapshot')
public.text='';assert(A:InsertQuestLogChatLink('CHANNEL LINK',draft,lfg))
assert(public.attrs.chatType=='CHANNEL' and public.attrs.channelTarget==4 and public.updated)
assert(A:InsertQuestLogChatLink(' CURRENT',draft,destinations[1]))
assert(private.text=='Private draft CURRENT' and public.text=='CHANNEL LINK','Current chat did not preserve its captured custom editor')

-- Popup cancel/reopen/success preserves scope and finishes once.
local drafted
function A:DraftQuestLogLink(saved,ids,offer,destination) drafted={saved=saved,ids=ids,offer=offer,destination=destination};return true end
A:OpenQuestLogShare(draft);local picker=A.questSharePicker;A:ShowQuestShareSelection()
picker.rows[1]:SetChecked(true);picker.rows[1].scripts.OnClick(picker.rows[1])
picker.submit.scripts.OnClick()
local popup=A.questShareDestination
assert(popup.shown and not picker.shown and picker.destinationActive and picker.selected[101],'destination popup lost the chooser')
popup.cancel.scripts.OnClick()
assert(picker.shown and picker.draft==draft and picker.selected[101],'destination Cancel lost selection or private draft')
picker.submit.scripts.OnClick();A:OpenQuestLogShare({text='replacement'})
assert(not picker.shown and picker.draft==draft,'Share reopen replaced the active destination draft')
popup.rows[1].scripts.OnClick()
assert(drafted.saved==draft and drafted.ids[101] and drafted.destination.kind=='CURRENT','destination submit changed scope or original draft')
assert(not popup.shown and not picker.shown and picker.draft==nil and not picker.destinationActive,'committed destination left a popup or stale draft')
print('PASS: copied Battle.net routing/reassembly/import, original markers, forwarding identity, current/joined destinations, stale channel rejection, no auto-send, private/occupied draft preservation and popup cancel/reopen/commit')
