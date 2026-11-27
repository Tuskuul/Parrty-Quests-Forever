local addon,P=...
local api=PartyQuestsForeverAPI
local function message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Party Questie Forever:|r "..text) end
end
if type(api)~="table" or type(api.RegisterTrackerPlugin)~="function" then
    message("This PQF version has no plugin support. Install the matching plugin-enabled Party Quests Forever test build.")
    return
end
local host,err=api.RegisterTrackerPlugin(addon,1)
if not host then message(err or "Unable to attach to Party Quests Forever.");return end
P.host=host
P.original={EffectiveDisplayMode=host.EffectiveDisplayMode,
    QuestieSummary=host.QuestieSummary}
function P:Layout() return self.db and self.db.layout or "tabs" end
function P:SetLayout(layout)
    if layout~="tabs" and layout~="sidebar" then return end
    host:SetDefaultTrackerLayout(layout,"questieTrackerLayout")
end
function host:EffectiveDisplayMode()
    if self.QuestieTabsRequested and self:QuestieTabsRequested() then return "blizzard" end
    return P.original.EffectiveDisplayMode(self)
end
function host:QuestieSummary()
    if self.trackerTabs and self.trackerTabs.active and self.trackerTabs.provider=="questie" then
        return "Party Questie Forever: tabbed Questie tracker active"
    end
    return P.original.QuestieSummary(self)
end
local events=CreateFrame("Frame");P.events=events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(self,_,name)
    if name~=addon then return end
    PartyQuestieForeverDB=host.readable(PartyQuestieForeverDB) and PartyQuestieForeverDB or {}
    P.db=PartyQuestieForeverDB
    if P.db.layout~="tabs" and P.db.layout~="sidebar" then P.db.layout="tabs" end
    if P.InitSettings then P:InitSettings() end
    host:InvalidateTrackerIntegration(true);host:TrackerIntegrationTick()
    if host.SyncSettings then host:SyncSettings() end
    self:UnregisterEvent("ADDON_LOADED")
end)
