local _,A=...
-- Rewards are for the viewer. Never import another player's level-dependent XP
-- or change the selected quest just to populate a title row.
function A:QuestRewardXPText(id,ready)
    if not ready or not self.validInteger(id,1,10000000) or type(GetQuestLogRewardXP)~="function" then return nil end
    self.rewardXPCache=self.rewardXPCache or {}
    local now=GetTime()
    local cached=self.rewardXPCache[id]
    if cached and now-cached.at<30 then return cached.text end
    local ok,xp=pcall(GetQuestLogRewardXP,id)
    local result
    if ok and self.validInteger(xp,1,1000000000) then
        local value=tostring(xp)
        if type(BreakUpLargeNumbers)=="function" then
            local good,formatted=pcall(BreakUpLargeNumbers,xp)
            if good and self.public(formatted,"string") then value=formatted end
        else
            value=value:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
        end
        result=value.." XP"
    end
    self.rewardXPCache[id]={at=now,text=result}
    return result
end
function A:LayoutQuestRewardXP(row,label,reward,width,parchment)
    if reward then
        if not row.rewardXP then row.rewardXP=row:CreateFontString(nil,"OVERLAY") end
        local xp=row.rewardXP
        local face,size,flags=label:GetFont()
        xp:SetFont(face,size,flags)
        xp:SetTextColor(0.72,0.86,1)
        if parchment and self:QuestPaperBrightness()>=80 then xp:SetTextColor(0.12,0.23,0.34) end
        xp:SetJustifyH("RIGHT");xp:SetWordWrap(false)
        xp:ClearAllPoints();xp:SetPoint("TOPRIGHT",row,"TOPRIGHT",-4,-(parchment and 3 or 0))
        xp:SetText(reward);xp:Show()
        local measured=xp:GetStringWidth()
        local reserve=(self.public(measured,"number") and measured or #reward*(size or 12)*0.6)+12
        xp:SetWidth(reserve-8)
        label:SetWidth(math.max(40,width-reserve))
    else
        if row.rewardXP then row.rewardXP:Hide() end
        label:SetWidth(width)
    end
end
