local _,A=...
local function combat() return InCombatLockdown and InCombatLockdown() end
local function read(object,method,...)
    local fn=object and object[method]
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,object,...)
    if ok and not A.secret(v) then return v end
end
local function finite(v) return A.public(v,"number") and v==v and math.abs(v)<100000 end
local function number(v) return finite(v) and v>0 end
function A:TrackerTabsRequested()
    return self.db and self.db.displayMode=="blizzard" and self.db.defaultTrackerLayout=="tabs"
        and not (self.QuestieOwnsTracker and self:QuestieOwnsTracker())
end
function A:TrackerTabsWanted()
    return self:TrackerTabsRequested() and not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
end
function A:TrackerTabsNotice(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Party Quests:|r "..message) end
end
function A:SetDefaultTrackerLayout(layout)
    if layout~="tabs" and layout~="sidebar" then return end
    if combat() then
        if self.integration.pendingTrackerLayout~=layout then
            self.integration.pendingTrackerLayout=layout
            self:TrackerTabsNotice("Tracker layout change queued until combat ends.")
        end
        return
    end
    self.db.defaultTrackerLayout=layout
    self:InvalidateTrackerIntegration(true);self:TrackerIntegrationTick()
    if self.SyncSettings then self:SyncSettings() end
end
function A:SelectTrackerTab(tab)
    if tab~="objectives" and tab~="party" then return end
    local t=self.trackerTabs
    if not t or not t.active then return end
    if combat() then
        if tab==self.db.trackerTab then t.pending=nil
        elseif t.pending~=tab then
            t.pending=tab;self:TrackerTabsNotice((tab=="party" and "Party Quests" or "Objectives").." tab queued until combat ends.")
        end
        self:UpdateTrackerTabsLabels();return
    end
    t.pending=nil;self.db.trackerTab=tab
    self:InvalidateTrackerIntegration(true);self:TrackerIntegrationTick()
end
function A:SetTabbedPartyCollapsed(value)
    local t=self.trackerTabs
    if combat() then t.combatCollapsed=not not value else self.db.trackerCollapsed=not not value end
    self:InvalidateTrackerIntegration();self:TrackerIntegrationTick()
end
function A:UpdateTrackerTabsLabels()
    local t=self.trackerTabs
    if not t then return end
    for i,key in ipairs({"objectives","party"}) do
        local selected=self.db.trackerTab==key
        local label=key=="party" and "Party Quests" or "Objectives"
        local button=t.buttons[i]
        local caption=label..(t.pending==key and " *" or "")
        local signature=caption..":"..tostring(selected)
        if button.tabVisualKey~=signature then
            button.tabVisualKey=signature;button:SetText(caption)
            if button.nativeTab then
                if selected then PanelTemplates_SelectTab(button) else PanelTemplates_DeselectTab(button) end
                -- Keep the active tab clickable so it can cancel a queued switch.
                button:Enable()
                PanelTemplates_TabResize(button,0,116)
            else
                button.selected:SetShown(selected)
                button:SetNormalFontObject(selected and (GameFontNormalSmall or GameFontNormal) or (GameFontDisableSmall or GameFontNormal))
                button:SetBackdropBorderColor(selected and 0.85 or 0.45,selected and 0.68 or 0.45,selected and 0.28 or 0.45,1)
            end
        end
    end
end
-- Native visibility belongs to a restricted controller prepared outside combat.
-- The ordinary addon tick only writes our independent frames during lockdown.
local state=[[
    if not self:GetAttribute("enabled") then return end
    local native=self:GetFrameRef("native")
    local hide=self:GetAttribute("party") or (newstate==1 and self:GetAttribute("auto"))
    self:SetAttribute("applying",true)
    if hide then native:Hide(true)
    elseif self:GetAttribute("wanted") then native:Show(true) end
    self:SetAttribute("applying",nil)
]]
function A:InitTrackerTabs(native)
    if combat() then return false end
    if type(RegisterStateDriver)~="function" or type(SecureHandlerWrapScript)~="function" then return false end
    local t=self.trackerTabs
    if not t then
        t={};self.trackerTabs=t
        t.bar=CreateFrame("Frame","SimplyPartyQuestsTrackerTabs",UIParent)
        t.bar:SetSize(240,28);t.bar:SetFrameStrata("MEDIUM");t.bar:SetClampedToScreen(true);t.buttons={}
        t.bar.tabPadding=0;t.bar.minTabWidth=116;t.bar.maxTabWidth=116
        for i,key in ipairs({"objectives","party"}) do
            local nativeTab=type(PanelTopTabButtonMixin)=="table" and type(PanelTemplates_SelectTab)=="function"
                and type(PanelTemplates_DeselectTab)=="function" and type(PanelTemplates_TabResize)=="function"
            local button=CreateFrame("Button",nil,t.bar,nativeTab and "PanelTopTabButtonTemplate" or "BackdropTemplate")
            button.nativeTab=nativeTab
            button:SetSize(116,28);button:SetPoint("BOTTOMLEFT",t.bar,"BOTTOMLEFT",(i-1)*120,0)
            if nativeTab then
                button.selected=button.MiddleActive
            else
                -- Older clients retain a framed tab, not a flat text/underline.
                button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
                button:SetBackdropColor(0.05,0.04,0.025,0.9)
                button:SetNormalFontObject(GameFontNormalSmall or GameFontNormal)
                button:SetHighlightFontObject(GameFontHighlightSmall or GameFontNormal)
                local selected=button:CreateTexture(nil,"ARTWORK");selected:SetColorTexture(0.8,0.55,0.12,0.16)
                selected:SetPoint("TOPLEFT",3,-3);selected:SetPoint("BOTTOMRIGHT",-3,3)
                button.selected=selected
            end
            button:SetScript("OnClick",function() A:SelectTrackerTab(key) end)
            button:SetScript("OnEnter",function(self)
                if GameTooltip then
                    GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText(key=="party" and "Party Quests" or "Objectives")
                    GameTooltip:AddLine("Switch views here. During combat, a change is queued until combat ends.",1,1,1,true);GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            t.buttons[i]=button
        end
        t.control=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
        t.control:SetAttribute("enabled",false);t.control:SetAttribute("_onstate-combat",state)
        RegisterStateDriver(t.control,"combat","[combat] 1; 0")
        t.bar:Hide();t.wrapped={}
    end
    if not t.wrapped[native] then
        SecureHandlerWrapScript(native,"OnShow",t.control,[[
            if control:GetAttribute("enabled") and self==control:GetFrameRef("native") then
                if not control:GetAttribute("applying") then control:SetAttribute("wanted",true) end
                if control:GetAttribute("party") or (control:GetAttribute("state-combat")==1 and control:GetAttribute("auto")) then
                    control:SetAttribute("applying",true);self:Hide(true);control:SetAttribute("applying",nil)
                end
            end
        ]])
        SecureHandlerWrapScript(native,"OnHide",t.control,[[
            if control:GetAttribute("enabled") and self==control:GetFrameRef("native") and not control:GetAttribute("applying") then
                control:SetAttribute("wanted",false)
            end
        ]])
        t.wrapped[native]=true
    end
    t.control:SetFrameRef("native",native);t.native=native
    return true
end
function A:LeaveTrackerTabs()
    local t=self.trackerTabs
    if not t or not t.active then return true end
    if combat() then return false end
    t.control:SetAttribute("enabled",false)
    if t.control:GetAttribute("wanted") and self:NativeTrackerWritesAllowed() then
        local ok,err=self:CallNativeTrackerMethod(t.native,"Show")
        if not ok then self.integration.lastError=err;return false end
    end
    t.active=nil;t.pending=nil;t.combatCollapsed=nil;t.bar:Hide()
    local f=self.sidebar
    f.title:Show();f.headerArt:Show();f.headerOffset=nil
    f.settings:ClearAllPoints();f.settings:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-3)
    f.refresh:ClearAllPoints();f.refresh:SetPoint("RIGHT",f.settings,"LEFT",-6,0)
    f.share:ClearAllPoints();f.share:SetPoint("RIGHT",f.refresh,"LEFT",-6,0)
    f.scroll:Show();f:Hide();f.trackerBackground:Hide()
    self.integration.anchor=nil;self.integration.appearanceSignature=nil;self.integration.sidebarScale=nil
    self:InvalidateTrackerIntegration();return true
end
function A:TrackerTabsTick()
    local t=self.trackerTabs
    if not combat() and self.integration.pendingTrackerLayout then
        self.db.defaultTrackerLayout=self.integration.pendingTrackerLayout;self.integration.pendingTrackerLayout=nil
        if self.SyncSettings then self:SyncSettings() end
    end
    if not self:TrackerTabsWanted() or self.integration.pendingDisplayMode then
        if t and t.active and not self:LeaveTrackerTabs() then return true end
        return false
    end
    local native=ObjectiveTrackerFrame
    if not native then return false end
    if combat() and (not t or not t.active or t.native~=native) then return false end
    if not combat() then
        if t and t.active and t.native~=native then
            if not self:LeaveTrackerTabs() then return true end
        end
        if not t or not t.active then
            if self.integration.tabsRetryAt and GetTime()<self.integration.tabsRetryAt then return false end
            if self.integration.combatRestorePending then self:RestoreCombatModules() end
            if self.ReleaseNativeCombatControl then self:ReleaseNativeCombatControl() end
            self:RestoreJoinedTrackerHeader();self:RestoreTrackerJoinVisuals()
            local ok,ready=pcall(self.InitTrackerTabs,self,native)
            if not ok or not ready then
                self.integration.tabsRetryAt=GetTime()+10
                self.integration.lastError="Tabbed tracker setup unavailable; using sidebar";return false
            end
            t=self.trackerTabs;t.control:SetAttribute("wanted",read(native,"IsShown")==true)
            self:InitTrackerSidebar();t.active=true;self.integration.dirty=true;self.integration.due=nil
        end
        if t.pending then self.db.trackerTab=t.pending;t.pending=nil end
        local scale,ui=read(native,"GetEffectiveScale"),read(UIParent,"GetEffectiveScale")
        local left,top,width=read(native,"GetLeft"),read(native,"GetTop"),read(native,"GetWidth")
        if not number(scale) or not number(ui) or not finite(left) or not number(top) or not number(width) then
            self:LeaveTrackerTabs();return false
        end
        local ratio=scale/ui
        if not number(ratio) or ratio>100 then self:LeaveTrackerTabs();return false end
        local f=self.sidebar
        local geometry=table.concat({width,ratio},":")
        if t.geometry~=geometry then t.geometry=geometry;self.integration.dirty=true;self.integration.due=nil end
        self:SyncTrackerSidebarAppearance(native)
        f:SetScale(ratio);t.bar:SetScale(ratio)
        -- Numeric UIParent anchors do not inherit the native frame's protection.
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        t.bar:ClearAllPoints();t.bar:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",left,top+2)
        t.bar:SetWidth(math.max(240,math.min(640,width)))
        f:SetWidth(math.max(240,math.min(640,width)));f.heightLimit=self:TrackerSidebarHeightLimit(native)
        f.headerOffset=0;f.title:Hide();f.headerArt:Hide()
        f.share:ClearAllPoints();f.share:SetPoint("TOPLEFT",f,"TOPLEFT",7,-3)
        f.refresh:ClearAllPoints();f.refresh:SetPoint("LEFT",f.share,"RIGHT",6,0)
        f.settings:ClearAllPoints();f.settings:SetPoint("LEFT",f.refresh,"RIGHT",6,0)
        f.collapse:ClearAllPoints();f.collapse:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-6)
        f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7,-32)
        if self.partyTrackerButton then self.partyTrackerButton:Hide() end
        t.control:SetAttribute("party",self.db.trackerTab=="party")
        t.control:SetAttribute("auto",self.db.combatAutoHide~=false)
        t.control:SetAttribute("enabled",true)
        local method=self.db.trackerTab=="party" and "Hide" or (t.control:GetAttribute("wanted") and "Show" or nil)
        if method and (read(native,"IsShown")==true)~=(method=="Show") then
            t.control:SetAttribute("applying",true)
            local ok,err=self:CallNativeTrackerMethod(native,method)
            t.control:SetAttribute("applying",nil)
            if not ok then self.integration.lastError=err;self:LeaveTrackerTabs();return false end
        end
    end
    local f,s=self.sidebar,self.integration
    local party=self.db.trackerTab=="party"
    if combat() and not t.inCombat then t.combatCollapsed=self.db.combatAutoHide~=false or self.db.trackerCollapsed==true end
    if not combat() then t.combatCollapsed=nil end
    t.inCombat=combat() and true or nil
    f.viewCollapsed=combat() and t.combatCollapsed or (not combat() and self.db.trackerCollapsed==true)
    f.scroll:SetShown(not f.viewCollapsed);f.collapse:Show()
    local atlas=f.viewCollapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
    f.collapse.normal:SetAtlas(atlas);f.collapse.pushed:SetAtlas(atlas.."-pressed")
    if s.dirty and party and (not s.due or GetTime()>=s.due) then
        local ok,err=pcall(function()
            s.entries,s.memberCount=self:BuildTrackerEntries();self:RenderTrackerSidebar(s.entries,s.memberCount)
        end)
        if ok then s.dirty=false;s.due=nil
        else s.lastError=self.public(err,"string") and err or "Tabbed party render unavailable";s.due=GetTime()+1 end
    end
    self:SizeTrackerSidebar();self:UpdateTrackerQuestFocus()
    f:SetShown(party);t.bar:Show();self:UpdateTrackerTabsLabels()
    self:SyncTrackerSidebarOpacity(native)
    local bg=f.trackerBackground
    bg:ClearAllPoints();bg:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);bg:SetSize(f:GetWidth(),f:GetHeight());bg:SetScale(f:GetScale())
    bg:SetShown(party)
    if self.window then self.window:Hide() end
    s.attached=true;s.status="Blizzard tabs: "..self.db.trackerTab..(t.pending and " (switch queued)" or "")
    return true
end
