local _, A = ...
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,result=pcall(fn,...)
    if ok and not (A.secret and A.secret(result)) then return result end
end
local function hasBit(mask,id)
    return math.floor(mask/2^(id-1))%2==1
end
function A:QuestCompletionReader()
    local lookup
    local values=call(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
    if self.readable(values) then
        lookup={}
        for _,id in pairs(values) do if self.public(id,"number") then lookup[id]=true end end
    end
    return function(id)
        if self.shareCompleted and self.shareCompleted[id] then return true end
        if lookup then return lookup[id] or false end
        local value=call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,id)
        if not self.public(value,"boolean") then value=call(IsQuestFlaggedCompleted,id) end
        if self.public(value,"boolean") then return value end
        return nil
    end
end
function A:CheckShareEligibility(id)
    if self.own[id] then return false,"Already in your quest log." end
    local completed=self:QuestCompletionReader()
    local done=completed(id)
    local d=self.questEligibility and self.questEligibility[id]
    if done==true then
        if d and d.special and hasBit(d.special,1) then return nil,"Repeatable quest completed before; current availability needs verification." end
        return false,"Already completed by this character."
    end
    if done==nil then return nil,"Completion history is unavailable." end
    if not d or d.uncertain then return nil,"Acceptance requirements need verification for this quest." end
    if not d.flags or not hasBit(d.flags,4) then return false,"Not marked shareable in the quest database." end
    if d.special and hasBit(d.special,1) then return nil,"Repeatable quest availability needs verification." end
    local level=call(UnitLevel,"player")
    if not self.public(level,"number") or not self.public(d.level,"number") then return nil,"Required level is unavailable." end
    if level<d.level then return false,"Requires level "..d.level.."." end
    if d.maxLevel and d.maxLevel>0 and level>d.maxLevel then return false,"Above the quest's maximum level." end
    local function identity(mask,fn,kind)
        if not mask or mask==0 then return true end
        if type(fn)~="function" then return nil,kind.." is unavailable." end
        local ok,_,_,value=pcall(fn,"player")
        if not ok or not A.public(value,"number") or value<1 or value>53 then return nil,kind.." is unavailable." end
        if not hasBit(mask,value) then return false,kind.." restriction." end
        return true
    end
    local ok,reason=identity(d.races,UnitRace,"Race");if ok~=true then return ok,reason end
    ok,reason=identity(d.classes,UnitClass,"Class");if ok~=true then return ok,reason end
    local function prerequisite(list,any)
        if not list or #list==0 then return true end
        local unknown=false
        for _,qid in ipairs(list) do
            if not A.public(qid,"number") or qid<=0 then return nil,"Special prerequisite needs verification." end
            local result=completed(qid)
            if any and result==true then return true end
            if not any and result==false then return false,"Missing prerequisite quest #"..qid.."." end
            if result==nil then unknown=true end
        end
        if unknown then return nil,"Prerequisite completion is unavailable." end
        if any then return false,"Missing a prerequisite quest." end
        return true
    end
    ok,reason=prerequisite(d.all,false);if ok~=true then return ok,reason end
    ok,reason=prerequisite(d.any,true);if ok~=true then return ok,reason end
    local function blocked(qid,activeOnly)
        if not qid or qid==0 then return false end
        if qid<0 then return nil end
        if A.own[qid] then return true end
        if activeOnly then return false end
        return completed(qid)
    end
    for _,qid in ipairs(d.exclusive or {}) do
        local result=blocked(qid)
        if result==nil then return nil,"Alternative quest history is unavailable." end
        if result then return false,"An alternative quest blocks this quest." end
    end
    for _,qid in ipairs({d.next or 0,d.breadcrumb or 0}) do
        local result=blocked(qid)
        if result==nil then return nil,"Quest-chain state is unavailable." end
        if result then return false,"A later quest in this chain is already active or completed." end
    end
    if d.parent and d.parent>0 and not self.own[d.parent] then return false,"Requires active parent quest #"..d.parent.."." end
    if d.starting and d.starting>0 then
        local result=blocked(d.starting)
        if result==nil then return nil,"Starting quest history is unavailable." end
        if not result then return false,"Missing starting quest #"..d.starting.."." end
    end
    if d.untilDone and d.untilDone>0 then
        local result=completed(d.untilDone)
        if result==nil then return nil,"Quest-chain history is unavailable." end
        if result then return false,"This quest's availability has ended." end
    end
    if d.disabled and self.own[d.disabled] then return false,"Another active quest blocks this quest." end
    if d.spell and d.spell>0 then
        local known=call(IsSpellKnown,d.spell)
        if not self.public(known,"boolean") then return nil,"Required spell needs verification." end
        if not known then return false,"Missing required spell." end
    end
    -- Do not interpret objective item possession as acceptance eligibility.
    if d.skill or d.spec or d.ranks then return nil,"Profession requirements need verification." end
    if d.minRep or d.maxRep then return nil,"Reputation requirements need verification." end
    if d.items or d.group or d.breadcrumbs then return nil,"Additional acceptance rules need verification." end
    return true,"Known acceptance checks passed."
end
function A:RequestQuestShare(id,guid)
    local function feedback(message)
        self.shareFeedback=self.shareFeedback or {};self.shareFeedback[id]=message
        print("Party Quests: "..message)
    end
    if self.demo then feedback("Share requests are disabled in sample preview.");return end
    if self.db.requestShares==false then feedback("Double-click share requests are disabled in settings.");return end
    local m=self.members[guid]
    if not m or not m.quests[id] or m.connected==false then feedback("The quest owner is no longer available in your party.");return end
    if not m.unit or call(UnitGUID,m.unit)~=guid then feedback("The party member could not be verified.");return end
    local readable,ok,reason=pcall(self.CheckShareEligibility,self,id)
    if not readable then feedback("Quest eligibility is unavailable right now; try again after combat.");return end
    if ok~=true then feedback(reason);return end
    local now=GetTime()
    self.shareRequests=self.shareRequests or {}
    if (self.shareRequests[id] and now-self.shareRequests[id]<60) or (self.shareLastSent and now-self.shareLastSent<5) then
        feedback("A share was requested recently; please wait.");return
    end
    local target=call(GetUnitName,m.unit,true)
    if not self.public(target,"string") or target=="" then feedback("The party member's whisper name is unavailable.");return end
    local send=SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
    if type(send)~="function" then feedback("Whisper sending is unavailable.");return end
    local title=m.quests[id].title
    if not self.public(title,"string") then feedback("Quest title is unavailable.");return end
    title=title:gsub("[\r\n|]",""):sub(1,120)
    local message=string.format("Could you share |cffffff00|Hquest:%d:-1|h[%s]|h|r with me, please?",id,title)
    local success,result=pcall(send,message,"WHISPER",nil,target)
    if not success or result==false then feedback("The client could not send the share request.");return end
    self.shareRequests[id]=now;self.shareLastSent=now
    feedback("Requested a share of ["..title.."] from "..m.name..".")
end
function A:BindQuestShareClick(button,id,guid)
    button:SetScript("OnDoubleClick",function(_,key)
        if key=="LeftButton" then A:RequestQuestShare(id,guid) end
    end)
end
local events=CreateFrame("Frame")
A.shareEvents=events
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent",function(_,_,id)
    if A.public(id,"number") then A.shareCompleted=A.shareCompleted or {};A.shareCompleted[id]=true end
end)
