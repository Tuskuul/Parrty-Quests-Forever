local _, A = ...
local function font(parent,text,template)
    local f=parent:CreateFontString(nil,"ARTWORK",template or "GameFontHighlightSmall")
    f:SetJustifyH("LEFT");f:SetJustifyV("TOP");f:SetText(text);return f
end
function A:SetViewShown(shown)
    self.soloOverride=shown and next(self.members)==nil or nil
    if self.db.displayMode=="blizzard" then
        self.db.trackerHidden=not shown;self:InvalidateTrackerIntegration()
    else self.db.hidden=not shown;self.window:SetShown(shown and self:ShouldShowPartyView()) end
    self:SyncSettings()
end
function A:SetViewCollapsed(value)
    if self.db.displayMode=="blizzard" then
        self.db.trackerCollapsed=not not value;self:InvalidateTrackerIntegration()
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
        self.db.diagLines={};self.db.diagChanges={};self.db.diagEvents={}
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
    self.window:SetShown(self.db.displayMode=="window" and not self.db.hidden)
    self:SyncSettings()
end
function A:SyncSettings()
    if not self.settingsControls or not self.db then return end
    for _,c in pairs(self.settingsControls) do
        if c.get then c:SetChecked(not not c.get()) end
    end
    local count=0;for _ in pairs(self.members) do count=count+1 end
    self.settingsStatus:SetText("View: "..(self.db.displayMode=="blizzard" and "Tracker sidebar" or "Pop-out window").."   |   Party members: "..count)
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
    local function text(value,heading)
        items[#items+1]={kind="text",label=font(body,value,heading and "GameFontNormal" or "GameFontHighlightSmall"),heading=heading}
    end
    local function check(key,label,help,get,set,radio)
        local b=CreateFrame("CheckButton",nil,body,radio and "UIRadioButtonTemplate" or "UICheckButtonTemplate")
        b:SetSize(24,24);b.get=get
        b.label=font(body,label,"GameFontNormal");b.help=font(body,help)
        b:SetScript("OnClick",function()
            if radio then set(true) else set(not not b:GetChecked()) end
            A:SyncSettings();A:Render()
        end)
        self.settingsControls[key]=b;items[#items+1]={kind="check",button=b}
    end
    local function actions(aKey,aLabel,aFn,bKey,bLabel,bFn)
        local row={kind="actions",buttons={}}
        local function add(key,label,fn)
            local b=CreateFrame("Button",nil,body,"UIPanelButtonTemplate");b:SetHeight(24);b:SetText(label)
            b:SetScript("OnClick",function() fn();A:SyncSettings() end)
            self.settingsControls[key]=b;row.buttons[#row.buttons+1]=b
        end
        add(aKey,aLabel,aFn);if bKey then add(bKey,bLabel,bFn) end
        items[#items+1]=row
    end
    text("Choose where party quests appear and how they are organized. Changes are saved immediately.")
    text("Quick access",true)
    actions("shareLog","Share my quest log in chat",function() A:OpenQuestLogShare() end)
    text("Creates a snapshot of your current quests and objective progress, then opens a chat draft for you to send. Recipients with this addon click it to view the snapshot. Links can be fetched for 15 minutes while you remain online. Completion means active objective progress / ready for turn-in, not your lifetime quest history.")
    check("minimap","Show minimap button","Left-click toggles party quests; right-click opens settings; Shift-click refreshes. Drag it around the minimap to move it.",function() return not A.db.hideMinimapButton end,function(v) A.db.hideMinimapButton=not v;A:UpdateMinimapButton() end)
    text("Display",true)
    check("blizzard","Beside Blizzard's objective tracker","Adds an independent scrolling list beside the normal tracker, using Blizzard's tracker fonts and colors.",function() return A.db.displayMode=="blizzard" end,function() A:SetDisplayMode("blizzard") end,true)
    check("window","Separate resizable window","Drag the title bar to move it, or the bottom-right corner to resize it.",function() return A.db.displayMode=="window" end,function() A:SetDisplayMode("window") end,true)
    check("visible","Show party quests","Automatically hidden when solo. You can open it anyway with the Party Quests button. Background discovery continues.",function() return A.db.displayMode=="blizzard" and not A.db.trackerHidden or A.db.displayMode=="window" and not A.db.hidden end,function(v) A:SetViewShown(v) end)
    check("collapsed","Collapse the selected party view","Keeps the heading visible and hides its contents.",function() return A.db.displayMode=="blizzard" and A.db.trackerCollapsed or A.db.displayMode=="window" and A.db.collapsed end,function(v) A:SetViewCollapsed(v) end)
    text("Tracker sidebar",true)
    check("sidebarLeft","Left of the default tracker","The default. Best when Blizzard's tracker is near the right edge.",function() return A.db.trackerSide~="right" end,function() A:SetTrackerSide("left") end,true)
    check("sidebarRight","Right of the default tracker","Choose this when there is room to the right. Both columns move with the default tracker.",function() return A.db.trackerSide=="right" end,function() A:SetTrackerSide("right") end,true)
    actions("narrower","Narrower sidebar",function() A:SetSidebarWidth((A.db.sidebarWidth or 420)-40) end,"wider","Wider sidebar",function() A:SetSidebarWidth((A.db.sidebarWidth or 420)+40) end)
    text("Height grows with the quest list, up to the Objective Tracker height set in Blizzard Edit Mode. Longer lists scroll. Small or empty lists stay compact. Click a player's name to collapse their personal sections.")
    text("Width defaults to 420 pixels and adjusts from 320 to 640. The panel follows the default tracker's position and visibility; scroll for longer lists.")
    check("requestShares","Double-click foreign quests to request a share","Single-click still expands. Double-click checks completion and known requirements, then whispers the quest owner. Unknown eligibility sends nothing; repeat requests have a cooldown.",function() return A.db.requestShares~=false end,function(v) A.db.requestShares=v end)
    text("Quest organization",true)
    check("combine","Combine shared quests","Show each quest you share with any party member once, with individual player progress.",function() return A.db.combineShared end,function(v) A:SetCombineShared(v) end)
    check("zones","Group quests by zone","Adds collapsible zone or quest-category headings. Unmatched quests use Unknown zone.",function() return A.db.groupByZone end,function(v) A:SetGroupByZone(v) end)
    check("locked","Lock pop-out movement and resizing","Keeps the separate window at its saved position and size.",function() return A.db.locked end,function(v) A.db.locked=v end)
    actions("refresh","Refresh party quests",function() A:RefreshParty() end,"scan","Scan for party quests",function() A:StartSweep() end)
    text("Refresh uses current sources. A scan checks the known quest catalog for additional party quests. Some work waits until combat ends.")
    actions("resetWindow","Reset window position and size",function() A:ResetWindowLayout(false) end)
    text("Blizzard tracker recovery",true)
    check("repair","Refresh stale Blizzard tracker counts","Enabled by default. Refreshes confirmed count mismatches outside combat and pauses if the result is blank or cannot be verified. You can disable it here.",function() return A.db.nativeTrackerRepair end,function(v) A:SetNativeRepair(v) end)
    actions("redraw","Refresh Blizzard tracker now",function() A:QueueNativeTracker("manual",true) end)
    text("Troubleshooting",true)
    actions("shareApiProbe","Inspect share APIs",function() A:StartShareApiProbe() end)
    text("Read-only: checks the last clicked quest and up to four own/four foreign quests before and after a data request. Captures native quest/share-related messages for 90 seconds. It sends no whispers and shares no quests. Reopen the report after testing.")
    check("diagnostics","Record detailed diagnostics","Collects recent quest responses and progress events, including character names. Turning this off keeps the captured report.",function() return A.db.diag end,function(v) A:SetDetailedDiagnostics(v) end)
    actions("report","Open diagnostic report",function() A:ShowDiagnosticReport() end,"restartCapture","Start a fresh capture",function() A:SetDetailedDiagnostics(true,true) end)
    text("Capture the report before manually refreshing a stuck tracker. Review names and quest information before sharing it.")
    actions("clear","Clear discovered quest cache",function()
        for _,m in pairs(A.members) do if not m.syncedAt then m.quests={} end end;A:Render()
    end,"preview","Toggle sample preview",function() A:SetDisplayMode("window");A:Demo() end)
    text("Clearing discoveries leaves synced full logs alone; refresh or scan to discover quests again. The sample preview does not change real party progress.")
    local function layout()
        local width=math.max(310,(panel:GetWidth() or 620)-60)
        body:SetWidth(width);local y=0
        for _,row in ipairs(items) do
            if row.kind=="text" then
                if row.heading then y=y+12 end
                row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT",0,-y);row.label:SetWidth(width-8)
                y=y+row.label:GetStringHeight()+12
            elseif row.kind=="check" then
                local b=row.button
                b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-y)
                b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",30,-y-3);b.label:SetWidth(width-36)
                local h=math.max(18,b.label:GetStringHeight())
                b.help:ClearAllPoints();b.help:SetPoint("TOPLEFT",30,-y-h-4);b.help:SetWidth(width-36)
                y=y+h+b.help:GetStringHeight()+16
            else
                for i,b in ipairs(row.buttons) do
                    local w=(width-8*(#row.buttons-1))/#row.buttons
                    b:ClearAllPoints();b:SetPoint("TOPLEFT",(i-1)*(w+8),-y);b:SetWidth(w)
                end
                y=y+34
            end
        end
        body:SetHeight(math.max(y,1))
    end
    panel:SetScript("OnSizeChanged",layout)
    panel:SetScript("OnShow",function() layout();A:SyncSettings() end)
    layout();self:SyncSettings()
    self:RegisterSettingsCategory()
end
function A:RegisterSettingsCategory()
    if not self.settingsPanel or self.settingsCategory or self.settingsLegacy then return end
    local panel=self.settingsPanel
    if Settings and type(Settings.RegisterCanvasLayoutCategory)=="function" and type(Settings.RegisterAddOnCategory)=="function" then
        local category=Settings.RegisterCanvasLayoutCategory(panel,panel.name)
        Settings.RegisterAddOnCategory(category);self.settingsCategory=category
    elseif type(InterfaceOptions_AddCategory)=="function" then
        InterfaceOptions_AddCategory(panel);self.settingsLegacy=true
    end
end

function A:OpenSettings()
    self:InitSettings();self:RegisterSettingsCategory();self:SyncSettings()
    if self.settingsCategory and Settings and type(Settings.OpenToCategory)=="function" then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif self.settingsLegacy and type(InterfaceOptionsFrame_OpenToCategory)=="function" then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        if not self.settingsDialog then
            local dialog=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
            dialog:SetSize(660,600);dialog:SetPoint("CENTER");dialog:SetFrameStrata("DIALOG")
            dialog:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});dialog:SetBackdropColor(0.04,0.05,0.07,1)
            local close=CreateFrame("Button",nil,dialog,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() dialog:Hide() end)
            self.settingsPanel:SetParent(dialog);self.settingsPanel:ClearAllPoints();self.settingsPanel:SetPoint("TOPLEFT",8,-8);self.settingsPanel:SetPoint("BOTTOMRIGHT",-8,8)
            self.settingsDialog=dialog
        end
        self.settingsPanel:Show();self.settingsDialog:Show()
    end
end
