local _, A = ...

local function tokenOK(s)
    return A.public(s,"string") and #s<=48 and s:match("^[%x]+%-%x+%-%x+$")~=nil
end
local function ownerOK(s)
    return A.public(s,"string") and #s>0 and #s<=80
        and not s:find("[%z\1-\31\127|]") and s:find("%S")~=nil
end
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function unhex(s)
    if #s==0 or #s>160 or #s%2~=0 or s:find("[^%x]") then return nil end
    return (s:gsub("%x%x",function(c) return string.char(tonumber(c,16)) end))
end
local function escaped(s) return (s:gsub("|","||")) end

function A:ParseCopiedQuestLogLink(text)
    if not self.public(text,"string") or #text>255 then return nil end
    text=text:match("^%s*(.-)%s*$")
    local token,name=text:match("^%[Party Quests Log:([%x%-]+):([%x]+)%]$")
    if not tokenOK(token) or not name then return nil end
    local owner=unhex(name)
    if not ownerOK(owner) then return nil end
    return {token=token,owner=owner}
end

function A:CreateCopiedQuestLogLink(questIDs)
    if not self:InitQuestLogLinks() or not self.questLinkComms then
        return nil,"Quest-log communication is unavailable in this client."
    end
    local token,snapshot=self:CreateQuestLogSnapshot(questIDs)
    if not token then return nil,snapshot end
    if not ownerOK(snapshot.owner) then return nil,"Your character name is unavailable." end
    -- Carry the original owner, rather than treating whoever pastes/forwards
    -- the marker as the publisher. Remains within normal WoW chat length.
    local marker="[Party Quests Log:"..token..":"..hex(snapshot.owner).."]"
    if #marker>255 then return nil,"The link is too long for WoW chat." end
    snapshot.published=true
    return marker
end

function A:RegisterCopiedQuestLogLink(ref)
    self:PruneQuestLinks()
    local s=self:QuestLinkState();local previous=s.observed[ref.token]
    if previous and previous.owner:lower()~=ref.owner:lower() then return false end
    local mine=s.published[ref.token]
    if mine and mine.owner:lower()~=ref.owner:lower() then return false end
    -- Repeated observation must not replace an existing Battle.net route.
    if previous and previous.accountID then return true end
    s.observed[ref.token]={owner=ref.owner,localTime=GetTime()}
    return true
end

function A:ObserveCopiedQuestLogLinks(message)
    return (message:gsub("%[Party Quests Log:([%x%-]+):([%x]+)%]",function(token,name)
        local ref=self:ParseCopiedQuestLogLink("[Party Quests Log:"..token..":"..name.."]")
        if not ref or not self:RegisterCopiedQuestLogLink(ref) then return nil end
        return "|cffffff00|Haddon:SPQLOG:"..token.."|h["..escaped(ref.owner).."'s Quest Log]|h|r"
    end))
end

function A:ImportCopiedQuestLogLink(text)
    local ref=self:ParseCopiedQuestLogLink(text)
    if not ref then return nil,"Paste the complete in-game string from Copy Share link." end
    if not self:InitQuestLogLinks() or not self.questLinkComms then
        return nil,"Quest-log communication is unavailable in this client."
    end
    if not self:RegisterCopiedQuestLogLink(ref) then return nil,"This token belongs to a different cached sender." end
    return ref.token
end

function A:ShowQuestLogTransfer(mode,questIDs)
    local text
    if mode=="copy" then
        local err;text,err=self:CreateCopiedQuestLogLink(questIDs)
        if not text then self.questSharePicker.status:SetText(err);self.questSharePicker.status:Show();return end
    end
    if not self.questLogTransfer then
        local f=CreateFrame("Frame","SimplyPartyQuestsShareTransfer",UIParent,"BasicFrameTemplateWithInset")
        self.questLogTransfer=f
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsShareTransfer" end
        f:SetSize(540,280);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:EnableMouse(true)
        f.title=self.readable(f.TitleText) and f.TitleText or f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        if not self.readable(f.TitleText) then f.title:SetPoint("TOPLEFT",16,-8) end
        f.help=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.help:SetPoint("TOPLEFT",16,-36);f.help:SetWidth(500);f.help:SetJustifyH("LEFT")
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT",20,-104);f.scroll:SetPoint("BOTTOMRIGHT",-38,82)
        f.edit=CreateFrame("EditBox",nil,f.scroll)
        f.edit:SetMultiLine(true);f.edit:SetAutoFocus(false);f.edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
        f.edit:SetWidth(478);f.edit:SetHeight(80);f.edit:SetMaxLetters(512)
        f.scroll:SetScrollChild(f.edit)
        f.edit:SetScript("OnEscapePressed",function() f:Hide() end)
        f.edit:SetScript("OnTextChanged",function(box)
            if f.mode=="copy" and box:GetText()~=f.copyText then box:SetText(f.copyText) end
        end)
        f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.status:SetPoint("BOTTOMLEFT",16,50);f.status:SetWidth(500);f.status:SetJustifyH("LEFT")
        f.submit=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        f.submit:SetSize(120,24);f.submit:SetPoint("BOTTOMLEFT",16,16);f.submit:SetText("Import")
        f.submit:SetScript("OnClick",function()
            local token,err=A:ImportCopiedQuestLogLink(f.edit:GetText())
            if not token then f.status:SetText(err);return end
            f:Hide()
            if A.questSharePicker then A.questSharePicker:Hide() end
            A:OpenQuestLogLink(token)
        end)
        f.close=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        f.close:SetSize(100,24);f.close:SetPoint("BOTTOMRIGHT",-16,16)
        f.close:SetScript("OnClick",function() f:Hide() end)
        f:SetScript("OnHide",function() f.edit:ClearFocus();f.mode=nil;f.copyText=nil;f.edit:SetText("") end)
    end
    local f=self.questLogTransfer
    f.mode=mode;f.copyText=text;f.title:SetText(mode=="copy" and "Copy Share link" or "Import shared quests")
    f.help:SetText(mode=="copy" and "Press Ctrl+C to copy the selected link, then paste it into a WoW character chat. Recipients need this beta or newer. The owner must stay online; links last 15 minutes."
        or "Paste a complete in-game string from Copy Share link with Ctrl+V, then click Import. The owner's addon supplies the snapshot; the owner must be online and the link still available.")
    f.status:SetText(mode=="copy" and "Copying does not change or send your current chat draft." or "")
    f.submit:SetShown(mode=="import");f.close:SetText(mode=="copy" and "Done" or "Cancel")
    f.edit:SetText(text or "");f.scroll:SetVerticalScroll(0)
    f:Show();f:Raise();f.edit:SetFocus()
    if mode=="copy" then f.edit:HighlightText() end
end
