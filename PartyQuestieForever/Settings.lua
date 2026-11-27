local _,P=...
local A=P.host
if not A then return end
function P:SyncSettings()
    if not self.buttons then return end
    self.buttons.tabs:SetChecked(self:Layout()=="tabs")
    self.buttons.sidebar:SetChecked(self:Layout()=="sidebar")
end
function P:PatchHostSettings()
    local c=A.settingsControls
    if not c then return end
    for _,key in ipairs({"layoutTabs","layoutSidebar"}) do
        local button=c[key]
        if button then
            local layout=key=="layoutTabs" and "tabs" or "sidebar"
            button.get=function()
                local current=A:QuestieOwnsTracker() and P:Layout() or A.db.defaultTrackerLayout
                return current==layout
            end
            if button.help then button.help:SetText(layout=="tabs"
                and "Both tabs stay available, including while solo. Questie uses Party Questie Forever's separate layout preference. Combat switches queue until combat ends."
                or "Show the active tracker and party pane beside each other.") end
        end
    end
end
local init, sync=A.InitSettings,A.SyncSettings
function A:InitSettings(...)
    init(self,...);P:PatchHostSettings()
end
function A:SyncSettings(...)
    sync(self,...);P:SyncSettings()
end
function P:InitSettings()
    self:PatchHostSettings()
    if self.panel then return end
    local panel=CreateFrame("Frame")
    panel.name="Party Questie Forever";self.panel=panel;self.buttons={}
    local function text(value,template,x,y)
        local label=panel:CreateFontString(nil,"ARTWORK",template)
        label:SetPoint("TOPLEFT",x,y);label:SetWidth(550);label:SetJustifyH("LEFT");label:SetText(value)
        return label
    end
    text("Party Questie Forever","GameFontNormalLarge",16,-16)
    text("Questie tracker integration for Party Quests Forever. Both addons remain installed and enabled.","GameFontHighlight",16,-52)
    text("Questie tracker layout","GameFontNormal",16,-102)
    for i,choice in ipairs({{"tabs","Tabbed"},{"sidebar","Side by Side"}}) do
        local key,label=choice[1],choice[2]
        local button=CreateFrame("CheckButton",nil,panel,"UIRadioButtonTemplate")
        button:SetSize(24,24);button:SetPoint("TOPLEFT",16,-126-(i-1)*34)
        local caption=button:CreateFontString(nil,"ARTWORK","GameFontHighlight")
        caption:SetPoint("LEFT",button,"RIGHT",4,0);caption:SetText(label)
        button:SetScript("OnClick",function() P:SetLayout(key);P:SyncSettings() end)
        self.buttons[key]=button
    end
    text("Tabbed shares one tracker area. Use Objectives to move or resize Questie. Layout changes made during combat apply afterward.","GameFontHighlightSmall",16,-216)
    local open=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    open:SetSize(240,26);open:SetPoint("TOPLEFT",16,-276);open:SetText("Open Party Quests settings")
    open:SetScript("OnClick",function() A:OpenSettings() end)
    panel:SetScript("OnShow",function() P:SyncSettings() end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.category=Settings.RegisterCanvasLayoutCategory(panel,panel.name)
        Settings.RegisterAddOnCategory(self.category)
    elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
    self:SyncSettings()
end
