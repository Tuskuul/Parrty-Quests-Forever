local _,A=...
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and not A.secret(value) then return value end
end
local function locked() return InCombatLockdown and InCombatLockdown() end
local function validID(id) return A.public(id,"number") and id>=1 and id<=10000000 and id%1==0 end
local function tokenOK(token) return A.public(token,"string") and #token<=48 and token:match("^[%x]+%-%x+%-%x+$")~=nil end
local function label(f,text,y)
    local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    A:StyleQuestDialogText(t,"body");t:SetPoint("TOPLEFT",16,y);t:SetWidth(408);t:SetJustifyH("LEFT");t:SetText(text);return t
end
function A:QuestOfferMember(name)
    if not self.public(name,"string") or not name:find("%S") then return nil end
    local match,target
    for guid,m in pairs(self.members) do
        if m.connected~=false and m.unit and call(UnitGUID,m.unit)==guid then
            local native=call(GetUnitName,m.unit,true)
            if self.public(native,"string") and native:lower()==name:lower() then
                if match then return nil end
                match,target=m,native
            end
        end
    end
    return match,target
end
function A:CanOfferQuest(id)
    if not validID(id) or not self.own[id] then return false end
    return call(C_QuestLog and C_QuestLog.IsPushableQuest,id)==true
end
function A:GetShareableQuestOffers()
    local now=GetTime();local peers={};local total=0
    for guid,m in pairs(self.members) do
        if m.connected~=false and m.unit and call(UnitGUID,m.unit)==guid then
            total=total+1
            if self.public(m.syncedAt,"number") and now-m.syncedAt>=0 and now-m.syncedAt<=120 then peers[#peers+1]=m end
        end
    end
    if total==0 then return {},"Join a party to find quests you can offer." end
    if #peers==0 then
        if self.Request then self:Request() end
        return {},"Waiting for current party logs. Party members need this addon; refresh party quests, then reopen this list."
    end
    if type(C_QuestLog and C_QuestLog.IsPushableQuest)~="function" then return {},"The client cannot check which quests you can share right now." end
    local offers={}
    if self.ownReadError then return offers,"Your quest log is temporarily unavailable." end
    for id,q in pairs(self.own) do
        if self:CanOfferQuest(id) then
            local missing={}
            for _,m in ipairs(peers) do if not m.quests[id] then missing[#missing+1]=m.name or m.fullName or "Party member" end end
            if #missing>0 then
                table.sort(missing)
                offers[#offers+1]={id=id,title=q.title,missing=missing}
            end
        end
    end
    return offers
end
function A:QuestOfferState()
    if not self.questOffers then self.questOffers={pending={},feedback={},peers={},confirmations={}} end
    local s=self.questOffers;local now=GetTime()
    for key,p in pairs(s.pending) do if now-p.at>120 then s.pending[key]=nil end end
    for key,p in pairs(s.feedback) do if now-p.at>900 then s.feedback[key]=nil end end
    for key,at in pairs(s.peers) do if now-at>60 then s.peers[key]=nil end end
    local n=0;for _ in pairs(s.feedback) do n=n+1 end
    while n>20 do
        local oldest,at
        for key,p in pairs(s.feedback) do if not at or p.at<at then oldest,at=key,p.at end end
        s.feedback[oldest]=nil;n=n-1
    end
    return s
end
function A:QuestOfferStatus(token)
    local status=self:QuestOfferState().feedback[token]
    return status and status.text
end
function A:SetQuestOfferStatus(token,text)
    local s=self:QuestOfferState();s.feedback[token]={at=GetTime(),text=text}
    local snapshot=self:QuestLinkState().received[token]
    if snapshot and self.sharedQuestLogToken==token and self.sharedQuestLogWindow and self.sharedQuestLogWindow:IsShown() then
        self:ShowSharedQuestLog(token,snapshot)
    end
end
function A:CheckQuestOfferEligibility(id,completionReader)
    if self.own[id] then return false,"Already in your quest log." end
    local ok,basic,basicReason=pcall(self.CheckBasicShareEligibility,self,id)
    if ok and basic==false then return false,basicReason end
    local api=C_QuestLog or {}
    local maximum=call(api.GetMaxNumQuestsCanAccept)
    if self.public(maximum,"number") and maximum>0 and type(api.GetNumQuestLogEntries)=="function" then
        local counted,_,used=pcall(api.GetNumQuestLogEntries)
        if counted and self.public(used,"number") and used>=maximum then return false,"Your quest log is full." end
    end
    local checked,eligible,reason=pcall(self.CheckShareEligibility,self,id,true,completionReader)
    if checked and eligible==false then return false,reason end
    if not ok or not checked then return nil,"The client could not verify the acceptance requirements." end
    if basic==nil then return nil,basicReason end
    return eligible,reason
end
function A:RequestOfferedQuest(token,id,snapshot)
    local s=self:QuestOfferState();self:PruneQuestLinks()
    local known=self:QuestLinkState().received[token]
    if not tokenOK(token) or not validID(id) or snapshot~=known or not known.offer or not known.quests[id] then return end
    local member,target=self:QuestOfferMember(known.owner)
    if not member then self:SetQuestOfferStatus(token,"The owner is no longer available in your party.");return end
    self:ReadOwn()
    if self.ownReadError then self:SetQuestOfferStatus(token,"Your quest log is temporarily unavailable.");return end
    local eligible,eligibilityReason=self:CheckQuestOfferEligibility(id)
    if eligible==false then
        self:QuestLinkTrace("offer-ineligible",token.." quest="..id)
        self:SetQuestOfferStatus(token,"Not eligible: "..eligibilityReason);return
    end
    local now=GetTime();local key=token..":"..id
    if (s.lastSent and now-s.lastSent<5) or (s.pending[key] and now-s.pending[key].at<15) then
        self:SetQuestOfferStatus(token,"A share was requested recently; please wait.");return
    end
    if not self:SendQuestLogPacket("Q|"..token.."|"..id,target) then
        self:SetQuestOfferStatus(token,"The request could not be sent. Try again shortly.");return
    end
    s.lastSent=now;s.pending[key]={at=now,owner=target,id=id}
    self:QuestLinkTrace("offer-request",token.." quest="..id)
    self:SetQuestOfferStatus(token,eligible==nil and ("Share requested; some requirements could not be verified. "..(eligibilityReason or "The game will check acceptance."))
        or "Share requested. Watch for the normal quest offer; the owner may need to confirm.")
end
function A:ValidateOfferedQuest(token,id,sender)
    self:PruneQuestLinks()
    local member,target=self:QuestOfferMember(sender)
    local offer=self:QuestLinkState().published[token]
    if not member or not offer or not offer.published or not offer.offer or not offer.offeredIDs or not offer.offeredIDs[id] then return nil end
    self:ReadOwn()
    if self.ownReadError or not self:CanOfferQuest(id) then return nil end
    return target,self.own[id]
end
function A:QuestOfferNativePush(token,id,target)
    if locked() then return false,"combat" end
    local api=C_QuestLog or {}
    if type(api.SetSelectedQuest)~="function" or type(api.GetSelectedQuest)~="function" or type(QuestLogPushQuest)~="function" then return false,"unavailable" end
    local previous=call(api.GetSelectedQuest)
    if not self.public(previous,"number") then return false,"unavailable" end
    local attempt={token=token,id=id,target=target,at=GetTime()}
    self.questOfferActiveAttempt=attempt
    local ok,result=pcall(function()
        api.SetSelectedQuest(id)
        if call(api.GetSelectedQuest)~=id then error("selected quest could not be verified") end
        return QuestLogPushQuest()
    end)
    local restored=pcall(api.SetSelectedQuest,previous)
    if not restored then self:QuestLinkTrace("offer-selection-restore-failed",token) end
    if attempt.blocked or not ok or (self.public(result,"boolean") and result==false) then
        self:QuestLinkTrace("offer-push-deferred",token.." quest="..id)
        return false,"confirm"
    end
    self:QuestLinkTrace("offer-push-attempt",token.." quest="..id)
    return true
end
function A:SendQuestOfferResult(token,id,target,status)
    self:SendQuestLogPacket("A|"..token.."|"..id.."|"..status,target)
end
function A:QueueQuestOfferConfirmation(token,id,target)
    local s=self:QuestOfferState()
    for _,p in ipairs(s.confirmations) do if p.token==token and p.id==id and p.target==target then return true end end
    if #s.confirmations>=8 then self:SendQuestOfferResult(token,id,target,"busy");return false end
    s.confirmations[#s.confirmations+1]={token=token,id=id,target=target,expires=GetTime()+90}
    self:SendQuestOfferResult(token,id,target,"queued")
    self:ShowQuestOfferConfirmation();return true
end
function A:ShowQuestOfferConfirmation()
    if not self.questOfferConfirmation then
        local f=CreateFrame("Frame","SimplyPartyQuestsOfferConfirm",UIParent,"BasicFrameTemplateWithInset")
        self.questOfferConfirmation=f
        self:StyleQuestDialog(f)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsOfferConfirm" end
        f:SetSize(440,180);f:SetPoint("CENTER",0,140);f:SetFrameStrata("MEDIUM")
        if self.readable(f.TitleText) then f.TitleText:SetText("Requested quest share") end
        f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function() f:StartMoving() end);f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        f.message=label(f,"",-40);f.status=label(f,"",-88)
        f.share=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.share:SetSize(130,24);f.share:SetPoint("BOTTOMLEFT",16,18);f.share:SetText("Share quest")
        f.cancel=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.cancel:SetSize(100,24);f.cancel:SetPoint("BOTTOMRIGHT",-16,18);f.cancel:SetText("Dismiss")
        f.share:SetScript("OnClick",function()
            local s=A:QuestOfferState();local p=s.confirmations[1]
            if not p or locked() then return end
            local target=A:ValidateOfferedQuest(p.token,p.id,p.target)
            if not target then table.remove(s.confirmations,1);A:UpdateQuestOfferConfirmation();return end
            local ok=A:QuestOfferNativePush(p.token,p.id,target)
            if ok then
                A:SendQuestOfferResult(p.token,p.id,target,"attempted");table.remove(s.confirmations,1);A:UpdateQuestOfferConfirmation()
            else f.status:SetText("The client could not share this quest. Try its normal Share Quest button.") end
        end)
        f.cancel:SetScript("OnClick",function() f:Hide() end)
        f:SetScript("OnHide",function()
            local s=A:QuestOfferState()
            for _,p in ipairs(s.confirmations) do A:SendQuestOfferResult(p.token,p.id,p.target,"dismissed") end
            s.confirmations={}
        end)
        f:SetScript("OnUpdate",function()
            if GetTime()>=(f.nextCheck or 0) then f.nextCheck=GetTime()+0.25;A:UpdateQuestOfferConfirmation() end
        end)
    end
    self:UpdateQuestOfferConfirmation()
end
function A:UpdateQuestOfferConfirmation()
    local s=self:QuestOfferState();local f=self.questOfferConfirmation
    if not f then return end
    while s.confirmations[1] do
        local p=s.confirmations[1]
        local offer=self:QuestLinkState().published[p.token]
        if GetTime()<=p.expires and offer and GetTime()-offer.localTime<=900 and self:QuestOfferMember(p.target) then break end
        self:SendQuestOfferResult(p.token,p.id,p.target,"unavailable");table.remove(s.confirmations,1)
    end
    local p=s.confirmations[1]
    if not p then f:Hide();return end
    local q=self.own[p.id]
    f.message:SetText(self:DisplayText(p.target).." requested:\n"..(q and self:QuestTitleText(p.id,q.title,true) or "Quest no longer in your log"))
    f.share:SetEnabled(not locked())
    f.status:SetText(locked() and "Share after combat ends." or "Shares through the normal party quest prompt.")
    f:Show()
end
function A:ReceiveQuestOfferPacket(message,sender)
    local token,rawID=message:match("^Q|([^|]+)|(%d+)$")
    if token then
        local id=tonumber(rawID)
        if not tokenOK(token) or not validID(id) then return true end
        local s=self:QuestOfferState();local member=self:QuestOfferMember(sender)
        if not member then return true end
        local now=GetTime()
        if s.peers[member.guid] and now-s.peers[member.guid]<5 then return true end
        s.peers[member.guid]=now
        local target=self:ValidateOfferedQuest(token,id,sender)
        if not target then self:SendQuestOfferResult(token,id,sender,"unavailable");return true end
        if s.lastPush and now-s.lastPush<5 then self:SendQuestOfferResult(token,id,target,"busy");return true end
        s.lastPush=now
        if locked() or s.manualOnly then self:QueueQuestOfferConfirmation(token,id,target);return true end
        local ok=self:QuestOfferNativePush(token,id,target)
        if ok then self:SendQuestOfferResult(token,id,target,"attempted")
        else s.manualOnly=true;self:QueueQuestOfferConfirmation(token,id,target) end
        return true
    end
    local status
    token,rawID,status=message:match("^A|([^|]+)|(%d+)|(%a+)$")
    if token then
        local id=tonumber(rawID)
        if not tokenOK(token) or not validID(id) then return true end
        local pending=self:QuestOfferState().pending[token..":"..id]
        if not pending or pending.owner:lower()~=sender:lower() or not self:QuestOfferMember(sender) then return true end
        local texts={attempted="The owner attempted the share. Watch for the normal quest offer.",queued="The owner needs to confirm the share. Combat may delay it.",busy="Another quest share is in progress. Try again shortly.",unavailable="The quest offer expired or the owner can no longer share it.",dismissed="The owner dismissed this share request."}
        if texts[status] then self:SetQuestOfferStatus(token,texts[status]) end
        return true
    end
    return false
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_ACTION_BLOCKED");events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent",function(_,_,addon,action)
    local p=A.questOfferActiveAttempt
    if addon~="SimplyPartyQuests" or not p or GetTime()-p.at>1 or not A.public(action,"string") then return end
    if not action:find("QuestLogPushQuest",1,true) and not action:find("SetSelectedQuest",1,true) then return end
    p.blocked=true;A:QuestOfferState().manualOnly=true
    A:QueueQuestOfferConfirmation(p.token,p.id,p.target)
end)
A.questOfferEvents=events
