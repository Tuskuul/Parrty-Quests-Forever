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
local now=100
GetTime=function() return now end
GetServerTime=function() return 10000 end
GetUnitName=function() return 'Tester-Realm' end

local active,hardware,pushFailure,blocked=false,false,false,false
local wire,pushes={},{}
local completionReads=0
GetUnitName=function(unit) return unit=='player' and active.name or active.peer end
UnitName=GetUnitName
UnitGUID=function(unit) return unit=='player' and active.name or active.peer end
InCombatLockdown=function() return active.combat end
local pushable={[101]=true,[202]=true,[404]=true}
C_QuestLog={
 IsPushableQuest=function(id) return pushable[id] or false end,
 IsQuestFlaggedCompleted=function() completionReads=completionReads+1;return false end,
 GetSelectedQuest=function() return active.selected end,
 SetSelectedQuest=function(id) active.selected=id end,
}
QuestLogPushQuest=function()
 if pushFailure and not hardware then error('requires owner hardware click') end
 if blocked and not hardware then active.questOfferEvents.scripts.OnEvent(nil,'ADDON_ACTION_BLOCKED','SimplyPartyQuests','QuestLogPushQuest()');return end
 pushes[#pushes+1]={owner=active.name,id=active.selected}
end
local function quest(id,title) return {id=id,title=title,objectives={}} end
local function client(name,peer)
 local a={name=name,peer=peer,selected=777}
 for _,file in ipairs({'Core.lua','ShareRequests.lua','QuestDialogStyle.lua','QuestLogLinks.lua','QuestLogCopy.lua','QuestOffers.lua','QuestLogSharePicker.lua'}) do assert(loadfile(file))('SimplyPartyQuests',a) end
 a.members={[peer]={guid=peer,name=peer,fullName=peer,unit='party1',connected=true,quests={},syncedAt=now}}
 function a:ReadOwn() end
 function a:InitQuestLogLinks() return true end
 function a:QuestLinkTrace(stage) self.stages=self.stages or {};self.stages[stage]=true end
 function a:SendQuestLogPacket(message,target) wire[#wire+1]={from=self.name,target=target,message=message};return true end
 function a:CaptureQuestLogChatDraft() return nil end
 a.questLinkComms=true;a.db={}
 return a
end
local owner=client('Owner-Realm','Guest-Realm')
local guest=client('Guest-Realm','Owner-Realm')
owner.own={[101]=quest(101,'Alpha'),[202]=quest(202,'Both have it'),[303]=quest(303,'Not shareable'),[404]=quest(404,'Known member has it')}
guest.own={[202]=quest(202,'Both have it')}
owner.own[101].ready=true;owner.own[101].objectives={{text='Private objective detail',finished=true}}
owner.members[owner.peer].quests={[202]=true,[404]=true}
active=owner
local offers=owner:GetShareableQuestOffers()
assert(#offers==1 and offers[1].id==101 and offers[1].missing[1]==owner.peer,'candidate list is not shareable-own minus known current party logs')
owner.members[owner.peer].syncedAt=now-121
assert(#owner:GetShareableQuestOffers()==0,'stale logs were treated as proof of absence')
owner.members[owner.peer].syncedAt=now
owner:OpenQuestLogShare();owner:ShowQuestShareSelection(true)
local picker=owner.questSharePicker
assert(picker.offers.text=='Open shareable' and picker.scope=='offer' and #picker.quests==1 and not picker.submit.enabled)
picker.rows[1]:SetChecked(true);picker.rows[1].scripts.OnClick(picker.rows[1]);assert(picker.copy.enabled)
local drafted
function owner:InsertQuestLogChatLink(marker) drafted=marker;return true end
assert(owner:DraftQuestLogLink(nil,{[101]=true},true) and drafted:find('Party Quests Offer:',1,true),'Share to chat did not draft an offer marker')
owner:ShowQuestLogTransfer('copy',{[101]=true},true)
assert(owner:ParseCopiedQuestLogLink(owner.questLogTransfer.edit.text).offer,'Copy Share link lost offer scope')
owner.questLogTransfer.close.scripts.OnClick()
assert(picker.shown and picker.scope=='offer' and picker.selected[101],'copy return lost offer selection')
local marker=assert(owner:CreateCopiedQuestLogLink({[101]=true},true))
assert(marker:find('Party Quests Offer:',1,true) and not owner:CreateCopiedQuestLogLink({[202]=true},true),'invalid or stale offer selection was published')
local ref=assert(owner:ParseCopiedQuestLogLink(marker));assert(ref.offer)
local token=ref.token
local published=owner:QuestLinkState().published[token]
local quests,isOffer=owner:ValidateQuestLinkPayload(published.payload)
assert(isOffer and quests[101] and not quests[202],'offer snapshot leaked unselected quests')
assert(not quests[101].ready and #quests[101].objectives==0 and not published.payload:find('Private objective detail',1,true),'offer carried unneeded objective/completion data')
assert(not owner:ValidateQuestLinkPayload('G\t1\n'..published.payload),'duplicate offer metadata accepted')
assert(completionReads==0,'publisher filtering or offer creation queried completion history')
active=guest
assert(guest:ImportCopiedQuestLogLink(marker)==token,'Import did not accept the copied offer')
assert(not guest:ImportCopiedQuestLogLink(marker:gsub('Offer:','Log:')),'same token was rebound to a different link purpose')
local changed=guest:ObserveQuestLogLink(marker,owner.name,'CHAT_MSG_PARTY')
assert(changed:find('Quest Offers',1,true),'offer marker did not become clickable')
guest:OpenQuestLogLink(token)
local request=table.remove(wire,1);assert(request.message=='R|'..token and request.target==owner.name)
active=owner;owner:ReceiveQuestLogLink(request.message,guest.name,'WHISPER')
while #owner:QuestLinkState().outgoing>0 do now=now+0.3;owner:QuestLinkTransferTick() end
while #wire>0 do
 local packet=table.remove(wire,1)
 active=guest;guest:ReceiveQuestLogLink(packet.message,owner.name,'WHISPER')
end
local received=guest:QuestLinkState().received[token]
assert(received and received.offer and received.quests[101],'offer transfer lost its purpose or quests')
assert(guest.sharedQuestLogWindow.title.text:find('Quest Offers',1,true))
assert(guest.sharedQuestLogWindow.rows[1].label.text:find('Check requirements',1,true))
guest.sharedQuestLogWindow.rows[1].scripts.OnClick()
request=table.remove(wire,1);assert(request and request.message=='Q|'..token..'|101','offer click did not request the real quest')
active=owner;owner:ReceiveQuestLogLink(request.message,guest.name,'WHISPER')
assert(#pushes==1 and pushes[1].id==101 and owner.selected==777,'native sharing used wrong quest or changed original selection')
local ack=table.remove(wire,1);active=guest;guest:ReceiveQuestLogLink(ack.message,owner.name,'WHISPER')
assert(guest:QuestOfferStatus(token):find('attempted',1,true),'ack claimed no native attempt')
-- Throttles, outsiders and quests not in the published allowlist cannot trigger native actions.
active=owner
owner:ReceiveQuestLogLink('Q|'..token..'|101','Outsider','WHISPER')
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER')
now=now+6;owner:ReceiveQuestLogLink('Q|'..token..'|202',guest.name,'WHISPER')
assert(#pushes==1,'outsider, repeated request or unoffered quest was pushed')
wire={}
-- Engine rejection queues exactly one owner confirmation; a hardware click retries.
now=now+6;pushFailure=true
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER')
assert(owner.selected==777 and #owner:QuestOfferState().confirmations==1 and owner.questOfferConfirmation.shown)
hardware=true;owner.questOfferConfirmation.share.scripts.OnClick();hardware=false
assert(#pushes==2 and #owner:QuestOfferState().confirmations==0 and not owner.questOfferConfirmation.shown,'owner confirmation failed')
-- Combat never selects or pushes a quest; it waits for an explicit owner click.
now=now+6;owner.combat=true;pushFailure=false
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER')
assert(#pushes==2 and not owner.questOfferConfirmation.share.enabled)
owner.combat=false;owner:UpdateQuestOfferConfirmation();hardware=true;owner.questOfferConfirmation.share.scripts.OnClick();hardware=false
assert(#pushes==3 and owner.selected==777,'post-combat confirmation lost the request')
-- A quest abandoned after publication must not be shared, including from queued confirmations.
now=now+6;owner.combat=true
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER')
owner.combat=false;owner.own[101]=nil;owner.questOfferConfirmation.share.scripts.OnClick()
assert(#pushes==3 and #owner:QuestOfferState().confirmations==0,'abandoned quest was shared')
owner.own[101]=quest(101,'Alpha')
-- Blocked-action notifications also trigger the confirmation fallback without reporting acceptance.
now=now+6;owner:QuestOfferState().manualOnly=false;blocked=true
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER')
assert(#owner:QuestOfferState().confirmations==1 and #pushes==3 and owner.selected==777)
blocked=false;owner.questOfferConfirmation:Hide()
-- Group departure and expired offers are rejected at the owner, not just hidden in the UI.
now=now+6;owner.members={}
owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER');assert(#pushes==3)
owner.members={[guest.name]={guid=guest.name,name=guest.name,unit='party1',connected=true,quests={},syncedAt=now}}
now=now+901;owner:ReceiveQuestLogLink('Q|'..token..'|101',guest.name,'WHISPER');assert(#pushes==3)
print('PASS: shareable filtering without completion history, unknown/stale log exclusion, offer UI/copy/transfer, recipient click, native selection restore, party/token/quest binding, throttles, combat and protected-action confirmation, abandoned/expired offers')
