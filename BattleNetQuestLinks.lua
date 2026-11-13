local _,A=...
local PREFIX="SPQLOG1"
local function validID(id) return A.public(id,"number") and id>0 and id%1==0 and id<100000000000 end
local function escaped(text) return (text:gsub("|","||")) end
function A:SendQuestLogPacket(message,target)
    local id=target:match("^BN:(%d+)$")
    local send,args
    if id then
        send=C_BattleNet and C_BattleNet.SendGameData or BNSendGameData
        args={tonumber(id),PREFIX,message}
    else
        send=C_ChatInfo and C_ChatInfo.SendAddonMessage
        args={PREFIX,message,"WHISPER",target}
    end
    local route=id and "Battle.net" or "character"
    local kind=message:sub(1,1)
    self:QuestLinkTrace("send-attempt",route.." target="..target.." kind="..kind.." bytes="..#message)
    if type(send)~="function" then self.questLogTransportError="Addon data transport unavailable";self:QuestLinkTrace("send-unavailable",route);return false end
    local ok,result=pcall(send,unpack(args))
    local returned=(result==nil and "nil") or (self.public(result,"number") and tostring(result)) or (self.public(result,"boolean") and tostring(result)) or "nonpublic result"
    self:QuestLinkTrace(ok and "send-return" or "send-exception",route.." result="..returned)
    if not ok or (result~=nil and result~=true and result~=0) then
        self.questLogTransportError="Addon data send failed or was restricted ("..returned..")";return false
    end
    return true
end
function A:BattleNetQuestLogPeer(accountID)
    if not validID(accountID) or not C_BattleNet or type(C_BattleNet.GetAccountInfoByID)~="function" then return nil end
    local ok,account=pcall(C_BattleNet.GetAccountInfoByID,accountID)
    if not ok or not self.readable(account) or not self.readable(account.gameAccountInfo) then return nil end
    local game=account.gameAccountInfo
    if not self.public(game.clientProgram,"string") or game.clientProgram~=(BNET_CLIENT_WOW or "WoW") or not self.public(game.isOnline,"boolean") or not game.isOnline or not validID(game.gameAccountID) then return nil end
    -- The recipient must be playing the same client flavor, even across realms.
    if self.public(WOW_PROJECT_ID,"number") and self.public(game.wowProjectID,"number") and game.wowProjectID~=WOW_PROJECT_ID then return nil end
    local label=self.public(game.characterName,"string") and game.characterName~="" and game.characterName or "Battle.net player"
    return "BN:"..game.gameAccountID,label
end
function A:ObserveBattleNetQuestLogLink(message,event,accountID)
    if not self.public(message,"string") or not validID(accountID) then return message end
    self:PruneQuestLinks();local state=self:QuestLinkState()
    return (message:gsub("%[Party Quests Log:([%x%-]+)%]",function(token)
        if #token>48 or not token:match("^[%x]+%-%x+%-%x+$") then return nil end
        local mine=state.published[token]
        local owner,label,unavailable
        if mine then
            if event~="CHAT_MSG_BN_WHISPER_INFORM" then return nil end
            mine.published=true;owner=mine.owner;label=mine.owner
        else
            -- An outgoing repost is not proof that the other person owns it.
            if event~="CHAT_MSG_BN_WHISPER" then return nil end
            owner,label=self:BattleNetQuestLogPeer(accountID)
            if not owner then
                owner="BNACCOUNT:"..accountID;label="Battle.net player"
                unavailable="This friend has no available WoW session for quest-log data. They must be online in the same WoW client version with this addon."
            elseif not ((C_BattleNet and type(C_BattleNet.SendGameData)=="function") or type(BNSendGameData)=="function") then
                unavailable="Battle.net addon data is unavailable in this client. Ask the player for an in-character quest-log link."
            end
        end
        local previous=state.observed[token]
        if previous and previous.owner:lower()~=owner:lower() then return nil end
        if not previous then self:QuestLinkTrace("bnet-link",event.." account="..accountID.." route="..owner.." token="..token) end
        state.observed[token]={owner=owner,displayOwner=label,accountID=accountID,unavailable=unavailable,localTime=GetTime()}
        return "|cffffff00|Haddon:SPQLOG:"..token.."|h["..escaped(label).."'s Quest Log]|h|r"
    end))
end
function A:InstallBattleNetQuestLogLinks()
    if self.battleNetQuestLinksInitialized then return end
    local addFilter=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(addFilter)~="function" then return end
    for _,event in ipairs({"CHAT_MSG_BN_WHISPER","CHAT_MSG_BN_WHISPER_INFORM"}) do
        addFilter(event,function(_,kind,message,sender,...)
            -- Native CHAT_MSG_BN_WHISPER argument 13 is the BNet account ID,
            -- distinct from the game-account ID used by SendGameData.
            local changed=A:ObserveBattleNetQuestLogLink(message,kind,select(11,...))
            if changed~=message then return false,changed,sender,... end
        end)
    end
    local f=CreateFrame("Frame")
    local ok,registered=pcall(f.RegisterEvent,f,"BN_CHAT_MSG_ADDON")
    self.battleNetQuestLinkEvent=ok and registered~=false
    f:SetScript("OnEvent",function(_,_,prefix,message,channel,senderID)
        if prefix~=PREFIX then return end
        local sender=validID(senderID) and tostring(senderID) or ("invalid-"..type(senderID))
        local rawChannel=A.public(channel,"string") and channel or ("nonpublic-"..type(channel))
        local kind=A.public(message,"string") and message:sub(1,1) or "nonpublic"
        A:QuestLinkTrace("bnet-event","sender="..sender.." channel="..rawChannel.." kind="..kind)
        if validID(senderID) then
            -- This dedicated BNet event is private data even if a client labels
            -- its channel differently from the documented WHISPER value.
            A:ReceiveQuestLogLink(message,"BN:"..senderID,"WHISPER")
        else A:QuestLinkTrace("reject-event","Battle.net sender ID is not a public positive integer") end
    end)
    self.battleNetQuestLinkFrame=f;self.battleNetQuestLinksInitialized=true
end

function A:BattleNetQuestLogSummary()
    local available=(C_BattleNet and type(C_BattleNet.SendGameData)=="function") or type(BNSendGameData)=="function"
    return "Battle.net quest logs: send="..tostring(not not available).."; receive="..tostring(self.battleNetQuestLinkEvent==true).."; last error="..(self.questLogTransportError or "none")
end
