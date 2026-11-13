local _, A = ...
local PREFIX="SPQLOG1"
local TTL,MAX_BYTES,CHUNK=900,48000,140
local function key(s) return s:lower() end
local function tokenOK(s) return A.public(s,"string") and #s<=48 and s:match("^[%x]+%-%x+%-%x+$")~=nil end
local function safe(s)
    if not A.public(s,"string") then return "" end
    return s:gsub("[%z\1-\8\11\12\14-\31]",""):gsub("|","||")
end
local function ownName() return GetUnitName and GetUnitName("player",true) or UnitName("player") end
local function epoch() return GetServerTime and GetServerTime() or (time and time() or 0) end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function A:QuestLinkState()
    if not self.questLinks then self.questLinks={published={},observed={},received={},pending={},outgoing={},lastRequest={},serial=0} end
    return self.questLinks
end
function A:PruneQuestLinks()
    local s=self:QuestLinkState();local now=GetTime()
    for token,q in pairs(s.published) do if now-q.localTime>TTL then s.published[token]=nil end end
    for token,q in pairs(s.observed) do if now-q.localTime>1800 then s.observed[token]=nil end end
    for token,q in pairs(s.received) do if now-q.localTime>1800 then s.received[token]=nil end end
    local function trim(t,maximum)
        while count(t)>maximum do
            local oldest,at;for id,q in pairs(t) do if not at or q.localTime<at then oldest,at=id,q.localTime end end
            t[oldest]=nil
        end
    end
    trim(s.published,6);trim(s.observed,80);trim(s.received,20)
    for who,at in pairs(s.lastRequest) do if now-at>60 then s.lastRequest[who]=nil end end
end
function A:CreateQuestLogSnapshot()
    self:ReadOwn();self:PruneQuestLinks()
    local s=self:QuestLinkState();s.serial=s.serial+1
    local name=ownName();if not self.public(name,"string") or name=="" then return nil,"Your character name is unavailable." end
    local hash=0;for i=1,#name do hash=(hash*33+name:byte(i))%4294967296 end
    local token=string.format("%x-%x-%x",math.floor(epoch()),hash,s.serial)
    local payload=self:Serialize()
    -- Preserve native completion flags for event/escort objectives without counts.
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        for id,q in pairs(self.own) do
            local ok,objectives=pcall(C_QuestLog.GetQuestObjectives,id)
            if ok and self.readable(objectives) then
                local index=0
                for _,o in ipairs(objectives) do
                    if self.readable(o) and self.public(o.text,"string") then
                        index=index+1
                        if q.objectives[index] and q.objectives[index].text==o.text and self.public(o.finished,"boolean") then
                            payload=payload.."\nF\t"..id.."\t"..index.."\t"..(o.finished and "1" or "0")
                        end
                    end
                end
            end
        end
    end
    if #payload>MAX_BYTES then return nil,"The quest snapshot exceeds the sharing limit." end
    local snapshot={payload=payload,owner=name,created=epoch(),localTime=GetTime(),published=false}
    s.published[token]=snapshot;self:QuestLinkTrace("snapshot-created",token.." bytes="..#payload);self:PruneQuestLinks()
    return token,snapshot
end
function A:CaptureQuestLogChatDraft(box)
    local util=ChatFrameUtil or {}
    local active=util.GetActiveWindow or ChatEdit_GetActiveWindow
    box=box or (self.FocusedQuestLogCustomChatBox and self:FocusedQuestLogCustomChatBox()) or (active and active())
    if not box or type(box.GetText)~="function" or type(box.GetCursorPosition)~="function" then return nil end
    local text,cursor=box:GetText(),box:GetCursorPosition()
    if not self.public(text,"string") or not self.public(cursor,"number") then return nil end
    local kind=self.QuestLogChatBoxKind and self:QuestLogChatBoxKind(box)
    local draft={box=box,text=text,cursor=cursor,attributes={},kind=kind}
    if kind=="WIM" and self.readable(box.parentWindow) then
        draft.window=box.parentWindow;draft.recipient=box.parentWindow.theUser;draft.windowType=box.parentWindow.type
    end
    if not kind and type(box.GetAttribute)=="function" then
        for _,name in ipairs({"chatType","tellTarget","channelTarget","stickyType"}) do
            local value=box:GetAttribute(name)
            if value==nil or self.public(value,"string") or self.public(value,"number") then
                draft.attributes[#draft.attributes+1]={name=name,value=value}
            end
        end
    end
    return draft
end
function A:InsertQuestLogChatLink(marker,draft)
    local util=ChatFrameUtil or {}
    local active=util.GetActiveWindow or ChatEdit_GetActiveWindow
    local last=util.GetLastActiveWindow or ChatEdit_GetLastActiveWindow
    local choose=util.ChooseBoxForSend or ChatEdit_ChooseBoxForSend
    local activate=util.ActivateChat or ChatEdit_ActivateChat
    local box=(draft and draft.box) or (self.FocusedQuestLogCustomChatBox and self:FocusedQuestLogCustomChatBox()) or (active and active()) or (last and last()) or (choose and choose())
    draft=draft or self:CaptureQuestLogChatDraft(box)
    if box and type(box.Insert)=="function" then
        if draft and draft.window and (box.parentWindow~=draft.window or draft.window.theUser~=draft.recipient or draft.window.type~=draft.windowType) then
            return false -- A recycled WIM window must not redirect a captured draft.
        end
        if (draft and draft.kind) or (self.QuestLogChatBoxKind and self:QuestLogChatBoxKind(box)) then
            box:Show();box:SetFocus()
        elseif activate then activate(box) else box:Show();box:SetFocus() end
        if draft then
            -- Focus loss may already have cleared text and reset to sticky chat.
            box:SetText(draft.text)
            for _,attribute in ipairs(draft.attributes) do box:SetAttribute(attribute.name,attribute.value) end
            box:SetCursorPosition(draft.cursor)
            if type(box.HighlightText)=="function" then box:HighlightText(draft.cursor,draft.cursor) end
            if type(box.UpdateHeader)=="function" then box:UpdateHeader() end
        end
        box:Insert(marker)
        return true
    end
    if type(ChatFrame_OpenChat)=="function" then ChatFrame_OpenChat(marker);return true end
    return false
end
function A:DraftQuestLogLink(draft)
    draft=draft or self:CaptureQuestLogChatDraft()
    if not self:InitQuestLogLinks() then print("Party Quests: chat linking is unavailable in this client.");return end
    if not self.questLinkComms then print("Party Quests: addon communication is unavailable.");return end
    local token,err=self:CreateQuestLogSnapshot()
    if not token then print("Party Quests: "..err);return end
    -- A plain marker survives normal chat transport. Receiving copies turn it
    -- into Blizzard's local-only addon hyperlink without sending custom markup.
    if not self:InsertQuestLogChatLink("[Party Quests Log:"..token.."]",draft) then
        print("Party Quests: the chat entry box is unavailable.")
    end
end
function A:ObserveQuestLogLink(message,sender,event,senderGUID)
    if not self.public(message,"string") or not self.public(sender,"string") or sender=="" then return message end
    local s=self:QuestLinkState();self:PruneQuestLinks()
    return (message:gsub("%[Party Quests Log:([%x%-]+)%]",function(token)
        if not tokenOK(token) then return nil end
        local mine=s.published[token]
        local name=ownName()
        local own=event=="CHAT_MSG_WHISPER_INFORM" or (self.public(name,"string") and key(name)==key(sender))
        if self.public(senderGUID,"string") and senderGUID==UnitGUID("player") then own=true end
        if mine then
            if not own then return nil end
            mine.published=true;sender=mine.owner
        end
        local previous=s.observed[token]
        if previous and key(previous.owner)~=key(sender) then return nil end
        s.observed[token]={owner=sender,localTime=GetTime()}
        return "|cffffff00|Haddon:SPQLOG:"..token.."|h["..safe(sender).."'s Quest Log]|h|r"
    end))
end
function A:ValidateQuestLinkPayload(payload)
    if not self.public(payload,"string") or #payload>MAX_BYTES then return nil end
    local lines,flags={},{}
    for line in payload:gmatch("[^\n]+") do
        if line:sub(1,2)=="F\t" then
            local id,index,value=line:match("^F\t(%d+)\t(%d+)\t([01])$")
            if not id then return nil end
            id,index=tonumber(id),tonumber(index)
            local k=id..":"..index
            if flags[k] or index<1 or index>30 then return nil end
            flags[k]={id=id,index=index,finished=value=="1"}
        else lines[#lines+1]=line end
    end
    local quests=self:Deserialize(table.concat(lines,"\n"))
    if not quests then return nil end
    for _,flag in pairs(flags) do
        local q=quests[flag.id]
        if not q or not q.objectives[flag.index] then return nil end
        q.objectives[flag.index].finished=flag.finished
    end
    for id,q in pairs(quests) do
        if id>10000000 or #q.title>240 then return nil end
        for _,o in ipairs(q.objectives) do
            if #o.text>512 then return nil end
            for _,v in ipairs({o.done or 0,o.total or 0}) do
                if v~=v or v<0 or v>1000000 or v%1~=0 then return nil end
            end
        end
    end
    return quests
end
function A:OpenQuestLogLink(token)
    if not tokenOK(token) then return end
    self:PruneQuestLinks();local s=self:QuestLinkState()
    local ref=s.observed[token]
    if not ref then self:ShowSharedQuestLog(token,nil,"This link is unavailable. Ask the player to post a fresh quest-log link.");return end
    if ref.unavailable then self:ShowSharedQuestLog(token,nil,ref.unavailable);return end
    local mine=s.published[token]
    if mine and mine.published and key(mine.owner)==key(ref.owner) then
        local quests=self:ValidateQuestLinkPayload(mine.payload)
        self:ShowSharedQuestLog(token,{owner=mine.owner,created=mine.created,quests=quests});return
    end
    local cached=s.received[token]
    if cached and key(cached.owner)==key(ref.owner) then self:ShowSharedQuestLog(token,cached);return end
    if not self.questLinkComms then self:ShowSharedQuestLog(token,nil,"Addon communication is unavailable.");return end
    if s.pending[token] then self:ShowSharedQuestLog(token,nil,"Loading "..(ref.displayOwner or ref.owner).."'s quest log...");return end
    self:QuestLinkTrace("request-open",token.." route="..ref.owner)
    s.pending[token]={owner=ref.owner,displayOwner=ref.displayOwner,started=GetTime(),parts={}}
    if not self:SendQuestLogPacket("R|"..token,ref.owner) then
        s.pending[token]=nil;self:ShowSharedQuestLog(token,nil,"Unable to send the snapshot request. The client may restrict this data channel.");return
    end
    self:ShowSharedQuestLog(token,nil,"Loading "..(ref.displayOwner or ref.owner).."'s quest log... The owner must be online with this addon.")
    self:WakeQuestLinkTransfers()
end
function A:ReceiveQuestLogLink(message,sender,channel)
    if channel~="WHISPER" or not self.public(message,"string") or #message>255 or not self.public(sender,"string") then return end
    local s=self:QuestLinkState();self:PruneQuestLinks()
    local token=message:match("^R|(.+)$")
    if token then
        if not tokenOK(token) then return end
        local now=GetTime();local who=key(sender)
        if s.lastRequest[who] and now-s.lastRequest[who]<10 then return end
        if count(s.lastRequest)>=200 and not s.lastRequest[who] then return end
        s.lastRequest[who]=now
        local snapshot=s.published[token]
        self:QuestLinkTrace("request-received",token.." sender="..sender)
        if not snapshot or not snapshot.published then
            self:QuestLinkTrace("request-unavailable",token.." state="..(snapshot and "not-published" or "missing-or-expired"))
            self:SendQuestLogPacket("E|"..token.."|expired",sender);return
        end
        local total=math.max(1,math.ceil(#snapshot.payload/CHUNK))
        if #s.outgoing+total>400 then self:SendQuestLogPacket("E|"..token.."|busy",sender);return end
        for i=1,total do
            s.outgoing[#s.outgoing+1]={target=sender,token=token,message=table.concat({"S",token,snapshot.created,i,total},"|").."|"..snapshot.payload:sub((i-1)*CHUNK+1,i*CHUNK)}
        end
        self:QuestLinkTrace("reply-queued",token.." target="..sender.." packets="..total)
        self:WakeQuestLinkTransfers();return
    end
    token=message:match("^E|([^|]+)|[%a]+$")
    if token then
        local p=s.pending[token]
        if p and key(p.owner)==key(sender) then
            self:QuestLinkTrace("error-received",token.." sender="..sender)
            s.pending[token]=nil
            if self.sharedQuestLogToken==token then self:ShowSharedQuestLog(token,nil,"Snapshot expired, unavailable, or busy. Ask the owner for a fresh link.") end
        end
        return
    end
    local created,index,total,part
    token,created,index,total,part=message:match("^S|([^|]+)|(%d+)|(%d+)|(%d+)|(.*)$")
    if not tokenOK(token) then return end
    local p=s.pending[token]
    if not p or key(p.owner)~=key(sender) then
        self:QuestLinkTrace("reply-rejected",token.." sender="..sender.." expected="..(p and p.owner or "no pending request"));return
    end
    created,index,total=tonumber(created),tonumber(index),tonumber(total)
    if not created or created>100000000000 or total<1 or total>343 or index<1 or index>total or #part>CHUNK then return end
    if p.total and (p.total~=total or p.created~=created) then return end
    self:QuestLinkTrace("part-received",token.." packet="..index.."/"..total)
    p.total,p.created=total,created;p.parts[index]=part
    for i=1,total do if p.parts[i]==nil then return end end
    local quests=self:ValidateQuestLinkPayload(table.concat(p.parts))
    s.pending[token]=nil
    if not quests then
        if self.sharedQuestLogToken==token then self:ShowSharedQuestLog(token,nil,"This quest-log snapshot is invalid or too large.") end
        return
    end
    local snapshot={owner=p.owner,displayOwner=p.displayOwner,created=created,quests=quests,localTime=GetTime()}
    self:QuestLinkTrace("snapshot-complete",token.." sender="..p.owner)
    s.received[token]=snapshot;self:PruneQuestLinks()
    if self.sharedQuestLogToken==token then self:ShowSharedQuestLog(token,snapshot) end
end
function A:QuestLinkTransferTick()
    local s=self:QuestLinkState();local now=GetTime()
    if #s.outgoing>0 and now>=(s.nextSend or 0) then
        local packet=table.remove(s.outgoing,1);local snapshot=s.published[packet.token]
        if snapshot and now-snapshot.localTime<=TTL then self:SendQuestLogPacket(packet.message,packet.target) end
        s.nextSend=now+0.25
    end
    for token,p in pairs(s.pending) do
        if now-p.started>120 then
            self:QuestLinkTrace("request-timeout",token.." route="..p.owner)
            s.pending[token]=nil
            if self.sharedQuestLogToken==token then self:ShowSharedQuestLog(token,nil,"No response. Open Transfer diagnostics on both clients to check delivery, sender response, and rejected replies. The owner must remain online with this addon.") end
        elseif self.sharedQuestLogToken==token and self.sharedQuestLogWindow and now>=(p.nextStatus or 0) then
            local received=0;for _ in pairs(p.parts) do received=received+1 end
            self.sharedQuestLogWindow.subtitle:SetText(string.format("Waiting for snapshot: %.0fs; packets %d/%s. Transfer diagnostics below.",now-p.started,received,tostring(p.total or "?")))
            p.nextStatus=now+1
        end
    end
    if #s.outgoing==0 and not next(s.pending) then self.questLinkFrame:SetScript("OnUpdate",nil) end
end
function A:WakeQuestLinkTransfers()
    self.questLinkFrame:SetScript("OnUpdate",function() A:QuestLinkTransferTick() end)
end
function A:ShowSharedQuestLog(token,snapshot,message)
    if not self.sharedQuestLogWindow then
        local f=CreateFrame("Frame","SimplyPartyQuestsSharedLog",UIParent,"BasicFrameTemplateWithInset")
        self.sharedQuestLogWindow=f
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsSharedLog" end
        f:SetSize(550,560);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG")
        f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function() f:StartMoving() end);f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        f.title=self.readable(f.TitleText) and f.TitleText or f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        if not self.readable(f.TitleText) then f.title:SetPoint("TOPLEFT",16,-8) end
        f.subtitle=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.subtitle:SetPoint("TOPLEFT",16,-33);f.subtitle:SetWidth(510);f.subtitle:SetJustifyH("LEFT")
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-72);f.scroll:SetPoint("BOTTOMRIGHT",-32,16)
        f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(494,1);f.scroll:SetScrollChild(f.child)
        f.transferReport=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        f.transferReport:SetSize(170,22);f.transferReport:SetPoint("BOTTOMLEFT",16,14)
        f.transferReport:SetText("Transfer diagnostics")
        f.transferReport:SetScript("OnClick",function() A:ShowDiagnosticReport() end)
        f.rows={}
    end
    local f=self.sharedQuestLogWindow
    if self.sharedQuestLogToken~=token then f.expanded={};f.scroll:SetVerticalScroll(0) end
    self.sharedQuestLogToken=token;f.expanded=f.expanded or {}
    f.title:SetText(snapshot and (safe(snapshot.displayOwner or snapshot.owner).."'s Quest Log") or "Shared Quest Log")
    local y,used=0,0
    local function row(label,heading,id,complete)
        used=used+1;local b=f.rows[used]
        if not b then
            b=CreateFrame("Button",nil,f.child);b.label=b:CreateFontString(nil,"ARTWORK")
            b.label:SetJustifyH("LEFT");b.label:SetJustifyV("TOP");b.label:SetPoint("TOPLEFT",6,-4);b.label:SetWidth(476)
            b.art=b:CreateTexture(nil,"BACKGROUND");b.art:SetAllPoints(b);b.art:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
            b:SetScript("OnClick",function()
                if b.questID then f.expanded[b.questID]=f.expanded[b.questID]==false;A:ShowSharedQuestLog(token,snapshot) end
            end)
            f.rows[used]=b
        end
        -- Refresh closures and row identity as pooled rows move between snapshots.
        b.questID=id;b:SetScript("OnClick",function()
            if b.questID then f.expanded[b.questID]=f.expanded[b.questID]==false;A:ShowSharedQuestLog(token,snapshot) end
        end)
        b.label:SetFontObject(heading and (ObjectiveTrackerLineFont or GameFontNormal) or (ObjectiveTrackerLineFont or GameFontHighlightSmall))
        if complete then b.label:SetTextColor(0.1,1,0.1)
        elseif heading then b.label:SetTextColor(1,0.82,0) else b.label:SetTextColor(0.8,0.8,0.8) end
        b.label:SetText(label);b.art:SetShown(heading);b:EnableMouse(id~=nil)
        local h=math.max(heading and 26 or 18,b.label:GetStringHeight()+8)
        b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y);b:SetSize(490,h);b:Show();y=y+h+3
    end
    if snapshot and snapshot.quests then
        local quests,ready={},0
        for _,q in pairs(snapshot.quests) do quests[#quests+1]=q;if q.ready then ready=ready+1 end end
        table.sort(quests,function(a,b) if a.title==b.title then return a.id<b.id end;return a.title<b.title end)
        local stamp=date and snapshot.created>0 and date("%Y-%m-%d %H:%M",snapshot.created) or "time unavailable"
        f.subtitle:SetText(#quests.." quests | "..ready.." ready for turn-in\nSnapshot: "..stamp.." (not a live view)")
        if #quests==0 then row("No quests in this snapshot.",false) end
        for _,q in ipairs(quests) do
            local expanded=f.expanded[q.id]~=false
            row((expanded and "- " or "+ ")..safe(q.title)..(q.ready and " [Ready for turn-in]" or ""),true,q.id,q.ready)
            if expanded then
                if #q.objectives==0 then row(q.ready and "Ready for turn-in." or "Objective progress unavailable.",false,nil,q.ready) end
                for _,o in ipairs(q.objectives) do
                    local label=safe(o.text)
                    if o.done and o.total and not label:find("%d+%s*/%s*%d+") then label=label.." ("..o.done.."/"..o.total..")" end
                    if o.finished and not (o.done and o.total and o.total>0) then label=label.." [Complete]" end
                    row("   "..label,false,nil,o.finished or (o.done and o.total and o.total>0 and o.done>=o.total))
                end
            end
        end
    else f.subtitle:SetText("Shared quest-log snapshot");row(message or "Snapshot unavailable.",false) end
    for i=used+1,#f.rows do f.rows[i].questID=nil;f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,y));f:Show()
end
function A:InstallQuestLogShareButton()
    local map=WorldMapFrame
    if not self.readable(map) then return end
    local border=map.BorderFrame
    if not self.readable(border) or not self.readable(border.MaximizeMinimizeFrame) then return end
    local arrow=border.MaximizeMinimizeFrame
    local b=self.questLogShareButton
    if not b then
        -- Use explicit classic button art: template-only buttons can retain a
        -- hit area while their themed regions fail to render on Forever's map.
        b=CreateFrame("Button","SimplyPartyQuestsShareLogButton",border)
        self.questLogShareButton=b
        b:SetSize(132,22)
        local function art(file,layer)
            local t=b:CreateTexture(nil,layer)
            t:SetTexture("Interface\\Buttons\\"..file);t:SetAllPoints(b)
            t:SetTexCoord(0,0.625,0,0.6875);t:SetVertexColor(1,1,1,1)
            return t
        end
        b.shareNormal=art("UI-Panel-Button-Up","BACKGROUND")
        b.sharePushed=art("UI-Panel-Button-Down","BACKGROUND")
        b.shareHighlight=art("UI-Panel-Button-Highlight","HIGHLIGHT")
        b.shareHighlight:SetBlendMode("ADD")
        b:SetNormalTexture(b.shareNormal);b:SetPushedTexture(b.sharePushed)
        b:SetHighlightTexture(b.shareHighlight)
        b.shareLabel=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        b.shareLabel:SetPoint("CENTER",b,"CENTER",0,0)
        b.shareLabel:SetTextColor(1,0.82,0,1);b.shareLabel:SetText("Share Quest Log")
        b:SetFontString(b.shareLabel);b:SetText("Share Quest Log")
        b:SetPushedTextOffset(1,-1)
        b:SetScript("OnMouseDown",function()
            if not A.questLogShareDraft then A.questLogShareDraft=A:CaptureQuestLogChatDraft() end
        end)
        b:SetScript("OnClick",function()
            local draft=A.questLogShareDraft;A.questLogShareDraft=nil
            A:DraftQuestLogLink(draft);A.questLogShareDraft=nil
        end)
        b:SetScript("OnEnter",function(button)
            A.questLogShareHover=true;A.questLogShareDraft=A:CaptureQuestLogChatDraft()
            GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
            GameTooltip:SetText("Share Quest Log")
            GameTooltip:AddLine("Draft a chat link to your current quests and objective progress. Players with Party Quests can click to view it.",1,1,1,true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function()
            A.questLogShareHover=false;A.questLogShareDraft=nil;GameTooltip:Hide()
        end)
    end
    b:SetParent(border);b:SetFrameStrata(arrow:GetFrameStrata())
    b:SetFrameLevel(math.max(border:GetFrameLevel(),arrow:GetFrameLevel())+10)
    b:SetAlpha(1)
    b:ClearAllPoints();b:SetPoint("RIGHT",arrow,"LEFT",-5,0)
    b:Show()
end
function A:InitQuestLogLinks()
    if self.InstallQuestLogChatCompatibility then self:InstallQuestLogChatCompatibility() end
    if self.InstallBattleNetQuestLogLinks then self:InstallBattleNetQuestLogLinks() end
    if self.questLinksInitialized then return true end
    if not ChatFrame_AddMessageEventFilter or not EventRegistry or type(EventRegistry.RegisterCallback)~="function" then return false end
    self:QuestLinkState()
    self.questLinkComms=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    for _,event in ipairs({"CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_CHANNEL","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER"}) do
        ChatFrame_AddMessageEventFilter(event,function(_,kind,message,sender,...)
            local changed=A:ObserveQuestLogLink(message,sender,kind,select(10,...))
            if changed~=message then return false,changed,sender,... end
        end)
    end
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost",function(_,box)
        if A.questLogShareHover then A.questLogShareDraft=A:CaptureQuestLogChatDraft(box) end
    end,self)
    EventRegistry:RegisterCallback("SetItemRef",function(_,link)
        if not A.public(link,"string") then return end
        local token=link:match("^addon:SPQLOG:(.+)$")
        if token then A:OpenQuestLogLink(token) end
    end,self)
    self.questLinksInitialized=true;return true
end
local f=CreateFrame("Frame")
A.questLinkFrame=f
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","CHAT_MSG_ADDON"}) do f:RegisterEvent(event) end
f:SetScript("OnEvent",function(_,event,...)
    if event=="CHAT_MSG_ADDON" then
        local prefix,message,channel,sender=...
        if prefix==PREFIX then A:ReceiveQuestLogLink(message,sender,channel) end
    elseif A.db then A:InitQuestLogLinks();A:InstallQuestLogShareButton() end
end)
