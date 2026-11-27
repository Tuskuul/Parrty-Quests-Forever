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
    if not self.db or self.db.displayMode~="blizzard" then return false end
    if self.QuestieOwnsTracker and self:QuestieOwnsTracker() then
        return self.QuestieTabsRequested and self:QuestieTabsRequested()
    end
    return self.db.defaultTrackerLayout=="tabs"
end
function A:TrackerLayoutSetting()
    return self.QuestieTabsRequested and self:QuestieOwnsTracker() and "questieTrackerLayout" or "defaultTrackerLayout"
end
function A:TrackerTabsFrameMethod(frame,method,...)
    if self.trackerTabs and self.trackerTabs.provider=="questie" then
        if combat() then return false,"Questie tab ownership change deferred in combat" end
        if frame~=Questie_BaseFrame and frame~=self.trackerTabs.native then return false,"Not the Questie tab root" end
        return pcall(frame[method],frame,...)
    end
    return self:CallNativeTrackerMethod(frame,method,...)
end
function A:TrackerTabsWanted()
    -- Layout availability is independent of party membership and the old
    -- sidebar Hide preference. The Party tab can display the empty-party state.
    return self:TrackerTabsRequested() and not self.demo
end
function A:TrackerTabsNotice(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Party Quests:|r "..message) end
end
function A:TrackerTabsReport()
    local t=self.trackerTabs
    if not t or not t.active then return "Tabs visibility: inactive; open queued="..tostring(self.integration.tabsOpenPending==true) end
    return "Tabs visibility: provider="..tostring(t.provider).."; host shown="..tostring(read(t.control,"IsShown"))
        .."; native shown="..tostring(read(t.native,"IsShown"))
        .."; native visible="..tostring(read(t.native,"IsVisible"))
        .."; parent owned="..tostring(read(t.native,"GetParent")==t.control)
end
function A:SetDefaultTrackerLayout(layout)
    if layout~="tabs" and layout~="sidebar" then return end
    if combat() then
        if self.integration.pendingTrackerLayout~=layout then
            self.integration.pendingTrackerLayout=layout
            self.integration.pendingTrackerLayoutKey=self:TrackerLayoutSetting()
            self:TrackerTabsNotice("Tracker layout change queued until combat ends.")
        end
        return
    end
    self.db[self:TrackerLayoutSetting()]=layout
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
function A:ToggleTabbedTracker()
    local t=self.trackerTabs
    if t and t.active then
        self:SelectTrackerTab(self.db.trackerTab=="party" and "objectives" or "party");return
    end
    if combat() then
        if not self.integration.tabsOpenPending then
            self.integration.tabsOpenPending=true
            self:TrackerTabsNotice("Party Quests tabs will open after combat.")
        end
        return
    end
    self:SetViewShown(true)
end
function A:SetTabbedPartyCollapsed(value)
    local t=self.trackerTabs
    if combat() then t.combatCollapsed=not not value else self.db.trackerCollapsed=not not value end
    self:InvalidateTrackerIntegration();self:TrackerIntegrationTick()
end
function A:UpdateTrackerTabsLabels()
    local t=self.trackerTabs
    if not t then return end
    local font=ObjectiveTrackerHeaderFont or GameFontNormal
    local face,size
    if font and type(font.GetFont)=="function" then face,size=font:GetFont() end
    size=number(size) and size or 14
    for i,key in ipairs({"objectives","party"}) do
        local selected=self.db.trackerTab==key
        local label=key=="party" and "Party Quests" or "Objectives"
        local button=t.buttons[i]
        local caption=label..(t.pending==key and " *" or "")
        local signature=caption..":"..tostring(selected)..":"..size
        if button.tabVisualKey~=signature then
            button.tabVisualKey=signature;button:SetText(caption)
            if button.nativeTab then
                if selected then PanelTemplates_SelectTab(button) else PanelTemplates_DeselectTab(button) end
                -- Keep the active tab clickable so it can cancel a queued switch.
                button:Enable()
                button:SetNormalFontObject(font);button:SetHighlightFontObject(font)
                PanelTemplates_TabResize(button,8,nil,112,200)
            else
                button.selected:SetShown(selected)
                button:SetNormalFontObject(font);button:SetHighlightFontObject(font)
                button:SetBackdropBorderColor(selected and 0.85 or 0.45,selected and 0.68 or 0.45,selected and 0.28 or 0.45,1)
                local label=read(button,"GetFontString")
                local width=read(label,"GetStringWidth")
                button:SetWidth(number(width) and math.max(112,math.min(200,width+24)) or 132)
            end
            local label=read(button,"GetFontString")
            if label then
                label:SetHeight(size+6);label:ClearAllPoints();label:SetPoint("CENTER",button,"CENTER",0,selected and -2 or -6)
            end
        end
    end
    t.bar:SetHeight(math.max(28,size+12))
    for _,button in ipairs(t.buttons) do button:SetHeight(t.bar:GetHeight()) end
end
-- A dedicated protected parent owns tab visibility. Native Show/SetShown and
-- turn-in layouts can run normally without revealing a hidden ancestor.
local state=[[
    if not self:GetAttribute("enabled") then return end
    local native=self:GetFrameRef("native")
    if native then native:SetParent(self) end
    local hide=self:GetAttribute("party") or (newstate==1 and self:GetAttribute("auto"))
    if hide then self:Hide(true) else self:Show(true) end
]]
function A:InitTrackerTabs(native)
    if combat() then return false end
    if not (self.QuestieTabsRequested and self:QuestieTabsRequested()) and
        (type(RegisterStateDriver)~="function" or type(SecureHandlerWrapScript)~="function") then return false end
    local provider=self.QuestieTabsRequested and self:QuestieTabsRequested() and "questie" or "blizzard"
    local t=self.trackerTabs
    if t and t.provider~=provider then
        self.trackerTabsCache=self.trackerTabsCache or {};self.trackerTabsCache[t.provider]=t
        t=self.trackerTabsCache[provider];self.trackerTabs=t
    end
    if not t then
        t={provider=provider};self.trackerTabs=t
        t.bar=CreateFrame("Frame",nil,UIParent)
        t.bar:SetSize(240,28);t.bar:SetFrameStrata("MEDIUM");t.bar:SetClampedToScreen(true);t.buttons={}
        t.bar.tabPadding=8;t.bar.minTabWidth=112;t.bar.maxTabWidth=200
        for i,key in ipairs({"objectives","party"}) do
            local nativeTab=type(PanelTopTabButtonMixin)=="table" and type(PanelTemplates_SelectTab)=="function"
                and type(PanelTemplates_DeselectTab)=="function" and type(PanelTemplates_TabResize)=="function"
            local button=CreateFrame("Button",nil,t.bar,nativeTab and "PanelTopTabButtonTemplate" or "BackdropTemplate")
            button.nativeTab=nativeTab
            button:SetSize(132,28)
            if i==1 then button:SetPoint("BOTTOMLEFT",t.bar,"BOTTOMLEFT",0,0)
            else button:SetPoint("BOTTOMLEFT",t.buttons[i-1],"BOTTOMRIGHT",6,0) end
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
        -- Questie uses an ordinary visibility parent: making its root secure would
        -- restrict Questie's own layout writes during combat.
        t.control=CreateFrame("Frame",nil,UIParent,provider=="blizzard" and "SecureHandlerStateTemplate" or nil)
        if provider=="blizzard" then
            t.control:SetAttribute("enabled",false);t.control:SetAttribute("_onstate-combat",state)
            RegisterStateDriver(t.control,"combat","[combat] 1; 0")
        end
        t.bar:Hide();t.wrapped={}
    end
    local parent=read(native,"GetParent")
    if not parent or parent==t.control then return false end
    t.originalParent=parent;t.originalLevel=read(native,"GetFrameLevel")
    local parentScale,uiScale=read(parent,"GetEffectiveScale"),read(UIParent,"GetEffectiveScale")
    if not number(parentScale) or not number(uiScale) then return false end
    local ratio=parentScale/uiScale
    if not number(ratio) or ratio>100 then return false end
    -- Keep our host out of the managed container's layout-child list, while
    -- preserving its bounds and inherited scale for native height calculations.
    t.control:SetParent(UIParent);t.control.ignoreInLayout=true
    t.control:SetScale(ratio);t.control:ClearAllPoints();t.control:SetAllPoints(parent)
    t.control:Show()
    if provider=="blizzard" then t.control:SetFrameRef("native",native) end
    if provider=="blizzard" and not t.wrapped[native] then
        -- The managed-frame system can reparent a tracker while showing it.
        -- Preserve the tab's ancestor after that native OnShow has completed.
        SecureHandlerWrapScript(native,"OnShow",t.control,[[ return true,true ]],[[
            if control:GetAttribute("enabled") and self==control:GetFrameRef("native") then
                self:SetParent(control)
            end
        ]])
        t.wrapped[native]=true
    end
    local ok,err=self:TrackerTabsFrameMethod(native,"SetParent",t.control)
    if not ok then error(err) end
    if finite(t.originalLevel) then
        ok,err=self:TrackerTabsFrameMethod(native,"SetFrameLevel",t.originalLevel)
        if not ok then
            self:TrackerTabsFrameMethod(native,"SetParent",parent)
            error(err)
        end
    end
    t.native=native
    return true
end
function A:LeaveTrackerTabs()
    local t=self.trackerTabs
    if not t or not t.active then return true end
    if combat() then return false end
    if t.provider=="blizzard" then t.control:SetAttribute("enabled",false) end
    -- Restore ownership, not a stale shown/hidden snapshot. Native quest updates
    -- decide whether their own tracker has content while the tab is inactive.
    local ok,err=self:TrackerTabsFrameMethod(t.native,"SetParent",t.originalParent)
    if not ok then self.integration.lastError=err;return false end
    if finite(t.originalLevel) then self:TrackerTabsFrameMethod(t.native,"SetFrameLevel",t.originalLevel) end
    t.originalParent=nil;t.originalLevel=nil;t.control:Hide()
    t.active=nil;t.pending=nil;t.combatCollapsed=nil;t.bar:Hide()
    if t.provider=="questie" and self.RestoreQuestieTabsAppearance then self:RestoreQuestieTabsAppearance() end
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
        self.db[self.integration.pendingTrackerLayoutKey or self:TrackerLayoutSetting()]=self.integration.pendingTrackerLayout
        self.integration.pendingTrackerLayout=nil;self.integration.pendingTrackerLayoutKey=nil
        if self.SyncSettings then self:SyncSettings() end
    end
    if not combat() and self.integration.tabsOpenPending then
        self.integration.tabsOpenPending=nil
        if self:TrackerTabsRequested() and not self.integration.pendingDisplayMode then
            self.db.trackerTab="party";self.db.trackerHidden=false;self:InvalidateTrackerIntegration(true)
        end
    end
    if not self:TrackerTabsWanted() or self.integration.pendingDisplayMode then
        if t and t.active and not self:LeaveTrackerTabs() then return true end
        return false
    end
    local questie=self.QuestieTabsRequested and self:QuestieTabsRequested()
    local native=questie and Questie_BaseFrame or (not questie and ObjectiveTrackerFrame)
    if not native then
        if t and t.active and not self:LeaveTrackerTabs() then return true end
        return false
    end
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
            if self.LeaveQuestieDock then self:LeaveQuestieDock() end
            local ok,ready=pcall(self.InitTrackerTabs,self,native)
            if not ok or not ready then
                self.integration.tabsRetryAt=GetTime()+10
                self.integration.lastError="Tabbed tracker setup unavailable; using sidebar";return false
            end
            t=self.trackerTabs
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
        f:SetWidth(math.max(240,math.min(640,width)))
        f.heightLimit=questie and self:QuestieTabsHeight(native,t) or self:TrackerSidebarHeightLimit(native)
        f.headerOffset=0;f.title:Hide();f.headerArt:Hide()
        f.share:ClearAllPoints();f.share:SetPoint("TOPLEFT",f,"TOPLEFT",7,-3)
        f.refresh:ClearAllPoints();f.refresh:SetPoint("LEFT",f.share,"RIGHT",6,0)
        f.settings:ClearAllPoints();f.settings:SetPoint("LEFT",f.refresh,"RIGHT",6,0)
        f.collapse:ClearAllPoints();f.collapse:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-6)
        f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7,-32)
        if self.partyTrackerButton then self.partyTrackerButton:Hide() end
        if not questie then
            t.control:SetAttribute("party",self.db.trackerTab=="party")
            t.control:SetAttribute("auto",self.db.combatAutoHide~=false)
            t.control:SetAttribute("enabled",true)
        end
        if read(native,"GetParent")~=t.control then
            local ok,err=self:TrackerTabsFrameMethod(native,"SetParent",t.control)
            if not ok then self.integration.lastError=err;self:LeaveTrackerTabs();return false end
        end
        t.control:SetShown(self.db.trackerTab~="party")
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
    if questie then self:SyncQuestieTabsAppearance() else self:SyncTrackerSidebarOpacity(native) end
    local bg=f.trackerBackground
    bg:ClearAllPoints();bg:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);bg:SetSize(f:GetWidth(),f:GetHeight());bg:SetScale(f:GetScale())
    bg:SetShown(party)
    if self.window then self.window:Hide() end
    s.attached=true;s.status=(questie and "Questie tabs: " or "Blizzard tabs: ")..self.db.trackerTab..(t.pending and " (switch queued)" or "")
    return true
end
