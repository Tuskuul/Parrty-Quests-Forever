local _, A = ...

local function label(parent,text,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    A:StyleQuestDialogText(t,"body");t:SetText(text);t:SetJustifyH("LEFT");return t
end
local function button(parent,text,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24);b:SetText(text);b:SetScript("OnClick",callback);return b
end

function A:UpdateQuestShareSelection()
    local f=self.questSharePicker;local selected=0
    for _,q in ipairs(f.quests) do if f.selected[q.id] then selected=selected+1 end end
    f.status:SetText(selected.." of "..#f.quests.." quests selected")
    f.submit:SetEnabled(selected>0);f.copy:SetEnabled(selected>0)
end

function A:ShowQuestShareSelection(offers)
    local f=self.questSharePicker
    f.scope=offers and "offer" or "selected"
    self:StyleQuestShareTabs(f)
    self:ReadOwn()
    f.quests={};f.selected={}
    local offerReason
    if offers then f.quests,offerReason=self:GetShareableQuestOffers()
    else
        for id,q in pairs(self.own) do f.quests[#f.quests+1]={id=id,title=q.title,ready=q.ready} end
    end
    table.sort(f.quests,function(a,b)
        if a.title==b.title then return a.id<b.id end
        return a.title<b.title
    end)
    f:SetSize(520,540)
    f.prompt:SetText(offers and "Choose shareable quests missing from a party member's log, then share the offer link." or "Choose quests, then Share to chat or Copy Share link.")
    f.scroll:Show();f.submit:Show();f.status:Show()
    f.scroll:SetVerticalScroll(0)
    local y=0
    for i,q in ipairs(f.quests) do
        local b=f.rows[i]
        if not b then
            b=CreateFrame("CheckButton",nil,f.child,"UICheckButtonTemplate")
            b:SetSize(26,26)
            b.caption=label(b,"");b.caption:SetPoint("TOPLEFT",b,"TOPRIGHT",3,-4)
            b.caption:SetWidth(412);b.caption:SetWordWrap(true)
            b:SetHitRectInsets(0,-415,0,0)
            b:SetScript("OnClick",function(row)
                if row:GetChecked() then f.selected[row.questID]=true else f.selected[row.questID]=nil end
                A:UpdateQuestShareSelection()
            end)
            f.rows[i]=b
        end
        b.questID=q.id;b:SetChecked(false)
        b:SetScript("OnEnter",function(row)
            if q.missing and GameTooltip then
                GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetText("Not currently on this quest")
                for _,name in ipairs(q.missing) do GameTooltip:AddLine(A:DisplayText(name),1,1,1) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        b.caption:SetText(A:QuestTitleText(q.id,q.title)..(q.ready and (" "..A:QuestDialogColorCode("ready").."[Ready]|r") or ""))
        b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y);b:Show()
        y=y+math.max(40,b.caption:GetStringHeight()+16)
    end
    for i=#f.quests+1,#f.rows do f.rows[i].questID=nil;f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,y))
    if #f.quests==0 then f.prompt:SetText(offers and (offerReason or "No shareable quests are missing from the known party logs.") or "Your quest log is empty.") end
    self:UpdateQuestShareSelection()
end

function A:ShowQuestShareFullLog()
    local f=self.questSharePicker
    f.scope="full";self:StyleQuestShareTabs(f);f.selected={};f:SetSize(520,240)
    f.scroll:Hide();f.submit:Show();f.status:Show()
    f.prompt:SetText("Share your log, select quests, open shareable quests, or import a link.")
    f.status:SetText("Full log selected. Share to chat prepares a message for you to send.")
    f.submit:SetEnabled(true);f.copy:SetEnabled(true)
end

function A:SubmitQuestLogShare(questIDs,destination)
    local f=self.questSharePicker
    if questIDs and not next(questIDs) then return end
    if self:DraftQuestLogLink(f.draft,questIDs,f.scope=="offer",destination) then
        local shown=f:IsShown()
        f.committed=true;f:Hide()
        if not shown then self:FinishQuestLogSharePicker() end
        return true
    end
    return false
end

function A:FinishQuestLogSharePicker()
    local f=self.questSharePicker
    if not f then return end
    f.transferActive=nil;f.destinationActive=nil
    if self.questShareDestination then self.questShareDestination:Hide() end
    if self.questLogTransfer then
        self.questLogTransfer.returnToPicker=nil
        self.questLogTransfer:Hide()
    end
    local saved=f.draft
    f.draft=nil;f.selected={}
    if not f.committed and saved then self:InsertQuestLogChatLink("",saved) end
    f.committed=nil
end

function A:OpenQuestLogShare(draft)
    if self.questSharePicker and self.questSharePicker.destinationActive and self.questShareDestination then self.questShareDestination:Raise();return end
    if self.questSharePicker and self.questSharePicker.transferActive and self.questLogTransfer then
        self.questLogTransfer:Raise();self.questLogTransfer.edit:SetFocus();return
    end
    if self.questSharePicker and self.questSharePicker:IsShown() then self.questSharePicker:Raise();return end
    -- Keep the original editor, text, cursor, channel and recipient across both
    -- popup steps, even after the original Share button loses its hover state.
    draft=draft or self:CaptureQuestLogChatDraft()
    if not self.questSharePicker then
        local f=CreateFrame("Frame","SimplyPartyQuestsSharePicker",UIParent,"BasicFrameTemplateWithInset")
        self.questSharePicker=f
        self:StyleQuestDialog(f)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsSharePicker" end
        f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true)
        f:SetMovable(true);f:RegisterForDrag("LeftButton")
        f:SetClampedToScreen(true)
        f:SetScript("OnDragStart",function() f:StartMoving() end)
        f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        if self.readable(f.TitleText) then f.TitleText:SetText("Share quests") end
        f.prompt=label(f,"How would you like to share your quests?")
        f.prompt:SetPoint("TOPLEFT",16,-36);f.prompt:SetWidth(480)
        f.full=button(f,"Full log",148,function() A:ShowQuestShareFullLog() end)
        f.full:SetPoint("TOPLEFT",16,-64)
        f.choose=button(f,"Select quests",148,function() A:ShowQuestShareSelection() end)
        f.choose:SetPoint("LEFT",f.full,"RIGHT",12,0)
        f.offers=button(f,"Open shareable",148,function() A:ShowQuestShareSelection(true) end)
        f.offers:SetPoint("LEFT",f.choose,"RIGHT",12,0)
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-104);f.scroll:SetPoint("BOTTOMRIGHT",-34,132)
        f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(458,1)
        f.scroll:SetScrollChild(f.child);f.rows={}
        f.status=label(f,"");f.status:SetPoint("BOTTOMLEFT",16,106);f.status:SetWidth(480)
        f.submit=button(f,"Share to chat",145,function()
            A:OpenQuestShareDestinations()
        end)
        f.submit:SetPoint("BOTTOMLEFT",16,62)
        f.copy=button(f,"Copy Share link",175,function()
            A:ShowQuestLogTransfer("copy",f.scope~="full" and f.selected or nil,f.scope=="offer")
        end)
        f.copy:SetPoint("LEFT",f.submit,"RIGHT",10,0)
        f.import=button(f,"Import",100,function() A:ShowQuestLogTransfer("import") end)
        f.import:SetPoint("LEFT",f.copy,"RIGHT",10,0)
        f.cancel=button(f,"Cancel",100,function() f:Hide() end)
        f.cancel:SetPoint("BOTTOMRIGHT",-16,18)
        f:SetScript("OnHide",function()
            -- Copy/import temporarily replaces this window. Keep its scope,
            -- selections and chat draft until the user returns or imports.
            if not f.transferActive and not f.destinationActive then A:FinishQuestLogSharePicker() end
        end)
    end
    local f=self.questSharePicker
    f.draft=draft;f.committed=nil;f.quests={};f.selected={}
    self:ShowQuestShareFullLog()
    f:Show();f:Raise()
end
