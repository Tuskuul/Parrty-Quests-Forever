local _, A = ...
local public = A.public
local function paused()
    return (InCombatLockdown and InCombatLockdown())
end
-- A false membership answer can mean unavailable remote state. Removal requires
-- a stable, loaded member in the same map/visibility context and a positive
-- control quest in that same validation pass, on two separate passes.
function A:CanValidateMembership(m)
    if paused() then return false end
    local connected=UnitIsConnected(m.unit)
    local guid=UnitGUID(m.unit)
    if not public(connected,"boolean") or not connected or not public(guid,"string") or guid~=m.guid then return false end
    if m.syncedAt and GetTime()-m.syncedAt<=120 then return false end
    if UnitIsVisible then
        local ok,visible=pcall(UnitIsVisible,m.unit)
        if ok and public(visible,"boolean") and visible then return true end
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok,a=pcall(C_Map.GetBestMapForUnit,"player")
        local got,b=pcall(C_Map.GetBestMapForUnit,m.unit)
        if ok and got and public(a,"number") and public(b,"number") and a>0 and a==b then return true end
    end
    return false
end
function A:QueueMembershipValidation(tasks)
    if not (C_QuestLog and C_QuestLog.IsUnitOnQuest) then return end
    for _,m in pairs(self.members) do
        if not m.syncedAt or GetTime()-m.syncedAt>120 then
            local ids={}
            for id,q in pairs(m.quests) do
                if not q.syncedAt or GetTime()-q.syncedAt>120 then ids[#ids+1]=id end
            end
            table.sort(ids)
            local pass={member=m,started=GetTime(),remaining=#ids,results={},positive=false,valid=self:CanValidateMembership(m)}
            for _,id in ipairs(ids) do tasks[#tasks+1]={kind="membership",value=id,pass=pass} end
        end
    end
end
function A:ValidationStep(task)
    local pass,id=task.pass,task.value
    local m=pass.member
    if self.members[m.guid]~=m or not self:CanValidateMembership(m) then pass.valid=false end
    if pass.valid then
        local ok,result=pcall(C_QuestLog.IsUnitOnQuest,m.unit,id)
        if ok and public(result,"boolean") then
            pass.results[id]=result
            if result then pass.positive=true end
        else pass.valid=false end
    end
    pass.remaining=pass.remaining-1
    if pass.remaining>0 then return end
    local now=GetTime()
    if not pass.valid or not pass.positive or not self:CanValidateMembership(m) then
        for _,q in pairs(m.quests) do q.pendingAbsentAt=nil end
        return
    end
    local removed=false
    for questID,present in pairs(pass.results) do
        local q=m.quests[questID]
        if q and (not q.syncedAt or now-q.syncedAt>120) then
            if present then q.pendingAbsentAt=nil;q.polledAt=now
            elseif not q.polledAt or q.polledAt<=pass.started then
                if q.pendingAbsentAt and now-q.pendingAbsentAt>60 then q.pendingAbsentAt=nil end
                if q.pendingAbsentAt and now-q.pendingAbsentAt>=5 then
                    m.quests[questID]=nil
                    m.removedQuests=m.removedQuests or {};m.removedQuests[questID]=now
                    removed=true
                    if self.ProgressChange then self:ProgressChange("REMOVED inactive quest="..questID.." player="..m.name.." after two validated passes") end
                else q.pendingAbsentAt=q.pendingAbsentAt or now end
            end
        end
    end
    if removed then self.liveDirty=true;self:Changed() end
end
function A:QuestTitle(id)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok,title=pcall(C_QuestLog.GetTitleForQuestID,id)
        if ok and public(title,"string") and title~="" then return title end
    end
    local title=self.QuestieField and self:QuestieField(id,"name")
    if public(title,"string") and title~="" then return title end
end
function A:UpdateQuestTitle(id)
    if not public(id,"number") then return end
    local title=self:QuestTitle(id)
    for _,m in pairs(self.members) do
        local q=m.quests[id]
        if q then
            if title and q.awaitingTitle then q.title=title;q.awaitingTitle=nil end
            self:PopulateRequirements(q,true)
        end
    end
    self:Changed()
end
function A:StartSweep()
    if paused() then
        self.sweepDue=GetTime()+0.5;self.sweepStatus="Discovery queued until combat ends"
        return
    end
    if self.sweep then return end
    self.sweepDue=nil
    if not (C_QuestLog and type(C_QuestLog.IsUnitOnQuest)=="function") then
        self.sweepStatus="Quest sweep API unavailable";self:Changed();return
    end
    local members={}
    for _,m in pairs(self.members) do
        -- Synced clients already provide the actual full log; no discovery needed.
        if not m.syncedAt or GetTime()-m.syncedAt>120 then members[#members+1]=m end
    end
    if #members==0 then self.sweepStatus=nil;self.sweepDue=GetTime()+120;self:Changed();return end
    table.sort(members,function(a,b) return a.guid<b.guid end)
    local seen,ids={},{}
    local function add(id) if not seen[id] then seen[id]=true;ids[#ids+1]=id end end
    -- First revisit known quests, then discover from the bundled factual ID catalog.
    for _,m in ipairs(members) do for id in pairs(m.quests) do add(id) end end
    for id in pairs(self.own) do add(id) end
    for _,id in ipairs(self.questCatalog or {}) do add(id) end
    self.sweep={members=members,ids=ids,index=1,memberIndex=1,checks=0,hits=0,unknown=0,errors=0,skipped=0}
    self.sweepStatus="Starting quest sweep";self:Changed()
end
function A:SweepSummary()
    local s=self.sweep or self.lastSweep
    if not s then return self.sweepStatus or "No quest sweep yet" end
    return string.format("%d checks, %d matches, %d unreadable, %d errors, %d skipped",s.checks,s.hits,s.unknown,s.errors,s.skipped)
end
function A:PollTick()
    if self.demo then return end
    local now=GetTime()
    if not self.sweep and self.sweepDue and now>=self.sweepDue and next(self.members) then self:StartSweep() end
    local s=self.sweep
    if not s then return end
    if paused() then
        if self.sweepStatus~="Quest sweep paused (combat)" then
            self.sweepStatus="Quest sweep paused (combat)";self:Changed()
        end
        return
    end
    local started=debugprofilestop and debugprofilestop()
    local changed=false
    -- At most 48 membership checks per tick, with a sub-millisecond time budget.
    -- Only confirmed positives trigger tooltip/title requests, never the whole catalog.
    for _=1,48 do
        local id=s.ids[s.index]
        if not id then break end
        local m=s.members[s.memberIndex]
        local connected=UnitIsConnected(m.unit)
        local guid=UnitGUID(m.unit)
        local valid=public(connected,"boolean") and connected and public(guid,"string") and guid==m.guid
            and (not m.syncedAt or now-m.syncedAt>120)
        if valid then
            s.checks=s.checks+1
            local ok,result=pcall(C_QuestLog.IsUnitOnQuest,m.unit,id)
            if not ok then s.errors=s.errors+1
            elseif not public(result,"boolean") then s.unknown=s.unknown+1
            elseif result then
                s.hits=s.hits+1
                local title=self:QuestTitle(id)
                local q=m.quests[id] or {id=id,title=title or ("Quest "..id),objectives={}}
                q.polledAt=now
                q.pendingAbsentAt=nil
                if m.removedQuests then m.removedQuests[id]=nil end
                if title then q.title=title end
                m.quests[id]=q;changed=true
                if not title and not q.awaitingTitle and C_QuestLog.RequestLoadQuestByID then
                    q.awaitingTitle=true
                end
                self:PopulateRequirements(q)
                if self.QueryPartyProgress then self:QueryPartyProgress(id)
                elseif C_TooltipInfo and C_TooltipInfo.GetQuestPartyProgress then
                    local got,data=pcall(C_TooltipInfo.GetQuestPartyProgress,id,false,true)
                    if got then
                        self.batchNative=true;self:Consume(data,id);self.batchNative=nil
                    end
                end
            end
        else s.skipped=s.skipped+1 end
        s.memberIndex=s.memberIndex+1
        if s.memberIndex>#s.members then s.memberIndex=1;s.index=s.index+1 end
        if s.errors>=20 then
            self.lastSweep=s;self.sweep=nil;self.sweepDue=now+120
            self.sweepStatus="Quest sweep stopped: API errors (/spq status)";self:Changed();return
        end
        if started and debugprofilestop()-started>=0.75 then break end
    end
    local status
    if s.index>#s.ids then
        self.lastSweep=s;self.sweep=nil;self.sweepDue=now+120
        for _,m in ipairs(s.members) do m.sweepAt=now end
        status="Sweep finished: "..s.hits.." matches (catalog coverage)"
    else
        local percent=math.floor((s.index-1)/math.max(1,#s.ids)*100)
        status="Quest sweep "..percent.."% - "..s.hits.." matches"
    end
    if changed or self.sweepStatus~=status then self.sweepStatus=status;self:Changed() end
end
