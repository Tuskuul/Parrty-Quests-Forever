local _, A = ...
A.members, A.own, A.queue, A.incoming = {}, {}, {}, {}
A.prefix = "SPQ1"
local serial, lastSend, lastRequest, lastDelta = 0, -100, -100, -100
local types = Enum and Enum.TooltipDataLineType or {}
local function secret(v) return issecretvalue and issecretvalue(v) end
local function readable(v) return not secret(v) and type(v) == "table" and not (issecrettable and issecrettable(v)) end
local function public(v, kind) return not secret(v) and type(v) == kind end
A.public, A.readable = public, readable
local function clean(s)
    if not public(s, "string") then return "" end
    return s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
local function encode(s) return tostring(s or ""):gsub("%%", "%%25"):gsub("\t", "%%09"):gsub("\n", "%%0A"):gsub("\r", "%%0D") end
local function decode(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)) end
local function fields(s)
    local t = {}
    for v in (s .. "\t"):gmatch("(.-)\t") do t[#t+1] = decode(v) end
    return t
end
function A:Changed()
    if self.InvalidateTrackerIntegration then self:InvalidateTrackerIntegration() end
    if self.batchNative then self.liveDirty=true elseif self.Render then self:Render() end
end
function A:QuestDisplayChanged(old,q)
    if not old or old.title~=q.title or old.ready~=q.ready or old.readyKnown~=q.readyKnown then return true end
    for _,field in ipairs({"objectives","requirements"}) do
        local a,b=old[field] or {},q[field] or {}
        if #a~=#b then return true end
        for i,o in ipairs(a) do
            local n=b[i]
            if o.text~=n.text or o.done~=n.done or o.total~=n.total or o.finished~=n.finished then return true end
        end
    end
    return false
end
-- Forever's second UnitName return is a surname, not a realm.
function A:UnitCharacterName(unit)
    local ok,first,surname=pcall(UnitName,unit)
    if not ok then return nil end
    first=public(first,"string") and clean(first) or nil
    surname=public(surname,"string") and clean(surname) or nil
    if first and first~="" then
        if not first:find(" ",1,true) and surname and surname~="" then return first.." "..surname,first end
        if first:find(" ",1,true) then return first,first end
    end
    if GetUnitName then
        local got,name=pcall(GetUnitName,unit,false)
        if got and public(name,"string") and name~="" and (not first or name:find(" ",1,true)) then return clean(name),first end
    end
    return first,first
end
function A:UpdateMemberName(m)
    local name,first=self:UnitCharacterName(m.unit)
    m.name=name or m.name or "Unknown player"
    m.firstName=first or m.firstName
    if GetUnitName then
        local ok,native=pcall(GetUnitName,m.unit,true)
        if ok and public(native,"string") and native~="" then m.fullName=clean(native) end
    end
    m.fullName=m.fullName or m.name
end
function A:MemberFromName(name)
    if not public(name,"string") or name=="" then return nil,false end
    local match,recognized
    for _,m in pairs(self.members) do
        if name==m.name or name==m.fullName or name==m.firstName then
            if match and match~=m then return nil,true end
            match,recognized=m,true
        end
    end
    -- A name-only row must not assign our own counts to a namesake.
    local own,first=self:UnitCharacterName("player")
    if name==own or name==first then return nil,true end
    return match,recognized or false
end
function A:Roster()
    self.soloOverride=nil
    local current = {}
    if not IsInRaid() then
        for i=1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local guid = UnitGUID(unit)
            if public(guid, "string") then
                local m = self.members[guid] or {guid=guid, quests={}}
                m.unit=unit;self:UpdateMemberName(m)
                m.class = select(2, UnitClass(unit))
                m.connected = UnitIsConnected(unit)
                current[guid] = m
            end
        end
    end
    self.members = current
    self.sweep, self.sweepDue = nil, GetTime()+2
    self.liveTasks,self.liveDue=nil,GetTime()+2
    self.triggerPending,self.triggerTasks,self.triggerActive=nil,nil,nil
    self.partyQueryCache={}
    self.questQueryState={}
    -- A new roster invalidates incomplete transmissions and queued old-group data.
    self.incoming, self.queue = {}, {}
    self.publishedQuests=nil;self.progressPending=nil
    self:Changed()
end
function A:MemberFromSender(sender)
    if not public(sender,"string") then return end
    local match
    local realm=GetNormalizedRealmName and GetNormalizedRealmName()
    for _,m in pairs(self.members) do
        for _,name in ipairs({m.fullName or m.name,m.name}) do
            if sender==name or (public(realm,"string") and sender==name.."-"..realm) then
                if match and match~=m then return nil end
                match=m
            end
        end
    end
    return match
end
function A:MemberFromLine(line)
    if public(line.guid,"string") and self.members[line.guid] then return self.members[line.guid] end
    return self:MemberFromName(clean(line.leftText))
end
function A:ReadOwn()
    local previous=self.own
    local quests,zoneName = {},nil
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        for i=1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if readable(info) and public(info.isHeader,"boolean") and info.isHeader then
                zoneName=public(info.title,"string") and info.title or nil
            end
            if readable(info) and not secret(info.isHeader) and not info.isHeader and public(info.questID, "number") then
                local q = {id=info.questID, title=public(info.title,"string") and info.title or ("Quest "..info.questID), objectives={}}
                q.zoneName=zoneName
                local list = C_QuestLog.GetQuestObjectives(q.id)
                if readable(list) then
                    for _, o in ipairs(list) do
                        if readable(o) and public(o.text,"string") then
                            q.objectives[#q.objectives+1] = {text=o.text,
                                done=public(o.numFulfilled,"number") and o.numFulfilled or nil,
                                total=public(o.numRequired,"number") and o.numRequired or nil}
                            if public(o.finished,"boolean") then q.objectives[#q.objectives].finished=o.finished end
                        end
                    end
                end
                -- GetInfo does not reliably provide isComplete on Forever.
                -- A missing flag must not become an authoritative false value.
                local complete
                local function known(value)
                    return public(value,"boolean") or (public(value,"number") and (value==0 or value==1 or value==-1))
                end
                if type(C_QuestLog.IsComplete)=="function" then
                    local ok,value=pcall(C_QuestLog.IsComplete,q.id)
                    if ok and known(value) then complete=value end
                end
                if not known(complete) and known(info.isComplete) then complete=info.isComplete end
                q.readyKnown=known(complete)
                if q.readyKnown then q.ready=complete==true or complete==1 end
                quests[q.id] = q
            end
        end
    end
    local ownChanged=false
    for id,q in pairs(quests) do
        if previous[id] and self:QuestDisplayChanged(previous[id],q) then ownChanged=true;break end
    end
    if ownChanged and self.QueueNativeTracker then self:QueueNativeTracker("local objective change") end
    local changed=false
    for id,q in pairs(quests) do if self:QuestDisplayChanged(previous[id],q) then changed=true;break end end
    if not changed then for id in pairs(previous) do if not quests[id] then changed=true;break end end end
    self.own = quests
    if changed then self.progressPending=true;self.sendPending=true end
    if self.partyQueryCache then
        for id in pairs(quests) do if not previous[id] then self.partyQueryCache[id]=nil end end
    end
    if self.PopulateRequirements then
        for _,m in pairs(self.members) do for _,q in pairs(m.quests) do self:PopulateRequirements(q) end end
    end
    self:Changed()
end
-- Native rows are grouped by quest title, then by player, then objectives.
-- Never infer a missing quest from an empty or restricted tooltip response.
function A:Consume(data, knownID, source)
    if not readable(data) or not readable(data.lines) then return 0 end
    local now, id, title, member = GetTime(), knownID, nil, nil
    local observations = {}
    for _, line in ipairs(data.lines) do
        if not readable(line) or secret(line.type) then return end
        if line.type == types.QuestTitle then
            id = public(line.id,"number") and line.id or knownID
            title, member = clean(line.leftText), nil
        elseif line.type == types.QuestPlayer then
            member = self:MemberFromLine(line)
        elseif line.type == types.QuestObjective and member and public(id,"number") then
            if public(line.leftText,"string") then
                local text=clean(line.leftText)
                if text=="Not on quest" then member=nil
                else
                local key = member.guid .. ":" .. id
                local entry = observations[key]
                if not entry then
                    local old = member.quests[id]
                    entry = {member=member, received=0, q={id=id, title=title ~= "" and title or nil, objectives={}, seen=now}}
                    entry.q.title = entry.q.title or (old and old.title) or ("Quest "..id)
                    observations[key] = entry
                end
                entry.received=entry.received+1
                local done=public(line.numFulfilled,"number") and line.numFulfilled or nil
                local total=public(line.numRequired,"number") and line.numRequired or nil
                if done==nil or total==nil then
                    local x,y=text:match("(%d+)%s*/%s*(%d+)")
                    if x and y then done,total=tonumber(x),tonumber(y) end
                end
                local readyText=text:match("^%s*(.-)%s*$")
                if readyText=="Ready for turn-in" or (QUEST_WATCH_QUEST_READY and readyText==QUEST_WATCH_QUEST_READY) then
                    entry.q.ready=true;entry.q.readyAt=now
                else
                    local finished=public(line.completed,"boolean") and line.completed
                    if not public(line.completed,"boolean") then finished=nil end
                    if finished==false or (done and total and done<total) then entry.q.ready=false end
                    entry.q.objectives[#entry.q.objectives+1] = {text=text,done=done,total=total,finished=finished,observedAt=now}
                end
                end
            end
        end
    end
    local changed, observationsAdded = false, 0
    for _, entry in pairs(observations) do
        local m, q = entry.member, entry.q
        local resurrect=true
        if m.removedQuests and m.removedQuests[q.id] then
            local ok,present=false,nil
            if C_QuestLog and C_QuestLog.IsUnitOnQuest then ok,present=pcall(C_QuestLog.IsUnitOnQuest,m.unit,q.id) end
            resurrect=ok and public(present,"boolean") and present
            if resurrect then m.removedQuests[q.id]=nil end
        end
        -- A recent full snapshot is richer than a tooltip's subset of objectives.
        if resurrect and (not m.syncedAt or now-m.syncedAt > 120) then
            local old = m.quests[q.id]
            if self.TrackProgress then self:TrackProgress(m,q,old,source or "native") end
            if old then
                if q.ready==nil then q.ready,q.readyAt=old.ready,old.readyAt end
                q.polledAt = old.polledAt
                q.pendingAbsentAt=old.pendingAbsentAt
                q.awaitingTitle = old.awaitingTitle and q.title == old.title or nil
                q.requirements,q.requirementSource=old.requirements,old.requirementSource
                q.requirementsChecked,q.dataRequestAt=old.requirementsChecked,old.dataRequestAt
                local merged, indices = {}, {}
                local function add(o)
                    local key = A:ObjectiveKey(o.text)
                    if indices[key] then merged[indices[key]] = o
                    else merged[#merged+1] = o; indices[key] = #merged end
                end
                for _, o in ipairs(old.objectives) do add(o) end
                for _, o in ipairs(q.objectives) do add(o) end
                q.objectives = merged
            end
            if self.PopulateRequirements then self:PopulateRequirements(q) end
            q.lastNativeSource=source or "native"
            changed=self:QuestDisplayChanged(old,q) or changed
            m.quests[q.id]=q
            observationsAdded=observationsAdded+entry.received
        end
    end
    if changed then self:Changed() end
    return observationsAdded
end
function A:ScanUnit(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit and UnitExists(unit)) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if ok then
        if self.RecordLiveData then self:RecordLiveData("unit:"..unit,data) else self:Consume(data) end
    end
end
function A:RefreshKnown()
    self.liveTasks=nil;self.liveDue=GetTime()
    if not (C_TooltipInfo and C_TooltipInfo.GetQuestPartyProgress) then return end
    local ids = {}
    for id in pairs(self.own) do ids[id] = true end
    for _, m in pairs(self.members) do for id in pairs(m.quests) do ids[id] = true end end
    for id in pairs(ids) do
        if self.QueryPartyProgress then self:QueryPartyProgress(id,true)
        else
            local ok,data=pcall(C_TooltipInfo.GetQuestPartyProgress,id,false,true)
            if ok then self:Consume(data,id) end
        end
    end
end
function A:Serialize(questIDs)
    local lines = {}
    for id, q in pairs(self.own) do
        if not questIDs or questIDs[id] then
            -- Legacy 0 did not distinguish unknown from confirmed incomplete.
            -- N preserves a confirmed false without adding fields/record types;
            -- older receivers already treat any value other than 1 as false.
            local ready=q.ready and "1" or (q.readyKnown and "N" or "0")
            lines[#lines+1] = table.concat({"Q",id,encode(q.title),ready}, "\t")
            for _, o in ipairs(q.objectives) do
                lines[#lines+1] = table.concat({"O",id,encode(o.text),o.done or "",o.total or ""}, "\t")
            end
        end
    end
    return table.concat(lines, "\n")
end
function A:Deserialize(payload,delta)
    local quests, count, removed = {}, 0, {}
    for line in payload:gmatch("[^\n]+") do
        local f = fields(line)
        local id = tonumber(f[2])
        if not id or id < 1 or id%1 ~= 0 then return nil end
        if delta and f[1]=="R" and #f==2 then
            if quests[id] or removed[id] then return nil end
            removed[id]=true
        elseif f[1] == "Q" and #f == 4 then
            count = count+1
            if count > 100 or quests[id] or removed[id] then return nil end
            if f[4]~="0" and f[4]~="1" and f[4]~="N" then return nil end
            quests[id] = {id=id,title=f[3],ready=f[4]=="1",readyKnown=(f[4]=="1" or f[4]=="N") or nil,objectives={}}
        elseif f[1] == "O" and #f == 5 and quests[id] then
            local q = quests[id]
            if #q.objectives >= 30 then return nil end
            q.objectives[#q.objectives+1] = {text=f[3],done=tonumber(f[4]),total=tonumber(f[5])}
        else return nil end
    end
    return quests,removed
end
function A:RememberPublishedQuests()
    self.publishedQuests={}
    for id in pairs(self.own) do self.publishedQuests[id]=self:Serialize({[id]=true}) end
end
function A:QueueProgressPayload(payload,delta)
    if #payload>60000 then return false end
    serial=serial+1
    local total=math.max(1,math.ceil(#payload/180))
    self.queue={}
    for i=1,total do self.queue[i]=(delta and "D" or "")..serial..":"..i..":"..total..":"..payload:sub((i-1)*180+1,i*180) end
    self:RememberPublishedQuests();self.progressPending=nil
    return true
end
function A:SendProgressDelta()
    if not next(self.members) or not self.comms or #self.queue>0 or GetTime()-lastDelta<0.35 then return end
    if not self.publishedQuests then self.sendPending=true;return end
    local lines={}
    for id in pairs(self.own) do
        local body=self:Serialize({[id]=true})
        if body~=self.publishedQuests[id] then lines[#lines+1]=body end
    end
    for id in pairs(self.publishedQuests) do if not self.own[id] then lines[#lines+1]="R\t"..id end end
    self.progressPending=nil
    if #lines>0 and self:QueueProgressPayload(table.concat(lines,"\n"),true) then lastDelta=GetTime() end
end
function A:SendSnapshot()
    if not next(self.members) or not self.comms or GetTime()-lastSend < 5 then return end
    local payload = self:Serialize()
    if #payload > 60000 then return end
    if self:QueueProgressPayload(payload,false) then lastSend=GetTime() end
end
function A:Request()
    if not self.comms or not next(self.members) or GetTime()-lastRequest < 5 then return end
    lastRequest = GetTime()
    C_ChatInfo.SendAddonMessage(self.prefix,"REQ","PARTY")
end
function A:Receive(message, sender)
    if not public(message,"string") or #message>255 then return end
    local m = self:MemberFromSender(sender)
    if not m then return end
    if message == "REQ" then
        self.sendPending=true;m.progressSequence=nil
        self.incoming[m.guid]=nil;self.incoming[m.guid..":delta"]=nil
        return
    end
    local delta=message:sub(1,1)=="D"
    if delta then message=message:sub(2) end
    local seq, index, total, part = message:match("^(%d+):(%d+):(%d+):(.*)$")
    seq,index,total = tonumber(seq),tonumber(index),tonumber(total)
    if not seq or total<1 or total>334 or index<1 or index>total or #part>180 then return end
    local key=m.guid..(delta and ":delta" or "")
    if delta and m.progressSequence and seq<=m.progressSequence then return end
    local p = self.incoming[key]
    if not p or p.seq~=seq then
        if p and seq<p.seq then return end
        p={seq=seq,total=total,parts={},at=GetTime()};self.incoming[key]=p
    end
    if p.total~=total then return end
    p.parts[index]=part
    for i=1,total do if p.parts[i]==nil then return end end
    local quests,removed=self:Deserialize(table.concat(p.parts),delta)
    if quests then
        m.removedQuests=delta and (m.removedQuests or {}) or {}
        for _,q in pairs(quests) do
            m.removedQuests[q.id]=nil
            for _,o in ipairs(q.objectives) do o.observedAt=GetTime() end
            if self.PopulateRequirements then self:PopulateRequirements(q) end
        end
        if delta then
            for id,q in pairs(quests) do m.quests[id]=q end
            for id in pairs(removed) do m.quests[id]=nil;m.removedQuests[id]=GetTime() end
        else m.quests,m.syncedAt=quests,GetTime() end
        m.progressSequence=seq;m.progressAt=GetTime()
        self:Changed()
    end
    self.incoming[key]=nil
end
function A:ScheduleOwn()
    -- Preserve the first deadline: continuous quest-log events must not starve reads.
    self.ownDue=self.ownDue or (GetTime()+0.2)
end
function A:CombatOwnTick()
    if self.demo or not (InCombatLockdown and InCombatLockdown()) then return end
    local now=GetTime()
    if self.combatOwnDue and now<self.combatOwnDue then return end
    self.combatOwnDue=now+1
    self:ScheduleOwn()
end
local elapsed, refreshElapsed = 0, 0
local frame=CreateFrame("Frame")
A.events=frame
frame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if (...)~="SimplyPartyQuests" then return end
        SimplyPartyQuestsDB=SimplyPartyQuestsDB or {}
        A.db=SimplyPartyQuestsDB
        A.db.expanded=A.db.expanded or {}
        A.db.questExpanded=A.db.questExpanded or {}
        A.db.sectionCollapsed=A.db.sectionCollapsed or {}
        A.db.zoneCollapsed=A.db.zoneCollapsed or {}
        A.db.trackerGroupsClosed=A.db.trackerGroupsClosed or {}
        if A.db.displayMode==nil then A.db.displayMode="blizzard" end
        if A.db.groupByZone==nil then A.db.groupByZone=true end
        if A.db.nativeTrackerRepair==nil then A.db.nativeTrackerRepair=true end
        if A.db.combatAutoHide==nil then A.db.combatAutoHide=true end
        if A.InitUI then A:InitUI() end
        if A.InitSettings then A:InitSettings() end
    elseif event=="PLAYER_LOGIN" then
        A.comms=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.RegisterAddonMessagePrefix(A.prefix)
        A:Roster(); A:ReadOwn(); A:Request(); A.sendPending=true
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
            for _,kind in ipairs({"Unit","Object","Item","QuestPartyProgress"}) do
                local t=Enum.TooltipDataType[kind]
                if t then TooltipDataProcessor.AddTooltipPostCall(t,function(tooltip,data)
                    if tooltip==GameTooltip then
                        if A.RecordLiveData then A:RecordLiveData("hover:"..kind,data) else A:Consume(data) end
                    end
                end) end
            end
        end
    elseif event=="UNIT_NAME_UPDATE" then
        local unit=...
        if public(unit,"string") then
            for _,m in pairs(A.members) do if m.unit==unit then A:UpdateMemberName(m) end end
            A:Changed()
        end
    elseif event=="GROUP_ROSTER_UPDATE" then
        A:Roster(); A:Request(); A.sendPending=true
    elseif event=="NAME_PLATE_UNIT_ADDED" then
        local unit=...
        if public(unit,"string") and A.liveNameplates then A.liveNameplates[unit]=true end
    elseif event=="NAME_PLATE_UNIT_REMOVED" then
        local unit=...
        if public(unit,"string") and A.liveNameplates then A.liveNameplates[unit]=nil end
    elseif event=="ZONE_CHANGED_NEW_AREA" then
        A.liveSources={};A.liveTasks=nil;A.liveDue=GetTime()+2
        A.partyQueryCache={}
        A.triggerPending,A.triggerTasks,A.triggerActive=nil,nil,nil
    elseif event=="QUEST_DATA_LOAD_RESULT" then
        local id,success=...
        if public(success,"boolean") and success and A.UpdateQuestTitle then A:UpdateQuestTitle(id) end
    elseif event=="UPDATE_MOUSEOVER_UNIT" then A:ScanUnit("mouseover")
    elseif event=="PLAYER_TARGET_CHANGED" then A:ScanUnit("target")
    elseif event=="CHAT_MSG_ADDON" then
        local prefix,message,channel,sender=...
        if prefix==A.prefix and channel=="PARTY" then A:Receive(message,sender) end
    else A:ScheduleOwn() end
end)
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","UNIT_NAME_UPDATE","GROUP_ROSTER_UPDATE","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","ZONE_CHANGED_NEW_AREA","UPDATE_MOUSEOVER_UNIT","PLAYER_TARGET_CHANGED","CHAT_MSG_ADDON","QUEST_DATA_LOAD_RESULT","QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN"}) do frame:RegisterEvent(event) end
frame:SetScript("OnUpdate",function(_,delta)
    if not A.db then return end
    elapsed,refreshElapsed=elapsed+delta,refreshElapsed+delta
    if elapsed<0.15 then return end
    elapsed=0
    if A.layoutDirty then A.layoutDirty=nil;A:Render() end
    local now=GetTime()
    A:CombatOwnTick()
    if A.PollTick then A:PollTick() end
    if A.TriggerTick then A:TriggerTick() end
    if A.NativeTrackerTick then A:NativeTrackerTick() end
    if A.TrackerIntegrationTick then A:TrackerIntegrationTick() end
    if A.LiveTick then A:LiveTick() end
    if A.ownDue and now>=A.ownDue then
        A.ownDue=nil; A:ReadOwn()
    end
    if A.sendPending and #A.queue==0 and now-lastSend>=5 then A.sendPending=nil;A:SendSnapshot() end
    if A.progressPending and #A.queue==0 then A:SendProgressDelta() end
    if #A.queue>0 and A.comms and next(A.members) then C_ChatInfo.SendAddonMessage(A.prefix,table.remove(A.queue,1),"PARTY") end
    for guid,p in pairs(A.incoming) do if now-p.at>90 then A.incoming[guid]=nil end end
    if refreshElapsed>=15 then
        refreshElapsed=0
        A.sendPending=true
        if not A.LiveTick then A:ScanUnit("target");A:RefreshKnown() end
        A:Changed()
    end
end)
