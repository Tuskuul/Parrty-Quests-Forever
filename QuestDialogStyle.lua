local _,A=...
-- One shared parchment treatment for addon-owned share dialogs. Never reskin the
-- real QuestFrame or inherit its quest acceptance scripts/protected controls.
local colors={
    body={0.20,0.13,0.07},heading={0.25,0.14,0.04},muted={0.36,0.29,0.21},
    ready={0.10,0.36,0.13},error={0.57,0.09,0.05},title={1,0.82,0},
}
function A:StyleQuestDialogText(text,role,heading)
    local color=colors[role] or colors.body
    local font=(heading or role=="heading") and (QuestFont or GameFontNormal)
        or (role=="title" and GameFontNormal or (QuestFontNormalSmall or GameFontHighlightSmall))
    if font then text:SetFontObject(font) end
    text:SetTextColor(color[1],color[2],color[3],1)
end
function A:StyleQuestDialog(frame)
    if frame.questPaper then return end
    frame:SetClampedToScreen(true)
    -- Both template variants use decorative dark insets. No dialog content
    -- lives inside them; hide the fill while retaining the native border art.
    for _,key in ipairs({"Inset","InsetBg"}) do
        local inset=frame[key]
        if self.readable(inset) and type(inset.Hide)=="function" then inset:Hide() end
    end
    local base=frame:CreateTexture(nil,"BACKGROUND",nil,0)
    base:SetPoint("TOPLEFT",7,-27);base:SetPoint("BOTTOMRIGHT",-7,7)
    base:SetColorTexture(0.86,0.73,0.48,1)
    local paper=frame:CreateTexture(nil,"BACKGROUND",nil,1)
    paper:SetAllPoints(base)
    local getAtlas=(C_Texture and C_Texture.GetAtlasInfo) or GetAtlasInfo
    local ok,info=false,nil
    if type(getAtlas)=="function" then ok,info=pcall(getAtlas,"QuestBG-Parchment") end
    if ok and self.readable(info) then paper:SetAtlas("QuestBG-Parchment",false)
    else
        -- The classic greeting frame's text area is parchment too. Crop away
        -- its portrait/title/border when the modern parchment atlas is absent.
        paper:SetTexture("Interface\\QuestFrame\\UI-QuestGreeting-TopLeft")
        paper:SetTexCoord(0.09,0.92,0.30,0.94)
    end
    frame.questPaper=paper
    if self.readable(frame.TitleText) then self:StyleQuestDialogText(frame.TitleText,"title") end
end
function A:StyleQuestShareTabs(frame)
    for _,item in ipairs({{frame.full,"full"},{frame.choose,"selected"},{frame.offers,"offer"}}) do
        local button,scope=item[1],item[2]
        if not button.questSelection then
            local t=button:CreateTexture(nil,"OVERLAY")
            t:SetAllPoints(button);t:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
            t:SetTexCoord(0,0.625,0,0.6875);t:SetBlendMode("ADD");t:SetVertexColor(1,0.72,0.12,0.7)
            button.questSelection=t
        end
        button.questSelection:SetShown(frame.scope==scope)
    end
end
