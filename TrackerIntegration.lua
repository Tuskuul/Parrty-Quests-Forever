local _, A = ...
local function combat() return InCombatLockdown and InCombatLockdown() end
local function invoke(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a=pcall(fn,...);if ok then return a end
end
local function nativeColor(role)
    local c=OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR[role]
    if c then return {c.r,c.g,c.b} end
    if role=="Header" then return {1,0.82,0} end
    if role=="Complete" then return {0.51,0.81,0.6} end
    return {0.8,0.8,0.8}
end
local function completeColor()
    return "|cff00ff00"
end
A.integration={dirty=true,nextTry=0,status="waiting for Blizzard tracker"}
-- A visual combat collapse leaves the native main header in place. Protected
-- native modules are hidden by secure snippets, rather than a combat Update().
local combatApply=[[
    self:CallMethod("TraceCombatTracker",newstate==1 and "combat enter" or "combat exit")
    local collapsed = self:GetAttribute("enabled") and (newstate == 1 or self:GetAttribute("rest-collapsed"))
    self:SetAttribute("combat-collapsed", collapsed and true or false)
    self:SetAttribute("manual-open",nil)
    for i=1,self:GetAttribute("count") or 0 do
        local frame=self:GetFrameRef("module"..i)
        if frame and frame:IsProtected() then
            self:SetAttribute("combat-stage","state-module-"..i)
            self:CallMethod("TraceCombatTracker","state module "..i)
            if collapsed then frame:Hide()
            elseif self:GetAttribute("shown"..i) then frame:Show()
            else frame:Hide() end
        end
    end
    local main=self:GetFrameRef("main-control")
    if main then
        if self:GetAttribute("enabled") then main:Show()
        else main:Hide() end
    end
    self:SetAttribute("combat-stage","state-visual")
    self:CallMethod("ApplyCombatVisual",collapsed and true or false)
]]
local combatClick=[[
    if control:GetAttribute("state-combat") == 1 and control:GetAttribute("enabled") then
        control:CallMethod("TraceCombatTracker",self:GetAttribute("party-launcher") and "party click entered" or "native click entered")
        local collapsed=control:GetAttribute("combat-collapsed")
        if self:GetAttribute("party-launcher") and not collapsed then return end
        collapsed=not collapsed
        control:SetAttribute("combat-collapsed",collapsed)
        control:SetAttribute("manual-open",not collapsed)
        for i=1,control:GetAttribute("count") or 0 do
            local frame=control:GetFrameRef("module"..i)
            if frame and frame:IsProtected() then
                control:SetAttribute("combat-stage","click-module-"..i)
                control:CallMethod("TraceCombatTracker","click module "..i)
                if collapsed then frame:Hide()
                elseif control:GetAttribute("available"..i) then frame:Show() end
            end
        end
        control:SetAttribute("combat-stage","click-visual")
        control:CallMethod("ApplyCombatVisual",collapsed,self:GetAttribute("party-launcher") and not collapsed)
        return false
    end
]]
function A:ApplyOrdinaryCombatModules(collapsed,restore)
    for module,state in pairs(self.integration.combatModuleStates or {}) do
        local protected=invoke(module.IsProtected,module)
        if restore or protected==false then
            local shown
            if restore then shown=state.shown and module.hasContents~=false
            else shown=not collapsed and state.available and module.hasContents~=false end
            if shown then invoke(module.Show,module) else invoke(module.Hide,module) end
        end
    end
end
function A:IsNativeTrackerCollapsed(tracker)
    local s=self.integration
    if tracker and tracker==s.preparedNative then return s.preparedCollapsed==true end
    return invoke(tracker and tracker.IsCollapsed,tracker)==true
end
function A:SetPreparedTrackerCollapsed(collapsed)
    if combat() then return end
    local s=self.integration
    if not s.preparedNative then return end
    s.preparedCollapsed=not not collapsed;s.preparedOpening=not collapsed
    self:SetJoinedCollapseVisual(s.preparedCollapsed)
    self:InvalidateTrackerIntegration()
end
function A:TraceCombatTracker(stage)
    local s=self.integration
    s.combatHistory=s.combatHistory or {}
    s.combatHistory[#s.combatHistory+1]=string.format("%.1f %s",GetTime(),stage)
    while #s.combatHistory>40 do table.remove(s.combatHistory,1) end
end
function A:CombatTrackerReport()
    local s=self.integration;local c=s.combatController
    local function safe(v)
        if self.public(v,"string") or self.public(v,"boolean") or self.public(v,"number") then return tostring(v) end
        return "unknown"
    end
    local configured=self.db and self.db.combatAutoHide~=false
    local out={"Combat tracker: auto-collapse="..safe(configured).."; setup="..(s.combatSetupStatus or "not attempted")
        .."; stage="..safe(c and invoke(c.GetAttribute,c,"combat-stage")),
        "Combat setup APIs: RegisterStateDriver="..type(RegisterStateDriver).."; SecureHandlerWrapScript="..type(SecureHandlerWrapScript),
        "Combat setup state: controller="..tostring(c~=nil).."; driver="..tostring(s.combatDriverReady==true)
            .."; modules="..safe(c and invoke(c.GetAttribute,c,"count")).."; settings queued="..tostring(self.settingsOpenPending==true)}
    if s.combatSetupError then out[#out+1]="Combat setup error: "..s.combatSetupError end
    local function frame(label,object)
        if not object then return end
        local ok,protected,explicit=pcall(function() return object:IsProtected() end)
        out[#out+1]=label..": shown="..safe(invoke(object.IsShown,object)).."; protected="..safe(ok and protected)
            .."; explicit="..safe(ok and explicit).."; height="..safe(invoke(object.GetHeight,object))
        local permission=C_RestrictedActions and C_RestrictedActions.CheckAllowProtectedFunctions
        if type(permission)=="function" then
            local allowed=invoke(permission,object,true)
            out[#out]=out[#out].."; addon writes="..safe(allowed)
        end
    end
    frame("Native container",ObjectiveTrackerFrame)
    frame("Native +/-",ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header and ObjectiveTrackerFrame.Header.MinimizeButton)
    frame("Combat +/- overlay",s.combatMainButton);frame("Party button",self.partyTrackerButton)
    out[#out+1]="Prepared native layout: active="..tostring(s.preparedNative~=nil)
        .."; outside-combat collapsed="..safe(s.preparedCollapsed)
        .."; native collapsed="..safe(invoke(ObjectiveTrackerFrame and ObjectiveTrackerFrame.IsCollapsed,ObjectiveTrackerFrame))
    for module,i in pairs(s.combatModules or {}) do
        frame("Module "..i,module);frame("Module "..i.." contents",module.ContentsFrame)
    end
    for _,row in ipairs(s.combatHistory or {}) do out[#out+1]=row end
    return table.concat(out,"\n")
end
function A:PrepareCombatCollapse()
    local s=self.integration
    local enabled=self.db and self.db.combatAutoHide~=false
    if s.combatSetupEnabled~=enabled then s.combatSetupRetryAt=nil;s.combatSetupEnabled=enabled end
    if s.combatSetupRetryAt and GetTime()<s.combatSetupRetryAt then return end
    local ok,err=pcall(self.PrepareCombatCollapseUnsafe,self)
    if not ok then
        s.combatSetupStatus="setup failed at "..(s.combatSetupPhase or "unknown phase")
        s.combatSetupError=self.public(err,"string") and err:sub(1,240) or "unavailable error text"
        s.combatSetupRetryAt=GetTime()+10
    end
end
function A:PrepareCombatCollapseUnsafe()
    local s=self.integration
    if not self.db then s.combatSetupStatus="waiting for saved settings";return end
    if combat() then
        if not s.combatSetupStatus then s.combatSetupStatus="waiting for combat to end" end
        return
    end
    s.combatSetupError=nil
    if self.db.combatAutoHide==false and not s.combatController then s.combatSetupStatus="disabled in settings";return end
    if type(RegisterStateDriver)~="function" then s.combatSetupStatus="unavailable: RegisterStateDriver";return end
    if type(SecureHandlerWrapScript)~="function" then s.combatSetupStatus="unavailable: SecureHandlerWrapScript";return end
    local native=ObjectiveTrackerFrame
    if not native then s.combatSetupStatus="waiting for Blizzard tracker";return end
    s.combatSetupPhase="controller"
    local c=s.combatController
    if not c then
        c=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
        s.combatController=c;s.combatModules={};s.combatButtons={};s.combatGuards={};s.combatModuleStates={}
        c:SetAttribute("count",0)
        c.QueueTrackerExpand=function() A:QueueTrackerExpand() end
        c.TraceCombatTracker=function(_,stage) A:TraceCombatTracker(stage) end
        c.ApplyCombatVisual=function(_,collapsed,showParty)
            s.combatVisualCollapsed=collapsed
            A:ApplyOrdinaryCombatModules(collapsed,not combat())
            A:TraceCombatTracker(showParty and "party click" or "native/state visibility")
            if combat() then
                s.nativeCollapsed=collapsed
                if showParty then A.db.trackerHidden=false end
                -- This native header method only swaps +/- texture atlases.
                -- Native module visibility has already changed in the secure
                -- snippet; do not call tracker:SetCollapsed/Update here.
                local header=s.autoCollapseNative and s.autoCollapseNative.Header
                if header and type(header.SetCollapsed)=="function" then header:SetCollapsed(collapsed) end
                if collapsed then
                    A:SyncCombatTrackerHeader(false)
                    if A.sidebar then A.sidebar:Hide();if A.sidebar.trackerBackground then A.sidebar.trackerBackground:Hide() end end
                else
                    A:RefreshCombatTrackerPane()
                end
            end
            A:InvalidateTrackerIntegration()
        end
        c:SetAttribute("_onstate-combat",combatApply)
    end
    c:SetAttribute("enabled",self.db.combatAutoHide~=false)
    s.combatSetupPhase="layout preparation"
    -- A native SetCollapsed(true) lets Blizzard keep hiding modules on refresh.
    -- Keep its real layout expanded before lockdown and collapse only the visuals.
    -- Our secure button handles the same control in and out of combat.
    if self.db.combatAutoHide~=false then
        if s.preparedNative~=native then
            s.preparedNative=native;s.preparedCollapsed=invoke(native.IsCollapsed,native)==true
        end
        if invoke(native.IsCollapsed,native)==true then
            s.preparedCollapsed=true;s.preparingCollapse=true
            local ok,err=pcall(native.SetCollapsed,native,false)
            s.preparingCollapse=nil
            if not ok then error(err) end
        end
    elseif s.preparedNative then
        local previous,collapsed=s.preparedNative,s.preparedCollapsed
        s.preparedNative=nil;s.preparedCollapsed=nil
        previous:SetCollapsed(not not collapsed)
    end
    c:SetAttribute("rest-collapsed",s.preparedCollapsed==true)
    local count=c:GetAttribute("count") or 0
    local seen={}
    local function add(module)
        if not self.readable(module) or seen[module] then return end
        seen[module]=true
        local i=s.combatModules[module]
        if not i then
            count=count+1;i=count
            -- Stored refs may name ordinary frames, but their restricted
            -- Show/Hide handles are unusable in combat unless IsProtected is true.
            c:SetFrameRef("module"..i,module)
            local explicit=false
            if type(module.IsProtected)=="function" then
                local ok,_,value=pcall(module.IsProtected,module)
                explicit=ok and value==true
            end
            if explicit then
                SecureHandlerWrapScript(module,"OnShow",c,[[
                    if control:GetAttribute("enabled") and ((control:GetAttribute("state-combat")==1 and control:GetAttribute("combat-collapsed")) or (control:GetAttribute("state-combat")~=1 and control:GetAttribute("rest-collapsed"))) then self:Hide() end
                ]])
            elseif type(module.HookScript)=="function" then
                module:HookScript("OnShow",function(frame)
                    local collapsed=combat() and c:GetAttribute("combat-collapsed") or (not combat() and s.preparedNative and s.preparedCollapsed)
                    if collapsed and (not combat() or invoke(frame.IsProtected,frame)==false) then
                        invoke(frame.Hide,frame)
                    end
                end)
            end
            s.combatModules[module]=i
            -- Do not force a native OnHide back to Show. A normal quest refresh
            -- legitimately hides empty modules and releases/rebuilds their rows.
        end
        if s.preparedOpening and module.hasContents==true then module:Show() end
        local shown=module:IsShown()
        local available=shown or module.hasContents==true
        c:SetAttribute("shown"..i,shown)
        c:SetAttribute("available"..i,available)
        s.combatModuleStates[module]={shown=shown,available=available}
        if s.preparedCollapsed then
            module:Hide();c:SetAttribute("shown"..i,false);s.combatModuleStates[module].shown=false
        end
    end
    s.combatSetupPhase="modules"
    if native then
        if type(native.ForEachModule)=="function" then native:ForEachModule(add) end
        for _,module in pairs(native.modules or {}) do add(module) end
    end
    s.preparedOpening=nil
    c:SetAttribute("count",count)
    local function button(frame,party)
        if not frame or s.combatButtons[frame] then return end
        if party then frame:SetAttribute("party-launcher",true)
        end
        SecureHandlerWrapScript(frame,"OnClick",c,combatClick)
        s.combatButtons[frame]=true
    end
    s.combatSetupPhase="buttons"
    local minimize=native and native.Header and native.Header.MinimizeButton
    if minimize then
        -- Use an addon-owned secure click surface, just like Party Quests.
        -- While enabled this also keeps out-of-combat collapse visual-only;
        -- native OnClick replacements cannot remove our handler.
        local main=s.combatMainButton
        if not main then
            main=CreateFrame("Button","SimplyPartyQuestsCombatMinimize",minimize,"SecureHandlerClickTemplate")
            main:RegisterForClicks("LeftButtonUp")
            main:SetScript("OnClick",function()
                if not combat() then A:SetPreparedTrackerCollapsed(not s.preparedCollapsed) end
            end)
            main:Hide();s.combatMainButton=main
        end
        if s.combatMainTarget~=minimize then
            main:SetParent(minimize);main:ClearAllPoints();main:SetAllPoints(minimize)
            main:SetFrameLevel((invoke(minimize.GetFrameLevel,minimize) or 0)+1)
            main:SetScript("OnEnter",function() if minimize.LockHighlight then minimize:LockHighlight() end end)
            main:SetScript("OnLeave",function() if minimize.UnlockHighlight then minimize:UnlockHighlight() end end)
            s.combatMainTarget=minimize
        end
        c:SetFrameRef("main-control",main)
        button(main,false)
    end
    button(self.partyTrackerButton,true)
    if s.combatMainButton then s.combatMainButton:SetShown(self.db.combatAutoHide~=false) end
    if s.preparedNative then
        s.nativeCollapsed=s.preparedCollapsed
        native.Header:SetCollapsed(s.preparedCollapsed)
    end
    s.combatSetupPhase="state driver"
    if not s.combatDriverReady then
        RegisterStateDriver(c,"combat","[combat] 1; 0");s.combatDriverReady=true
    end
    s.combatSetupStatus=self.db.combatAutoHide==false and "disabled in settings" or "ready"
    s.combatSetupError=nil;s.combatSetupRetryAt=nil;s.combatSetupPhase="complete"
end
function A:SyncCombatAutoHide()
    local s=self.integration
    if not self.db then return false end
    if combat() then
        if not s.autoHideArmed then return false end
        s.autoHideActive=true
        local collapsed=s.combatController and s.combatController:GetAttribute("combat-collapsed")
        if s.autoCollapseNativeShown then
            -- No controller means there is no secure native visibility state.
            if collapsed==nil then return false end
            local header=s.autoCollapseNative and s.autoCollapseNative.Header
            if header and type(header.SetCollapsed)=="function" then header:SetCollapsed(not not collapsed) end
            if collapsed then
                self:SyncCombatTrackerHeader(false)
                if self.sidebar then
                    self.sidebar:Hide()
                    if self.sidebar.trackerBackground then self.sidebar.trackerBackground:Hide() end
                end
            end
        elseif self.sidebar and self.sidebar.scroll and not self.db.trackerHidden and self:ShouldShowPartyView() then
            local f=self.sidebar;f.viewCollapsed=true;f.scroll:Hide();f.hint:Hide()
            f:SetHeight(30+(f.headerOffset or 0));f:Show()
            if f.trackerBackground then f.trackerBackground:Hide() end
        end
        if self.window and self.db.displayMode=="window" and self.SetCollapsed then
            local saved=self.db.collapsed;self:SetCollapsed(true);self.db.collapsed=saved
        end
        return collapsed or not s.autoCollapseNativeShown
    end
    if s.autoHideActive then
        s.autoHideActive=nil
        local native=s.autoCollapseNative
        if native and native.Header and type(native.Header.SetCollapsed)=="function" then native.Header:SetCollapsed(self:IsNativeTrackerCollapsed(native)) end
        if self.window and self.db.displayMode=="window" and self.SetCollapsed then self:SetCollapsed(not not self.db.collapsed) end
        s.restoreNativeLayout=true;self:InvalidateTrackerIntegration()
    end
    s.autoHideArmed=self.db.combatAutoHide~=false
    s.autoCollapseNative=ObjectiveTrackerFrame
    s.autoCollapseNativeShown=s.autoCollapseNative and invoke(s.autoCollapseNative.IsShown,s.autoCollapseNative)==true
    self:PrepareCombatCollapse()
    return false
end
function A:RestoreNativeExpandedLayout(tracker)
    local s=self.integration
    if combat() or not s.restoreNativeLayout or not tracker then return end
    s.restoreNativeLayout=nil
    if self:IsNativeTrackerCollapsed(tracker) or invoke(tracker.IsShown,tracker)==false then return end
    -- A main expand must not leave module contents hidden by an earlier collapse.
    -- Use native module methods, then the same full layout as a native main expand.
    local seen={}
    local function restore(module)
        if not self.readable(module) or seen[module] then return end
        seen[module]=true
        if invoke(module.IsCollapsed,module)==true then invoke(module.SetCollapsed,module,false) end
        local contents=self.readable(module.ContentsFrame) and module.ContentsFrame
        if contents and type(contents.Show)=="function" then contents:Show() end
    end
    if self.db.displayMode=="blizzard" then
        invoke(tracker.ForEachModule,tracker,restore)
        for _,module in pairs(tracker.modules or {}) do restore(module) end
    end
    if type(tracker.Update)=="function" then
        local ok,err=pcall(tracker.Update,tracker)
        if not ok then s.lastError=self.public(err,"string") and err:sub(1,180) or "native expand layout failed" end
    end
end
local function progress(lines,kinds,name,q,remote,connected,ownKey)
    local expanded=ownKey and (A.db.trackerOwnProgressExpanded or {})[ownKey]
    local prefix=ownKey and (expanded and "- " or "+ ") or ""
    lines[#lines+1]=prefix..name..(connected==false and " (offline, cached)" or "")..":"
    kinds[#lines]=ownKey and "ownPlayer" or "player"
    if ownKey and not expanded then return end
    if A:IsQuestReady(q) then
        lines[#lines+1]=completeColor().."Ready for turn-in|r";kinds[#lines]="objective"
        return
    end
    local count=0
    for _,o in ipairs(q.objectives or {}) do
        local text=A:DisplayText(o.text or "Objective")
        if A:IsGenericObjective(text) then text="Unnamed step" end
        if o.total and o.total>0 and not text:find("%d+%s*/%s*%d+") then text=text.." "..(o.done or "?").."/"..o.total end
        if remote and (o.done==nil or o.total==nil) then text=text.." (progress unknown)" end
        lines[#lines+1]=text;kinds[#lines]="objective";count=count+1
    end
    if count==0 then lines[#lines+1]="progress unknown";kinds[#lines]="objective" end
end
function A:IsTrackerQuestReady(q,ownQuest)
    if not q.participants then return self:IsQuestReady(q) end
    -- A combined entry contains identity/participants, not objective state.
    -- Mark the shared parent only when every displayed quest holder is ready.
    if not ownQuest or not self:IsQuestReady(ownQuest) or #q.participants==0 then return false end
    for _,member in ipairs(q.participants) do
        local quest=member.quests and member.quests[q.id]
        if not quest or not self:IsQuestReady(quest) then return false end
    end
    return true
end
function A:BuildTrackerEntries()
    local view=self:BuildPartyViewData()
    local members=view.members
    local entries,sources={},{}
    local function source(key,name,quests,member)
        sources[#sources+1]={key=key,name=name,quests=quests,member=member}
    end
    if self.db.combineShared and #view.combined>0 then source("all","Shared quests",view.combined) end
    for _,m in ipairs(members) do
        local data=view.sections[m.guid]
        sources[#sources+1]={kind="member",member=m,count=data.count}
        if not (self.db.trackerMembersClosed or {})[m.guid] then
            if not self.db.combineShared and #data.shared>0 then source(m.guid..":shared",m.name.." — Both on",data.shared,m) end
            if #data.other>0 then source(m.guid..":other",m.name.." — Other quests",data.other,m) end
        end
    end
    local closed=self.db.trackerGroupsClosed or {}
    for _,s in ipairs(sources) do
        if s.kind=="member" then
            local m=s.member
            entries[#entries+1]={kind="member",key=m.guid,closed=(self.db.trackerMembersClosed or {})[m.guid],title=m.name.." ("..s.count..")",name=m.name,class=m.class,count=s.count,connected=m.connected,syncedAt=m.syncedAt,sweepAt=m.sweepAt}
            if s.count==0 and not (self.db.trackerMembersClosed or {})[m.guid] then
                entries[#entries+1]={kind="empty",title=m.connected==false and "No cached quests." or (m.syncedAt and "No active quests." or "No quests discovered yet.")}
            end
        else
        local groups=self.db.groupByZone and self:GroupQuestsByZone(s.quests) or {{key="flat",name="",quests=s.quests}}
        if #groups==0 then groups={{key="flat",name="",quests={}}} end
        for _,g in ipairs(groups) do
            table.sort(g.quests,function(a,b) if a.title==b.title then return a.id<b.id end;return a.title<b.title end)
            local groupKey=s.key..":"..g.key
            entries[#entries+1]={kind="group",key=groupKey,title=s.name..(g.name~="" and (" / "..g.name) or "").." ("..#g.quests..")",memberName=s.member and s.member.name,section=s.member and (s.key:match(":shared$") and "Shared with you" or "Other quests") or "Shared quests",sourceKey=s.key,zone=g.name,count=#g.quests,closed=closed[groupKey]}
            if not closed[groupKey] then
                if #g.quests==0 then entries[#entries+1]={kind="empty",title=s.member and (s.member.syncedAt and "No quests in this section." or "None discovered yet.") or "No shared quests discovered yet."} end
                for _,q in ipairs(g.quests) do
                    local key=s.member and (s.member.guid..":"..q.id) or ("all:"..q.id)
                    local lines,lineKinds={},{}
                    if view.own[q.id] then progress(lines,lineKinds,"You",view.own[q.id],false,nil,key) end
                    local participants=q.participants or {s.member}
                    for _,m in ipairs(participants) do
                        if m and m.quests[q.id] then progress(lines,lineKinds,m.name,m.quests[q.id],true,m.connected) end
                    end
                    local requirements=q.requirements
                    if not requirements and q.participants then
                        for _,m in ipairs(q.participants) do
                            local participant=m.quests and m.quests[q.id]
                            local r=participant and participant.requirements
                            if r and #r>0 then requirements=r;break end
                        end
                    end
                    local title=A:DisplayText(q.title)..(self:IsTrackerQuestReady(q,view.own[q.id]) and (" "..completeColor().."[Ready]|r") or "")
                    if q.participants then title=title.." ["..(#q.participants+1).."/"..(#members+1).." players]" end
                    entries[#entries+1]={kind="quest",key=key,id=q.id,title=title,ownerGuid=s.member and s.member.guid,lines=lines,lineKinds=lineKinds,requirements=requirements,context=s.name..(g.name~="" and (" / "..g.name) or ""),open=self.db.questExpanded[key]}
                end
            end
        end
    end
    end
    return entries,#members
end
function A:InvalidateTrackerIntegration()
    local s=self.integration
    s.dirty=true;s.due=s.due or (GetTime()+0.25)
end
function A:CombatControlNotice(message)
    local now=GetTime();local s=self.integration
    if s.controlNotice~=message or not s.controlNoticeAt or now-s.controlNoticeAt>=5 then
        s.controlNotice=message;s.controlNoticeAt=now
        print("Party Quests Forever: "..message)
    end
end
function A:ApplyPendingDisplayMode()
    local s=self.integration
    if combat() or not s.pendingDisplayMode then return end
    local mode=s.pendingDisplayMode;s.pendingDisplayMode=nil
    self:SetDisplayMode(mode)
end
function A:SetDisplayMode(mode)
    if mode~="blizzard" and mode~="window" then return end
    if combat() then
        if mode==self.db.displayMode then
            if self.integration.pendingDisplayMode then self:CombatControlNotice("Pending display change cancelled.") end
            self.integration.pendingDisplayMode=nil
        else
            self.integration.pendingDisplayMode=mode
            self:CombatControlNotice("Display mode will change after combat.")
        end
        if self.SyncSettings then self:SyncSettings() end
        return
    end
    self.db.displayMode=mode;self.db.trackerHidden=false
    if mode=="window" then self.db.hidden=false end
    self.integration.nextTry=0;self:InvalidateTrackerIntegration()
    if self.window then self.window:SetShown(mode=="window") end
    self:TrackerIntegrationTick()
    if self.SyncSettings then self:SyncSettings() end
end
function A:RefreshParty()
    self:ReadOwn();self:Request();self:ScanUnit("target");self:RefreshKnown();self:StartSweep()
end
-- This panel is anchored beside the tracker, never inserted into its module list.
-- Its own scroll area and fonts are independent of Blizzard's narrow columns.
function A:SetTrackerSide(side)
    if side~="left" and side~="right" then return end
    self.db.trackerSide=side;self:InvalidateTrackerIntegration();self:SyncSettings()
end
function A:SetSidebarWidth(width)
    self.db.sidebarWidth=math.max(320,math.min(640,width))
    self:InvalidateTrackerIntegration();self:SyncSettings()
end
function A:ShouldShowPartyView()
    return self.demo or next(self.members)~=nil or self.soloOverride==true
end
function A:QueueTrackerExpand()
    local s=self.integration
    if combat() and UIErrorsFrame and type(UIErrorsFrame.AddMessage)=="function"
        and (not s.expandNoticeAt or GetTime()-s.expandNoticeAt>=1) then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "You can't expand the tracker during combat.",1,0.1,0.1)
        s.expandNoticeAt=GetTime()
    end
    self.integration.expandAfterCombat=true
    self:InvalidateTrackerIntegration()
end
function A:ApplyPendingTrackerRestore()
    local s=self.integration
    if combat() or not self.db or self.db.displayMode~="blizzard" then return end
    if not s.expandAfterCombat and not s.blockedRestore then return end
    local native=ObjectiveTrackerFrame
    if not native then return end
    if s.expandAfterCombat then
        self.db.trackerHidden=false;self.db.trackerCollapsed=false
        if self:IsNativeTrackerCollapsed(native) and type(native.SetCollapsed)=="function" then
            local ok,err=pcall(function()
                if s.preparedNative==native then self:SetPreparedTrackerCollapsed(false) else native:SetCollapsed(false) end
            end)
            if not ok then s.lastError=self.public(err,"string") and err:sub(1,180) or "queued tracker expansion failed";return end
        end
    end
    s.expandAfterCombat=nil;s.blockedRestore=nil;s.restoreNativeLayout=true
    self:InvalidateTrackerIntegration()
end
function A:TogglePartyTracker()
    if combat() and self.db.displayMode=="blizzard" then
        if self.integration.combatVisualCollapsed or self.integration.nativeCollapsed then
            self:QueueTrackerExpand();return
        end
    end
    if self.db.displayMode=="blizzard" and not combat() then
        local native=ObjectiveTrackerFrame
        if native and self:IsNativeTrackerCollapsed(native) then
            self:SetViewShown(true)
            if self.integration.preparedNative==native then self:SetPreparedTrackerCollapsed(false)
            elseif type(native.SetCollapsed)=="function" then native:SetCollapsed(false) end
            self.integration.restoreNativeLayout=true
            self:InvalidateTrackerIntegration();self:TrackerIntegrationTick()
            return
        end
    end
    local frame=self.window
    local shown=self.db.displayMode=="blizzard" and not self.db.trackerHidden
        or self.db.displayMode~="blizzard" and frame and frame:IsShown()
    self:SetViewShown(not shown)
    self:TrackerIntegrationTick()
end
function A:EnsurePartyTrackerButton(tracker)
    if not self.partyTrackerButton then
        local b=CreateFrame("Button","SimplyPartyQuestsMainToggle",UIParent,"UIPanelButtonTemplate,SecureHandlerClickTemplate")
        b:SetNormalFontObject(ObjectiveTrackerLineFont or GameFontNormal)
        b:SetSize(96,20);b:SetText("Party Quests");b:SetFrameStrata("MEDIUM")
        b:SetScript("OnClick",function() A:TogglePartyTracker() end)
        self.partyTrackerButton=b
    end
    local b=self.partyTrackerButton
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local minimize=header and self.readable(header.MinimizeButton) and header.MinimizeButton or nil
    local anchor=minimize or header or tracker
    if self.integration.buttonAnchor~=anchor then
        b:ClearAllPoints()
        if minimize then b:SetPoint("RIGHT",minimize,"LEFT",-6,0)
        else b:SetPoint("TOPRIGHT",anchor,"TOPRIGHT",-24,-3) end
        b:SetFrameLevel(tracker:GetFrameLevel()+10)
        self.integration.buttonAnchor=anchor
    end
    -- Parent visibility handles header hiding immediately, including during combat.
    -- A tracker frame can remain shown even when its empty header is hidden.
    b:SetParent(header or tracker)
    b:SetShown(header~=nil and header:IsShown() and tracker:IsShown())
end
function A:TrackerEntryClick(row,button)
    if row.kind=="quest" then self.shareProbeSelected=row.id end
    if IsShiftKeyDown and IsShiftKeyDown() then
        self:RefreshParty();return
    end
    if row.kind=="member" then
        self.db.trackerMembersClosed=self.db.trackerMembersClosed or {}
        self.db.trackerMembersClosed[row.key]=not self.db.trackerMembersClosed[row.key]
    elseif row.kind=="ownProgress" then
        self.db.trackerOwnProgressExpanded=self.db.trackerOwnProgressExpanded or {}
        self.db.trackerOwnProgressExpanded[row.key]=not self.db.trackerOwnProgressExpanded[row.key]
    elseif row.kind=="group" then self.db.trackerGroupsClosed[row.key]=not self.db.trackerGroupsClosed[row.key]
    elseif row.kind=="quest" then
        if button=="RightButton" and self.own[row.id] and type(QuestMapFrame_OpenToQuestDetails)=="function" then
            if combat() then
                self:CombatControlNotice("Open quest details after combat.")
            else QuestMapFrame_OpenToQuestDetails(row.id) end
            return
        end
        self.db.questExpanded[row.key]=not self.db.questExpanded[row.key]
    end
    self:InvalidateTrackerIntegration()
    if combat() then
        self:RenderCombatTrackerSidebar()
        return
    end
    self:Render()
end
function A:RenderCombatTrackerSidebar()
    if self:SyncCombatAutoHide() then return false end
    local f=self.sidebar
    if not f or not f.scroll then return false end
    local ok,err=pcall(function()
        -- Rebuild even after a hide/collapse; text-only ticks cannot restore rows.
        local entries,count=self:BuildTrackerEntries()
        self:RenderTrackerSidebar(entries,count)
        f.scroll:SetShown(not f.viewCollapsed)
        f.child:Show()
        self:ResizeCombatTrackerBackground()
        self.integration.entries=entries;self.integration.memberCount=count
    end)
    if ok then self.integration.lastError=nil
    else
        self.integration.lastError=self.public(err,"string") and err:sub(1,180) or "combat expansion failed"
        local now=GetTime()
        if not self.integration.combatNoticeAt or now-self.integration.combatNoticeAt>=10 then
            self.integration.combatNoticeAt=now
            print("Party Quests Forever: combat display unavailable; /spq report includes the failed stage.")
        end
    end
    return ok
end
function A:RefreshCombatTrackerPane()
    if self:SyncCombatAutoHide() then return end
    if not combat() or self.db.displayMode~="blizzard" then return end
    local f,s=self.sidebar,self.integration
    if not f then return end
    local visible=not s.nativeCollapsed and not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    f.viewCollapsed=not s.nativeVisible and not not self.db.trackerCollapsed
    f:SetShown(visible)
    local joined=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    self:SyncCombatTrackerHeader(joined and s.nativeVisible and not s.nativeCollapsed)
    if visible then self:RenderCombatTrackerSidebar() end
    self:ResizeCombatTrackerBackground()
    self:InvalidateTrackerIntegration()
end
function A:TrackerBackgroundContentTop(top,ownTop,scale)
    local timer=QuestTimerFrame
    local shown=timer and invoke(timer.IsVisible,timer)
    if shown==nil and timer then shown=invoke(timer.IsShown,timer) end
    if shown~=true then return top end
    local header=self.integration.backgroundHeader
    if not header then return top end
    local headerTop=invoke(header.GetTop,header)
    local headerScale=invoke(header.GetEffectiveScale,header)
    local function number(v) return self.public(v,"number") and v==v and math.abs(v)<math.huge end
    if not (number(headerTop) and number(headerScale) and headerScale>0 and number(scale) and scale>0) then return top end
    -- The native NineSlice includes the separate timer's top-padding area.
    -- Our joined canvas begins at All Objectives, leaving the timer's own art alone.
    return math.max(top,(ownTop*scale-headerTop*headerScale)/scale)
end
function A:MeasureCombatTrackerBackground()
    local f,s=self.sidebar,self.integration
    local native=s.nativeBackdrop and s.nativeBackdrop.frame
    if not f or not native then return end
    local function number(v) return self.public(v,"number") and v==v and math.abs(v)<math.huge end
    -- Read current screen bounds only. No native anchors, modules or layout writes.
    local scale=invoke(f.GetEffectiveScale,f)
    local nativeScale=invoke(native.GetEffectiveScale,native)
    local ownLeft,ownTop=invoke(f.GetLeft,f),invoke(f.GetTop,f)
    local left,right,top,bottom=invoke(native.GetLeft,native),invoke(native.GetRight,native),invoke(native.GetTop,native),invoke(native.GetBottom,native)
    if not (number(scale) and scale>0 and number(nativeScale) and nativeScale>0
        and number(ownLeft) and number(ownTop) and number(left) and number(right) and number(top) and number(bottom)) then return end
    f.combatBackgroundBounds={native={left=(left*nativeScale-ownLeft*scale)/scale,
        right=(right*nativeScale-ownLeft*scale)/scale,top=self:TrackerBackgroundContentTop((ownTop*scale-top*nativeScale)/scale,ownTop,scale),
        bottom=(ownTop*scale-bottom*nativeScale)/scale}}
end
function A:ResizeCombatTrackerBackground()
    if self.integration.autoHideActive and self.integration.combatVisualCollapsed then return end
    self:MeasureCombatTrackerBackground()
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    local bounds=f.combatBackgroundBounds
    if not bounds then return end
    local native=self.integration.nativeBackdrop and bounds.native
    local party=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    local background=f.trackerBackground
    if self.integration.nativeCollapsed or (not native and not party) then background:Hide();return end
    local left,right,top,bottom=0,f:GetWidth(),0,f:GetHeight()
    if native then
        if party then
            left=math.min(left,native.left);right=math.max(right,native.right)
            top=math.min(top,native.top);bottom=math.max(bottom,native.bottom)
        else left,right,top,bottom=native.left,native.right,native.top,native.bottom end
    end
    f.joinedExpandedHeight=bottom-top
    local signature=table.concat({left,right,top,f.joinedExpandedHeight},":")
    if f.backgroundJoinSignature~=signature then
        background:ClearAllPoints();background:SetPoint("TOPLEFT",f,"TOPLEFT",left,-top)
        background:SetWidth(right-left);background:SetHeight(f.joinedExpandedHeight)
        f.backgroundJoinSignature=signature
    end
    background:Show()
end
local function applyFont(f,role)
    f:SetFontObject(role=="header" and (ObjectiveTrackerHeaderFont or GameFontNormal) or (ObjectiveTrackerLineFont or GameFontHighlightSmall))
end
local function text(parent,role,color)
    local f=parent:CreateFontString(nil,"ARTWORK")
    applyFont(f,role);f:SetJustifyH("LEFT");f:SetJustifyV("TOP")
    f:SetTextColor(unpack(color));return f
end
function A:InitTrackerSidebar()
    if self.sidebar then return end
    local f=CreateFrame("Frame","SimplyPartyQuestsSidebar",UIParent,"BackdropTemplate")
    self.sidebar=f;f:SetSize(420,540);f:SetClampedToScreen(true);f:SetFrameStrata("MEDIUM")
    -- A sibling backdrop spans both columns, so its alpha is applied once.
    -- It stays visible behind the main header when the content frame is hidden.
    f.trackerBackground=CreateFrame("Frame",nil,UIParent)
    f.trackerBackground:SetFrameStrata("LOW")
    local art
    if NineSliceUtil and type(NineSliceUtil.ApplyLayoutByName)=="function" then
        art=CreateFrame("Frame",nil,f.trackerBackground,"NineSlicePanelTemplate")
        NineSliceUtil.ApplyLayoutByName(art,"UniqueCornersLayout","common-opacity-background")
    else
        art=CreateFrame("Frame",nil,f.trackerBackground)
        art.fill=art:CreateTexture(nil,"BACKGROUND");art.fill:SetAllPoints(art);art.fill:SetColorTexture(0,0,0,1)
    end
    art:SetAllPoints(f.trackerBackground);f.trackerBackground.art=art
    f.trackerBackground:Hide()
    f.trackerBackground:SetAlpha(0)
    f.title=text(f,"header",nativeColor("Header"));f.title:SetPoint("TOPLEFT",7,-38);f.title:SetText("Party Quests")
    local headerArt=f:CreateTexture(nil,"BACKGROUND");f.headerArt=headerArt
    headerArt:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
    headerArt:SetPoint("TOPLEFT",0,-32);headerArt:SetPoint("TOPRIGHT",0,-32);headerArt:SetHeight(26)
    local function button(label,width,callback)
        local b=CreateFrame("Button",nil,f);b:SetSize(width,22)
        local labelFont=text(b,"line",nativeColor("Header"));labelFont:SetPoint("CENTER");labelFont:SetText(label)
        b.caption=labelFont;b.SetText=function(_,v) labelFont:SetText(v) end
        b:SetScript("OnClick",callback)
        b:SetScript("OnEnter",function() labelFont:SetTextColor(1,1,1) end)
        b:SetScript("OnLeave",function() labelFont:SetTextColor(unpack(nativeColor("Header"))) end)
        return b
    end
    f.collapse=button("-",18,function() A:SetViewCollapsed(not A.db.trackerCollapsed);A:SyncSettings() end)
    f.collapse.caption:Hide()
    f.collapse.normal=f.collapse:CreateTexture(nil,"ARTWORK");f.collapse.normal:SetAllPoints(f.collapse)
    f.collapse.pushed=f.collapse:CreateTexture(nil,"ARTWORK");f.collapse.pushed:SetAllPoints(f.collapse)
    f.collapse:SetNormalTexture(f.collapse.normal);f.collapse:SetPushedTexture(f.collapse.pushed)
    local glow=f.collapse:CreateTexture(nil,"HIGHLIGHT");glow:SetAtlas("ui-questtrackerbutton-yellow-highlight");glow:SetAllPoints(f.collapse)
    f.collapse:SetHighlightTexture(glow)
    f.collapse:SetSize(16,16);f.collapse:SetPoint("TOPRIGHT",-4,-38)
    f.settings=button("Settings",56,function() A:OpenSettings() end)
    f.settings:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-35)
    f.refresh=button("Refresh",54,function() A:RefreshParty() end);f.refresh:SetPoint("RIGHT",f.settings,"LEFT",-6,0)
    f.share=button("Share",42,function()
        local draft=A.questLogShareDraft;A.questLogShareDraft=nil
        A:OpenQuestLogShare(draft);A.questLogShareDraft=nil
    end)
    f.share:SetPoint("RIGHT",f.refresh,"LEFT",-6,0)
    f.share:SetScript("OnMouseDown",function()
        if not A.questLogShareDraft then A.questLogShareDraft=A:CaptureQuestLogChatDraft() end
    end)
    f.share:SetScript("OnEnter",function(button)
        f.share.caption:SetTextColor(1,1,1)
        A.questLogShareHover=true;A.questLogShareDraft=A:CaptureQuestLogChatDraft()
        GameTooltip:SetOwner(button,"ANCHOR_BOTTOM")
        GameTooltip:SetText("Share Quest Log")
        GameTooltip:AddLine("Draft a chat link to your current quests and objective progress.",1,1,1,true)
        GameTooltip:Show()
    end)
    f.share:SetScript("OnLeave",function()
        f.share.caption:SetTextColor(unpack(nativeColor("Header")))
        A.questLogShareHover=false;A.questLogShareDraft=nil;GameTooltip:Hide()
    end)
    f.hint=text(f,"line",nativeColor("Normal"));f.hint:SetPoint("BOTTOMLEFT",4,0);f.hint:SetText("Mouse wheel to scroll")
    f.scroll=CreateFrame("ScrollFrame",nil,f)
    f.scroll:SetPoint("TOPLEFT",7,-68)
    f.scroll:SetClipsChildren(true)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel",function(_,delta)
        local max=f.maxScroll or 0
        f.scroll:SetVerticalScroll(math.max(0,math.min(max,(f.scroll:GetVerticalScroll() or 0)-delta*36)))
    end)
    f.child=CreateFrame("Frame",nil,f.scroll);f.child:SetSize(380,1);f.scroll:SetScrollChild(f.child)
    f.rows={};f.contentHeight=1;f.heightLimit=420;f.maxScroll=0;f:Hide()
end
function A:SetTrackerSidebarHeaderLayout(nativeVisible)
    local f=self.sidebar
    local offset=nativeVisible and 38 or 0
    if f.headerOffset==offset then return end
    f.headerOffset=offset
    -- Only reserve an All Objectives row when Blizzard actually displays it.
    f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",f,"TOPLEFT",7,-6-offset)
    f.headerArt:ClearAllPoints()
    f.headerArt:SetPoint("TOPLEFT",f,"TOPLEFT",0,-offset)
    f.headerArt:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,-offset)
    f.collapse:ClearAllPoints();f.collapse:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-6-offset)
    if f.settings then
        f.settings:ClearAllPoints();f.settings:SetPoint("TOPRIGHT",f,"TOPRIGHT",nativeVisible and -6 or -28,-3-offset)
    end
    f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7,-36-offset)
    self.integration.dirty=true
end
function A:UpdateTrackerQuestFocus()
    local f=self.sidebar
    if not f or type(f.rows)~="table" then return end
    local api=C_SuperTrack or {}
    local id=invoke(api.GetSuperTrackedQuestID)
    if not self.public(id,"number") or id<=0 or invoke(api.IsSuperTrackingQuest)==false then id=nil end
    self.integration.focusedQuestID=id
    for _,row in ipairs(f.rows) do
        local e=row.entry
        local focused=not not (id and e and e.kind=="quest" and e.id==id)
        if row.focusFill and row.focusAccent and row.focusShown~=focused then
            row.focusFill:SetShown(focused);row.focusAccent:SetShown(focused)
            row.focusShown=focused
        end
    end
end
function A:RenderTrackerSidebar(entries,memberCount)
    local f=self.sidebar;local width=math.max(1,f:GetWidth()-22)
    f.child:SetWidth(width)
    local used,y=0,0
    local function row(label,role,color,indent,entry,liveQuestKey,liveLine)
        used=used+1
        local b=f.rows[used]
        if not b then
            b=CreateFrame("Button",nil,f.child);b.label=text(b,role,color)
            b.headerBackground=false
            -- Allocate once with the pooled row; focus changes only toggle art.
            b.focusFill=b:CreateTexture(nil,"BACKGROUND",nil,1)
            b.focusFill:SetPoint("TOPLEFT",b,"TOPLEFT",-6,1)
            b.focusFill:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-7,-1)
            b.focusFill:SetColorTexture(1,0.76,0.08,0.18);b.focusFill:Hide()
            b.focusAccent=b:CreateTexture(nil,"BACKGROUND",nil,2)
            b.focusAccent:SetPoint("TOPLEFT",b,"TOPLEFT",-6,1)
            b.focusAccent:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",-6,-1)
            b.focusAccent:SetWidth(3);b.focusAccent:SetColorTexture(1,0.8,0.1,0.9);b.focusAccent:Hide()
            b.focusShown=false
            b.label:SetPoint("TOPLEFT",0,0);b:RegisterForClicks("LeftButtonUp","RightButtonUp")
            b:SetScript("OnClick",function(_,key) if b.entry then A:TrackerEntryClick(b.entry,key) end end)
            b:SetScript("OnDoubleClick",function(_,key)
                local e=b.entry
                if key=="LeftButton" and e and e.kind=="quest" and e.ownerGuid and not A.own[e.id] then A:RequestQuestShare(e.id,e.ownerGuid) end
            end)
            f.rows[used]=b
        end
        b.entry=entry;b.liveQuestKey=liveQuestKey;b.liveLine=liveLine
        applyFont(b.label,role);b.label:SetTextColor(unpack(color))
        local heading=entry and (entry.kind=="member" or entry.kind=="group")
        if heading and not b.headerBackground then
            b.headerBackground=b:CreateTexture(nil,"BACKGROUND")
            b.headerBackground:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
            b.headerBackground:SetAllPoints(b)
        end
        if b.headerBackground then b.headerBackground:SetShown(not not heading) end
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT",heading and 7 or 0,heading and -5 or 0)
        b.label:SetWidth(width-indent-(heading and 14 or 0));b.label:SetText(label)
        local height=math.max(heading and 26 or 1,b.label:GetStringHeight()+(heading and 10 or 3))
        b:ClearAllPoints();b:SetPoint("TOPLEFT",indent,-y);b:SetSize(width-indent,height)
        b:EnableMouse(entry~=nil);b:Show();y=y+height+2
    end
    if memberCount==0 then row("Join a party to see available quests.","line",nativeColor("Normal"),0)
    elseif #entries==0 then row("No party quests discovered yet. Try Refresh in Settings.","line",nativeColor("Normal"),0)
    else
        local previousSource,previousMember
        for _,e in ipairs(entries) do
            if e.kind=="member" then
                if used>0 then y=y+10 end
                row((e.closed and "+ " or "- ")..e.title,"header",nativeColor("Header"),0,e)
                local status=e.syncedAt and "Full log synced" or "Discovered quests"
                if e.connected==false then status=status.." - offline, cached" end
                if not e.closed then row(status,"line",nativeColor("Normal"),8) end
                previousMember=e.name;previousSource=nil
            elseif e.kind=="empty" then
                row(e.title,"line",nativeColor("Normal"),20)
            elseif e.kind=="group" then
                if e.sourceKey~=previousSource then
                    if used>0 then y=y+10 end
                    if e.memberName and e.memberName~=previousMember then
                        row(e.memberName,"line",nativeColor("Header"),0)
                        previousMember=e.memberName
                    end
                    if e.zone and e.zone~="" then row(e.section,"line",nativeColor("Normal"),8) end
                    previousSource=e.sourceKey
                end
                local heading=(e.zone and e.zone~="" and e.zone or e.section).." ("..e.count..")"
                row((e.closed and "+ " or "- ")..heading,"header",nativeColor("Header"),8,e)
            else
                row((e.open and "- " or "+ ")..e.title,"line",nativeColor("Header"),20,e,e.key,0)
                if e.open then
                    for _,r in ipairs(e.requirements or {}) do row(A:DisplayText(r.text),"line",nativeColor("Normal"),34) end
                    for i,line in ipairs(e.lines or {}) do
                        local kind=e.lineKinds and e.lineKinds[i]
                        local player=kind=="player" or kind=="ownPlayer"
                        if player then y=y+4 end
                        local action=kind=="ownPlayer" and {kind="ownProgress",key=e.key} or nil
                        row(line,"line",nativeColor(player and "Header" or "Normal"),
                            kind=="objective" and 46 or 34,action,e.key,i)
                    end
                end
            end
        end
    end
    for i=used+1,#f.rows do f.rows[i].entry=nil;f.rows[i].liveQuestKey=nil;f.rows[i].liveLine=nil;f.rows[i]:Hide() end
    f.child:SetHeight(math.max(1,y))
    f.contentHeight=y
    self:SizeTrackerSidebar()
    self:UpdateTrackerQuestFocus()
end
function A:SizeTrackerSidebar()
    local f=self.sidebar
    local limit=f.heightLimit or 420
    local content=f.contentHeight or 1
    local padding=44+(f.headerOffset or 38)
    local overflow=content+padding>limit
    local viewport=math.max(1,math.min(content,limit-padding-(overflow and 14 or 0)))
    f.scroll:SetSize(math.max(1,f:GetWidth()-14),math.max(1,viewport))
    f.maxScroll=math.max(0,content-viewport)
    f.hint:SetShown(overflow and not f.viewCollapsed)
    f:SetHeight(f.viewCollapsed and (padding-14) or math.min(limit,content+padding+(overflow and 14 or 0)))
    local offset=f.scroll:GetVerticalScroll() or 0
    if offset>f.maxScroll then f.scroll:SetVerticalScroll(f.maxScroll) end
end
-- Extend only the native header's visual anchors, never its quest column width.
-- Keep original anchors so hiding/detaching restores Blizzard's header exactly.
function A:RestoreJoinedTrackerHeader()
    local saved=self.integration.joinedHeader
    if not saved then return end
    for _,item in ipairs(saved.items) do
        if item.justifyH then item.region:SetJustifyH(item.justifyH) end
        item.region:ClearAllPoints()
        for _,point in ipairs(item.points) do item.region:SetPoint(unpack(point)) end
    end
    self.integration.joinedHeader=nil
end
-- Native-only headers retain an atlas inset after the party column closes.
-- Extend just the left artwork edge; preserve native title/control positions
-- and restore the exact original texture anchors when integration ends.
function A:FitNativeTrackerHeader(tracker,enabled)
    local s=self.integration
    local header=self.readable(tracker) and self.readable(tracker.Header) and tracker.Header
    local background=header and self.readable(header.Background) and header.Background
    if enabled and not background then return end
    local saved=s.nativeHeaderFit
    if saved and (not enabled or saved.region~=background) then
        saved.region:ClearAllPoints()
        if saved.resized then saved.region:SetWidth(saved.width) end
        for _,point in ipairs(saved.points) do saved.region:SetPoint(unpack(point)) end
        s.nativeHeaderFit=nil;saved=nil
    end
    if not enabled or not background or saved then return end
    local points,left,right={},false,false
    for i=1,background:GetNumPoints() do
        local point={background:GetPoint(i)}
        if not self.public(point[1],"string") or not self.public(point[4] or 0,"number") then return end
        left=left or point[1]:find("LEFT",1,true)~=nil
        right=right or point[1]:find("RIGHT",1,true)~=nil
        points[#points+1]=point
    end
    if #points==0 then return end
    local width=invoke(background.GetWidth,background)
    if not (left and right) and (not self.public(width,"number") or width~=width or width<=0 or width==math.huge) then return end
    saved={region=background,points=points,width=width,resized=not (left and right)}
    background:ClearAllPoints()
    if saved.resized then background:SetWidth(width+24) end
    for _,point in ipairs(points) do
        local adjusted={unpack(point)}
        if point[1]:find("LEFT",1,true) then adjusted[4]=(point[4] or 0)-24
        elseif not right then adjusted[4]=(point[4] or 0)-12 end
        background:SetPoint(unpack(adjusted))
    end
    s.nativeHeaderFit=saved
end
function A:SyncCombatTrackerHeader(joined)
    local s=self.integration
    if not joined then
        if s.joinedHeader then
            -- Keep both native and joined visual anchors for a combat reopen.
            s.combatJoinedHeader=s.joinedHeader
            self:RestoreJoinedTrackerHeader()
        end
        local state=s.combatJoinedHeader
        if state then self:FitNativeTrackerHeader({Header=state.header},true) end
    elseif not s.joinedHeader and s.combatJoinedHeader then
        self:FitNativeTrackerHeader(nil,false)
        local state=s.combatJoinedHeader
        for _,item in ipairs(state.items) do
            item.region:ClearAllPoints()
            for _,point in ipairs(item.joinedPoints) do item.region:SetPoint(unpack(point)) end
        end
        state.titleCentered=nil
        s.joinedHeader=state;s.combatJoinedHeader=nil
        self:PositionJoinedTrackerTitle(false)
    end
end
function A:JoinTrackerHeader(tracker,enabled)
    if self:IsNativeTrackerCollapsed(tracker) then
        self:SyncCombatTrackerHeader(false)
        return
    end
    self.integration.combatJoinedHeader=nil
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local side=self.db.trackerSide=="right" and "right" or "left"
    local saved=self.integration.joinedHeader
    if saved and (not enabled or saved.header~=header or saved.side~=side) then self:RestoreJoinedTrackerHeader();saved=nil end
    self:FitNativeTrackerHeader(tracker,not enabled)
    if not enabled or not header or saved then return end
    local background=self.readable(header.Background) and header.Background or nil
    local title=self.readable(header.Text) and header.Text or nil
    local state={header=header,side=side,items={}}
    local function save(region)
        local points={}
        for i=1,region:GetNumPoints() do points[#points+1]={region:GetPoint(i)} end
        state.items[#state.items+1]={region=region,points=points,justifyH=invoke(region.GetJustifyH,region)}
        region:ClearAllPoints()
    end
    local left=side=="left" and self.sidebar or header
    local right=side=="right" and self.sidebar or header
    if background then
        save(background)
        background:SetPoint("TOPLEFT",left,"TOPLEFT",-24,0)
        background:SetPoint("BOTTOMRIGHT",right,"TOPRIGHT",8,-32)
    end
    if title then
        save(title)
        state.title=title;state.background=background;state.left=left
    end
    self.integration.joinedHeader=state
    self:PositionJoinedTrackerTitle(self:IsNativeTrackerCollapsed(tracker))
    for _,item in ipairs(state.items) do
        item.joinedPoints={}
        for i=1,item.region:GetNumPoints() do item.joinedPoints[#item.joinedPoints+1]={item.region:GetPoint(i)} end
    end
end
function A:PositionJoinedTrackerTitle(collapsed)
    local state=self.integration.joinedHeader
    if not state or not state.title then return end
    local centered=state.background~=nil
    if state.titleCentered==centered then return end
    state.title:ClearAllPoints()
    if type(state.title.SetJustifyH)=="function" then state.title:SetJustifyH(centered and "CENTER" or "LEFT") end
    if centered then state.title:SetPoint("CENTER",state.background,"CENTER",0,0)
    else state.title:SetPoint("LEFT",state.left,"TOPLEFT",32,-16) end
    state.titleCentered=centered
end
function A:UpdateTrackerSidebarCombat()
    local f,s=self.sidebar,self.integration
    if not f or not f:IsShown() or not s.dirty or (s.due and GetTime()<s.due) then return end
    -- Use the same full addon-owned reflow as a user click. Objective completion
    -- can change line count, wrapping, Ready labels and the scrollable height.
    if self:RenderCombatTrackerSidebar() then
        s.dirty=false;s.due=nil
    else s.due=GetTime()+1 end
end
function A:SyncTrackerSidebarOpacity(tracker)
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    -- This is the normalized background value used by Blizzard's Forever
    -- ObjectiveTrackerManager:SetOpacity, not the whole frame's text alpha.
    local manager=ObjectiveTrackerManager
    local alpha=self.readable(manager) and manager.backgroundAlpha or nil
    if not self.public(alpha,"number") then
        local background=tracker and self.readable(tracker.NineSlice) and tracker.NineSlice
        alpha=background and invoke(background.GetAlpha,background) or nil
    end
    if not self.public(alpha,"number") or alpha~=alpha then return end
    alpha=math.max(0,math.min(1,alpha))
    if f.trackerBackgroundAlpha~=alpha then
        f.trackerBackground:SetAlpha(alpha);f.trackerBackgroundAlpha=alpha
    end
end
-- Only visual regions are suppressed; native quest layout/update code is untouched.
function A:RestoreTrackerJoinVisuals()
    local s=self.integration
    self:FitNativeTrackerHeader(nil,false)
    local saved=s.nativeBackdrop;s.nativeBackdrop=nil
    if saved and saved.shown then saved.frame:Show() end
    local buttons=s.moduleButtons;s.moduleButtons=nil
    if buttons then
        for button,state in pairs(buttons) do
            if state.shown then button:Show() end
        end
    end
    if self.sidebar and self.sidebar.trackerBackground then self.sidebar.trackerBackground:Hide() end
end
function A:SetJoinedCollapseVisual(collapsed)
    if self.integration.preparingCollapse then return end
    if not combat() and self.integration.preparedNative then
        if self.integration.preparedCollapsed and not collapsed then self.integration.preparedOpening=true end
        self.integration.preparedCollapsed=not not collapsed
    end
    local wasCollapsed=self.integration.nativeCollapsed
    if wasCollapsed and not collapsed then self.integration.restoreNativeLayout=true end
    self.integration.nativeCollapsed=not not collapsed
    local joined=not collapsed and not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    self:SyncCombatTrackerHeader(joined and self.integration.nativeVisible)
    local f=self.sidebar
    if self:SyncCombatAutoHide() then return end
    if not f or not self.integration.nativeBackdrop then return end
    f:SetShown(not collapsed and not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView())
    if f.trackerBackground and f.joinedExpandedHeight then
        f.trackerBackground:SetHeight(collapsed and 26 or f.joinedExpandedHeight)
        -- The primary header already supplies its own art when fully collapsed.
        f.trackerBackground:SetShown(not collapsed)
    end
    if combat() then self:RefreshCombatTrackerPane() end
    self:InvalidateTrackerIntegration()
end
function A:PrepareTrackerJoinVisuals(tracker)
    local s=self.integration
    local native=self.readable(tracker.NineSlice) and tracker.NineSlice
    if s.nativeBackdrop and s.nativeBackdrop.frame~=native then self:RestoreTrackerJoinVisuals() end
    if native and not s.nativeBackdrop then
        s.nativeBackdrop={frame=native,shown=native:IsShown()}
        s.backdropHooks=s.backdropHooks or {}
        if not s.backdropHooks[native] then
            native:HookScript("OnShow",function(frame)
                local state=A.integration.nativeBackdrop
                if state and state.frame==frame then state.shown=true;frame:Hide() end
            end)
            s.backdropHooks[native]=true
        end
    end
    if native then native:Hide() end
    s.moduleButtons=s.moduleButtons or {};s.moduleButtonHooks=s.moduleButtonHooks or {}
    local seen={}
    local function prepareModule(module)
        if not self.readable(module) or seen[module] then return end
        seen[module]=true
        local header=self.readable(module.Header) and module.Header
        local button=header and self.readable(header.MinimizeButton) and header.MinimizeButton
        if button and not s.moduleButtons[button] then
            s.moduleButtons[button]={shown=button:IsShown()}
            if not s.moduleButtonHooks[button] then
                button:HookScript("OnShow",function(frame)
                    local state=A.integration.moduleButtons and A.integration.moduleButtons[frame]
                    if state then state.shown=true;frame:Hide() end
                end)
                s.moduleButtonHooks[button]=true
            end
            -- An independently collapsed module must not stay stuck behind a hidden button.
            if invoke(module.IsCollapsed,module)==true then invoke(module.SetCollapsed,module,false) end
        end
        if button then button:Hide() end
    end
    -- Use the container's iterator, with its list as a fallback for client variants.
    invoke(tracker.ForEachModule,tracker,prepareModule)
    for _,module in pairs(tracker.modules or {}) do prepareModule(module) end
    s.collapseHooks=s.collapseHooks or {}
    if not s.collapseHooks[tracker] and type(hooksecurefunc)=="function" and type(tracker.SetCollapsed)=="function" then
        hooksecurefunc(tracker,"SetCollapsed",function(_,collapsed) A:SetJoinedCollapseVisual(collapsed) end)
        s.collapseHooks[tracker]=true
    end
end
function A:SyncTrackerBackgroundJoin(tracker,nativeVisible)
    if combat() then return end
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    local partyVisible=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    if self.db.displayMode~="blizzard" or (not nativeVisible and not partyVisible) then
        self:RestoreTrackerJoinVisuals();return
    end
    local background=f.trackerBackground
    local width,height=f:GetWidth(),f:GetHeight()
    local left,right,top,bottom=0,width,0,height
    local nativeBounds
    local native=nativeVisible and tracker and self.readable(tracker.NineSlice) and tracker.NineSlice
    local function number(value) return self.public(value,"number") and value==value and math.abs(value)<math.huge end
    local scale=invoke(f.GetEffectiveScale,f)
    if native then
        local nativeScale=invoke(native.GetEffectiveScale,native)
        local ownLeft,ownTop=invoke(f.GetLeft,f),invoke(f.GetTop,f)
        local l,r,t,b=invoke(native.GetLeft,native),invoke(native.GetRight,native),invoke(native.GetTop,native),invoke(native.GetBottom,native)
        if not (number(scale) and scale>0 and number(nativeScale) and nativeScale>0
            and number(ownLeft) and number(ownTop) and number(l) and number(r) and number(t) and number(b)) then
            -- Do not suppress native art before we can replace it with valid bounds.
            self:RestoreTrackerJoinVisuals();return
        end
        local nl=(l*nativeScale-ownLeft*scale)/scale
        local nr=(r*nativeScale-ownLeft*scale)/scale
        self.integration.backgroundHeader=self.readable(tracker.Header) and tracker.Header or nil
        local nt=self:TrackerBackgroundContentTop((ownTop*scale-t*nativeScale)/scale,ownTop,scale)
        local nb=(ownTop*scale-b*nativeScale)/scale
        nativeBounds={left=nl,right=nr,top=nt,bottom=nb}
        if partyVisible then
            left=math.min(left,nl);right=math.max(right,nr)
            top=math.min(top,nt);bottom=math.max(bottom,nb)
        else left,right,top,bottom=nl,nr,nt,nb end
        -- Keep the one-button policy even when Party Quests is toggled off.
        self:PrepareTrackerJoinVisuals(tracker)
    elseif self.integration.nativeBackdrop then self:RestoreTrackerJoinVisuals() end
    local parentScale=UIParent and invoke(UIParent.GetEffectiveScale,UIParent)
    if number(scale) and number(parentScale) and parentScale>0 then background:SetScale(scale/parentScale) end
    -- Frame levels cannot put a MEDIUM-strata backdrop below Blizzard's LOW text.
    background:SetFrameStrata(invoke(tracker.GetFrameStrata,tracker) or "LOW")
    background:SetFrameLevel(math.max(0,tracker:GetFrameLevel()-1))
    if background.art then background.art:SetFrameLevel(background:GetFrameLevel()) end
    local collapsed=nativeVisible and self:IsNativeTrackerCollapsed(tracker)
    self.integration.nativeCollapsed=collapsed
    f.combatBackgroundBounds={native=nativeBounds}
    f.joinedExpandedHeight=bottom-top
    local drawHeight=collapsed and 26 or f.joinedExpandedHeight
    local signature=table.concat({left,right,top,drawHeight},":")
    if f.backgroundJoinSignature~=signature then
        background:ClearAllPoints();background:SetPoint("TOPLEFT",f,"TOPLEFT",left,-top)
        background:SetWidth(right-left);background:SetHeight(drawHeight)
        f.backgroundJoinSignature=signature
    end
    -- Avoid a second rounded panel protruding beyond the primary header art.
    background:SetShown(not collapsed)
end
function A:SyncTrackerSidebarAppearance(tracker)
    if combat() then return end
    local f,s=self.sidebar,self.integration
    if not f then return end
    local now=GetTime()
    if s.nextAppearance and now<s.nextAppearance then return end
    s.nextAppearance=now+0.25
    local parts={}
    local function add(value)
        if self.public(value,"string") or self.public(value,"number") or self.public(value,"boolean") then
            parts[#parts+1]=tostring(value)
        else parts[#parts+1]="-" end
    end
    -- Font objects can change in place after Edit Mode or accessibility changes.
    -- Include their shadow/outline/spacing as well as face and point size.
    for _,font in ipairs({ObjectiveTrackerHeaderFont or GameFontNormal,ObjectiveTrackerLineFont or GameFontHighlightSmall}) do
        for _,method in ipairs({"GetFont","GetShadowOffset","GetShadowColor","GetSpacing"}) do
            if type(font[method])=="function" then
                local ok,a,b,c,d=pcall(font[method],font)
                if ok then add(a);add(b);add(c);add(d) end
            end
        end
    end
    for _,role in ipairs({"Header","Normal","NormalHighlight","Complete"}) do
        for _,v in ipairs(nativeColor(role)) do add(v) end
    end
    local scale=tracker and invoke(tracker.GetEffectiveScale,tracker)
    local parentScale=UIParent and invoke(UIParent.GetEffectiveScale,UIParent)
    if self.public(scale,"number") and self.public(parentScale,"number") and scale>0 and parentScale>0 then
        scale=scale/parentScale
        if scale==scale and scale<100 then add(scale) else scale=nil end
    else scale=nil end
    local signature=table.concat(parts,";")
    if s.appearanceSignature==signature then return end
    s.appearanceSignature=signature
    if scale and s.sidebarScale~=scale then f:SetScale(scale);s.sidebarScale=scale end
    local function refresh(region,role,color)
        if not region then return end
        applyFont(region,role);region:SetTextColor(unpack(nativeColor(color)))
    end
    refresh(f.title,"header","Header");refresh(f.partyOnlyTitle,"header","Header")
    refresh(f.hint,"line","Normal")
    for _,name in ipairs({"share","refresh","settings","collapse"}) do
        local button=f[name]
        if button then refresh(button.caption,"line","Header") end
    end
    -- Rebuild our rows to recalculate wrapping and height for the live fonts.
    s.dirty=true;s.due=nil
end
function A:TrackerSidebarHeightLimit(tracker)
    local function valid(value)
        return self.public(value,"number") and value==value and value>0 and value<math.huge
    end
    local setting=Enum and Enum.EditModeObjectiveTrackerSetting and Enum.EditModeObjectiveTrackerSetting.Height
    local height=tracker and setting and invoke(tracker.GetSettingValue,tracker,setting)
    if not valid(height) then height=tracker and tracker.editModeHeight end
    if not valid(height) then height=tracker and invoke(tracker.GetHeight,tracker) end
    if not valid(height) then height=420 end
    return height
end
function A:TrackerIntegrationTick()
    if not self.db then return end
    if self.integration.pendingDisplayMode and not combat() then self:ApplyPendingDisplayMode();return end
    if self:SyncCombatAutoHide() then return end
    self:ApplyPendingTrackerRestore()
    self:RestoreNativeExpandedLayout(ObjectiveTrackerFrame)
    self:UpdateTrackerQuestFocus()
    if combat() then
        self:UpdateTrackerSidebarCombat()
        -- Native content can contract without changing our quest data.
        if self.db.displayMode=="blizzard" then self:ResizeCombatTrackerBackground() end
        return
    end
    if self.UpdateMinimapButton then self:UpdateMinimapButton() end
    local s=self.integration
    if ObjectiveTrackerFrame then self:EnsurePartyTrackerButton(ObjectiveTrackerFrame)
    elseif self.partyTrackerButton then self.partyTrackerButton:Hide() end
    if self.db.displayMode~="blizzard" then
        self:RestoreJoinedTrackerHeader()
        self:RestoreTrackerJoinVisuals()
        if self.sidebar then self.sidebar:Hide() end
        s.attached=false;s.status="pop-out window"
        if self.window then self.window:SetShown(not self.db.hidden and self:ShouldShowPartyView()) end
        return
    end
    local tracker=ObjectiveTrackerFrame
    if not tracker then
        self:RestoreJoinedTrackerHeader()
        self:RestoreTrackerJoinVisuals()
        if self.sidebar then self.sidebar:Hide() end
        s.attached=false;s.status="Blizzard tracker unavailable; using pop-out"
        if self.window then self.window:SetShown(not self.db.hidden and not self.db.trackerHidden and self:ShouldShowPartyView()) end
        return
    end
    self:InitTrackerSidebar()
    self:SyncTrackerSidebarOpacity(tracker)
    self:SyncTrackerSidebarAppearance(tracker)
    local f=self.sidebar
    local side=self.db.trackerSide=="right" and "right" or "left"
    local width=math.max(320,math.min(640,self.db.sidebarWidth or 420))
    -- Auto-size to our content, capped by the shared Edit Mode height setting.
    -- The native tracker can currently be empty/shorter than its configured cap.
    local height=self:TrackerSidebarHeightLimit(tracker)
    local header=self.readable(tracker.Header) and tracker.Header or nil
    local nativeVisible=tracker:IsShown() and (not header or header:IsShown())
    local anchor=nativeVisible and header or tracker
    if s.anchor~=anchor or s.side~=side or s.nativeVisible~=nativeVisible then
        f:ClearAllPoints()
        f:SetParent(UIParent);f:SetFrameLevel(tracker:GetFrameLevel()+2)
        f:SetClampedToScreen(not nativeVisible)
        if not nativeVisible then f:SetPoint("TOPLEFT",anchor,"TOPLEFT",0,0)
        elseif side=="right" then f:SetPoint("TOPLEFT",anchor,"TOPRIGHT",0,0)
        else f:SetPoint("TOPRIGHT",anchor,"TOPLEFT",0,0) end
        s.anchor=anchor;s.side=side;s.nativeVisible=nativeVisible;s.dirty=true
    end
    self:SetTrackerSidebarHeaderLayout(nativeVisible)
    local collapsed=not nativeVisible and not not self.db.trackerCollapsed
    f.viewCollapsed=collapsed
    if f:GetWidth()~=width or f.heightLimit~=height then f:SetWidth(width);f.heightLimit=height;s.dirty=true end
    f.scroll:SetShown(not collapsed)
    f.collapse:SetShown(not nativeVisible)
    local collapseAtlas=collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
    f.collapse.normal:SetAtlas(collapseAtlas);f.collapse.pushed:SetAtlas(collapseAtlas.."-pressed")
    self:SizeTrackerSidebar()
    local visible=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    self:JoinTrackerHeader(tracker,visible and nativeVisible)
    local allCollapsed=nativeVisible and self:IsNativeTrackerCollapsed(tracker)
    f:SetShown(visible and not allCollapsed)
    self.window:Hide();s.attached=true
    s.status=nativeVisible and ("sidebar "..side) or "party-only tracker; native tracker empty/hidden"
    if s.dirty and (not s.due or GetTime()>=s.due) then
        local ok,err=pcall(function()
            s.entries,s.memberCount=self:BuildTrackerEntries()
            self:RenderTrackerSidebar(s.entries,s.memberCount)
        end)
        if ok then s.dirty=false;s.due=nil;s.lastError=nil
        else
            s.lastError=self.public(err,"string") and err:sub(1,180) or "unreadable error"
            s.status="sidebar layout failed; using pop-out";self.db.displayMode="window"
            f:Hide();self:RestoreJoinedTrackerHeader();self:RestoreTrackerJoinVisuals();self.db.hidden=false;self.window:Show();s.attached=false
        end
    end
    self:SyncTrackerBackgroundJoin(tracker,nativeVisible)
end
local events=CreateFrame("Frame")
A.integrationEvents=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","SUPER_TRACKING_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="SUPER_TRACKING_CHANGED" then A:UpdateTrackerQuestFocus()
    else
        A:SyncCombatAutoHide()
        if event=="PLAYER_REGEN_ENABLED" then A.integration.restoreNativeLayout=true end
        A:InvalidateTrackerIntegration()
    end
end)
