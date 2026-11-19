local _, A = ...
local function font(parent,text,template)
    local f=parent:CreateFontString(nil,"ARTWORK",template or "GameFontHighlightSmall")
    f:SetJustifyH("LEFT");f:SetJustifyV("TOP");f:SetText(text);return f
end
function A:SetViewShown(shown)
    self.soloOverride=shown and next(self.members)==nil or nil
    if self:EffectiveDisplayMode()=="blizzard" then
        self.db.trackerHidden=not shown;self:InvalidateTrackerIntegration()
        if self.RefreshCombatTrackerPane then self:RefreshCombatTrackerPane() end
    else self.db.hidden=not shown;self.window:SetShown(shown and self:ShouldShowPartyView()) end
    if self.SyncCombatAutoHide then self:SyncCombatAutoHide() end
    self:SyncSettings()
end
function A:SetCombatAutoHide(value)
    self.db.combatAutoHide=not not value
    if self.SyncCombatAutoHide then self:SyncCombatAutoHide() end
    self:InvalidateTrackerIntegration();self:SyncSettings()
end
function A:SetViewCollapsed(value)
    if self.QuestieDockActive and self:QuestieDockActive() then
        if InCombatLockdown and InCombatLockdown() then self.questieCompatibility.dockCombatCollapsed=not not value
        else self.db.trackerCollapsed=not not value end
        self:QuestieDockTick();return
    end
    if self:EffectiveDisplayMode()=="blizzard" then
        local tracker=ObjectiveTrackerFrame
        if tracker and tracker:IsShown() and tracker.Header and tracker.Header:IsShown() then
            if InCombatLockdown and InCombatLockdown() then return end
            local ok,err=self:CallNativeTrackerMethod(tracker,"SetCollapsed",not not value)
            if not ok then self.integration.lastError=err end
        else
            self.db.trackerCollapsed=not not value
            if self.RefreshCombatTrackerPane then self:RefreshCombatTrackerPane() end
        end
        self:InvalidateTrackerIntegration()
    else self:SetCollapsed(not not value) end
end
function A:SetNativeRepair(value)
    self.db.nativeTrackerRepair=not not value
    if value then
        self.nativeTracker.suspended=nil;self.nativeTracker.lastMismatch=nil
        self:QueueNativeTracker("enabled",true)
    else self.nativeTracker.due=nil;self.nativeTracker.reason=nil;self.nativeTracker.verify=nil end
end
function A:SetDetailedDiagnostics(value,restart)
    local before=self.db.diag;self.db.diag=not not value
    if value and (not before or restart) then
        self.diagLines={};self.diagChanges={};self.diagEvents={}
        if self.triggerStats then self.triggerStats.events={};self.triggerStats.units={};self.triggerStats.batches=0 end
        local s=self.liveStats;s.changes=0;s.first=0;s.repeated=0;s.readyChanges=0;s.bySource={}
        s.scope={shared={data=0,empty=0},foreign={data=0,empty=0}}
    end
end
function A:ResetWindowLayout(show)
    if show then self:SetDisplayMode("window") end
    self.db.size={width=460,height=540};self.db.position=nil
    self.window:SetSize(460,540);self:ResizeLayout(460,540)
    self.window:ClearAllPoints();self.window:SetPoint("CENTER")
    self:SetCollapsed(false)
    self.window:SetShown(self:EffectiveDisplayMode()=="window" and not self.db.hidden)
    self:SyncSettings()
end
function A:SyncSettings()
    if not self.settingsControls or not self.db then return end
    for _,c in pairs(self.settingsControls) do
        if c.get then c:SetChecked(not not c.get()) end
    end
    local count=0;for _ in pairs(self.members) do count=count+1 end
    local pending=A.integration and A.integration.pendingDisplayMode
    local suffix=pending and ("   |   "..(pending=="blizzard" and "Tracker" or "Window").." queued after combat")
        or ((InCombatLockdown and InCombatLockdown()) and "   |   Layout changes apply after combat" or "")
    self.settingsStatus:SetText("View: "..(self:EffectiveDisplayMode()=="blizzard" and "Tracker sidebar" or "Pop-out window").."   |   Party members: "..count..suffix)
    if self.settingsQuestieStatus then self.settingsQuestieStatus:SetText(self.QuestieSummary and self:QuestieSummary() or "Questie: not loaded") end
    if self.settingsPaperSlider then
        self.settingsPaperSync=true;self.settingsPaperSlider:SetValue(self:QuestPaperBrightness());self.settingsPaperSync=nil
        self.settingsPaperLabel:SetText("Parchment brightness: "..self:QuestPaperBrightness().."%")
    end
    if self.settingsWidthLabel then self.settingsWidthLabel:SetText("Sidebar width: "..(self.db.sidebarWidth or 420).." pixels") end
    if self.settingsControls.advanced then self.settingsControls.advanced:SetText((self.settingsAdvancedOpen and "Hide" or "Show").." troubleshooting") end
    if self.settingsLayout and self.settingsPanel:IsShown() then self.settingsLayout() end
end
function A:InitSettings()
    if self.settingsPanel then return end
    local panel=CreateFrame("Frame","SimplyPartyQuestsSettingsPanel",UIParent)
    panel.name="Party Quests Forever";panel:SetSize(620,560);panel:Hide();self.settingsPanel=panel
    local title=font(panel,"Party Quests Forever","GameFontNormalLarge");title:SetPoint("TOPLEFT",16,-16)
    local metadata=(C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version=metadata and metadata("SimplyPartyQuests","Version") or "Unknown"
    local build=metadata and metadata("SimplyPartyQuests","X-Build")
    if build then version=version.." ("..build..")" end
    local versionLabel=font(panel,"Version "..version);versionLabel:SetPoint("TOPRIGHT",-16,-20)
    self.settingsStatus=font(panel,"");self.settingsStatus:SetPoint("TOPLEFT",16,-43)
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-70);scroll:SetPoint("BOTTOMRIGHT",-34,16)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(560,1);scroll:SetScrollChild(body)
    local items={};self.settingsControls={}
    local condition
    local function text(value,heading)
        items[#items+1]={kind="text",label=font(body,value,heading and "GameFontNormal" or "GameFontHighlightSmall"),heading=heading,when=condition}
        return items[#items].label
    end
    local function section(label,when)
        condition=when;text(label,true)
    end
    local function check(key,label,help,get,set,radio)
        local b=CreateFrame("CheckButton",nil,body,radio and "UIRadioButtonTemplate" or "UICheckButtonTemplate")
        b:SetSize(24,24);b.get=get
        b.label=font(body,label,"GameFontNormal");b.help=font(body,help)
        b:SetScript("OnClick",function()
            if radio then set(true) else set(not not b:GetChecked()) end
            A:SyncSettings();A:Render()
        end)
        self.settingsControls[key]=b;items[#items+1]={kind="check",button=b,when=condition}
    end
    local function actions(aKey,aLabel,aFn,bKey,bLabel,bFn)
        local row={kind="actions",buttons={},when=condition}
        local function add(key,label,fn)
            local b=CreateFrame("Button",nil,body,"UIPanelButtonTemplate");b:SetHeight(24);b:SetText(label)
            b:SetScript("OnClick",function() fn();A:SyncSettings() end)
            self.settingsControls[key]=b;row.buttons[#row.buttons+1]=b
        end
        add(aKey,aLabel,aFn);if bKey then add(bKey,bLabel,bFn) end
        items[#items+1]=row
    end
    local function sidebar() return A:EffectiveDisplayMode()=="blizzard" end
    local function window() return A:EffectiveDisplayMode()=="window" end
    local function advanced() return A.settingsAdvancedOpen end
    section("Display")
    check("blizzard","Beside the active quest tracker","Docks beside Blizzard or Questie; choose a separate window for independent placement.",sidebar,function() A:SetDisplayMode("blizzard") end,true)
    check("window","Separate window","Move and resize the party quest window independently.",window,function() A:SetDisplayMode("window") end,true)
    check("minimap","Show minimap button","Click to toggle party quests; right-click for settings; Shift-click to refresh.",function() return not A.db.hideMinimapButton end,function(v) A.db.hideMinimapButton=not v;A:UpdateMinimapButton() end)
    check("combatAutoHide","Collapse during combat","Restores the previous view after combat. With Questie loaded, only the Party Quests pane collapses; Questie's tracker keeps its own controls. Changes during combat apply afterward.",function() return A.db.combatAutoHide~=false end,function(v) A:SetCombatAutoHide(v) end)
    self.settingsQuestieStatus=text("")
    section("Tracker layout",sidebar)
    check("sidebarLeft","Party quests on the left","",function() return A.db.trackerSide~="right" end,function() A:SetTrackerSide("left") end,true)
    check("sidebarRight","Party quests on the right","",function() return A.db.trackerSide=="right" end,function() A:SetTrackerSide("right") end,true)
    self.settingsWidthLabel=text("")
    actions("narrower","Narrower",function() A:SetSidebarWidth((A.db.sidebarWidth or 420)-40) end,"wider","Wider",function() A:SetSidebarWidth((A.db.sidebarWidth or 420)+40) end)
    text("Height follows the active tracker: Questie's visible height, or Blizzard's Edit Mode setting. Longer lists scroll.")
    section("Window layout",window)
    check("locked","Lock position and size","",function() return A.db.locked end,function(v) A.db.locked=v end)
    actions("resetWindow","Reset position and size",function() A:ResetWindowLayout(false) end)
    section("Quests")
    check("combine","Combine shared quests","One entry per shared quest, with each player's progress underneath.",function() return A.db.combineShared end,function(v) A:SetCombineShared(v) end)
    check("zones","Group by zone","Organizes quests into collapsible zone headings.",function() return A.db.groupByZone end,function(v) A:SetGroupByZone(v) end)
    check("requestShares","Double-click to request a quest share","Checks known eligibility before whispering the quest owner.",function() return A.db.requestShares~=false end,function(v) A.db.requestShares=v end)
    section("Quest windows")
    self.settingsPaperLabel=text("")
    local paperSlider=CreateFrame("Slider","SimplyPartyQuestsParchmentBrightness",body,"OptionsSliderTemplate")
    paperSlider:SetMinMaxValues(35,100);paperSlider:SetValueStep(5);paperSlider:SetObeyStepOnDrag(true)
    for _,key in ipairs({"Low","High","Text"}) do
        local region=_G["SimplyPartyQuestsParchmentBrightness"..key]
        if A.readable(region) then region:SetText("") end
    end
    paperSlider:SetScript("OnValueChanged",function(_,value)
        if A.settingsPaperSync then return end
        A:SetQuestPaperBrightness(value);A:SyncSettings()
    end)
    self.settingsPaperSlider=paperSlider
    items[#items+1]={kind="slider",slider=paperSlider,when=condition}
    text("Darker paper improves yellow quest text. Text contrast adjusts with brightness; Copy/Import fields keep dark ink.")
    actions("resetPaper","Reset parchment brightness",function() A:SetQuestPaperBrightness(65) end)
    section("Tools")
    actions("shareLog","Share quest log",function() A:OpenQuestLogShare() end,"refresh","Refresh party quests",function() A:RefreshParty() end)
    text("Sharing opens full-log or selected-quest options. Refresh also scans for undiscovered party quests.")
    actions("advanced","Show troubleshooting",function() A.settingsAdvancedOpen=not A.settingsAdvancedOpen end)
    condition=advanced
    check("diagnostics","Record detailed diagnostics","Includes character names and quest information. Review the report before sharing.",function() return A.db.diag end,function(v) A:SetDetailedDiagnostics(v) end)
    actions("report","Open diagnostic report",function() A:ShowDiagnosticReport() end,"restartCapture","Start fresh capture",function() A:SetDetailedDiagnostics(true,true) end)
    condition=function() return advanced() and sidebar() end
    check("repair","Refresh stale Blizzard counts","Checks confirmed mismatches outside combat. Paused while Questie owns the tracker; your preference is preserved.",function() return A.db.nativeTrackerRepair end,function(v) A:SetNativeRepair(v) end)
    text("Capture a diagnostic report before refreshing a stuck tracker.")
    local function layout()
        local width=math.max(310,(panel:GetWidth() or 620)-60)
        body:SetWidth(width);local y=0
        for _,row in ipairs(items) do
            local shown=not row.when or not not row.when()
            if row.label then row.label:SetShown(shown) end
            if row.slider then row.slider:SetShown(shown) end
            if row.button then
                row.button:SetShown(shown);row.button.label:SetShown(shown);row.button.help:SetShown(shown)
            end
            for _,button in ipairs(row.buttons or {}) do button:SetShown(shown) end
            if shown then
            if row.kind=="text" then
                if row.heading then y=y+12 end
                row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT",0,-y);row.label:SetWidth(width-8)
                y=y+row.label:GetStringHeight()+12
            elseif row.kind=="slider" then
                row.slider:ClearAllPoints();row.slider:SetPoint("TOPLEFT",8,-y);row.slider:SetWidth(width-24)
                y=y+38
            elseif row.kind=="check" then
                local b=row.button
                b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y)
                b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",30,-y-3);b.label:SetWidth(width-36)
                local h=math.max(18,b.label:GetStringHeight())
                b.help:ClearAllPoints();b.help:SetPoint("TOPLEFT",30,-y-h-4);b.help:SetWidth(width-36)
                local helpHeight=b.help:GetStringHeight()
                y=y+h+(helpHeight>0 and helpHeight+16 or 10)
            else
                for i,b in ipairs(row.buttons) do
                    local w=(width-8*(#row.buttons-1))/#row.buttons
                    b:ClearAllPoints();b:SetPoint("TOPLEFT",(i-1)*(w+8),-y);b:SetWidth(w)
                end
                y=y+34
            end
            end
        end
        body:SetHeight(math.max(y,1))
        local height=scroll:GetHeight()
        if height and height>0 then
            local maxScroll=math.max(0,y-height)
            if scroll:GetVerticalScroll()>maxScroll then scroll:SetVerticalScroll(maxScroll) end
        end
    end
    self.settingsLayout=layout
    panel:SetScript("OnSizeChanged",layout)
    panel:SetScript("OnShow",function() layout();A:SyncSettings() end)
    layout();self:SyncSettings()
    self:RegisterSettingsCategory()
end
function A:RegisterSettingsCategory()
    if not self.settingsPanel or self.settingsCategory or self.settingsLegacy then return end
    -- Keep the real controls in our movable dialog. The native category is
    -- only a launcher, so opening it never reparents an active share/settings UI.
    local panel=self.settingsCategoryPanel
    if not panel then
        panel=CreateFrame("Frame",nil,UIParent);panel.name="Party Quests Forever";panel:Hide()
        local help=font(panel,"Open Party Quests settings in a movable window alongside your quest and sharing windows.")
        help:SetPoint("TOPLEFT",16,-20);help:SetWidth(520)
        local open=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
        open:SetSize(240,26);open:SetPoint("TOPLEFT",16,-65);open:SetText("Open Party Quests settings")
        open:SetScript("OnClick",function() A:OpenSettings() end)
        self.settingsCategoryPanel=panel
    end
    if Settings and type(Settings.RegisterCanvasLayoutCategory)=="function" and type(Settings.RegisterAddOnCategory)=="function" then
        local category=Settings.RegisterCanvasLayoutCategory(panel,panel.name)
        Settings.RegisterAddOnCategory(category);self.settingsCategory=category
    elseif type(InterfaceOptions_AddCategory)=="function" then
        InterfaceOptions_AddCategory(panel);self.settingsLegacy=true
    end
end

function A:ApplyPendingSettings()
    if self.settingsOpenPending and not (InCombatLockdown and InCombatLockdown()) then self:OpenSettings() end
end
function A:OpenSettings()
    if InCombatLockdown and InCombatLockdown() then
        if not self.settingsOpenPending then
            self.settingsOpenPending=true
            if self.CombatControlNotice then self:CombatControlNotice("Settings will open after combat.")
            else print("Party Quests Forever: settings will open after combat.") end
        end
        return false
    end
    self.settingsOpenPending=nil
    self:InitSettings();self:RegisterSettingsCategory();self:SyncSettings()
    -- Leaving our native launcher uses Blizzard's normal close flow, including
    -- its confirmation for unapplied game settings. Our host is not a UIPanel.
    local launcher=self.settingsCategoryPanel
    if launcher and launcher:IsShown() then
        if SettingsPanel and type(SettingsPanel.Close)=="function" and SettingsPanel:IsShown() then SettingsPanel:Close(true)
        elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and type(HideUIPanel)=="function" then HideUIPanel(InterfaceOptionsFrame) end
    end
    self:ShowSettingsDialog()
    return true
end
function A:ShowSettingsDialog()
    if not self.settingsDialog then
        local dialog=CreateFrame("Frame","SimplyPartyQuestsSettingsDialog",UIParent,"BackdropTemplate")
        dialog:SetSize(660,600);dialog:SetPoint("CENTER",-100,30);dialog:SetFrameStrata("MEDIUM")
        dialog:SetToplevel(true);dialog:SetClampedToScreen(true);dialog:EnableMouse(true)
        dialog:SetMovable(true);dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart",function() dialog:StartMoving() end)
        dialog:SetScript("OnDragStop",function() dialog:StopMovingOrSizing() end)
        dialog:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
        dialog:SetBackdropColor(0.04,0.05,0.07,1)
        local close=CreateFrame("Button",nil,dialog,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() dialog:Hide() end)
        self.settingsPanel:SetParent(dialog);self.settingsPanel:ClearAllPoints();self.settingsPanel:SetPoint("TOPLEFT",8,-8);self.settingsPanel:SetPoint("BOTTOMRIGHT",-8,8)
        self.settingsDialog=dialog
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="SimplyPartyQuestsSettingsDialog" end
    end
    self.settingsDialog:Show();self.settingsDialog:Raise();self.settingsPanel:Show()
end
