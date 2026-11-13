local _,A=...
-- WIM owns its edit boxes and their recipient routing. Never pass these to
-- Blizzard's ActivateChat or reset their attributes as native chat controls.
function A:QuestLogChatBoxKind(box)
    if not self.readable(box) then return nil end
    local wim=WIM
    local window=box.parentWindow
    if self.readable(wim) and ((self.readable(window) and self.readable(window.widgets) and window.widgets.msg_box==box) or wim.EditBoxInFocus==box) then return "WIM" end
    if box==CHAT_FOCUS_OVERRIDE then return "override" end
end
function A:FocusedQuestLogCustomChatBox()
    local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus then
        if self:QuestLogChatBoxKind(focus) then return focus end
        return nil -- Never use an old WIM reference while another control owns focus.
    end
    if self.readable(WIM) and self.readable(WIM.EditBoxInFocus) then
        local box=WIM.EditBoxInFocus
        if type(box.HasFocus)~="function" or box:HasFocus() then return box end
    end
    if self.readable(CHAT_FOCUS_OVERRIDE) and type(CHAT_FOCUS_OVERRIDE.HasFocus)=="function" and CHAT_FOCUS_OVERRIDE:HasFocus() then return CHAT_FOCUS_OVERRIDE end
end
function A:InstallQuestLogChatCompatibility()
    local wim=WIM
    if not self.readable(wim) then return end
    local state=self.questLogChatCompatibility or {};self.questLogChatCompatibility=state
    if not state.wimFocus and type(wim.RegisterWidgetTrigger)=="function" then
        local ok=pcall(wim.RegisterWidgetTrigger,"msg_box","whisper,chat,w2w","OnEditFocusLost",function(box)
            if A.questLogShareHover then A.questLogShareDraft=A:CaptureQuestLogChatDraft(box) end
        end)
        state.wimFocus=ok
    end
    if not state.wimLinks and type(wim.RegisterItemRefHandler)=="function" then
        -- Register just our namespace, preserving WIM's other addon/item links.
        local ok=pcall(wim.RegisterItemRefHandler,"addon:SPQLOG",function(link)
            if not A.public(link,"string") then return end
            local token=link:match("^addon:SPQLOG:(.+)$")
            if token then A:OpenQuestLogLink(token) end
        end)
        state.wimLinks=ok
    end
end
function A:QuestLogChatCompatibilitySummary()
    local state=self.questLogChatCompatibility or {}
    return "Quest-log chat: native/Blizzard chat overrides; WIM focus="..tostring(state.wimFocus==true).."; WIM links="..tostring(state.wimLinks==true)
end
