local _,A=...
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and not A.secret(value) then return value end
end
function A:GetQuestShareDestinations()
    local party=call(IsInGroup)==true and call(IsInRaid)~=true
    local result={
        {kind="CURRENT",label="Current chat / whisper",enabled=true},
        {kind="PARTY",label="Party",enabled=party},
        {kind="GUILD",label="Guild",enabled=call(IsInGuild)==true},
        {kind="SAY",label="Say",enabled=true},
        {kind="YELL",label="Yell",enabled=true},
    }
    if type(GetChannelList)=="function" then
        local function pack(...) return {n=select("#",...),...} end
        local channels=pack(pcall(GetChannelList))
        if channels[1] then
            for i=2,channels.n,3 do
                local id,name,disabled=channels[i],channels[i+1],channels[i+2]
                if self.public(id,"number") and id>0 and id<=1000 and id%1==0
                    and self.public(name,"string") and name~="" and #name<=120 then
                    local enabled=not self.secret(disabled) and (disabled==nil
                        or (self.public(disabled,"boolean") and not disabled)
                        or (self.public(disabled,"number") and disabled==0))
                    result[#result+1]={kind="CHANNEL",id=id,name=name,label="/"..id.." "..name,enabled=enabled}
                end
            end
        end
    end
    return result
end
function A:ValidateQuestShareDestination(destination)
    if not self.readable(destination) then return false end
    for _,current in ipairs(self:GetQuestShareDestinations()) do
        if current.kind==destination.kind and current.id==destination.id and current.name==destination.name then
            return current.enabled==true
        end
    end
    return false
end
function A:QuestLogDestinationBox(destination)
    if not self:ValidateQuestShareDestination(destination) then
        return nil,"That destination is no longer available. Reopen Share to chat to refresh the list."
    end
    local util=ChatFrameUtil or {}
    local choose=util.ChooseBoxForSend or ChatEdit_ChooseBoxForSend
    local box=call(choose)
    if not box and self.readable(DEFAULT_CHAT_FRAME) then box=DEFAULT_CHAT_FRAME.editBox end
    if not self.readable(box) or type(box.GetText)~="function" or type(box.SetAttribute)~="function"
        or (self.QuestLogChatBoxKind and self:QuestLogChatBoxKind(box)) then
        return nil,"A Blizzard chat entry box is unavailable. Try Current chat / whisper instead."
    end
    local current=box:GetText()
    if not self.public(current,"string") or current~="" then
        return nil,"Your chat entry already has a draft. Use Current chat / whisper to keep it, or send or clear it first."
    end
    return box
end
function A:InsertQuestLogDestination(marker,destination)
    local box,reason=self:QuestLogDestinationBox(destination)
    if not box then return false,reason end
    local util=ChatFrameUtil or {}
    local activate=util.ActivateChat or ChatEdit_ActivateChat
    if activate then activate(box) else box:Show();box:SetFocus() end
    -- Start a fresh public draft; never copy private WIM/Battle.net text here.
    box:SetAttribute("chatType",destination.kind)
    box:SetAttribute("stickyType",destination.kind)
    box:SetAttribute("tellTarget",nil)
    box:SetAttribute("channelTarget",destination.kind=="CHANNEL" and destination.id or nil)
    box:SetText(marker);box:SetCursorPosition(#marker)
    if type(box.UpdateHeader)=="function" then box:UpdateHeader()
    elseif type(ChatEdit_UpdateHeader)=="function" then ChatEdit_UpdateHeader(box) end
    box:SetFocus()
    return true
end
function A:OpenQuestShareDestinations()
    local picker=self.questSharePicker
    if not picker then return end
    if self.questShareDestination and self.questShareDestination:IsShown() then self.questShareDestination:Raise();return end
    if not self.questShareDestination then
        local f=CreateFrame("Frame","SimplyPartyQuestsShareDestination",UIParent,"BasicFrameTemplateWithInset")
        self.questShareDestination=f;self:StyleQuestDialog(f)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsShareDestination" end
        f:SetSize(360,390);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true)
        f:SetMovable(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function() f:StartMoving() end);f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        if self.readable(f.TitleText) then f.TitleText:SetText("Share to chat") end
        f.help=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");self:StyleQuestDialogText(f.help,"body")
        f.help:SetPoint("TOPLEFT",16,-36);f.help:SetWidth(328);f.help:SetJustifyH("LEFT")
        f.help:SetText("Choose where to prepare the link. Press Enter in chat to send it.")
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-76);f.scroll:SetPoint("BOTTOMRIGHT",-32,96)
        f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(304,1);f.scroll:SetScrollChild(f.child)
        f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");self:StyleQuestDialogText(f.status,"error")
        f.status:SetPoint("BOTTOMLEFT",16,43);f.status:SetWidth(328);f.status:SetJustifyH("LEFT")
        f.cancel=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");f.cancel:SetSize(100,24)
        f.cancel:SetPoint("BOTTOMRIGHT",-16,12);f.cancel:SetText("Cancel");f.cancel:SetScript("OnClick",function() f:Hide() end)
        f.rows={}
        f:SetScript("OnHide",function()
            local source=A.questSharePicker
            if source and source.destinationActive then source.destinationActive=nil;source:Show();source:Raise() end
        end)
    end
    local f=self.questShareDestination
    f.status:SetText("")
    local destinations=self:GetQuestShareDestinations()
    for i,destination in ipairs(destinations) do
        local b=f.rows[i]
        if not b then b=CreateFrame("Button",nil,f.child,"UIPanelButtonTemplate");b:SetSize(304,24);f.rows[i]=b end
        b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-(i-1)*30);b:SetText(self:DisplayText(destination.label))
        b:SetEnabled(destination.enabled);b:Show()
        b:SetScript("OnClick",function()
            if not A:ValidateQuestShareDestination(destination) then
                f.status:SetText("Destination changed. Cancel and reopen to refresh.");return
            end
            if not A:SubmitQuestLogShare(picker.scope~="full" and picker.selected or nil,destination) then
                f.status:SetText("Could not prepare the link. Check chat for the reason, or choose Current chat / whisper.")
            end
        end)
    end
    for i=#destinations+1,#f.rows do f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,#destinations*30));f.scroll:SetVerticalScroll(0)
    picker.destinationActive=true;picker:Hide();f:Show();f:Raise()
end
