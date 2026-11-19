local _, A = ...
local function value(v)
    if A.secret and A.secret(v) then return "restricted" end
    if type(v)=="boolean" or type(v)=="number" then return tostring(v) end
    if type(v)=="string" then return v:gsub("[\r\n]"," "):sub(1,180) end
    if v==nil then return "nil" end
    return "["..type(v).."]"
end
local function query(fn,id)
    if type(fn)~="function" then return "unavailable" end
    local ok,result=pcall(fn,id)
    if not ok then return "error: "..value(result) end
    return value(result)
end
function A:SampleShareAPIs(label)
    local p=self.shareApiProbe
    if not p then return end
    p.samples[#p.samples+1]=label.." at "..string.format("%.1f",GetTime()-p.started).."s"
    local api=C_QuestLog or {}
    for _,item in ipairs(p.ids) do
        p.samples[#p.samples+1]=string.format("#%d %s | pushable=%s; logIndex=%s; completed=%s; repeatable=%s; disabled=%s; difficulty=%s",
            item.id,item.scope,query(api.IsPushableQuest,item.id),query(api.GetLogIndexForQuestID,item.id),
            query(api.IsQuestFlaggedCompleted,item.id),query(api.IsRepeatableQuest,item.id),
            query(api.IsQuestDisabledForSession,item.id),query(api.GetQuestDifficultyLevel,item.id))
    end
end
function A:StartShareApiProbe()
    if InCombatLockdown and InCombatLockdown() then
        print("Party Quests: run the share API inspector out of combat.");return
    end
    local ids,seen={},{}
    local function add(id,scope)
        if not A.public(id,"number") or id<=0 or seen[id] then return end
        seen[id]=true;ids[#ids+1]={id=id,scope=scope}
    end
    if self.shareProbeSelected then add(self.shareProbeSelected,self.own[self.shareProbeSelected] and "selected / own" or "selected / foreign") end
    local own,foreign={},{}
    for id in pairs(self.own) do own[#own+1]=id end
    for _,m in pairs(self.members) do for id in pairs(m.quests) do if not self.own[id] then foreign[id]=true end end end
    local other={};for id in pairs(foreign) do other[#other+1]=id end
    table.sort(own);table.sort(other)
    for i=1,math.min(4,#own) do add(own[i],"own") end
    for i=1,math.min(4,#other) do add(other[i],"foreign") end
    self.shareApiProbe={started=GetTime(),due=GetTime()+2,untilTime=GetTime()+90,ids=ids,samples={},events={},loaded={}}
    self:SampleShareAPIs("Before requesting quest data")
    for _,item in ipairs(ids) do
        local fn=C_QuestLog and C_QuestLog.RequestLoadQuestByID
        if type(fn)=="function" then pcall(fn,item.id) end
    end
    self.shareApiProbeFrame:SetScript("OnUpdate",function()
        local p=A.shareApiProbe
        if not p then A.shareApiProbeFrame:SetScript("OnUpdate",nil);return end
        if p.due and GetTime()>=p.due then
            p.due=nil;A:SampleShareAPIs("After 2 seconds (data availability still depends on client)")
        end
        if GetTime()>=p.untilTime then A.shareApiProbeFrame:SetScript("OnUpdate",nil) end
    end)
    self:ShowDiagnosticReport()
end
function A:ShareApiReport()
    local p=self.shareApiProbe
    if not p then return "Share API inspector: not run. Use /spq inspect to inspect share APIs." end
    local lines={"Share API inspector (read-only; never whispers or shares):",
        "Selected quest plus up to 4 own and 4 foreign IDs. False outside the log is not treated as proof of unshareability.",
        "Capture: "..(GetTime()<p.untilTime and "active; reopen the report after testing" or "finished")}
    for _,line in ipairs(p.samples) do lines[#lines+1]=line end
    lines[#lines+1]="Native quest / error / system events (90-second capture; may include names):"
    for _,line in ipairs(p.events) do lines[#lines+1]=line end
    return table.concat(lines,"\n")
end
local f=CreateFrame("Frame")
A.shareApiProbeFrame=f
for _,event in ipairs({"QUEST_DATA_LOAD_RESULT","QUEST_DETAIL","QUEST_ACCEPT_CONFIRM","QUEST_ACCEPTED","UI_ERROR_MESSAGE","UI_INFO_MESSAGE","CHAT_MSG_SYSTEM"}) do
    pcall(f.RegisterEvent,f,event)
end
f:SetScript("OnEvent",function(_,event,...)
    local p=A.shareApiProbe
    if not p or GetTime()>p.untilTime then return end
    if event=="QUEST_DATA_LOAD_RESULT" then
        local id,success=...
        if A.public(id,"number") and A.public(success,"boolean") and success and not p.loaded[id] then
            for _,item in ipairs(p.ids) do
                if item.id==id then
                    p.loaded[id]=true;A:SampleShareAPIs("After QUEST_DATA_LOAD_RESULT #"..id);break
                end
            end
        end
    end
    local fields={string.format("%.1fs %s",GetTime()-p.started,event)}
    for i=1,math.min(3,select("#",...)) do fields[#fields+1]=value(select(i,...)) end
    if event=="UI_ERROR_MESSAGE" or event=="UI_INFO_MESSAGE" then
        local id=...
        if A.public(id,"number") and type(GetGameMessageInfo)=="function" then
            local ok,name=pcall(GetGameMessageInfo,id)
            if ok then fields[#fields+1]="nativeName="..value(name) end
        end
    end
    if #p.events>=80 then table.remove(p.events,1) end
    p.events[#p.events+1]=table.concat(fields," | ")
end)
