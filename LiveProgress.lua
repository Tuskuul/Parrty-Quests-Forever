local _, A = ...
local public,readable=A.public,A.readable
A.liveSources,A.liveNameplates={},{}
A.liveStats={queries=0,payloads=0,rows=0,empty=0,errors=0,changes=0,first=0,repeated=0,readyChanges=0,bySource={}}
A.liveStats.scope={shared={data=0,empty=0},foreign={data=0,empty=0}}
A.partyQueryCache={}
A.questQueryState={}
A.itemQueryState={}
local function entityKey(guid)
    local npc=guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return npc and ("npc:"..npc) or guid
end
local function text(value)
    if not public(value,"string") then return "" end
    return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):match("^%s*(.-)%s*$")
end
local function printable(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    local kind=type(value)
    if kind=="string" then return value:sub(1,240):gsub("\n"," ") end
    if kind=="number" or kind=="boolean" then return tostring(value) end
    return "-"
end
function A:Diag(line)
    if not (self.db and self.db.diag) then return end
    self.db.diagLines=self.db.diagLines or {}
    local lines=self.db.diagLines
    lines[#lines+1]=string.format("%.1f %s",GetTime(),line)
    while #lines>350 do table.remove(lines,1) end
end
function A:ProgressChange(line)
    self:Diag(line)
    if not (self.db and self.db.diag) then return end
    self.db.diagChanges=self.db.diagChanges or {}
    local rows=self.db.diagChanges
    rows[#rows+1]=string.format("%.1f %s",GetTime(),line)
    while #rows>60 do table.remove(rows,1) end
end
function A:TrackProgress(member,q,old,source)
    local previous={}
    if old then for _,o in ipairs(old.objectives) do previous[self:ObjectiveKey(o.text)]=o end end
    local stats=self.liveStats
    for _,o in ipairs(q.objectives) do
        if o.done~=nil and o.total~=nil then
            local before=previous[self:ObjectiveKey(o.text)]
            if not before or before.done==nil or before.total==nil then stats.first=stats.first+1
            elseif before.done~=o.done or before.total~=o.total then
                stats.changes=stats.changes+1
                stats.bySource[source]=(stats.bySource[source] or 0)+1
                self:ProgressChange("COUNT CHANGE source="..source.." player="..member.name.." quest="..q.id.." "
                    ..before.done.."/"..before.total.." -> "..o.done.."/"..o.total.." "..o.text)
            else stats.repeated=stats.repeated+1 end
        end
    end
    if q.ready~=nil and (old and old.ready or false)~=q.ready then
        stats.readyChanges=stats.readyChanges+1
        self:ProgressChange("READY CHANGE source="..source.." player="..member.name.." quest="..q.id.." ready="..tostring(q.ready))
    end
end
function A:LogPayload(source,data,id)
    if not (self.db and self.db.diag) then return end
    if not readable(data) or not readable(data.lines) then self:Diag(source.." quest="..printable(id).." <no readable payload>");return end
    local scope=id and (self.own[id] and " shared" or " not-in-your-log") or ""
    self:Diag(source.." quest="..printable(id)..scope.." type="..printable(data.type).." id="..printable(data.id).." rows="..#data.lines)
    for i,line in ipairs(data.lines) do
        if i>32 then self:Diag(" ... remaining rows omitted");break end
        if not readable(line) then self:Diag(" row "..i.." <restricted>")
        else self:Diag(" row "..i.." type="..printable(line.type).." id="..printable(line.id).." guid="..printable(line.guid).." unit="..printable(line.unitToken)
            .." left="..printable(line.leftText).." right="..printable(line.rightText)
            .." counts="..printable(line.numFulfilled).."/"..printable(line.numRequired)) end
    end
end
-- Party-progress tooltips need not use the same typed rows as a unit tooltip.
-- Recognize explicit party identities and real numeric counters; never assign
-- anonymous counters by row position or use our own quest-log progress here.
function A:NormalizePartyProgress(data,id)
    if not public(id,"number") or not readable(data) or not readable(data.lines) then return nil end
    local kinds=Enum.TooltipDataLineType
    local title=self.own[id] and self.own[id].title
    if not title then for _,m in pairs(self.members) do if m.quests[id] then title=m.quests[id].title;break end end end
    local rows={{type=kinds.QuestTitle,id=id,leftText=title or ("Quest "..id)}}
    local member
    for _,line in ipairs(data.lines) do
        if not readable(line) or (issecretvalue and issecretvalue(line.type)) then return nil end
        local left,right=text(line.leftText),text(line.rightText)
        local named=left:gsub(":%s*$", "")
        local found,identity=nil,false
        if public(line.guid,"string") then found=self.members[line.guid];identity=true
        elseif public(line.unitToken,"string") then
            local guid=UnitGUID(line.unitToken)
            if public(guid,"string") then found=self.members[guid];identity=true end
        end
        if not identity then found,identity=self:MemberFromName(named) end
        if line.type==kinds.QuestTitle then
            if public(line.leftText,"string") then rows[1].leftText=line.leftText end
            member=nil
        elseif identity or line.type==kinds.QuestPlayer then member=found end
        if member then
            local done=public(line.numFulfilled,"number") and line.numFulfilled or nil
            local total=public(line.numRequired,"number") and line.numRequired or nil
            local memberLabel=named==member.name or named==member.fullName or named==member.firstName
            local body=left
            if right~="" then body=(identity and memberLabel) and right or (left.." "..right) end
            if done==nil or total==nil then
                local x,y=body:match("(%d+)%s*/%s*(%d+)")
                if x and y then done,total=tonumber(x),tonumber(y) end
            end
            if done and total and total>0 and done>=0 then
                if body=="" or (identity and memberLabel and right=="") then body="Unnamed objective: "..done.."/"..total end
                rows[#rows+1]={type=kinds.QuestPlayer,guid=member.guid,leftText=member.name}
                rows[#rows+1]={type=kinds.QuestObjective,leftText=body,numFulfilled=done,numRequired=total}
            elseif line.type==kinds.QuestObjective and left~="" then
                rows[#rows+1]={type=kinds.QuestPlayer,guid=member.guid,leftText=member.name}
                rows[#rows+1]={type=kinds.QuestObjective,leftText=left}
            elseif not identity and line.type~=kinds.QuestPlayer and left~="" then
                member=nil -- Unknown headings must not leak the previous member's ownership.
            end
        end
    end
    return {lines=rows}
end
-- Candidates are sources to ask, never evidence that loot awarded quest credit.
function A:RememberLiveSource(kind,value)
    if not ((kind=="guid" and public(value,"string")) or (kind=="item" and public(value,"number"))) then return end
    local key=kind..":"..value
    local record={kind=kind,value=value,at=GetTime()}
    if kind=="guid" then
        record.entity=entityKey(value)
        for k,r in pairs(self.liveSources) do
            if k~=key and r.kind==kind and (r.entity or entityKey(r.value))==record.entity then self.liveSources[k]=nil end
        end
    end
    self.liveSources[key]=record
    local keys={}
    for k,r in pairs(self.liveSources) do keys[#keys+1]={key=k,at=r.at} end
    table.sort(keys,function(a,b) return a.at>b.at end)
    for j=33,#keys do self.liveSources[keys[j].key]=nil end
end
function A:ObserveLootLink(message)
    if not public(message,"string") then return end
    local item=tonumber(message:match("|Hitem:(%d+):"))
    if item then self:RememberLiveSource("item",item) end
end
function A:RecordLiveData(source,data,id)
    self:LogPayload(source,data,id)
    if not readable(data) or not readable(data.lines) then self.liveStats.empty=self.liveStats.empty+1;return 0 end
    self.liveStats.payloads=self.liveStats.payloads+1
    if public(data.type,"number") and data.type==Enum.TooltipDataType.QuestPartyProgress and not id then
        id=public(data.id,"number") and data.id or nil
    end
    local normalized=id and source:lower():find("party",1,true) and self:NormalizePartyProgress(data,id) or nil
    local added=self:Consume(normalized or data,id,source) or 0
    self.liveStats.rows=self.liveStats.rows+added
    if added>0 then
        if public(data.guid,"string") and data.guid:match("^Creature%-") then
            self:RememberLiveSource("guid",data.guid)
        elseif public(data.type,"number") and data.type==Enum.TooltipDataType.Item and public(data.id,"number") then
            self:RememberLiveSource("item",data.id)
        end
    end
    return added
end
function A:LiveQuery(source,fn,id,...)
    if type(fn)~="function" then return end
    if self.liveTriggerContext then source="event["..self.liveTriggerContext.."]:"..source end
    self.liveStats.queries=self.liveStats.queries+1
    local unitGUID
    if source:find("unit:",1,true) then
        local token=...
        if public(token,"string") then
            local ok,guid=pcall(UnitGUID,token)
            if ok and public(guid,"string") and guid:match("^Creature%-") then unitGUID=guid end
        end
    end
    local ok,data=pcall(fn,...)
    local restricted=false
    if ok and readable(data) and readable(data.lines) then
        for _,line in ipairs(data.lines) do
            if readable(line) then
                for _,field in ipairs({"id","guid","leftText","numFulfilled","numRequired"}) do
                    if issecretvalue and issecretvalue(line[field]) then restricted=true end
                end
                if unitGUID and public(line.type,"number") and line.type==Enum.TooltipDataLineType.QuestTitle then
                    self:RememberLiveSource("guid",unitGUID);unitGUID=nil
                end
            end
        end
    end
    if source:find("party-progress",1,true) and public(id,"number") then
        local scope=self.liveStats.scope[self.own[id] and "shared" or "foreign"]
        local hasData=ok and readable(data) and readable(data.lines) and #data.lines>0
        if hasData then scope.data=scope.data+1 else scope.empty=scope.empty+1 end
        self.questQueryState[id]={at=GetTime(),source=source,status=not ok and "error" or (restricted and "restricted" or (hasData and "payload" or "empty"))}
        local cache=self.partyQueryCache[id]
        if cache then cache.empty=hasData and 0 or ((cache.empty or 0)+1) end
    end
    local added=0
    if ok then added=self:RecordLiveData(source,data,id) or 0
    else self.liveStats.errors=self.liveStats.errors+1;self:Diag(source.." error="..printable(data)) end
    local state=id and self.questQueryState[id]
    if state and source:find("party-progress",1,true) then state.rows=added end
    if source:find("item",1,true) then
        local item=...
        if public(item,"number") then
            self.itemQueryState[item]={at=GetTime(),rows=added,status=not ok and "error" or (restricted and "restricted" or (added>0 and "progress" or "no progress"))}
            local keys={}
            for k,v in pairs(self.itemQueryState) do keys[#keys+1]={key=k,at=v.at} end
            table.sort(keys,function(a,b) return a.at>b.at end)
            for j=65,#keys do self.itemQueryState[keys[j].key]=nil end
        end
    end
    return added
end
function A:QueryPartyProgress(id,force)
    local now,cache=GetTime(),self.partyQueryCache[id]
    local interval=self.liveTriggerContext and 2 or 10
    if cache and (cache.empty or 0)>=2 then interval=math.max(interval,self.own[id] and 15 or 60) end
    if not force and cache and now-cache.at<interval then
        self.liveStats.skipped=(self.liveStats.skipped or 0)+1;return 0
    end
    self.partyQueryCache[id]=cache or {empty=0};self.partyQueryCache[id].at=now
    if C_TooltipInfo then return self:LiveQuery("party-progress",C_TooltipInfo.GetQuestPartyProgress,id,id,false,true) end
end
function A:BuildLiveTasks(forEvent)
    local tasks,seen={},{}
    local function unit(token)
        if not public(token,"string") then return end
        local ok,exists=pcall(UnitExists,token)
        if not ok or not public(exists,"boolean") or not exists then return end
        local guid=UnitGUID(token)
        local key=public(guid,"string") and entityKey(guid) or token
        if not seen[key] then seen[key]=true;tasks[#tasks+1]={kind="unit",value=token} end
    end
    unit("target");unit("focus");unit("mouseover")
    for _,m in pairs(self.members) do unit(m.unit.."target") end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok,plates=pcall(C_NamePlate.GetNamePlates)
        if ok and readable(plates) then
            for _,plate in ipairs(plates) do
                if readable(plate) and public(plate.namePlateUnitToken,"string") then unit(plate.namePlateUnitToken) end
            end
        end
    end
    for token in pairs(self.liveNameplates) do unit(token) end
    if not forEvent and not (InCombatLockdown and InCombatLockdown()) then self:QueueMembershipValidation(tasks) end
    local ids={}
    for _,m in pairs(self.members) do for id in pairs(m.quests) do ids[id]=true end end
    for id in pairs(self.own) do ids[id]=true end
    local recent={}
    for key,record in pairs(self.liveSources) do
        if GetTime()-record.at>600 then self.liveSources[key]=nil
        else recent[#recent+1]=record end
    end
    table.sort(recent,function(a,b) return a.at>b.at end)
    for i=1,math.min(4,#recent) do
        local r=recent[i]
        local key=r.entity or (r.kind=="guid" and entityKey(r.value)) or r.value
        if not seen[key] then seen[key]=true;tasks[#tasks+1]={kind=r.kind,value=r.value} end
    end
    local itemIDs={}
    for id in pairs(ids) do
        for _,item in ipairs((self.questItemSources or {})[id] or {}) do itemIDs[item]=true end
    end
    local ordered={}
    for item in pairs(itemIDs) do ordered[#ordered+1]=item end
    table.sort(ordered)
    self.itemSourceCursor=self.itemSourceCursor or 1
    if self.itemSourceCursor>#ordered then self.itemSourceCursor=1 end
    for j=1,math.min(4,#ordered) do
        local item=ordered[(self.itemSourceCursor+j-2)%#ordered+1]
        if not seen[item] then tasks[#tasks+1]={kind="item",value=item};seen[item]=true end
    end
    if #ordered>0 then self.itemSourceCursor=(self.itemSourceCursor+math.min(4,#ordered)-1)%#ordered+1 end
    for id in pairs(ids) do tasks[#tasks+1]={kind="party",value=id} end
    self.liveTasks,self.liveIndex=tasks,1
end
function A:LiveTick()
    if self.demo or not next(self.members) then self.liveTasks=nil;return end
    local inCombat=InCombatLockdown and InCombatLockdown()
    local now=GetTime()
    if not self.liveTasks and (not self.liveDue or now>=self.liveDue) then self:BuildLiveTasks() end
    if not self.triggerTasks and not self.liveTasks then return end
    local previous=self.batchNative;self.batchNative=true
    local started=debugprofilestop and debugprofilestop()
    for _=1,3 do
        local triggered=self.triggerTasks~=nil
        if triggered and self.liveTasks and self.liveTasks[self.liveIndex] and (self.liveEventStreak or 0)>=2 then triggered=false end
        local task
        if triggered then task=self.triggerTasks[self.triggerIndex]
        else task=self.liveTasks and self.liveTasks[self.liveIndex] end
        if not task then
            if triggered then self:FinishTriggeredRefresh() else self.liveTasks=nil;self.liveDue=now+10 end
            break
        end
        if triggered then self.triggerIndex=self.triggerIndex+1;self.liveEventStreak=(self.liveEventStreak or 0)+1
        else self.liveIndex=self.liveIndex+1;self.liveEventStreak=0 end
        self.liveTriggerContext=triggered and self.triggerActive.context or nil
        local api=C_TooltipInfo or {}
        if task.kind=="membership" then
            if not inCombat then self:ValidationStep(task) end
        elseif task.kind=="party" then self:QueryPartyProgress(task.value)
        elseif task.kind=="unit" then
            local ok,exists=pcall(UnitExists,task.value)
            if ok and public(exists,"boolean") and exists then self:LiveQuery("unit:"..task.value,api.GetUnit,nil,task.value) end
        elseif task.kind=="guid" then self:LiveQuery("remembered-unit",api.GetHyperlink,nil,"unit:"..task.value)
        elseif task.kind=="item" then self:LiveQuery("remembered-item",api.GetItemByID,nil,task.value) end
        self.liveTriggerContext=nil
        if started and debugprofilestop()-started>=0.75 then break end
    end
    self.batchNative=previous
    if self.liveDirty then self.liveDirty=nil;self:Changed() end
end
function A:QuestStateReport()
    local lines,entries={},{}
    for _,m in pairs(self.members) do
        for id,q in pairs(m.quests) do entries[#entries+1]={m=m,q=q,id=id} end
    end
    table.sort(entries,function(a,b) if a.id==b.id then return a.m.name<b.m.name end;return a.id<b.id end)
    for i,e in ipairs(entries) do
        if i>160 then lines[#lines+1]="... remaining member quests omitted";break end
        local q=e.q
        local state=self.questQueryState[e.id]
        local progress={}
        for _,o in ipairs(q.objectives or {}) do
            progress[#progress+1]=o.text..(o.observedAt and (" [observed "..math.floor(GetTime()-o.observedAt).."s ago]") or "")
        end
        local items={}
        for _,item in ipairs((self.questItemSources or {})[e.id] or {}) do
            local a=self.itemQueryState[item]
            items[#items+1]=item..":"..(a and (a.status.." "..math.floor(GetTime()-a.at).."s ago") or "not queried")
        end
        lines[#lines+1]=e.id.." "..q.title.." player="..e.m.name.." ready="..tostring(q.ready)
            .." direct="..(state and (state.status.." "..math.floor(GetTime()-state.at).."s ago") or "not queried this session")
            .." rows="..(state and state.rows or 0).." source="..(q.lastNativeSource or (e.m.syncedAt and "addon sync" or "none"))
            .." progress="..(#progress>0 and table.concat(progress,"; ") or "unknown")
            .." items="..table.concat(items,",")
    end
    return table.concat(lines,"\n")
end
function A:DiagnosticReport()
    local build="unknown"
    if GetBuildInfo then
        local version,number,date,interface=GetBuildInfo()
        build=table.concat({printable(version),printable(number),printable(date),printable(interface)}," ")
    end
    local s=self.liveStats
    local sources={}
    for source,count in pairs(s.bySource) do sources[#sources+1]=source.."="..count end
    table.sort(sources)
    local memberCount=0
    for _ in pairs(self.members) do memberCount=memberCount+1 end
    local inInstance=IsInInstance and IsInInstance() or false
    local inCombat=InCombatLockdown and InCombatLockdown() or false
    local ownIDs={}
    for id in pairs(self.own) do ownIDs[#ownIDs+1]=id end
    table.sort(ownIDs)
    return table.concat({"Party Quests Forever 1.1.6-beta7", "Client: "..build,
        self:QuestLogChatCompatibilitySummary(),
        self:BattleNetQuestLogSummary(),
        self:QuestLogTransferReport(),
        "Polling: "..(self.demo and "demo" or (memberCount==0 and "no tracked party" or (inCombat and "active (combat; discovery/layout deferred)" or "active")))
            .."; members="..memberCount.."; instance="..tostring(inInstance).."; raid="..tostring(IsInRaid()),
        "Sweep: "..self:SweepSummary(),
        string.format("Live: %d calls; %d payloads; %d rows applied; %d empty/restricted; %d errors",s.queries,s.payloads,s.rows,s.empty,s.errors),
        string.format("Counters: %d first observations; %d changed; %d repeated; %d readiness changes",s.first,s.changes,s.repeated,s.readyChanges),
        "Count changes by source: "..table.concat(sources,"; "),
        string.format("Direct quest responses - shared: %d payloads / %d empty; not in your log: %d payloads / %d empty",
            s.scope.shared.data,s.scope.shared.empty,s.scope.foreign.data,s.scope.foreign.empty),
        "Your current quest IDs: "..table.concat(ownIDs,", "),
        "Current member quest state (available with diagnostics off):",self:QuestStateReport(),
        "Display mode: "..tostring(self.db.displayMode).."; integration="..(self.integration and self.integration.status or "unavailable")
            .."; sidebar side="..tostring(self.db.trackerSide or "left").."; width="..tostring(self.db.sidebarWidth or 420)
            .."; last error="..(self.integration and self.integration.lastError or "none"),
        "Diagnostics: "..(self.db.diag and "on" or "off"),
        self.ShareApiReport and self:ShareApiReport() or "",
        self.NativeTrackerReport and self:NativeTrackerReport() or "",
        self.TriggerReport and self:TriggerReport() or "",
        "Payloads below can include party names and quest IDs. Review before sharing.",
        "Recent changes (retained separately from repeated payloads):",
        table.concat(self.db.diagChanges or {},"\n"),
        "Recent payloads:",table.concat(self.db.diagLines or {},"\n")},"\n")
end
function A:ShowDiagnosticReport()
    if not self.reportWindow then
        local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        f:SetSize(620,430);f:SetPoint("CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:EnableMouse(true)
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});f:SetBackdropColor(0.035,0.045,0.065,1)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() f:Hide() end)
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");title:SetPoint("TOPLEFT",14,-12);title:SetText("Diagnostic report - click text, Ctrl+A, Ctrl+C")
        local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",14,-40);scroll:SetPoint("BOTTOMRIGHT",-32,14)
        local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetFontObject(ChatFontNormal);edit:SetWidth(560);edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed",function() f:Hide() end);scroll:SetScrollChild(edit)
        self.reportWindow,self.reportEdit=f,edit
    end
    self.reportEdit:SetText(self:DiagnosticReport());self.reportWindow:Show();self.reportEdit:SetFocus();self.reportEdit:HighlightText()
end
