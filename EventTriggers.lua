local _, A = ...
local public=A.public
A.triggerStats={events={},units={},batches=0,registered={}}
local triggers={"UNIT_QUEST_LOG_CHANGED","PARTY_KILL","CHAT_MSG_LOOT","BAG_UPDATE_DELAYED",
    "QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_REGEN_ENABLED","TOOLTIP_DATA_UPDATE"}
function A:TriggerLog(line)
    self:Diag(line)
    if not (self.db and self.db.diag) then return end
    self.diagEvents=self.diagEvents or {}
    local log=self.diagEvents
    log[#log+1]=string.format("%.1f %s",GetTime(),line)
    while #log>100 do table.remove(log,1) end
end
function A:QueueTriggeredRefresh(event,member,followup)
    if not next(self.members) or self.demo then return end
    local priority=followup and 1 or (member and 2 or 0)
    local due=GetTime()+(followup and 0.75 or (member and 0.1 or 0.25))
    local job=self.triggerPending
    if not job then job={due=due,reasons={},members={},all=false,followup=followup,priority=priority};self.triggerPending=job
    elseif priority<job.priority then return
    elseif priority>job.priority then
        job.due=math.min(job.due,due);job.reasons={};job.members={};job.all=false;job.followup=followup;job.priority=priority
    else job.due=math.min(job.due,due);if not followup then job.followup=false end end
    job.reasons[event]=true
    if member then job.members[member.guid]=true else job.all=true end
end
function A:HandleTrigger(event,...)
    if not self.db or self.demo then return end
    if event=="TOOLTIP_DATA_UPDATE" then
        if self.TooltipDataUpdated then self:TooltipDataUpdated(...) end
        return
    end
    local stats=self.triggerStats
    stats.events[event]=(stats.events[event] or 0)+1
    local member,unit
    if event=="UNIT_QUEST_LOG_CHANGED" then
        local raw=...
        unit=public(raw,"string") and raw or "<unreadable>"
        stats.units[unit]=(stats.units[unit] or 0)+1
        self:TriggerLog("EVENT "..event.." unit="..unit)
        if unit=="player" then
            self:ScheduleOwn()
            if self.QueueNativeTracker then self:QueueNativeTracker(event) end
        else
            for _,m in pairs(self.members) do if unit==m.unit or unit==m.guid then member=m;break end end
            if not member then return end
            self.lastPartyQuestSignal=GetTime()
        end
    else
        -- An item link identifies a tooltip to query; it never awards credit.
        if event=="CHAT_MSG_LOOT" and self.ObserveLootLink then self:ObserveLootLink(...) end
        -- Kill GUIDs and loot amounts are never interpreted as objective counts.
        self:TriggerLog("EVENT "..event)
        if event=="QUEST_WATCH_UPDATE" then
            self:ScheduleOwn()
            if self.QueueNativeTracker then self:QueueNativeTracker(event) end
        end
    end
    -- Inventory shuffles and generic local redraws are not progress signals.
    if event=="BAG_UPDATE_DELAYED" or event=="QUEST_LOG_UPDATE" then return end
    if event=="PLAYER_REGEN_ENABLED" and not self.triggerPending then return end
    if not member and self.lastPartyQuestSignal and GetTime()-self.lastPartyQuestSignal<1.5 then return end
    self:QueueTriggeredRefresh(event,member)
end
function A:TriggerTick()
    if not next(self.members) or self.demo then
        self.triggerPending,self.triggerTasks,self.triggerActive=nil,nil,nil;return
    end
    if self.triggerTasks or not self.triggerPending then return end
    local now=GetTime()
    local cooldown=self.triggerPending.priority==2 and 0.35 or (self.triggerPending.followup and 0.75 or 1)
    if now<self.triggerPending.due or (self.triggerLastAt and now-self.triggerLastAt<cooldown) then return end
    local job=self.triggerPending;self.triggerPending=nil
    -- Reuse available native sources, while preserving the periodic queue's
    -- cursor. Event bursts never cancel a membership validation pass.
    local savedTasks,savedIndex=self.liveTasks,self.liveIndex
    self:BuildLiveTasks(true)
    local available=self.liveTasks
    self.liveTasks,self.liveIndex=savedTasks,savedIndex
    local ids={}
    for guid in pairs(job.members) do
        local m=self.members[guid]
        if m then for id in pairs(m.quests) do ids[id]=true end end
    end
    local tasks={}
    for _,task in ipairs(available) do
        if task.kind~="membership" and (task.kind~="party" or job.all or ids[task.value]) then tasks[#tasks+1]=task end
    end
    local reasons={}
    for event in pairs(job.reasons) do reasons[#reasons+1]=event end
    table.sort(reasons)
    job.context=table.concat(reasons,"+")
    self.triggerTasks,self.triggerIndex,self.triggerActive=tasks,1,job
    self.triggerLastAt=now;self.triggerStats.batches=self.triggerStats.batches+1
    self:TriggerLog("REFRESH "..job.context.." tasks="..#tasks..(job.followup and " follow-up" or ""))
end
function A:FinishTriggeredRefresh()
    local job=self.triggerActive
    self.triggerTasks,self.triggerActive=nil,nil
    if job and not job.followup then
        if job.all then self:QueueTriggeredRefresh("follow-up",nil,true)
        else
            for guid in pairs(job.members) do
                if self.members[guid] then self:QueueTriggeredRefresh("follow-up",self.members[guid],true) end
            end
        end
    end
end
function A:TriggerReport()
    local stats=self.triggerStats
    local registration,events,units={},{},{}
    for event,status in pairs(stats.registered) do registration[#registration+1]=event.."="..status end
    for event,count in pairs(stats.events) do events[#events+1]=event.."="..count end
    for unit,count in pairs(stats.units) do units[#units+1]=unit.."="..count end
    table.sort(registration);table.sort(events);table.sort(units)
    return table.concat({"Trigger registrations: "..table.concat(registration,"; "),
        "Events observed: "..table.concat(events,"; "),
        "Quest-change units: "..table.concat(units,"; "),
        "Triggered refresh batches: "..stats.batches,
        "Recent events and refreshes:",table.concat(self.diagEvents or {},"\n")},"\n")
end
local frame=CreateFrame("Frame")
A.triggerFrame=frame
frame:SetScript("OnEvent",function(_,event,...) A:HandleTrigger(event,...) end)
for _,event in ipairs(triggers) do
    local ok,result=pcall(frame.RegisterEvent,frame,event)
    A.triggerStats.registered[event]=(ok and result~=false) and "registered" or "unavailable"
end
