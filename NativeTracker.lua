local _, A = ...
local public,readable=A.public,A.readable
A.nativeTracker={queued=0,requested=0,errors=0,history={}}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
end
local function object(value)
    if A.secret and A.secret(value) then return nil end
    if type(value)=="table" and readable(value) then return value end
    if type(value)=="userdata" then return value end
end
local function safe(value)
    if A.secret and A.secret(value) then return "<restricted>" end
    if type(value)=="string" then return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n"," "):sub(1,220) end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    return "-"
end
function A:QueueNativeTracker(reason,manual)
    if not self:NativeTrackerWritesAllowed() then return end
    if not self.db or self.demo or (not manual and not self.db.nativeTrackerRepair) then return end
    local s=self.nativeTracker
    if s.suspended then return end
    s.queued=s.queued+1
    -- Keep the first deadline; event bursts must not defer a refresh forever.
    s.due=s.due or (GetTime()+0.8)
    s.reason=manual and "manual" or (s.reason or reason)
end
local function counts(value)
    if not public(value,"string") then return end
    local done,total=value:match("(%d+)%s*/%s*(%d+)")
    if done and total then return tonumber(done),tonumber(total) end
end
function A:ReadNativeTrackerObjective(module,id,index)
    local api=C_QuestLog or {}
    local logIndex=call(api.GetLogIndexForQuestID,id)
    if not public(logIndex,"number") or logIndex<1 then return end
    local text=call(GetQuestLogLeaderBoard,index,logIndex,true)
    local done,total=counts(text)
    if not done or not total or total<1 then return end
    local block=object(call(module.GetExistingBlock,module,id))
    local line=block and object(call(block.GetExistingLine,block,index))
    local font=line and object(line.Text)
    local visible=font and call(font.GetText,font)
    local shownDone,shownTotal=counts(visible)
    return {id=id,index=index,done=done,total=total,shownDone=shownDone,shownTotal=shownTotal,
        text=text,visible=visible,block=block~=nil}
end
function A:NativeTrackerRefreshReady(module)
    local parent=object(module and module.parentContainer)
    if not parent then return false,"native module is not attached" end
    if call(module.CanUpdate,module)==false then return false,"native module is busy" end
    local collapsed=self.IsNativeTrackerCollapsed and self:IsNativeTrackerCollapsed(parent) or call(parent.IsCollapsed,parent)==true
    if call(module.IsCollapsed,module)==true or collapsed then
        return false,"native tracker is collapsed"
    end
    if call(parent.IsShown,parent)==false then return false,"native tracker is hidden" end
    return true
end
function A:RecordNativeTrackerRefresh(message)
    local s=self.nativeTracker
    s.history[#s.history+1]=string.format("%.1f %s",GetTime(),message)
    while #s.history>12 do table.remove(s.history,1) end
end
function A:VerifyNativeTrackerRefresh(module)
    local s=self.nativeTracker
    local check=s.verify
    if not check or GetTime()<check.at then return end
    local ready,why=self:NativeTrackerRefreshReady(module)
    if not ready then
        if GetTime()>=check.deadline then
            s.verify=nil;s.due=nil;s.suspended=true;self.db.nativeTrackerRepair=false
            s.result="redraw verification unavailable: "..why.."; automatic refresh paused"
            self:RecordNativeTrackerRefresh(s.result)
            print("Party Quests Forever: native redraw could not be verified; automatic refresh is now off. Use /spq report for refresh details.")
        else s.result="verification deferred: "..why;check.at=GetTime()+1 end
        return
    end
    local matched,stale,blank,unknown=0,0,0,0
    for _,before in ipairs(check.objectives) do
        local after=self:ReadNativeTrackerObjective(module,before.id,before.index)
        local watched=call((C_QuestLog or {}).GetQuestWatchType,before.id)
        if not after then unknown=unknown+1
        elseif after.shownDone and after.shownTotal then
            if after.done==after.shownDone and after.total==after.shownTotal then matched=matched+1
            else stale=stale+1 end
        elseif public(watched,"number") and watched>=0 then blank=blank+1
        else unknown=unknown+1 end
    end
    s.verify=nil
    s.result=string.format("verified counter text: %d match; %d stale; %d blank; %d unavailable",matched,stale,blank,unknown)
    self:RecordNativeTrackerRefresh(s.result)
    if blank>0 then
        s.suspended=true;s.due=nil;self.db.nativeTrackerRepair=false
        print("Party Quests Forever: Blizzard's quest rows became blank after a redraw. Automatic refresh is now off. Use /reload to restore the tracker; /spq report includes refresh details.")
    end
end
function A:NativeTrackerTick()
    local s=self.nativeTracker
    if not self:NativeTrackerWritesAllowed() then
        s.due=nil;s.reason=nil;s.verify=nil
        s.result="paused while Questie owns the tracker"
        return
    end
    if self.demo or (InCombatLockdown and InCombatLockdown()) then return end
    local tracker=object(QuestObjectiveTracker)
    if s.verify then
        self:VerifyNativeTrackerRefresh(tracker)
        return
    end
    if not s.due or GetTime()<s.due or s.suspended then return end
    if s.last and GetTime()-s.last<2 then return end
    if not tracker or type(tracker.MarkDirty)~="function" then
        s.due=nil
        s.result="native quest tracker unavailable";s.reason=nil;return
    end
    local ready,why=self:NativeTrackerRefreshReady(tracker)
    if not ready then s.result="redraw deferred: "..why;s.due=GetTime()+1;return end
    local mismatches={}
    for id in pairs(self.own) do
        local index=call((C_QuestLog or {}).GetLogIndexForQuestID,id)
        local total=public(index,"number") and call(GetNumQuestLeaderBoards,index) or nil
        if public(total,"number") then
            for i=1,math.min(total,30) do
                local row=self:ReadNativeTrackerObjective(tracker,id,i)
                if row and row.shownDone and row.shownTotal and (row.done~=row.shownDone or row.total~=row.shownTotal) then
                    mismatches[#mismatches+1]=row
                end
            end
        end
    end
    s.due=nil
    if #mismatches==0 then s.result="no confirmed numeric mismatch; no redraw";s.reason=nil;return end
    table.sort(mismatches,function(a,b) if a.id==b.id then return a.index<b.index end;return a.id<b.id end)
    local signature={}
    for _,r in ipairs(mismatches) do signature[#signature+1]=table.concat({r.id,r.index,r.done,r.total,r.shownDone,r.shownTotal},":") end
    signature=table.concat(signature,";")
    if s.lastMismatch==signature then s.result="same stale counters; duplicate redraw skipped";s.reason=nil;return end
    s.lastMismatch=signature;s.last=GetTime()
    self:RecordNativeTrackerRefresh("confirmed mismatch "..signature)
    -- One normal native dirty request per distinct mismatch. No direct edits
    -- to counters, block state, module contents, visibility or watched quests.
    s.refreshInFlight=true
    local ok,err=self:CallNativeTrackerMethod(tracker,"MarkDirty")
    s.refreshInFlight=nil
    if ok and not s.suspended then
        s.requested=s.requested+1;s.result="redraw requested; awaiting counter verification"
        s.verify={at=GetTime()+1.5,deadline=GetTime()+8,objectives=mismatches}
    elseif not ok then
        s.errors=s.errors+1;s.result="redraw failed: "..safe(err)
        s.suspended=true
        self.db.nativeTrackerRepair=false -- no repeated errors in a broken UI
    end
    s.history[#s.history+1]=string.format("%.1f %s: %s",GetTime(),s.reason or "progress",s.result)
    while #s.history>12 do table.remove(s.history,1) end
    s.reason=nil
end
function A:NativeTrackerReport()
    local s=self.nativeTracker
    local module=object(QuestObjectiveTracker)
    local rows={"Guarded native refresh: suspended="..tostring(not not s.suspended),
        "Native tracker repair: "..(self.db.nativeTrackerRepair and "on" or "off")
        .."; requests="..s.requested.."; errors="..s.errors.."; pending="..tostring(s.due~=nil),
        "Last redraw: "..(s.result or "none"),
        "Native module: dirty="..safe(module and module.isDirty).."; state="..safe(module and module.state)}
    if InCombatLockdown and InCombatLockdown() then
        rows[#rows+1]="Native comparison deferred during combat";return table.concat(rows,"\n")
    end
    local api=C_QuestLog or {}
    local ids={}
    for id in pairs(self.own) do ids[#ids+1]=id end
    table.sort(ids)
    for n,id in ipairs(ids) do
        if n>40 then rows[#rows+1]="... remaining quests omitted";break end
        local index=call(api.GetLogIndexForQuestID,id)
        local complete=call(api.IsComplete,id)
        local objectives=call(api.GetQuestObjectives,id)
        local block=module and object(call(module.GetExistingBlock,module,id))
        local count=public(index,"number") and call(GetNumQuestLeaderBoards,index) or nil
        if not public(count,"number") then count=readable(objectives) and #objectives or 0 end
        rows[#rows+1]="LOCAL quest="..id.." ready="..safe(complete).." block="..tostring(block~=nil)
        for i=1,math.min(count,12) do
            local text,kind,finished
            if public(index,"number") then text,kind,finished=call(GetQuestLogLeaderBoard,i,index,true) end
            local entry=readable(objectives) and objectives[i]
            local o=readable(entry) and entry or {}
            local line=block and object(call(block.GetExistingLine,block,i))
            local font=line and object(line.Text)
            local visible=font and call(font.GetText,font)
            local x,y=safe(text):match("(%d+)%s*/%s*(%d+)")
            local vx,vy=safe(visible):match("(%d+)%s*/%s*(%d+)")
            local mismatch=x and vx and (tonumber(x)~=tonumber(vx) or tonumber(y)~=tonumber(vy))
            rows[#rows+1]=" step="..i.." log="..safe(text).." finished="..safe(finished)
                .." API="..safe(o.text).." counts="..safe(o.numFulfilled).."/"..safe(o.numRequired)
                .." visible="..safe(visible).." anim="..safe(line and line.state)..(mismatch and " COUNT MISMATCH" or "")
        end
    end
    rows[#rows+1]="Native redraw history:";rows[#rows+1]=table.concat(s.history,"\n")
    rows[#rows+1]="Recent addon block notifications (reported addon/action; not proof of causation):"
    for _,entry in ipairs(s.blocks or {}) do rows[#rows+1]=entry end
    return table.concat(rows,"\n")
end
local frame=CreateFrame("Frame")
A.nativeTrackerEvents=frame
frame:SetScript("OnEvent",function(_,event,addon,action)
    local s=A.nativeTracker
    s.blocks=s.blocks or {}
    s.blocks[#s.blocks+1]=string.format("%.1f %s addon=%s action=%s",GetTime(),event,safe(addon),safe(action))
    while #s.blocks>12 do table.remove(s.blocks,1) end
    if public(addon,"string") and addon=="SimplyPartyQuests" then
        -- Settings access says nothing about the health of a quest redraw.
        if public(action,"string") and (action:find("Settings",1,true) or action:find("InterfaceOptions",1,true)) then return end
        if A.integration and A.integration.attached then
            A.integration.lastError="addon block notification; docked restore queued"
            A.integration.blockedRestore=true
            A:InvalidateTrackerIntegration()
        end
        -- Pause repair only when a redraw is executing or being verified.
        -- Preserve saved opt-outs and do not disable repair for unrelated UI work.
        if s.refreshInFlight or s.verify then
            if A.db then A.db.nativeTrackerRepair=false end
            s.due=nil;s.verify=nil;s.suspended=true
            s.result="redraw paused after a blocked action during repair"
        end
    end
end)
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do pcall(frame.RegisterEvent,frame,event) end
