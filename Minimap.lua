local _, A = ...
function A:PositionMinimapButton()
    if not self.minimapButton or not Minimap then return end
    local angle=(self.db.minimapAngle or 140)*math.pi/180
    local radius=(Minimap:GetWidth() or 140)/2+6
    if self.minimapButton.lastAngle==angle and self.minimapButton.lastRadius==radius then return end
    self.minimapButton.lastAngle=angle;self.minimapButton.lastRadius=radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius)
end
function A:UpdateMinimapButton()
    if not self.db or not Minimap then return end
    if not self.minimapButton then
        local b=CreateFrame("Button","SimplyPartyQuestsMinimapButton",Minimap)
        self.minimapButton=b
        b:SetSize(32,32);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(Minimap:GetFrameLevel()+5)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:RegisterForDrag("LeftButton")
        local icon=b:CreateTexture(nil,"BACKGROUND");icon:SetTexture("Interface\\AddOns\\SimplyPartyQuests\\Assets\\Icon")
        icon:SetSize(20,20);icon:SetPoint("CENTER",0,1);icon:SetTexCoord(0.07,0.93,0.07,0.93)
        local border=b:CreateTexture(nil,"OVERLAY");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(54,54);border:SetPoint("TOPLEFT",0,0)
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:SetScript("OnClick",function(_,key)
            if IsShiftKeyDown and IsShiftKeyDown() then A:RefreshParty()
            elseif key=="RightButton" then A:OpenSettings()
            else A:TogglePartyTracker() end
        end)
        b:SetScript("OnEnter",function()
            if not GameTooltip or type(GameTooltip.AddLine)~="function" then return end
            GameTooltip:SetOwner(b,"ANCHOR_LEFT");GameTooltip:ClearLines()
            GameTooltip:AddLine("Party Quests",1,0.82,0)
            local tabbed=A.TrackerTabsRequested and A:TrackerTabsRequested()
            GameTooltip:AddLine(tabbed and "Left-click: open party quests / switch tabs" or "Left-click: show / hide party quests",1,1,1)
            GameTooltip:AddLine("Right-click: settings",1,1,1)
            GameTooltip:AddLine("Shift-click: refresh party quests",1,1,1)
            GameTooltip:AddLine("Drag to move around the minimap",0.7,0.7,0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() if GameTooltip and type(GameTooltip.Hide)=="function" then GameTooltip:Hide() end end)
        b:SetScript("OnDragStart",function()
            if GameTooltip and type(GameTooltip.Hide)=="function" then GameTooltip:Hide() end
            b:SetScript("OnUpdate",function()
                local x,y=GetCursorPosition()
                local scale=Minimap:GetEffectiveScale()
                local cx,cy=Minimap:GetCenter()
                if not cx or not cy or not scale or scale==0 then return end
                local dx,dy=x/scale-cx,y/scale-cy
                local angle
                if math.atan2 then angle=math.atan2(dy,dx)
                elseif dx~=0 then angle=math.atan(dy/dx)+(dx<0 and math.pi or 0)
                else angle=dy>=0 and math.pi/2 or -math.pi/2 end
                A.db.minimapAngle=angle*180/math.pi;A:PositionMinimapButton()
            end)
        end)
        local function stop() b:SetScript("OnUpdate",nil) end
        b:SetScript("OnDragStop",stop);b:SetScript("OnHide",stop)
    end
    self:PositionMinimapButton()
    self.minimapButton:SetShown(not self.db.hideMinimapButton)
end
