local _,A=...
local function combat() return InCombatLockdown and InCombatLockdown() end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...)
    if ok and not A.secret(v) then return v end
end
local function number(v) return A.public(v,"number") and v==v and math.abs(v)<100000 end
-- Read named UI geometry only. Never import Questie's runtime modules, parent
-- our pane to its tracker, or change its anchors, scripts, settings or children.
function A:QuestieDockIsSolo()
    return not next(self.members or {}) and not self.demo
end
function A:QuestieDockCollapsed()
    local q=self.questieCompatibility
    local rest=self:QuestieDockIsSolo() and q.dockSoloExpanded~=true or (not self:QuestieDockIsSolo() and self.db.trackerCollapsed==true)
    if combat() then
        if q.dockInCombat then return q.dockCombatCollapsed==true end
        return self.db.combatAutoHide~=false or rest
    end
    return rest
end
function A:ReadQuestieDockRect()
    local target=Questie_BaseFrame
    if not target or call(target.IsShown,target)~=true then return end
    local scale=call(target.GetEffectiveScale,target)
    local uiScale=UIParent and call(UIParent.GetEffectiveScale,UIParent)
    if not number(scale) or not number(uiScale) or scale<=0 or uiScale<=0 then return end
    local left,right,top,bottom=call(target.GetLeft,target),call(target.GetRight,target),call(target.GetTop,target),call(target.GetBottom,target)
    if not number(left) or not number(right) or not number(top) or not number(bottom) or right<=left or top<=bottom then return end
    local ratio=scale/uiScale
    left,right,top,bottom=left*ratio,right*ratio,top*ratio,bottom*ratio
    -- The fill is inset from the frame bounds. Join the visible fills rather
    -- than adding a gap between two already-inset backdrop rectangles.
    local backdrop=call(target.GetBackdrop,target)
    local insets=self.readable(backdrop) and self.readable(backdrop.insets) and backdrop.insets or nil
    local function inset(key)
        local value=insets and insets[key]
        return (number(value) and value>=0 and value<=32 and value or 4)*ratio
    end
    local padding={left=inset("left"),right=inset("right"),top=inset("top"),bottom=inset("bottom")}
    local edge=self.readable(backdrop) and backdrop.edgeSize
    edge=(number(edge) and edge>=0 and edge<=64 and edge or 16)*ratio
    local sw,sh=call(UIParent.GetWidth,UIParent),call(UIParent.GetHeight,UIParent)
    if not number(sw) or not number(sh) or sw<=0 or sh<=0 then return end
    local width=math.max(320,math.min(640,self.db.sidebarWidth or 420))
    local solo=self:QuestieDockIsSolo()
    local q=self.questieCompatibility
    local compact=self:QuestieDockCollapsed()
    if compact then width=180 end
    local side=self.db.trackerSide=="right" and "right" or "left"
    local leftEdge,rightEdge=left+padding.left+padding.right,right-padding.right-padding.left
    local roomLeft,roomRight=leftEdge,sw-rightEdge
    if side=="left" and roomLeft<width and roomRight>roomLeft then side="right"
    elseif side=="right" and roomRight<width and roomLeft>roomRight then side="left" end
    local room=side=="left" and roomLeft or roomRight
    if room<(compact and 180 or 320) then return end -- retain the standalone fallback if neither side fits
    width=math.min(width,room)
    local s=self.questieCompatibility
    local height=top-bottom
    if height>=128 then s.dockExpandedHeight=height else height=s.dockExpandedHeight or 420 end
    height=math.min(math.max(128,height),sh-16)
    local header=Questie_HeaderFrame
    local label=header and self.readable(header.trackedQuests) and header.trackedQuests.label
    local title=label and type(label.GetTop)=="function" and label or header
    local headerShown=header and call(header.IsShown,header)==true
    local headerTop=headerShown and title and call(title.GetTop,title)
    local hs=title and call(title.GetEffectiveScale,title)
    if headerShown and not number(headerTop) then headerTop=call(header.GetTop,header);hs=call(header.GetEffectiveScale,header) end
    local titleInset=10*ratio
    if number(headerTop) and number(hs) and hs>0 and math.abs(headerTop*hs/uiScale-top)<64 then titleInset=math.max(padding.top,top-headerTop*hs/uiScale) end
    top=math.max(48,math.min(sh-4,top))
    if top<128 then return end
    height=math.min(height,top-4)
    if not compact and top-bottom>=128 then height=math.min(height,top-bottom) end
    local x=side=="left" and leftEdge-width or rightEdge
    return {target=target,x=x,top=top,width=width,height=height,side=side,compact=compact,solo=solo,scale=ratio,
        padding=padding,edge=edge,titleInset=titleInset}
end
function A:RefreshQuestieDockTarget()
    local s=self.questieCompatibility
    local solo=self:QuestieDockIsSolo()
    if s.dockWasSolo~=solo then
        s.dockWasSolo=solo;s.dockSoloExpanded=nil;s.dockSoloCombatExpanded=nil
        self.integration.dirty=true;self.integration.due=nil
    end
    local requested=self.db.displayMode=="blizzard" and self:QuestieOwnsTracker()
    local rect=requested and (not s.dockRetryAt or GetTime()>=s.dockRetryAt) and self:ReadQuestieDockRect() or nil
    -- Do not move a formerly Blizzard-attached pane into a different layout
    -- during lockdown. An already-independent dock may follow Questie normally.
    if combat() and not s.dockActive then rect=nil end
    s.dockRect=rect;s.dockReady=rect~=nil
end
function A:QuestieDockActive()
    local s=self.questieCompatibility
    return not not (s and s.dockReady and self.db and self.db.displayMode=="blizzard" and self:QuestieOwnsTracker())
end
function A:ApplyQuestieDockPosition(rect)
    local q,f=self.questieCompatibility,self.sidebar
    if not f then return end
    if q.dockX~=rect.x or q.dockTop~=rect.top then
        f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",rect.x,rect.top)
        q.dockX,q.dockTop=rect.x,rect.top
    end
end
-- Geometry only: runs before the ordinary 150ms work budget. Never rebuild
-- quest rows, query progress, or write to Questie's frames while following it.
function A:QuestieDockPositionTick()
    local q,f=self.questieCompatibility,self.sidebar
    if not q or not q.dockActive or not f or not f:IsShown() or not self:QuestieDockActive() then return end
    if combat() and call(f.IsProtected,f)==true then return end
    local rect=self:ReadQuestieDockRect()
    if not rect or not q.dockRect or rect.width~=q.dockRect.width or rect.side~=q.dockRect.side then return end
    self:ApplyQuestieDockPosition(rect)
end
local function rgba(frame,method)
    local fn=frame and frame[method]
    if type(fn)~="function" then return end
    local ok,r,g,b,a=pcall(fn,frame)
    if not ok then return end
    for _,v in ipairs({r,g,b,a}) do if not number(v) or v<0 or v>1 then return end end
    if not number(r) or not number(g) or not number(b) or not number(a) then return end
    return r,g,b,a
end
function A:ReadQuestieDockAppearance()
    local target=Questie_BaseFrame
    local p=self.readable(Questie) and self.readable(Questie.db) and self.readable(Questie.db.profile) and Questie.db.profile or nil
    local r,g,b,a=rgba(target,"GetBackdropColor")
    if not r then
        local c=p and self.readable(p.trackerBackdropColor) and p.trackerBackdropColor
        if c and p.trackerBackdropEnabled==true and p.trackerBackdropFader~=true and number(c.r) and number(c.g) and number(c.b) and number(c.a) then
            r,g,b,a=math.max(0,math.min(1,c.r)),math.max(0,math.min(1,c.g)),math.max(0,math.min(1,c.b)),math.max(0,math.min(1,c.a))
        else r,g,b,a=0,0,0,0 end
    end
    if p and p.trackerBackdropEnabled==false then a=0 end
    local br,bg,bb,ba=rgba(target,"GetBackdropBorderColor")
    if not br then br,bg,bb,ba=1,1,1,(p and p.trackerBorderEnabled==true and a or 0) end
    if p and (p.trackerBackdropEnabled==false or p.trackerBorderEnabled==false) then ba=0 end
    local alpha=target and call(target.GetEffectiveAlpha,target)
    local parentAlpha=UIParent and call(UIParent.GetEffectiveAlpha,UIParent)
    if not number(alpha) then alpha=target and call(target.GetAlpha,target) end
    if not number(parentAlpha) or parentAlpha<=0 then parentAlpha=1 end
    alpha=number(alpha) and math.max(0,math.min(1,alpha/parentAlpha)) or 1
    return r,g,b,a,br,bg,bb,ba,alpha
end
function A:OpenQuestieDockMenu()
    local f=self.sidebar
    if not f or not f:IsShown() then return end
    local menu=self.questieDockMenu
    if not menu then
        menu=CreateFrame("Frame","SimplyPartyQuestsDockMenu",UIParent,"BackdropTemplate")
        self.questieDockMenu=menu
        menu:SetSize(154,112);menu:SetFrameStrata("DIALOG");menu:EnableMouse(true)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        menu:SetBackdropColor(0.06,0.06,0.06,0.95)
        local choices={{"Share quests",function(draft) A:OpenQuestLogShare(draft) end},
            {"Refresh",function() A:RefreshParty() end},{"Settings",function() A:OpenSettings() end}}
        menu.buttons={}
        for i,choice in ipairs(choices) do
            local button=CreateFrame("Button",nil,menu,"UIPanelButtonTemplate")
            button:SetSize(138,26);button:SetPoint("TOPLEFT",8,-8-(i-1)*32);button:SetText(choice[1])
            local action=choice[2]
            button:SetScript("OnClick",function() local draft=menu.draft;menu:Hide();action(draft) end)
            menu.buttons[i]=button
        end
        menu:SetScript("OnHide",function() menu.draft=nil end)
        menu:SetScript("OnUpdate",function()
            if not A:QuestieDockActive() or not A.sidebar:IsShown() or (menu.dismissAt and GetTime()>menu.dismissAt) then menu:Hide() end
        end)
        menu:Hide()
    end
    if menu:IsShown() then menu:Hide();self.questieCompatibility.dockDraft=nil;return end
    menu.draft=self.questieCompatibility.dockDraft or self:CaptureQuestLogChatDraft()
    self.questieCompatibility.dockDraft=nil
    menu:ClearAllPoints();menu:SetPoint("TOPRIGHT",f.settings,"BOTTOMRIGHT",0,-3)
    menu:SetClampedToScreen(true);menu.dismissAt=GetTime()+12;menu:Show();menu:Raise()
end
function A:StyleQuestieDock()
    local f,q=self.sidebar,self.questieCompatibility
    if not q.dockStyle then
        local font,size,flags=f.title:GetFont()
        q.dockStyle={font=font,size=size,flags=flags,settingsClick=f.settings:GetScript("OnClick"),settingsDown=f.settings:GetScript("OnMouseDown")}
        f.questieHeaderClick=f.questieHeaderClick or CreateFrame("Button",nil,f)
        f.questieHeaderClick:SetAllPoints(f.title);f.questieHeaderClick:RegisterForClicks("LeftButtonUp","RightButtonUp")
        local function capture() A.questieCompatibility.dockDraft=A:CaptureQuestLogChatDraft() end
        f.questieHeaderClick:SetScript("OnMouseDown",capture)
        f.settings:SetScript("OnMouseDown",capture)
        f.questieHeaderClick:SetScript("OnClick",function(_,button)
            if button=="RightButton" then A:OpenQuestieDockMenu()
            else A:SetViewCollapsed(not A.sidebar.viewCollapsed) end
        end)
        f.settings:SetScript("OnClick",function() A:OpenQuestieDockMenu() end)
        f.headerArt:Hide();f.share:Hide();f.refresh:Hide()
        f.settings:SetText("...");f.settings:SetSize(20,20)
        f.questieHeaderClick:Show()
        f.questiePlain=true
    end
    local h=Questie_HeaderFrame
    local label=h and self.readable(h.trackedQuests) and h.trackedQuests.label
    if label and type(label.GetFont)=="function" then
        local ok,font,size,flags=pcall(label.GetFont,label)
        if ok and self.public(font,"string") and number(size) and size>0 and size<60 then
            local ratio=q.dockRect and q.dockRect.scale or 1
            size=math.max(8,math.min(32,size*ratio));flags=self.public(flags,"string") and flags or ""
            local signature=font..":"..size..":"..flags
            if q.dockFont~=signature then f.title:SetFont(font,size,flags);q.dockFont=signature end
        end
    elseif q.dockFont~="default" then
        f.title:SetFontObject(GameFontNormalSmall or GameFontNormal);q.dockFont="default"
    end
    local rect=q.dockRect
    local _,size=f.title:GetFont()
    size=number(size) and size or 14
    local inset=rect and rect.titleInset or 10
    local ratio=rect and rect.scale or 1
    local bottom=rect and rect.padding.bottom or 4
    local layout=table.concat({inset,size,ratio,bottom},":")
    if q.dockHeaderLayout~=layout then
        q.dockHeaderLayout=layout
        f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",f,"TOPLEFT",7*ratio,-inset)
        f.collapse:SetSize(16*ratio,16*ratio)
        f.collapse:ClearAllPoints();f.collapse:SetPoint("LEFT",f.title,"RIGHT",5*ratio,0)
        f.settings:SetSize(20*ratio,20*ratio)
        f.settings:ClearAllPoints();f.settings:SetPoint("LEFT",f.collapse,"RIGHT",3*ratio,0)
        f.questieCollapsedHeight=inset+math.max(size,20*ratio)+bottom
        f.questieContentInset=inset+size+6*ratio
        f.scroll:ClearAllPoints();f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",7*ratio,-f.questieContentInset)
    end
end
function A:RestoreQuestieDockStyle()
    local f,q=self.sidebar,self.questieCompatibility
    local saved=q.dockStyle
    if not f or not saved then return end
    q.dockStyle=nil;q.dockAppearance=nil;q.dockFont=nil;q.dockCollapseState=nil;q.dockHeaderLayout=nil;q.dockBackdropLayout=nil
    f.questiePlain=nil;f.questieContentInset=nil;f.questieCollapsedHeight=nil;f:SetAlpha(1);f.headerOffset=nil
    if saved.font and saved.size then f.title:SetFont(saved.font,saved.size,saved.flags) end
    f.headerArt:Show();f.share:Show();f.refresh:Show()
    f.collapse:SetSize(16,16)
    f.settings:SetText("Settings");f.settings:SetSize(56,22);f.settings:SetScript("OnClick",saved.settingsClick);f.settings:SetScript("OnMouseDown",saved.settingsDown)
    if f.questieHeaderClick then f.questieHeaderClick:Hide() end
    if self.questieDockMenu then self.questieDockMenu:Hide() end
    if f.trackerBackground.questieArt then f.trackerBackground.questieArt:Hide() end
    f.trackerBackground.art:Show();f.trackerBackground:SetAlpha(1)
end

function A:SyncQuestieDockBackground()
    local f=self.sidebar
    if not f or not f.trackerBackground then return end
    local bg,q=f.trackerBackground,self.questieCompatibility
    if not bg.questieArt then
        bg.questieArt=CreateFrame("Frame",nil,bg,"BackdropTemplate");bg.questieArt:SetAllPoints(bg)
    end
    local rect=q.dockRect
    local p=rect and rect.padding or {left=4,right=4,top=4,bottom=4}
    local edge=rect and rect.edge or 16
    local layout=table.concat({p.left,p.right,p.top,p.bottom,edge},":")
    if q.dockBackdropLayout~=layout then
        q.dockBackdropLayout=layout;q.dockAppearance=nil
        bg.questieArt:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,edgeSize=edge,insets=p})
    end
    -- Questie's border already supplies the shared edge. Do not draw another
    -- full edge/corners over it; only change our own backdrop textures.
    for _,name in ipairs({"LeftEdge","RightEdge","TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner"}) do
        local region=bg.questieArt[name]
        if self.readable(region) and type(region.SetShown)=="function" then
            local shared=rect and ((rect.side=="left" and name:find("Right",1,true)) or (rect.side=="right" and name:find("Left",1,true)))
            region:SetShown(not shared)
        end
    end
    bg.art:Hide();bg.questieArt:Show()
    local signature=tostring(f:GetWidth())..":"..tostring(f:GetHeight())
    if q.dockBackground~=signature then
        q.dockBackground=signature;bg:ClearAllPoints();bg:SetPoint("TOPLEFT",f,"TOPLEFT",0,0)
        bg:SetWidth(f:GetWidth());bg:SetHeight(f:GetHeight())
    end
    local r,g,b,a,br,bgColor,bb,ba,alpha=self:ReadQuestieDockAppearance()
    local appearance=table.concat({r,g,b,a,br,bgColor,bb,ba,alpha},":")
    if q.dockAppearance~=appearance then
        q.dockAppearance=appearance
        bg.questieArt:SetBackdropColor(r,g,b,a);bg.questieArt:SetBackdropBorderColor(br,bgColor,bb,ba)
        bg:SetAlpha(alpha);f:SetAlpha(alpha)
    end
    f.trackerBackgroundAlpha=nil;f.backgroundJoinSignature=nil;bg:SetShown(f:IsShown())
end

function A:QuestieDockTick()
    if not self:QuestieDockActive() then return false end
    local q,s=self.questieCompatibility,self.integration
    local rect=q.dockRect
    self:InitTrackerSidebar()
    local f=self.sidebar
    if not q.dockActive then
        q.dockActive=true;s.anchor=nil;s.side=nil;s.appearanceSignature=nil;s.sidebarScale=nil
        s.nativeVisible=false;s.nativeCollapsed=false;s.dirty=true;s.due=nil
        f:SetScale(1)
    end
    if combat() then
        if not q.dockInCombat then
            q.dockInCombat=true
            local restCollapsed
            if rect.solo then restCollapsed=q.dockSoloExpanded~=true else restCollapsed=self.db.trackerCollapsed==true end
            q.dockCombatCollapsed=self.db.combatAutoHide~=false or restCollapsed
            q.dockSoloCombatExpanded=rect.solo and not q.dockCombatCollapsed
        end
    else q.dockInCombat=nil;q.dockCombatCollapsed=nil;q.dockSoloCombatExpanded=nil end
    local collapsed
    if q.dockInCombat then collapsed=q.dockCombatCollapsed else collapsed=not not self.db.trackerCollapsed end
    self:ApplyQuestieDockPosition(rect)
    local signature=table.concat({rect.width,rect.height},":")
    if q.dockGeometry~=signature then
        q.dockGeometry=signature
        f:SetWidth(rect.width);f.heightLimit=rect.height;s.dirty=true;s.due=nil
    end
    self:SetTrackerSidebarHeaderLayout(false)
    self:StyleQuestieDock()
    if rect.solo and not q.dockInCombat then collapsed=q.dockSoloExpanded~=true end
    f.viewCollapsed=collapsed;f.scroll:SetShown(not collapsed);f.collapse:Show()
    if q.dockCollapseState~=collapsed then
        q.dockCollapseState=collapsed
        local atlas=collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
        f.collapse.normal:SetAtlas(atlas);f.collapse.pushed:SetAtlas(atlas.."-pressed")
    end
    local visible=not self.db.trackerHidden and not self.demo and self:ShouldShowPartyView()
    f:SetShown(visible)
    if self.window then self.window:Hide() end
    if visible and s.dirty and (not s.due or GetTime()>=s.due) then
        local ok,err=pcall(function()
            s.entries,s.memberCount=self:BuildTrackerEntries()
            self:RenderTrackerSidebar(s.entries,s.memberCount)
        end)
        if ok then s.dirty=false;s.due=nil;s.lastError=nil
        else
            s.lastError=self.public(err,"string") and err:sub(1,180) or "Questie sidebar render failed"
            f:Hide();f.trackerBackground:Hide();q.dockReady=false;q.dockActive=nil
            q.dockRetryAt=GetTime()+10
            return false
        end
    end
    self:SizeTrackerSidebar();self:SyncQuestieDockBackground()
    s.attached=true;s.status="Questie sidebar "..rect.side
    return true
end
function A:LeaveQuestieDock()
    local q,s=self.questieCompatibility,self.integration
    if not q.dockActive and not q.dockStyle then return end
    self:RestoreQuestieDockStyle()
    q.dockActive=nil;q.dockGeometry=nil;q.dockX=nil;q.dockTop=nil;q.dockBackground=nil;q.dockInCombat=nil;q.dockCombatCollapsed=nil
    q.dockWasSolo=nil;q.dockSoloExpanded=nil;q.dockSoloCombatExpanded=nil
    s.anchor=nil;s.side=nil;s.appearanceSignature=nil;s.sidebarScale=nil;s.nativeCollapsed=nil
    s.dirty=true;s.due=nil
    if self.sidebar then self.sidebar:Hide();self.sidebar.trackerBackground:Hide() end
end
