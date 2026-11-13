local _, A = ...
local public,readable=A.public,A.readable
A.nativeTracker={queued=0,requested=0,errors=0,history={}}
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
end
local function object(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=="table" and readable(value) then return value end
    if type(value)=="userdata" then return value end
end
local function safe(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    if type(value)=="string" then return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n"," "):sub(1,220) end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    return "-"
end
function A:QueueNativeTracker(reason,manual)
    if not self.db or self.demo or (not manual and not self.db.nativeTrackerRepair) then return end
    local s=self.nativeTracker
    s.queued=s.queued+1
    -- Keep the first deadline; event bursts must not defer a refresh forever.
    s.due=s.due or (GetTime()+0.8)
    s.reason=manual and "manual" or (s.reason or reason)
end
function A:NativeTrackerTick()
    local s=self.nativeTracker
    if self.demo or not s.due or GetTime()<s.due or (InCombatLockdown and InCombatLockdown()) then return end
    if s.last and GetTime()-s.last<2 then return end
    s.due=nil;s.last=GetTime()
    local tracker=object(QuestObjectiveTracker)
    if not tracker or type(tracker.MarkDirty)~="function" then
        s.result="native quest tracker unavailable";s.reason=nil;return
    end
    -- Ask the native quest module to schedule its normal redraw. Never edit
    -- its blocks/counters or untrack quests to force a reconstruction.
    local ok,err=pcall(tracker.MarkDirty,tracker)
    if ok then s.requested=s.requested+1;s.result="redraw requested (not display verification)"
    else
        s.errors=s.errors+1;s.result="redraw failed: "..safe(err)
        self.db.nativeTrackerRepair=false -- no repeated errors in a broken UI
    end
    s.history[#s.history+1]=string.format("%.1f %s: %s",GetTime(),s.reason or "progress",s.result)
    while #s.history>12 do table.remove(s.history,1) end
    s.reason=nil
end
function A:NativeTrackerReport()
    local s=self.nativeTracker
    local module=object(QuestObjectiveTracker)
    local rows={"Native tracker repair: "..(self.db.nativeTrackerRepair and "on" or "off")
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
        if A.db then
            A.db.nativeTrackerRepair=false
            if A.integration and A.integration.attached then
                A.db.displayMode="window";A.db.hidden=false
                A.integration.lastError="addon block notification; integration disabled"
                A:InvalidateTrackerIntegration()
            end
        end;s.due=nil
    end
end)
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do pcall(frame.RegisterEvent,frame,event) end
