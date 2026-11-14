local _, A = ...

local function label(parent,text,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    t:SetText(text);t:SetJustifyH("LEFT");return t
end
local function button(parent,text,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24);b:SetText(text);b:SetScript("OnClick",callback);return b
end
local function plain(text)
    -- Quest titles are display text, never executable chat markup.
    return text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|","||")
end

function A:UpdateQuestShareSelection()
    local f=self.questSharePicker;local selected=0
    for _,q in ipairs(f.quests) do if f.selected[q.id] then selected=selected+1 end end
    f.status:SetText(selected.." of "..#f.quests.." quests selected")
    f.submit:SetEnabled(selected>0)
end

function A:ShowQuestShareSelection()
    local f=self.questSharePicker
    self:ReadOwn()
    f.quests={};f.selected={}
    for id,q in pairs(self.own) do
        f.quests[#f.quests+1]={id=id,title=q.title,ready=q.ready}
    end
    table.sort(f.quests,function(a,b)
        if a.title==b.title then return a.id<b.id end
        return a.title<b.title
    end)
    f:SetSize(460,500)
    f.prompt:SetText("Choose one or more quests, then click Share selected.")
    f.scroll:Show();f.submit:Show();f.status:Show()
    f.scroll:SetVerticalScroll(0)
    local y=0
    for i,q in ipairs(f.quests) do
        local b=f.rows[i]
        if not b then
            b=CreateFrame("CheckButton",nil,f.child,"UICheckButtonTemplate")
            b:SetSize(26,26)
            b.caption=label(b,"");b.caption:SetPoint("TOPLEFT",b,"TOPRIGHT",3,-4)
            b.caption:SetWidth(352);b.caption:SetWordWrap(true)
            b:SetHitRectInsets(0,-355,0,0)
            b:SetScript("OnClick",function(row)
                if row:GetChecked() then f.selected[row.questID]=true else f.selected[row.questID]=nil end
                A:UpdateQuestShareSelection()
            end)
            f.rows[i]=b
        end
        b.questID=q.id;b:SetChecked(false)
        b.caption:SetText(plain(q.title)..(q.ready and " |cff19ff19[Ready]|r" or ""))
        b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y);b:Show()
        y=y+math.max(40,b.caption:GetStringHeight()+16)
    end
    for i=#f.quests+1,#f.rows do f.rows[i].questID=nil;f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,y))
    if #f.quests==0 then f.prompt:SetText("Your quest log is empty.") end
    self:UpdateQuestShareSelection()
end

function A:SubmitQuestLogShare(questIDs)
    local f=self.questSharePicker
    if questIDs and not next(questIDs) then return end
    if self:DraftQuestLogLink(f.draft,questIDs) then
        f.committed=true;f:Hide()
    end
end

function A:OpenQuestLogShare(draft)
    -- Keep the original editor, text, cursor, channel and recipient across both
    -- popup steps, even after the original Share button loses its hover state.
    draft=draft or self:CaptureQuestLogChatDraft()
    if not self.questSharePicker then
        local f=CreateFrame("Frame","SimplyPartyQuestsSharePicker",UIParent,"BasicFrameTemplateWithInset")
        self.questSharePicker=f
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsSharePicker" end
        f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true)
        f:SetMovable(true);f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function() f:StartMoving() end)
        f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        if self.readable(f.TitleText) then f.TitleText:SetText("Share quests") end
        f.prompt=label(f,"How would you like to share your quests?")
        f.prompt:SetPoint("TOPLEFT",16,-36);f.prompt:SetWidth(420)
        f.full=button(f,"Full log",190,function() A:SubmitQuestLogShare() end)
        f.full:SetPoint("TOPLEFT",16,-64)
        f.choose=button(f,"Select quests",190,function() A:ShowQuestShareSelection() end)
        f.choose:SetPoint("LEFT",f.full,"RIGHT",12,0)
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",16,-104);f.scroll:SetPoint("BOTTOMRIGHT",-34,80)
        f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(398,1)
        f.scroll:SetScrollChild(f.child);f.rows={}
        f.status=label(f,"");f.status:SetPoint("BOTTOMLEFT",16,58)
        f.submit=button(f,"Share selected",160,function() A:SubmitQuestLogShare(f.selected) end)
        f.submit:SetPoint("BOTTOMLEFT",16,18)
        f.cancel=button(f,"Cancel",100,function() f:Hide() end)
        f.cancel:SetPoint("BOTTOMRIGHT",-16,18)
        f:SetScript("OnHide",function()
            local saved=f.draft
            f.draft=nil;f.selected={}
            -- Closing or Escape restores the draft without publishing a link.
            if not f.committed and saved then A:InsertQuestLogChatLink("",saved) end
            f.committed=nil
        end)
    end
    local f=self.questSharePicker
    f.draft=draft;f.committed=nil;f.quests={};f.selected={}
    f:SetSize(440,154)
    f.prompt:SetText("How would you like to share your quests?")
    f.scroll:Hide();f.submit:Hide();f.status:Hide()
    f:Show();f:Raise()
end
