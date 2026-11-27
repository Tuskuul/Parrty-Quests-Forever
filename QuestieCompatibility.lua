local _,A=...
-- Only read Questie's profile. Never import runtime modules, edit its saved
-- variables, consume its private comms cache, or impersonate its wire protocol.
A.questieCompatibility={updates=0,errors=0}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and not A.secret(v) then return v end
end
function A:QuestieLoaded()
    if self.readable(Questie) then return true end
    return call((C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded,"Questie")==true
end
function A:QuestieOwnsTracker()
    if not self:QuestieLoaded() then return false end
    local q=Questie
    local db=self.readable(q) and self.readable(q.db) and q.db
    local profile=db and self.readable(db.profile) and db.profile
    -- An absent/changed profile is unknown, not permission to control its UI.
    local requested=not profile or not self.public(profile.trackerEnabled,"boolean") or profile.trackerEnabled
    -- A tracker-off toggle during lockdown must not re-enter native layout.
    return requested or ((InCombatLockdown and InCombatLockdown()) and self.questieCompatibility.lastBlocked==true)
end
function A:QuestieSummary()
    if not self:QuestieLoaded() then return "Questie: not loaded" end
    if self:QuestieOwnsTracker() then
        if self.trackerTabs and self.trackerTabs.active and self.trackerTabs.provider=="questie" then return "Questie: tabbed tracker active" end
        if self.QuestieDockActive and self:QuestieDockActive() then return "Questie: tracker enabled; independent party sidebar active" end
        return "Questie: tracker enabled or initializing; party popout active"
    end
    return "Questie: maps only; Blizzard sidebar available; native combat controls paused"
end
function A:ReleaseNativeCombatControl()
    local state=self.questieCompatibility
    if InCombatLockdown and InCombatLockdown() then return end
    if state.cleanupRetryAt and GetTime()<state.cleanupRetryAt then return end
    local ok,err=pcall(self.ReleaseNativeCombatControlUnsafe,self)
    if ok then state.cleanupError=nil;state.cleanupRetryAt=nil
    else
        state.cleanupError=self.public(err,"string") and err:sub(1,240) or "unreadable cleanup error"
        state.cleanupRetryAt=GetTime()+10
    end
end
function A:ReleaseNativeCombatControlUnsafe()
    local s=self.integration
    if not s or (InCombatLockdown and InCombatLockdown()) then return end
    local c=s.combatController
    if c then
        c:SetAttribute("enabled",false);c:SetAttribute("rest-collapsed",false)
        c:SetAttribute("combat-collapsed",false)
    end
    if s.combatMainButton then s.combatMainButton:Hide() end
    local native,collapsed=s.preparedNative,s.preparedCollapsed
    s.preparedNative=nil;s.preparedCollapsed=nil;s.preparedOpening=nil
    -- Undo our visual-only collapse once. Do not expand or redraw a tracker
    -- merely because Questie was detected.
    if native and type(native.SetCollapsed)=="function" then
        local ok,err=self:CallNativeTrackerMethod(native,"SetCollapsed",not not collapsed)
        if not ok then
            s.preparedNative=native;s.preparedCollapsed=collapsed
            error(err)
        end
    end
    s.autoHideArmed=nil;s.autoHideActive=nil;s.autoCollapseNative=nil
    s.autoCollapseNativeShown=nil;s.combatVisualCollapsed=nil
    -- Sidebar collapse is independent of secure-controller ownership. Preserve
    -- it when Questie maps-only cleanup runs on each integration tick.
    s.expandAfterCombat=nil;s.blockedRestore=nil
    s.combatRestorePending=nil;s.combatCycleActive=nil
    s.combatSetupStatus=self.trackerTabs and self.trackerTabs.active and "native collapse handled by tracker tabs" or "paused while Questie is loaded"
end
function A:QuestieCompatibilityTick()
    if not self.db then return end
    local s=self.questieCompatibility
    local loaded,blocked=self:QuestieLoaded(),self:QuestieOwnsTracker()
    if not (InCombatLockdown and InCombatLockdown()) then s.lastBlocked=blocked
    elseif blocked then s.lastBlocked=true end
    if self.RefreshQuestieDockTarget then self:RefreshQuestieDockTarget() end
    local signature=tostring(loaded)..":"..tostring(blocked)..":"..tostring(s.dockReady==true)
    if signature~=s.signature then
        s.signature=signature;s.layoutPending=true;self.layoutDirty=true
        self:InvalidateTrackerIntegration()
        if self.SyncSettings then self:SyncSettings() end
    end
    if loaded and not (InCombatLockdown and InCombatLockdown()) then self:ReleaseNativeCombatControl() end
    local api=self.readable(Questie) and self.readable(Questie.API) and Questie.API
    if api and self.public(api.isReady,"boolean") and api.isReady==true and s.callbackAPI~=api and type(api.RegisterForQuestUpdates)=="function"
        and (not s.callbackRetryAt or GetTime()>=s.callbackRetryAt) then
        local ok=pcall(api.RegisterForQuestUpdates,function(id)
            if not A.db or not A:QuestieLoaded() or not A.validInteger(id,1,10000000) then return end
            s.updates=s.updates+1
            -- Wake our normal authoritative local-log reader, coalesced by it.
            A:ScheduleOwn()
        end)
        if ok then s.callbackAPI=api;s.callbackRetryAt=nil
        else s.errors=s.errors+1;s.callbackRetryAt=GetTime()+10 end
    end
    if not (InCombatLockdown and InCombatLockdown()) and s.layoutPending then
        if blocked then
            self:RestoreJoinedTrackerHeader();self:RestoreTrackerJoinVisuals()
            if self.sidebar then self.sidebar:Hide() end
            if self.partyTrackerButton then self.partyTrackerButton:Hide() end
        end
        s.layoutPending=nil
    end
end
function A:QuestieWindowCombatTick()
    local s=self.questieCompatibility
    if not self.window or not self.SetCollapsed then return end
    local collapse=self:EffectiveDisplayMode()=="window" and self.db.combatAutoHide~=false
        and (InCombatLockdown and InCombatLockdown()) or false
    if collapse and not s.windowCollapsed then
        s.windowCollapsed=true
        local saved=self.db.collapsed;self:SetCollapsed(true);self.db.collapsed=saved
    elseif not collapse and s.windowCollapsed then
        s.windowCollapsed=nil;self:SetCollapsed(not not self.db.collapsed)
    end
end
function A:QuestieField(id,key)
    local provider=LibQuestieDB
    if not self.validInteger(id,1,10000000) or not self.readable(provider) then return nil end
    -- Contract 1 is sufficient for these entity reads. Validate on demand so a
    -- late-loaded, corrected or replaced provider never leaves stale caches.
    if call(provider.RequireContract,1)~=true or not self.readable(provider.Quest) then return nil end
    local value=call(provider.Quest.Get,id,key)
    if value~=nil then self.questieCompatibility.databaseReads=(self.questieCompatibility.databaseReads or 0)+1 end
    return value
end
function A:QuestieCompatibilityReport()
    local s=self.questieCompatibility
    local metadata=(C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version=call(metadata,"Questie","Version")
    return self:QuestieSummary().."\nQuestie version: "..(self.public(version,"string") and version or "unknown")
        .."; requested view="..tostring(self.db.displayMode).."; effective view="..self:EffectiveDisplayMode()
        .."; cleanup pending="..tostring(s.layoutPending==true)
        .."\nQuestie public update callback="..tostring(s.callbackAPI~=nil).."; updates="..s.updates
        .."; registration errors="..s.errors.."; QuestieDB reads="..(s.databaseReads or 0)
        .."\nNative combat cleanup: "..(s.cleanupError or "no error")
        .."\nQuestie dock: ready="..tostring(s.dockReady==true).."; active="..tostring(s.dockActive==true)
        .."; side="..(s.dockRect and s.dockRect.side or "none")
        .."; backdrop alpha="..tostring(s.dockBackdropAlpha or "unknown").."; overall alpha="..tostring(s.dockOverallAlpha or "unknown")
        .."\nQuestie private progress/protocol: unused; native/SPQ progress remains authoritative"
end
