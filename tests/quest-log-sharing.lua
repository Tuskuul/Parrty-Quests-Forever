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
assert(loadfile('Core.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestDialogStyle.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogLinks.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestShareDestinations.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogSharePicker.lua'))('SimplyPartyQuests',A)
assert(loadfile('QuestLogCopy.lua'))('SimplyPartyQuests',A)
A.own={
 [101]={id=101,title='Alpha',objectives={{text='Escort',done=0,total=0,finished=true}}},
 [202]={id=202,title='Beta',ready=true,objectives={{text='Collect',done=2,total=2,finished=true}}},
 [303]={id=303,title='Gamma',objectives={{text='Secret quest',done=1,total=3,finished=false}}},
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
click(f.submit);click(A.questShareDestination.rows[1])
assert(not f.shown and #markers==1 and f.draft==nil)
local sharedToken=markers[1]:match('Log:([^%]]+)')
assert(sharedToken and size(A:ValidateQuestLinkPayload(A.questLinks.published[sharedToken].payload))==2)
A:OpenQuestLogShare(draft);click(f.full)
assert(#markers==1,'choosing full log sent a message')
click(f.submit);click(A.questShareDestination.rows[1])
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

-- Copied links carry their publisher when pasted by a different player.
A.own=own
local copied=assert(A:CreateCopiedQuestLogLink({[101]=true,[202]=true}))
assert(#copied<=255,'copy exceeds normal chat message length')
local ref=assert(A:ParseCopiedQuestLogLink(copied))
assert(ref.owner=='Tester-Realm' and ref.token,'copy lost publisher')
local publisher=A.questLinks
assert(publisher.published[ref.token].published,'copied log cannot be fetched')
local selected=A:ValidateQuestLinkPayload(publisher.published[ref.token].payload)
assert(size(selected)==2 and not selected[303],'copy leaked unselected quest')
-- Difficulty coloring is presentation only, including quests in snapshots.
C_PlayerInfo={GetContentDifficultyQuestForPlayer=function(id) return id end}
GetDifficultyColor=function() return {r=1,g=0.1,b=0.1} end
A:OpenQuestLogShare(draft);A:ShowQuestShareSelection()
assert(f.rows[1].caption.text:find('|cffff1a1aAlpha|r',1,true),'selector title lacks native difficulty')
assert(f.rows[2].caption.text:find(A:QuestDialogColorCode('ready')..'[Ready]|r',1,true),'difficulty replaced Ready status')
A:ShowSharedQuestLog('colors',{quests=own,owner='Tester',created=0})
assert(A.sharedQuestLogWindow.rows[1].label.text:find('|cffff1a1aAlpha|r',1,true),'snapshot title lacks native difficulty')
assert(not A:Serialize():find('|c',1,true),'presentation color leaked into packets')
f.selected[101]=true
local selectedBefore=f.selected
GetDifficultyColor=function() return {r=0.5,g=0.5,b=0.5} end
A:RefreshQuestDifficultyViews()
assert(f.selected==selectedBefore and f.selected[101],'recolor reset selection')
assert(f.rows[1].caption.text:find('|cff808080Alpha|r',1,true),'open selector did not recolor')
assert(A.sharedQuestLogWindow.rows[1].label.text:find('|cff808080Alpha|r',1,true),'open snapshot did not recolor')

A.sharedQuestLogWindow:Hide();f:Hide()
C_PlayerInfo=nil;GetDifficultyColor=nil
local sends,shown={},{}
function A:SendQuestLogPacket(message,target) sends[#sends+1]={message=message,target=target};return true end
function A:WakeQuestLinkTransfers() end
function A:ShowSharedQuestLog(token,snapshot,message) self.sharedQuestLogToken=token;shown={token=token,snapshot=snapshot,message=message} end
A.questLinks=nil
local rendered=A:ObserveQuestLogLink('Check '..copied,'Forwarder-Realm','CHAT_MSG_GUILD')
assert(rendered:find('|Haddon:SPQLOG:',1,true),'copied marker not clickable')
assert(A.questLinks.observed[ref.token].owner=='Tester-Realm','forwarder stole ownership')
local receiver=A.questLinks
A:OpenQuestLogLink(ref.token)
assert(sends[#sends].target=='Tester-Realm' and sends[#sends].message=='R|'..ref.token,'request routed to forwarder')
A.questLinks=publisher
A:ReceiveQuestLogLink('R|'..ref.token,'Recipient-Realm','WHISPER')
assert(#publisher.outgoing>0,'owner did not supply copied snapshot')
A.questLinks=receiver
for _,packet in ipairs(publisher.outgoing) do
 A:ReceiveQuestLogLink(packet.message,'Tester-Realm','WHISPER')
end
assert(shown.snapshot and size(shown.snapshot.quests)==2,'copy transfer failed')
assert(shown.snapshot.quests[101].objectives[1].finished,'copy lost event completion')
assert(shown.snapshot.quests[202].ready and not shown.snapshot.quests[303],'copied Ready/subset changed')
assert(A.own==own and A.own[303],'import altered player quest log')

local sentBefore=#sends
for _,bad in ipairs({'','not a link','https://example.com','[Party Quests Log:abc]',copied:sub(1,-2),copied..'extra',string.rep('a',256),
 '[Party Quests Log:a-b-c:0]','[Party Quests Log:a-b-c:00]','[Party Quests Log:a-b-c:7c486974656d]','[Party Quests Log:a-b-c:0a]'}) do
 assert(not A:ImportCopiedQuestLogLink(bad),'invalid import accepted: '..bad)
end
assert(#sends==sentBefore,'invalid import sent traffic')
assert(A:ImportCopiedQuestLogLink(' \n'..copied..'\n ')==ref.token,'surrounding whitespace rejected')
receiver.observed[ref.token]={owner='Different-Realm',localTime=100}
assert(not A:ImportCopiedQuestLogLink(copied),'conflicting publisher replaced')
assert(A:ObserveQuestLogLink(copied,'Forwarder-Realm','CHAT_MSG_PARTY')==copied,'conflicting link rendered')
A.questLinks=nil

-- Copy/import dialogs preserve the original draft and selected scope.
A:OpenQuestLogShare(draft);click(f.choose)
assert(f.submit.text=='Share to chat' and f.copy.text=='Copy Share link' and f.import.text=='Import')
assert(not f.copy.enabled,'empty selection can be copied')
f.rows[2]:SetChecked(true);click(f.rows[2])
local beforeMarkers=#markers
click(f.copy)
local transfer=A.questLogTransfer
local uiCopy=transfer.edit:GetText();local uiRef=assert(A:ParseCopiedQuestLogLink(uiCopy))
assert(transfer.edit.highlighted and not transfer.submit.shown,'copy is not selected for Ctrl+C')
assert(not f.shown and transfer.shown,'copy overlaps chooser on first open')
A:OpenQuestLogShare({text='Another draft'})
assert(not f.shown and transfer.shown and f.draft==draft,'reopening Share overlaps active copy or replaces draft')
assert(#markers==beforeMarkers and f.draft==draft,'copy changed chat draft')
assert(size(A:ValidateQuestLinkPayload(A.questLinks.published[uiRef.token].payload))==1,'copy ignored scope')
transfer.edit:SetText('changed')
assert(transfer.edit:GetText()==uiCopy,'copy field lost original string')
click(transfer.close)
assert(f.shown and f.selected[202] and f.draft==draft,'closing copy lost selection/draft')
click(f.import);transfer.edit:SetText('bad');click(transfer.submit)
assert(transfer.shown and not f.shown and transfer.status.text~='','invalid import closed popup or overlaps chooser')
transfer.edit:SetText(uiCopy);click(transfer.submit)
assert(not transfer.shown and not f.shown,'successful import left popups open')
assert(shown.snapshot and shown.snapshot.quests[202] and size(shown.snapshot.quests)==1,'import did not open selected snapshot')
assert(markers[#markers]=='','import sent or modified chat draft')
A:OpenQuestLogShare(draft);click(f.copy)
transfer.scripts.OnDragStart(transfer);transfer.scripts.OnDragStop(transfer)
transfer.edit.scripts.OnEscapePressed(transfer.edit)
assert(f.shown and f.scope=='full' and f.draft==draft,'Escape did not return to chooser')
click(f.import)
assert(not f.shown and transfer.shown,'import overlaps chooser on repeat open')
click(transfer.close)
assert(f.shown and f.draft==draft,'import Cancel lost original chooser/draft')
click(f.cancel)
assert(not transfer.shown and f.draft==nil,'cancel left copy open')

GetTime=function() return 1101 end
A:PruneQuestLinks()
assert(not A.questLinks.published[uiRef.token],'copy never expired')
print('PASS: full/selected chat sharing, copied publisher routing and transfer, completion flags, bounded/invalid imports, no cache/log mutation, copy/import UI and draft preservation, expiry')

