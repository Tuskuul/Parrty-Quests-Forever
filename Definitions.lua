local _, A = ...
function A:ObjectiveKey(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("%d+%s*/%s*%d+", ""):gsub("[%s%p]", ""):lower()
end
-- Requirement definitions are separate from a player's observed objective state.
-- Counts returned by our own quest-log API must NEVER become somebody else's counts.
function A:IsGenericObjective(text)
    if not self.public(text,"string") then return true end
    local plain=text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain=plain:gsub("[%s%p%d]", ""):lower()
    for _,label in ipairs({"Objective","Objectives","Quest objective","Quest objectives",OBJECTIVE or "",QUEST_OBJECTIVES or ""}) do
        local key=label:gsub("[%s%p%d]", ""):lower()
        if key~="" and plain==key then return true end
    end
    return plain==""
end
function A:RequirementText(text, total)
    if self:IsGenericObjective(text) then return nil end
    text=text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text=text:gsub("%d+%s*/%s*(%d+)", "%1 required")
    text=text:gsub("%$[Bb]", "\n"):gsub("%$[Nn]", "your character")
    if self.public(total,"number") and total>0 and not text:find("%d") then
        text=text.." ("..total.." required)"
    end
    if text:match("^%s*$") then return nil end
    return text
end
function A:PopulateRequirements(q, force)
    local now=GetTime()
    if not force and q.requirementsChecked and now-q.requirementsChecked<30 then return end
    q.requirementsChecked=now
    local requirements,seen,hasGeneric={},{},false
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok,list=pcall(C_QuestLog.GetQuestObjectives,q.id)
        if ok and self.readable(list) then
            for _,o in ipairs(list) do
                if self.readable(o) then
                    if self:IsGenericObjective(o.text) then hasGeneric=true end
                    local text=self:RequirementText(o.text,o.numRequired)
                    if text and not seen[text] then
                        seen[text]=true;requirements[#requirements+1]={text=text}
                    end
                end
            end
        end
    end
    if #requirements>0 and not hasGeneric then
        q.requirements,q.requirementSource=requirements,"client"
    elseif self.questRequirements and self.questRequirements[q.id] then
        for _,text in ipairs(self.questRequirements[q.id]) do
            text=self:RequirementText(text)
            if text and not seen[text] then requirements[#requirements+1]={text=text};seen[text]=true end
        end
        q.requirements,q.requirementSource=requirements,"database"
    elseif #requirements>0 then q.requirements,q.requirementSource=requirements,"client"
    elseif not q.requirements then q.requirements={} end
    -- A request can supply titles/requirements asynchronously even when the title
    -- was already cached. This is requested only for a discovered quest, not all IDs.
    if (#requirements==0 or q.requirementSource~="client" or q.awaitingTitle)
        and C_QuestLog and C_QuestLog.RequestLoadQuestByID
        and (not q.dataRequestAt or now-q.dataRequestAt>=30) then
        q.dataRequestAt=now;pcall(C_QuestLog.RequestLoadQuestByID,q.id)
    end
end
