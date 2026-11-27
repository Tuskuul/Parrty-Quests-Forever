local _,P=...
local A=P.host
if not A then return end
local base={Init=A.InitTrackerTabs,Leave=A.LeaveTrackerTabs,Tick=A.TrackerTabsTick}
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
function A:SaveTrackerTabsLayout(key,value)
    if key=="questieTrackerLayout" then
        if P.db then P.db.layout=value end
    else self.db[key]=value end
end
function A:TrackerTabsFrameMethod(frame,method,...)
    if self.trackerTabs and self.trackerTabs.provider=="questie" then
        if combat() then return false,"Questie tab ownership change deferred in combat" end
        if frame~=Questie_BaseFrame and frame~=self.trackerTabs.native then return false,"Not the Questie tab root" end
        return pcall(frame[method],frame,...)
    end
    return self:CallNativeTrackerMethod(frame,method,...)
end
function A:TrackerTabsReport()
    local t=self.trackerTabs
    if not t or not t.active then return "Tabs visibility: inactive; open queued="..tostring(self.integration.tabsOpenPending==true) end
    return "Tabs visibility: provider="..tostring(t.provider).."; host shown="..tostring(read(t.control,"IsShown"))
        .."; native shown="..tostring(read(t.native,"IsShown"))
        .."; native visible="..tostring(read(t.native,"IsVisible"))
        .."; parent owned="..tostring(read(t.native,"GetParent")==t.control)
end
function A:SetDefaultTrackerLayout(layout,settingKey)
    if layout~="tabs" and layout~="sidebar" then return end
    settingKey=settingKey or self:TrackerLayoutSetting()
    if combat() then
        if self.integration.pendingTrackerLayout~=layout or self.integration.pendingTrackerLayoutKey~=settingKey then
            self.integration.pendingTrackerLayout=layout
            self.integration.pendingTrackerLayoutKey=settingKey
            self:TrackerTabsNotice("Tracker layout change queued until combat ends.")
        end
        return
    end
    self:SaveTrackerTabsLayout(settingKey,layout)
    self:InvalidateTrackerIntegration(true);self:TrackerIntegrationTick()
    if self.SyncSettings then self:SyncSettings() end
end
function A:InitTrackerTabs(native)
    if combat() then return false end
    local provider="questie"
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
        t.control=CreateFrame("Frame",nil,UIParent,nil)
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
        self:SaveTrackerTabsLayout(self.integration.pendingTrackerLayoutKey or self:TrackerLayoutSetting(),self.integration.pendingTrackerLayout)
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

-- Keep Blizzard's implementation owned by the dependency. Only the Questie
-- provider uses the companion controller; native fixes in PQF remain effective.
local questieInit,questieLeave,questieTick=A.InitTrackerTabs,A.LeaveTrackerTabs,A.TrackerTabsTick
local function useCache(self,provider)
    local t=self.trackerTabs
    if t and (t.provider or "blizzard")~=provider then
        self.trackerTabsCache=self.trackerTabsCache or {}
        self.trackerTabsCache[t.provider or "blizzard"]=t
        self.trackerTabs=self.trackerTabsCache[provider]
    elseif t and not t.provider then t.provider="blizzard"
    elseif not t and self.trackerTabsCache then self.trackerTabs=self.trackerTabsCache[provider] end
end
function A:InitTrackerTabs(native)
    local questie=native==Questie_BaseFrame
    useCache(self,questie and "questie" or "blizzard")
    if questie then return questieInit(self,native) end
    local ready=base.Init(self,native)
    if self.trackerTabs then self.trackerTabs.provider="blizzard" end
    return ready
end
function A:LeaveTrackerTabs()
    if self.trackerTabs and self.trackerTabs.provider=="questie" then return questieLeave(self) end
    return base.Leave(self)
end
function A:TrackerTabsTick()
    if not combat() and self.integration.pendingTrackerLayoutKey=="questieTrackerLayout" then
        self:SaveTrackerTabsLayout("questieTrackerLayout",self.integration.pendingTrackerLayout)
        self.integration.pendingTrackerLayout=nil;self.integration.pendingTrackerLayoutKey=nil
        if self.SyncSettings then self:SyncSettings() end
    end
    if self:QuestieTabsRequested() and self:TrackerTabsWanted() then
        if self.trackerTabs and self.trackerTabs.active and self.trackerTabs.provider~="questie" then
            if not self:LeaveTrackerTabs() then return true end
        end
        useCache(self,"questie")
        return questieTick(self)
    end
    if self.trackerTabs and self.trackerTabs.provider=="questie" and self.trackerTabs.active then
        if not self:LeaveTrackerTabs() then return true end
    end
    useCache(self,"blizzard")
    local active=base.Tick(self)
    if not self.integration.pendingTrackerLayout then self.integration.pendingTrackerLayoutKey=nil end
    return active
end
