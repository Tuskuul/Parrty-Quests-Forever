local _,A=...
A.PartyHeaderEnabled=true
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}
local function style(b)
    b:SetBackdrop(backdrop);b:SetBackdropColor(0.04,0.035,0.025,0.9);b:SetBackdropBorderColor(0.65,0.5,0.25,0.9)
end
function A:StylePartyToolbar(f)
    for _,key in ipairs({"share","refresh","settings"}) do style(f[key]) end
end
function A:SetPartyExpansion(mode)
    if mode~="collapse" and mode~="members" and mode~="all" then return end
    local db=self.db
    db.trackerMembersClosed=db.trackerMembersClosed or {}
    db.questExpanded=db.questExpanded or {};db.trackerGroupsClosed=db.trackerGroupsClosed or {}
    db.trackerOwnProgressExpanded=db.trackerOwnProgressExpanded or {}
    local allClosed=true
    for guid in pairs(self.members) do if not db.trackerMembersClosed[guid] then allClosed=false end end
    db.trackerPartyCollapsed=mode=="collapse" and allClosed and db.trackerPartyCollapsePrimed==true or false
    db.trackerPartyCollapsePrimed=mode=="collapse" or nil
    for guid,m in pairs(self.members) do
        db.trackerMembersClosed[guid]=mode~="all" or nil
        local prefix=guid..":"
        for key in pairs(db.trackerGroupsClosed) do
            if key:sub(1,#prefix)==prefix then db.trackerGroupsClosed[key]=nil end
        end
        for id in pairs(m.quests or {}) do
            local key=guid..":"..id
            db.questExpanded[key]=mode=="all" or nil
            db.trackerOwnProgressExpanded[key]=mode=="all" or nil
        end
    end
    self:InvalidateTrackerIntegration(true)
    if InCombatLockdown and InCombatLockdown() then self:RenderCombatTrackerSidebar() else self:Render() end
end
function A:LayoutPartyHeader(row,width,count,height)
    if not row.partyActions then
        local actions=CreateFrame("Frame",nil,row);row.partyActions=actions;actions.buttons={}
        for i,choice in ipairs({{"collapse","Collapse all"},{"members","Expand"},{"all","Expand all"}}) do
            local mode,label=choice[1],choice[2]
            local b=CreateFrame("Button",nil,actions,"BackdropTemplate")
            b:SetNormalFontObject(GameFontNormalSmall);b:SetHighlightFontObject(GameFontHighlightSmall)
            b:SetText(label);style(b)
            b:SetScript("OnClick",function() A:SetPartyExpansion(mode) end)
            actions.buttons[i]=b
        end
        local bar=CreateFrame("Frame",nil,row,"BackdropTemplate");style(bar);row.partyBar=bar
        bar.label=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        bar.label:SetPoint("LEFT",5,0);bar.label:SetTextColor(0.7,0.7,0.7)
    end
    local actions=row.partyActions
    actions:ClearAllPoints();actions:SetPoint("TOPLEFT",row,"TOPLEFT",0,-height-2);actions:SetSize(width,22)
    -- A narrower center button leaves more room for the two longer captions.
    local gap=4;local available=math.max(150,width-2*gap)
    local widths={available*0.36,available*0.28,available*0.36};local x=0
    for i,b in ipairs(actions.buttons) do
        b:ClearAllPoints();b:SetPoint("TOPLEFT",actions,"TOPLEFT",x,0);b:SetSize(widths[i],22);x=x+widths[i]+gap
    end
    actions:Show()
    local extra=26
    if self.db.trackerPartyCollapsed then
        local bar=row.partyBar;bar:ClearAllPoints();bar:SetPoint("TOPLEFT",actions,"BOTTOMLEFT",0,-4)
        bar:SetSize(width,18);bar.label:SetText(count.." party members collapsed");bar:Show();extra=extra+22
    else row.partyBar:Hide() end
    row:SetHeight(height+extra)
    return extra
end
